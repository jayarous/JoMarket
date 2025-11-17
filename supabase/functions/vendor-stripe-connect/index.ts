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

const defaultReturnUrl = Deno.env.get("STRIPE_ONBOARDING_RETURN_URL") ?? "https://app.jomarket.local/onboarding";
const defaultRefreshUrl = Deno.env.get("STRIPE_ONBOARDING_REFRESH_URL") ?? "https://app.jomarket.local/onboarding/retry";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceKey || !stripe) {
    return jsonResponse(500, { error: "Stripe Connect not configured" });
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

  const vendorId: string | undefined = body.vendorId;
  const returnUrl: string = body.returnUrl ?? defaultReturnUrl;
  const refreshUrl: string = body.refreshUrl ?? defaultRefreshUrl;

  if (!vendorId) {
    return jsonResponse(400, { error: "vendorId is required" });
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

    const vendor = await fetchVendor(supabaseAdmin, vendorId);
    if (!vendor) {
      return jsonResponse(404, { error: "Vendor not found" });
    }

    if (vendor.owner_user_id !== user.id) {
      return jsonResponse(403, { error: "Only vendor owners can manage payouts" });
    }

    let accountId = vendor.stripe_account_id as string | undefined;
    if (!accountId) {
      accountId = await createStripeAccount(stripe, vendor);
      await supabaseAdmin
        .from("vendors")
        .update({ stripe_account_id: accountId })
        .eq("id", vendorId);
    }

    const account = await stripe.accounts.retrieve(accountId);
    await supabaseAdmin
      .from("vendors")
      .update({
        stripe_charges_enabled: account.charges_enabled ?? false,
        stripe_payouts_enabled: account.payouts_enabled ?? false,
        stripe_requirements: account.requirements ?? {},
        updated_at: new Date().toISOString(),
      })
      .eq("id", vendorId);

    let onboardingUrl: string | null = null;
    if (!account.charges_enabled || !account.payouts_enabled) {
      const link = await stripe.accountLinks.create({
        account: accountId,
        refresh_url: refreshUrl,
        return_url: returnUrl,
        type: "account_onboarding",
      });
      onboardingUrl = link.url;
    }

    return jsonResponse(200, {
      accountId,
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
      detailsSubmitted: account.details_submitted,
      requirementsDue: account.requirements?.currently_due ?? [],
      onboardingUrl,
    });
  } catch (error) {
    console.error("vendor-stripe-connect error", error);
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

async function fetchVendor(client: ReturnType<typeof createClient>, vendorId: string) {
  const { data } = await client
    .from("vendors")
    .select("id, owner_user_id, stripe_account_id, stripe_charges_enabled, stripe_payouts_enabled, stripe_requirements, address_id")
    .eq("id", vendorId)
    .maybeSingle();
  return data as any;
}

async function createStripeAccount(stripeClient: Stripe, vendor: any) {
  const country = "JO";
  const account = await stripeClient.accounts.create({
    type: "express",
    country,
    metadata: {
      vendor_id: vendor.id,
    },
    capabilities: {
      transfers: { requested: true },
      card_payments: { requested: true },
    },
    business_profile: {
      mcc: "7299",
      product_description: "JoMarket vendor",
    },
  });
  return account.id;
}
