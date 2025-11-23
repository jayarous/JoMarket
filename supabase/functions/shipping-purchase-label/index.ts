import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const shippoToken = Deno.env.get("SHIPPO_API_TOKEN") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceKey || !shippoToken) {
    return jsonResponse(500, { error: "Shipping service not configured" });
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

  const shipmentId: string | undefined = body.shipmentId;
  const overrideRateToken: string | undefined = body.rateToken;
  if (!shipmentId) {
    return jsonResponse(400, { error: "shipmentId is required" });
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

    const shipment = await fetchShipment(supabaseAdmin, shipmentId);
    if (!shipment) {
      return jsonResponse(404, { error: "Shipment not found" });
    }

    await assertVendorAccess(supabaseAdmin, shipment.vendor_id, user.id);

    const rateToken = overrideRateToken ?? shipment.shipping_rate_token;
    if (!rateToken) {
      return jsonResponse(400, { error: "Shipping rate token missing" });
    }

    const transaction = await purchaseLabel(rateToken);
    if (transaction.status !== "SUCCESS") {
      const message = transaction.messages?.[0]?.text ?? "Label purchase failed";
      throw new Error(message);
    }

    const carrier = transaction.rate?.provider ?? shipment.carrier ?? null;
    const serviceCode = transaction.rate?.servicelevel?.token ?? shipment.carrier_service_code ?? null;
    const labelUrl = transaction.label_url ?? transaction.label_file ?? null;
    const trackingNumber = transaction.tracking_number ?? shipment.tracking_number ?? null;
    const trackingUrl = transaction.tracking_url_provider ?? transaction.tracking_url ?? null;

    await supabaseAdmin
      .from("shipments")
      .update({
        carrier,
        carrier_service_code: serviceCode,
        tracking_number: trackingNumber,
        label_url: labelUrl,
        label_tracking_url: trackingUrl,
        shipping_rate_token: rateToken,
        updated_at: new Date().toISOString(),
      })
      .eq("id", shipmentId);

    return jsonResponse(200, {
      shipmentId,
      carrier,
      trackingNumber,
      labelUrl,
      trackingUrl,
    });
  } catch (error) {
    console.error("shipping-purchase-label error", error);
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

async function fetchShipment(client: ReturnType<typeof createClient>, shipmentId: string) {
  const { data } = await client
    .from("shipments")
    .select("id, vendor_id, shipping_rate_token, carrier, carrier_service_code, tracking_number")
    .eq("id", shipmentId)
    .maybeSingle();
  return data as any;
}

async function assertVendorAccess(
  client: ReturnType<typeof createClient>,
  vendorId: string | null,
  userId: string,
) {
  if (!vendorId) {
    throw new Error("Shipment missing vendor context");
  }

  const { data: vendor } = await client
    .from("vendors")
    .select("id, owner_user_id")
    .eq("id", vendorId)
    .maybeSingle();

  if (vendor?.owner_user_id === userId) {
    return;
  }

  const { data: staff } = await client
    .from("vendor_staff")
    .select("id")
    .eq("vendor_id", vendorId)
    .eq("user_id", userId)
    .maybeSingle();

  if (!staff) {
    throw new Error("Access denied for shipment");
  }
}

async function purchaseLabel(rateToken: string) {
  const response = await fetch("https://api.goshippo.com/transactions/", {
    method: "POST",
    headers: {
      "Authorization": `ShippoToken ${shippoToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      rate: rateToken,
      label_file_type: "PDF_4X6",
      async: false,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Shippo transaction failed: ${text}`);
  }

  return await response.json();
}
