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
const shippoToken = Deno.env.get("SHIPPO_API_TOKEN") ?? "";
const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

const shipFromAddress = {
  name: Deno.env.get("SHIP_FROM_NAME") ?? "JoMarket Fulfillment",
  street1: Deno.env.get("SHIP_FROM_STREET1") ?? "King Hussein Business Park",
  street2: Deno.env.get("SHIP_FROM_STREET2") ?? undefined,
  city: Deno.env.get("SHIP_FROM_CITY") ?? "Amman",
  state: Deno.env.get("SHIP_FROM_STATE") ?? "Amman",
  zip: Deno.env.get("SHIP_FROM_POSTAL_CODE") ?? "11185",
  country: Deno.env.get("SHIP_FROM_COUNTRY") ?? "JO",
  phone: Deno.env.get("SHIP_FROM_PHONE") ?? undefined,
  email: Deno.env.get("SHIP_FROM_EMAIL") ?? undefined,
};

const stripe = stripeSecret
  ? new Stripe(stripeSecret, {
    apiVersion: "2024-06-20",
    httpClient: Stripe.createFetchHttpClient(),
  })
  : null;

interface CartItemRecord {
  id: string;
  product_id: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  currency: string;
}

interface ProductDimension {
  product_id: string;
  weight_grams: number | null;
  length_cm: number | null;
  width_cm: number | null;
  height_cm: number | null;
}

interface ShippingOption {
  id: string;
  label: string;
  description?: string;
  feeCents: number;
  currency: string;
  carrier?: string;
  serviceLevel?: string;
  serviceCode?: string;
  estimatedDays?: number | null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceKey) {
    return new Response(JSON.stringify({ error: "Missing Supabase configuration" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return new Response(JSON.stringify({ error: "Invalid auth token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let payload: any = {};
  try {
    payload = await req.json();
  } catch (_) {
    // ignore, will validate below
  }

  const cartId: string | undefined = payload.cartId;
  const addressId: string | undefined = payload.addressId;
  const shippingRateToken: string | undefined = payload.shippingRateToken;

  if (!cartId || !addressId) {
    return new Response(JSON.stringify({ error: "cartId and addressId are required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceKey);

  try {
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const address = await fetchAddress(supabaseAdmin, addressId);
    if (!address || address.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Address not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const cart = await fetchCart(supabaseAdmin, cartId);
    if (!cart || cart.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Cart not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const cartItems = await fetchCartItems(supabaseAdmin, cartId);
    if (cartItems.length === 0) {
      return new Response(JSON.stringify({ error: "Cart is empty" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const dimensions = await fetchProductDimensions(
      supabaseAdmin,
      cartItems.map((item) => item.product_id),
    );
    const dimensionLookup = new Map(
      dimensions.map((dim) => [dim.product_id, dim]),
    );

    const profile = await fetchProfile(supabaseAdmin, user.id);

    const subtotalCents = cartItems.reduce((sum, item) => sum + item.total_cents, 0);

    const { normalized, validation } = shippoToken
      ? await validateAddressWithShippo(address, profile)
      : { normalized: address, validation: null };

    if (validation) {
      const validationStatus = validation.is_valid === false
        ? "invalid"
        : validation.is_valid === true
        ? "verified"
        : "unknown";
      await supabaseAdmin
        .from("addresses")
        .update({
          validation_status: validationStatus,
          validation_metadata: validation,
          verified_at: validation.is_valid ? new Date().toISOString() : address.verified_at,
        })
        .eq("id", address.id);
    }

    const shippingOptions = shippoToken
      ? await fetchShippoRates(normalized, cartItems, dimensionLookup)
      : buildFallbackRates();

    const selectedShipping = shippingRateToken
      ? shippingOptions.find((option) => option.id === shippingRateToken)
      : shippingOptions[0];

    const shippingCents = selectedShipping?.feeCents ?? 0;

    let taxCents = 0;
    let taxSource = "static";
    if (stripe && shippingRateToken && selectedShipping) {
      const tax = await calculateStripeTax(stripe, cartItems, normalized, shippingCents).catch(() => null);
      if (tax) {
        taxCents = tax.amount;
        taxSource = tax.source;
      }
    }

    const response = {
      subtotalCents,
      shippingCents,
      taxCents,
      totalCents: subtotalCents + shippingCents + taxCents,
      currency: cartItems[0].currency ?? "JOD",
      shippingOptions,
      selectedRateToken: selectedShipping?.id ?? null,
      address: {
        id: address.id,
        line1: normalized.line1 ?? normalized.street1 ?? address.line1,
        line2: normalized.line2 ?? address.line2,
        city: normalized.city ?? address.city,
        state: normalized.state ?? address.state,
        postalCode: normalized.postal_code ?? normalized.zip ?? address.postal_code,
        country: normalized.country ?? address.country,
        validation: validation,
        validationStatus: validation
          ? validation.is_valid === false
            ? "invalid"
            : validation.is_valid === true
            ? "verified"
            : "unknown"
          : null,
      },
      taxSource,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("checkout-quote error", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function fetchAddress(client: ReturnType<typeof createClient>, addressId: string) {
  const { data } = await client.from("addresses").select("*").eq("id", addressId).maybeSingle();
  return data as any;
}

async function fetchCart(client: ReturnType<typeof createClient>, cartId: string) {
  const { data } = await client.from("carts").select("*").eq("id", cartId).maybeSingle();
  return data as any;
}

async function fetchProfile(client: ReturnType<typeof createClient>, userId: string) {
  const { data } = await client.from("profiles").select("full_name, phone").eq("user_id", userId).maybeSingle();
  return data as any;
}

async function fetchCartItems(
  client: ReturnType<typeof createClient>,
  cartId: string,
): Promise<CartItemRecord[]> {
  const { data } = await client
    .from("cart_items")
    .select("id, product_id, quantity, unit_price_cents, total_cents, currency")
    .eq("cart_id", cartId);
  return (data ?? []) as CartItemRecord[];
}

async function fetchProductDimensions(
  client: ReturnType<typeof createClient>,
  productIds: string[],
): Promise<ProductDimension[]> {
  if (productIds.length === 0) return [];
  const uniqueIds = Array.from(new Set(productIds));
  const { data } = await client
    .from("product_dimensions")
    .select("product_id, weight_grams, length_cm, width_cm, height_cm")
    .in("product_id", uniqueIds);
  return (data ?? []) as ProductDimension[];
}

async function validateAddressWithShippo(address: any, profile: any) {
  const payload = {
    name: profile?.full_name ?? address.label ?? "Customer",
    street1: address.line1,
    street2: address.line2,
    city: address.city,
    state: address.state,
    zip: address.postal_code,
    country: address.country ?? "JO",
    phone: profile?.phone ?? undefined,
    email: undefined,
    validate: true,
  };

  const response = await fetch("https://api.goshippo.com/addresses/", {
    method: "POST",
    headers: buildShippoHeaders(),
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text();
    console.error("Shippo address validation failed", text);
    return { normalized: address, validation: null };
  }

  const result = await response.json();
  const normalized = {
    label: address.label,
    line1: result.street1 ?? address.line1,
    line2: result.street2 ?? address.line2,
    city: result.city ?? address.city,
    state: result.state ?? address.state,
    postal_code: result.zip ?? address.postal_code,
    country: result.country ?? address.country,
  };

  return { normalized, validation: result.validation_results ?? null };
}

async function fetchShippoRates(
  address: any,
  cartItems: CartItemRecord[],
  dimensionLookup: Map<string, ProductDimension>,
): Promise<ShippingOption[]> {
  const parcel = buildParcel(cartItems, dimensionLookup);
  const shipmentPayload = {
    address_from: shipFromAddress,
    address_to: {
      name: address.label ?? "Customer",
      street1: address.line1 ?? address.street1,
      street2: address.line2 ?? address.street2,
      city: address.city,
      state: address.state,
      zip: address.postal_code ?? address.zip,
      country: address.country ?? "JO",
    },
    parcels: [parcel],
    async: false,
  };

  const response = await fetch("https://api.goshippo.com/shipments/", {
    method: "POST",
    headers: buildShippoHeaders(),
    body: JSON.stringify(shipmentPayload),
  });

  if (!response.ok) {
    const text = await response.text();
    console.error("Shippo shipment error", text);
    return buildFallbackRates();
  }

  const shipment = await response.json();
  const rates = shipment?.rates ?? [];

  return rates.slice(0, 6).map((rate: any) => {
    const feeCents = Math.round(parseFloat(rate.amount) * 100);
    const estimatedDays = rate.estimated_days ?? null;
    const serviceCode = rate.servicelevel?.token;
    return {
      id: rate.object_id,
      label: `${rate.provider} ${rate.servicelevel?.name ?? ''}`.trim(),
      description: rate.servicelevel?.token ?? undefined,
      feeCents,
      fee_cents: feeCents,
      currency: rate.currency ?? "JOD",
      carrier: rate.provider,
      serviceLevel: rate.servicelevel?.name,
      serviceCode,
      service_code: serviceCode,
      estimatedDays,
      estimated_days: estimatedDays,
    };
  });
}

function buildParcel(
  items: CartItemRecord[],
  dimensionLookup: Map<string, ProductDimension>,
) {
  let totalWeightGrams = 0;
  let maxLength = 0;
  let maxWidth = 0;
  let maxHeight = 0;

  items.forEach((item) => {
    const dim = dimensionLookup.get(item.product_id);
    const weight = Number(dim?.weight_grams) || 500;
    const length = Number(dim?.length_cm) || 20;
    const width = Number(dim?.width_cm) || 15;
    const height = Number(dim?.height_cm) || 10;

    totalWeightGrams += weight * item.quantity;
    maxLength = Math.max(maxLength, length);
    maxWidth = Math.max(maxWidth, width);
    maxHeight = Math.max(maxHeight, height);
  });

  if (totalWeightGrams === 0) {
    totalWeightGrams = items.reduce((sum, item) => sum + item.quantity, 0) * 500;
  }

  return {
    length: Math.max(maxLength, 20),
    width: Math.max(maxWidth, 15),
    height: Math.max(maxHeight, 10),
    distance_unit: "cm",
    weight: Math.max(totalWeightGrams / 1000, 0.5),
    mass_unit: "kg",
  };
}

function buildFallbackRates(): ShippingOption[] {
  return [
    {
      id: "standard",
      label: "Standard Courier",
      description: "2-3 business days",
      feeCents: 250,
      fee_cents: 250,
      currency: "JOD",
      carrier: "LocalPost",
      serviceLevel: "express",
      service_code: "standard",
      estimatedDays: 3,
      estimated_days: 3,
    },
    {
      id: "express",
      label: "Express Courier",
      description: "Next business day",
      feeCents: 450,
      fee_cents: 450,
      currency: "JOD",
      carrier: "LocalPost",
      serviceLevel: "overnight",
      service_code: "express",
      estimatedDays: 1,
      estimated_days: 1,
    },
  ];
}

function buildShippoHeaders() {
  return {
    "Authorization": `ShippoToken ${shippoToken}`,
    "Content-Type": "application/json",
  };
}

async function calculateStripeTax(
  stripeClient: Stripe,
  items: CartItemRecord[],
  address: any,
  shippingCents: number,
) {
  const lineItems = items.map((item) => ({
    amount: item.total_cents,
    reference: item.product_id,
    tax_behavior: "exclusive",
    tax_code: "txcd_99999999",
  }));

  const params: Stripe.Tax.CalculationCreateParams = {
    currency: items[0]?.currency?.toLowerCase() ?? "jod",
    line_items: lineItems,
    customer_details: {
      address: {
        line1: address.line1 ?? address.street1,
        line2: address.line2 ?? undefined,
        city: address.city,
        state: address.state,
        postal_code: address.postal_code ?? address.zip,
        country: (address.country ?? "JO").toUpperCase(),
      },
    },
  };

  if (shippingCents > 0) {
    params.shipping_cost = { amount: shippingCents, tax_behavior: "exclusive" };
  }

  const calculation = await stripeClient.tax.calculations.create(params);
  return {
    amount: calculation.tax_amount_exclusive ?? calculation.tax_amount_inclusive ?? 0,
    source: "stripe_tax",
  };
}
