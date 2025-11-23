import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";
import Stripe from "stripe";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

const stripe = stripeSecret
  ? new Stripe(stripeSecret, {
    apiVersion: "2024-06-20",
    httpClient: Stripe.createFetchHttpClient(),
  })
  : null;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceKey || !stripe) {
    return jsonResponse(500, { error: "Payments service not configured" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return jsonResponse(401, { error: "Missing Authorization header" });
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch (_) {
    // ignore
  }

  const orderId: string | undefined = body.orderId;
  const paymentIntentId: string | undefined = body.paymentIntentId;
  if (!orderId || !paymentIntentId) {
    return jsonResponse(400, { error: "orderId and paymentIntentId are required" });
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceKey);

  try {
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return jsonResponse(401, { error: "Unauthorized" });
    }

    const order = await fetchOrder(supabaseAdmin, orderId);
    if (!order || order.user_id !== user.id) {
      return jsonResponse(404, { error: "Order not found" });
    }

    const intent = await stripe.paymentIntents.retrieve(paymentIntentId, {
      expand: ["charges.data.balance_transaction"],
    });

    if (intent.status !== "succeeded") {
      return jsonResponse(400, {
        error: "PaymentIntent not succeeded",
        status: intent.status,
      });
    }

    const latestCharge = intent.latest_charge as string | undefined;
    const chargeId = latestCharge ?? intent.charges?.data?.[0]?.id;

    await upsertPaymentRecord(supabaseAdmin, orderId, intent);
    await updatePaymentIntentRecord(supabaseAdmin, paymentIntentId, intent);
    await supabaseAdmin
      .from("orders")
      .update({ status: "confirmed", updated_at: new Date().toISOString() })
      .eq("id", orderId);

    const payoutResults = await distributeVendorPayouts(
      supabaseAdmin,
      stripe,
      orderId,
      chargeId,
    );

    return jsonResponse(200, {
      status: "paid",
      paymentIntentId: intent.id,
      transferResults: payoutResults,
    });
  } catch (error) {
    console.error("payments-confirm-intent error", error);
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function fetchOrder(client: ReturnType<typeof createClient>, orderId: string) {
  const { data } = await client
    .from("orders")
    .select("id, user_id, currency, total_cents")
    .eq("id", orderId)
    .maybeSingle();
  return data as any;
}

async function upsertPaymentRecord(
  client: ReturnType<typeof createClient>,
  orderId: string,
  intent: Stripe.PaymentIntent,
) {
  const payload = {
    order_id: orderId,
    provider: "stripe",
    provider_ref: intent.id,
    status: "paid",
    amount_cents: intent.amount ?? 0,
    currency: intent.currency?.toUpperCase() ?? "JOD",
    provider_fee_cents: 0,
    raw_response: { payment_intent_id: intent.id },
  };

  const { data: existing } = await client
    .from("payments")
    .select("id")
    .eq("provider_ref", intent.id)
    .maybeSingle();

  if (existing?.id) {
    await client.from("payments").update(payload).eq("id", existing.id);
  } else {
    await client.from("payments").insert(payload);
  }
}

async function updatePaymentIntentRecord(
  client: ReturnType<typeof createClient>,
  paymentIntentId: string,
  intent: Stripe.PaymentIntent,
) {
  await client
    .from("payment_intents")
    .update({
      status: intent.status,
      provider_ref: intent.id,
      client_secret: intent.client_secret,
      updated_at: new Date().toISOString(),
    })
    .eq("provider_ref", paymentIntentId);
}

async function distributeVendorPayouts(
  client: ReturnType<typeof createClient>,
  stripeClient: Stripe,
  orderId: string,
  sourceChargeId?: string,
) {
  const { data: settlements } = await client
    .from("order_vendor_settlements")
    .select("id, vendor_id, net_payout_cents, currency, settled, stripe_transfer_id, metadata")
    .eq("order_id", orderId);

  if (!settlements || settlements.length === 0) {
    return [];
  }

  const vendorIds = settlements.map((row: any) => row.vendor_id);
  const { data: vendors } = await client
    .from("vendors")
    .select("id, stripe_account_id")
    .in("id", vendorIds);

  const vendorAccounts = new Map<string, string>();
  (vendors ?? []).forEach((vendor: any) => {
    if (vendor.stripe_account_id) {
      vendorAccounts.set(vendor.id, vendor.stripe_account_id);
    }
  });

  const results: Array<{ vendorId: string; status: string; message?: string }> = [];

  for (const settlement of settlements) {
    const vendorId = settlement.vendor_id as string;
    const net = Number(settlement.net_payout_cents) ?? 0;
    if (!vendorId || net <= 0) {
      continue;
    }

    if (settlement.settled && settlement.stripe_transfer_id) {
      results.push({ vendorId, status: "skipped", message: "already settled" });
      continue;
    }

    const destination = vendorAccounts.get(vendorId);
    if (!destination) {
      await client
        .from("order_vendor_settlements")
        .update({
          metadata: {
            ...(settlement.metadata ?? {}),
            transfer_error: "missing_stripe_account",
          },
        })
        .eq("id", settlement.id);
      results.push({ vendorId, status: "pending", message: "missing Stripe account" });
      continue;
    }

    try {
      const transfer = await stripeClient.transfers.create({
        amount: net,
        currency: (settlement.currency ?? "JOD").toLowerCase(),
        destination,
        source_transaction: sourceChargeId,
        transfer_group: orderId,
        metadata: {
          order_id: orderId,
          vendor_id: vendorId,
        },
      });

      await client
        .from("order_vendor_settlements")
        .update({
          settled: true,
          settled_at: new Date().toISOString(),
          stripe_transfer_id: transfer.id,
          metadata: {
            ...(settlement.metadata ?? {}),
            stripe_transfer_id: transfer.id,
          },
        })
        .eq("id", settlement.id);

      results.push({ vendorId, status: "transferred" });
    } catch (error) {
      console.error("transfer failure", vendorId, error);
      await client
        .from("order_vendor_settlements")
        .update({
          metadata: {
            ...(settlement.metadata ?? {}),
            transfer_error: error instanceof Error ? error.message : "transfer_failed",
          },
        })
        .eq("id", settlement.id);
      results.push({ vendorId, status: "error", message: error instanceof Error ? error.message : "transfer failed" });
    }
  }

  return results;
}
