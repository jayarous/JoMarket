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
    return new Response(
      JSON.stringify({ error: "Payments service not configured" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return new Response(
      JSON.stringify({ error: "Authorization header missing" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  let payload: any = {};
  try {
    payload = await req.json();
  } catch (_) {
    // ignore, validation below
  }

  const orderId: string | undefined = payload.orderId;
  if (!orderId) {
    return new Response(
      JSON.stringify({ error: "orderId is required" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceKey);

  try {
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const order = await fetchOrder(supabaseAdmin, orderId);
    if (!order || order.user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Order not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const orderItems = await fetchOrderItems(supabaseAdmin, orderId);
    if (orderItems.length === 0) {
      throw new Error("Order has no line items");
    }

    const profile = await fetchProfile(supabaseAdmin, user.id);
    let stripeCustomerId = profile?.stripe_customer_id as string | undefined;

    if (!stripeCustomerId) {
      const customer = await stripe.customers.create({
        email: user.email ?? undefined,
        name: profile?.full_name ?? undefined,
        phone: profile?.phone ?? undefined,
        metadata: { supabase_user_id: user.id },
      });
      stripeCustomerId = customer.id;
      await supabaseAdmin
        .from("profiles")
        .update({ stripe_customer_id: stripeCustomerId })
        .eq("user_id", user.id);
    }

    const vendorTotals = aggregateVendorTotals(orderItems);
    await ensureVendorSettlements(
      supabaseAdmin,
      orderId,
      vendorTotals,
      order.currency ?? "JOD",
    );

    const shippingAddress = await fetchAddress(
      supabaseAdmin,
      order.shipping_address_id,
    );

    const intent = await stripe.paymentIntents.create({
      amount: order.total_cents,
      currency: (order.currency ?? "JOD").toLowerCase(),
      customer: stripeCustomerId,
      description: `JoMarket order ${order.order_number}`,
      automatic_payment_methods: { enabled: true },
      transfer_group: orderId,
      metadata: {
        order_id: orderId,
        user_id: user.id,
        vendor_ids: Array.from(vendorTotals.keys()).join(","),
      },
      shipping: shippingAddress
        ? {
          name: shippingAddress.label ?? profile?.full_name ?? "Customer",
          address: {
            line1: shippingAddress.line1,
            line2: shippingAddress.line2 ?? undefined,
            city: shippingAddress.city ?? undefined,
            state: shippingAddress.state ?? undefined,
            postal_code: shippingAddress.postal_code ?? undefined,
            country: shippingAddress.country ?? "JO",
          },
        }
        : undefined,
      automatic_tax: { enabled: true },
    }, { idempotencyKey: `order-${orderId}` });

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: stripeCustomerId },
      { stripeVersion: "2024-06-20" },
    );

    await upsertPaymentIntentRecord(
      supabaseAdmin,
      orderId,
      {
        amount_cents: order.total_cents,
        currency: order.currency,
        status: intent.status,
        client_secret: intent.client_secret,
        provider: "stripe",
        provider_ref: intent.id,
        stripe_customer_id: stripeCustomerId,
      },
    );

    return new Response(
      JSON.stringify({
        paymentIntentId: intent.id,
        clientSecret: intent.client_secret,
        ephemeralKey: ephemeralKey.secret,
        customerId: stripeCustomerId,
        amountCents: order.total_cents,
        currency: order.currency ?? "JOD",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("payments-create-intent error", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

async function fetchOrder(client: ReturnType<typeof createClient>, orderId: string) {
  const { data } = await client
    .from("orders")
    .select("id, user_id, order_number, currency, subtotal_cents, discount_cents, shipping_cents, tax_cents, total_cents, shipping_address_id, shipping_provider")
    .eq("id", orderId)
    .maybeSingle();
  return data as any;
}

async function fetchOrderItems(client: ReturnType<typeof createClient>, orderId: string) {
  const { data } = await client
    .from("order_items")
    .select("id, vendor_id, total_cents")
    .eq("order_id", orderId);
  return (data ?? []) as { vendor_id: string; total_cents: number }[];
}

async function fetchProfile(client: ReturnType<typeof createClient>, userId: string) {
  const { data } = await client
    .from("profiles")
    .select("full_name, phone, stripe_customer_id")
    .eq("user_id", userId)
    .maybeSingle();
  return data as any;
}

async function fetchAddress(client: ReturnType<typeof createClient>, addressId: string | null) {
  if (!addressId) return null;
  const { data } = await client
    .from("addresses")
    .select("id, label, line1, line2, city, state, postal_code, country")
    .eq("id", addressId)
    .maybeSingle();
  return data as any;
}

function aggregateVendorTotals(items: { vendor_id: string; total_cents: number }[]) {
  const map = new Map<string, number>();
  for (const item of items) {
    if (!item.vendor_id) continue;
    const current = map.get(item.vendor_id) ?? 0;
    map.set(item.vendor_id, current + (item.total_cents ?? 0));
  }
  return map;
}

async function ensureVendorSettlements(
  client: ReturnType<typeof createClient>,
  orderId: string,
  vendorTotals: Map<string, number>,
  currency: string,
) {
  if (vendorTotals.size === 0) return;

  const vendorIds = Array.from(vendorTotals.keys());
  const { data: settings } = await client
    .from("vendor_financial_settings")
    .select("vendor_id, commission_rate")
    .in("vendor_id", vendorIds);

  const settingsMap = new Map<string, number>();
  (settings ?? []).forEach((setting: any) => {
    settingsMap.set(setting.vendor_id, Number(setting.commission_rate) || 0);
  });

  const rows = vendorIds.map((vendorId) => {
    const subtotal = vendorTotals.get(vendorId) ?? 0;
    const commissionRate = settingsMap.get(vendorId) ?? 0;
    const commission = Math.round(subtotal * (commissionRate / 100));
    const net = Math.max(subtotal - commission, 0);
    return {
      order_id: orderId,
      vendor_id: vendorId,
      subtotal_cents: subtotal,
      discount_cents: 0,
      tax_cents: 0,
      shipping_cents: 0,
      commission_cents: commission,
      net_payout_cents: net,
      currency: currency,
    };
  });

  if (rows.length === 0) return;

  await client.from("order_vendor_settlements").upsert(rows, {
    onConflict: "order_id,vendor_id",
  });
}

async function upsertPaymentIntentRecord(
  client: ReturnType<typeof createClient>,
  orderId: string,
  record: {
    amount_cents: number;
    currency: string | null;
    status: string;
    client_secret: string | null;
    provider: string;
    provider_ref: string;
    stripe_customer_id?: string;
  },
) {
  const { data: existing } = await client
    .from("payment_intents")
    .select("id")
    .eq("order_id", orderId)
    .maybeSingle();

  const payload = {
    order_id: orderId,
    amount_cents: record.amount_cents,
    currency: record.currency ?? "JOD",
    status: record.status,
    client_secret: record.client_secret,
    provider: record.provider,
    provider_ref: record.provider_ref,
    stripe_customer_id: record.stripe_customer_id,
    updated_at: new Date().toISOString(),
  };

  if (existing?.id) {
    await client.from("payment_intents").update(payload).eq("id", existing.id);
  } else {
    await client.from("payment_intents").insert({ ...payload, created_at: new Date().toISOString() });
  }
}
