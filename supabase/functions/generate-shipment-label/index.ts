import { serve } from "std/http/server.ts";
import { encode as base64Encode, decode as base64Decode } from "std/encoding/base64.ts";
import { PDFDocument, StandardFonts } from "https://esm.sh/pdf-lib@1.17.1?target=deno";
import QRCode from "https://esm.sh/qrcode@1.5.3?target=deno";

type LabelRequest = {
  shipmentId: string;
  vendorName: string;
  orderNumber: string;
  customerName?: string | null;
  customerPhone?: string | null;
  shipmentTracking: string;
  shippingAddress?: string | null;
  items?: string[];
  carrier?: string | null;
};

type LabelResponse = {
  fileName: string;
  base64: string;
  mimeType: string;
};

const PAGE_WIDTH = 4.1 * 72;
const PAGE_HEIGHT = 6 * 72;
const PAGE_MARGIN = 24;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const payload = (await req.json()) as LabelRequest;
    validatePayload(payload);

    const pdfBytes = await buildLabel(payload);
    const body: LabelResponse = {
      fileName: `shipment-${payload.shipmentId}.pdf`,
      base64: base64Encode(pdfBytes),
      mimeType: "application/pdf",
    };

    return new Response(JSON.stringify(body), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("generate-shipment-label error", error);
    const message =
      error instanceof Error ? error.message : "Failed to generate shipment label";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function validatePayload(payload: LabelRequest) {
  if (!payload || typeof payload !== "object") {
    throw new Error("Invalid request payload");
  }
  if (!payload.shipmentId) throw new Error("shipmentId is required");
  if (!payload.vendorName) throw new Error("vendorName is required");
  if (!payload.orderNumber) throw new Error("orderNumber is required");
  if (!payload.shipmentTracking) throw new Error("shipmentTracking is required");
}

async function buildLabel(payload: LabelRequest): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const page = doc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
  const regularFont = await doc.embedFont(StandardFonts.Helvetica);
  const boldFont = await doc.embedFont(StandardFonts.HelveticaBold);

  let cursorY = PAGE_HEIGHT - PAGE_MARGIN;

  const drawLine = (
    text: string,
    { size = 12, bold = false }: { size?: number; bold?: boolean } = {},
  ) => {
    const font = bold ? boldFont : regularFont;
    cursorY -= size + 2;
    page.drawText(text, {
      x: PAGE_MARGIN,
      y: cursorY,
      font,
      size,
    });
  };

  const addSpacer = (value = 8) => {
    cursorY -= value;
  };

  drawLine(payload.vendorName, { size: 18, bold: true });
  addSpacer(2);
  drawLine(`Order #${payload.orderNumber}`, { size: 12 });
  addSpacer(10);
  drawLine("Ship To:", { bold: true });
  drawLine(payload.customerName?.trim() || "Customer", { size: 12 });
  buildAddressLines(payload.shippingAddress).forEach((line) =>
    drawLine(line, { size: 11 })
  );

  if (payload.carrier) {
    addSpacer(2);
    drawLine(`Carrier: ${payload.carrier}`, { size: 11 });
  }
  if (payload.customerPhone) {
    addSpacer(2);
    drawLine(`Phone: ${payload.customerPhone}`, { size: 11 });
  }

  addSpacer(10);
  drawLine("Items:", { bold: true });
  buildItemLines(payload.items).forEach((line) =>
    drawLine(line, { size: 11 })
  );

  // Barcode / QR
  const qrSize = 140;
  const qrPadding = 80;
  const qrDataUrl = await QRCode.toDataURL(payload.shipmentTracking, {
    margin: 1,
    scale: 6,
  });
  const parts = qrDataUrl.split(",");
  const imageBytes = base64Decode(parts[1] ?? "");
  const qrImage = await doc.embedPng(imageBytes);
  page.drawImage(qrImage, {
    x: (PAGE_WIDTH - qrSize) / 2,
    y: qrPadding,
    width: qrSize,
    height: qrSize,
  });

  page.drawText(`Tracking: ${payload.shipmentTracking}`, {
    x: PAGE_MARGIN,
    y: qrPadding - 24,
    font: regularFont,
    size: 11,
  });

  return await doc.save();
}

function buildAddressLines(address?: string | null): string[] {
  if (!address) return ["Address unavailable"];
  return address
    .split(/,|\n/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
    .flatMap((part) => wrapText(part, 48));
}

function buildItemLines(items?: string[]): string[] {
  if (!items || items.length === 0) return ["Item details unavailable"];
  return items
    .slice(0, 5)
    .map((item) => item.trim())
    .filter((item) => item.length > 0)
    .flatMap((item) => wrapText(item, 48));
}

function wrapText(text: string, maxChars: number): string[] {
  if (text.length <= maxChars) return [text];
  const words = text.split(" ");
  const lines: string[] = [];
  let current = "";

  for (const word of words) {
    const candidate = current.length === 0 ? word : `${current} ${word}`;
    if (candidate.length <= maxChars) {
      current = candidate;
    } else {
      if (current.length > 0) lines.push(current);
      current = word;
    }
  }

  if (current.length > 0) lines.push(current);
  return lines;
}
