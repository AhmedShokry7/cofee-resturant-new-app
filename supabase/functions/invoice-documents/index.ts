// Server-only generation and short-lived download signing for immutable invoice
// snapshots. Clients never submit a Storage path or PDF body.
import PDFDocument from "npm:pdfkit@0.16.0";
import QRCode from "npm:qrcode@1.5.4";
import { render as shapeAndReorderRtl } from "npm:bidi-shaper@0.1.2";
import regularArabicFontBase64 from "./assets/arabic_regular_font.ts";
import boldArabicFontBase64 from "./assets/arabic_bold_font.ts";
import {
  buildZatcaPhaseOneQrPayload,
  expectedObjectPath,
  HASH_RE,
  isInvoiceId,
  UUID_RE,
  validateInvoiceSnapshot,
} from "./contract.ts";

const BUCKET = "invoice-documents";
const URL_TTL_SECONDS = 300;
const MAX_PDF_BYTES = 10 * 1024 * 1024;

type Json = Record<string, any>;
type Fetcher = typeof fetch;

function nonEmpty(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing_configuration_${name}`);
  return value;
}

function publicApiKey(): string {
  const direct = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY");
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
    return typeof keys.default === "string" ? keys.default : "";
  } catch {
    return "";
  }
}

function serviceRoleKey(): string {
  const direct = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    if (typeof keys.default === "string" && keys.default.length > 0) {
      return keys.default;
    }
  } catch {
    // The legacy environment variable is checked above; fail closed below.
  }
  throw new Error("missing_configuration_SUPABASE_SERVICE_ROLE_KEY");
}

async function rest(
  path: string,
  init: RequestInit = {},
  fetcher: Fetcher = fetch,
): Promise<any> {
  const response = await fetcher(`${env("SUPABASE_URL")}/rest/v1${path}`, {
    ...init,
    headers: {
      apikey: serviceRoleKey(),
      Authorization: `Bearer ${serviceRoleKey()}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  const body = await response.text();
  if (!response.ok) throw new Error(`database_${response.status}`);
  return body ? JSON.parse(body) : null;
}

async function authorize(
  req: Request,
  invoiceId: string,
  fetcher: Fetcher,
): Promise<Json> {
  const apiKey = publicApiKey();
  if (!apiKey) {
    throw new Error("missing_configuration_SUPABASE_PUBLISHABLE_KEY");
  }
  const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)
    ?.[1];
  if (!token) throw new Error("unauthorized");
  const auth = await fetcher(`${env("SUPABASE_URL")}/auth/v1/user`, {
    headers: { apikey: apiKey, Authorization: `Bearer ${token}` },
  });
  if (!auth.ok) throw new Error("unauthorized");
  const response = await fetcher(
    `${env("SUPABASE_URL")}/rest/v1/rpc/invoice_document_access`,
    {
      method: "POST",
      headers: {
        apikey: apiKey,
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_invoice_id: invoiceId }),
    },
  );
  const result = await response.json().catch(() => null);
  if (
    response.status === 404 || result?.code === "P0002" ||
    result?.message === "invoice not found"
  ) {
    throw new Error("invoice_not_found");
  }
  if (!response.ok) {
    if (response.status === 401 || response.status === 403) {
      throw new Error("forbidden");
    }
    throw new Error("authorization_check_failed");
  }
  return result;
}

async function claim(invoiceId: string): Promise<Json> {
  const result = await rest("/rpc/claim_invoice_document_generation", {
    method: "POST",
    body: JSON.stringify({ p_invoice_id: invoiceId }),
  });
  return result as Json;
}

async function sign(path: string, fetcher: Fetcher): Promise<string> {
  if (!/^invoices\/[0-9a-f-]{36}\/[0-9a-f]{64}\.pdf$/i.test(path)) {
    throw new Error("invalid_stored_document_path");
  }
  const response = await fetcher(
    `${env("SUPABASE_URL")}/storage/v1/object/sign/${BUCKET}/${
      path.split("/").map(encodeURIComponent).join("/")
    }`,
    {
      method: "POST",
      headers: {
        apikey: serviceRoleKey(),
        Authorization: `Bearer ${serviceRoleKey()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ expiresIn: URL_TTL_SECONDS }),
    },
  );
  if (!response.ok) throw new Error("document_signing_failed");
  const data = await response.json();
  const signed = data.signedURL ?? data.signedUrl;
  if (typeof signed !== "string") throw new Error("document_signing_failed");
  const normalized = signed.startsWith("/object/sign/")
    ? `/storage/v1${signed}`
    : signed;
  const projectUrl = new URL(env("SUPABASE_URL"));
  const url = new URL(normalized, projectUrl);
  if (
    url.host !== projectUrl.host ||
    !url.pathname.startsWith("/storage/v1/object/sign/")
  ) {
    throw new Error("document_signing_failed");
  }
  return url.toString();
}

async function upload(
  path: string,
  bytes: Uint8Array,
  fetcher: Fetcher,
): Promise<Uint8Array> {
  if (
    bytes.length === 0 || bytes.length > MAX_PDF_BYTES ||
    new TextDecoder().decode(bytes.slice(0, 5)) !== "%PDF-"
  ) {
    throw new Error("invalid_generated_pdf");
  }
  const url = `${env("SUPABASE_URL")}/storage/v1/object/${BUCKET}/${
    path.split("/").map(encodeURIComponent).join("/")
  }`;
  const response = await fetcher(url, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey(),
      Authorization: `Bearer ${serviceRoleKey()}`,
      "Content-Type": "application/pdf",
      "x-upsert": "false",
      "cache-control": "private, max-age=0, no-store",
    },
    body: bytes,
  });
  if (response.ok) return bytes;
  // A prior attempt may have uploaded before failing to persist metadata. The
  // deterministic path is immutable: reuse that server-created object.
  if (response.status === 409) {
    const existing = await fetcher(url, {
      headers: {
        apikey: serviceRoleKey(),
        Authorization: `Bearer ${serviceRoleKey()}`,
      },
    });
    if (!existing.ok) throw new Error("existing_document_unavailable");
    const existingBytes = new Uint8Array(await existing.arrayBuffer());
    if (
      existingBytes.length === 0 || existingBytes.length > MAX_PDF_BYTES ||
      new TextDecoder().decode(existingBytes.slice(0, 5)) !== "%PDF-"
    ) {
      throw new Error("invalid_existing_document");
    }
    // The deterministic path is write-once. If a prior request uploaded the
    // PDF before crashing, persist metadata for that exact object rather than
    // replacing it with potentially different PDF metadata bytes.
    return existingBytes;
  }
  throw new Error("document_upload_failed");
}

async function verifyStoredObject(
  path: string,
  expectedHash: string,
  expectedLength: number,
  fetcher: Fetcher,
): Promise<void> {
  if (
    !HASH_RE.test(expectedHash) || expectedLength < 1 ||
    expectedLength > MAX_PDF_BYTES
  ) {
    throw new Error("invalid_document_metadata");
  }
  const url = `${env("SUPABASE_URL")}/storage/v1/object/${BUCKET}/${
    path.split("/").map(encodeURIComponent).join("/")
  }`;
  const stored = await fetcher(url, {
    headers: {
      apikey: serviceRoleKey(),
      Authorization: `Bearer ${serviceRoleKey()}`,
    },
  });
  if (!stored.ok) throw new Error("stored_document_unavailable");
  const bytes = new Uint8Array(await stored.arrayBuffer());
  if (
    bytes.length !== expectedLength ||
    new TextDecoder().decode(bytes.slice(0, 5)) !== "%PDF-" ||
    await sha256(bytes) !== expectedHash
  ) throw new Error("stored_document_integrity_failed");
}

async function renderInvoice(invoice: Json): Promise<Uint8Array> {
  const snapshot = invoice.snapshot as Json;
  validateInvoiceSnapshot(snapshot, invoice.invoice_type);
  const readFont = (encoded: string): Uint8Array => {
    const binary = atob(encoded.trim());
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  };
  const regular = readFont(regularArabicFontBase64);
  const bold = readFont(boldArabicFontBase64);
  const doc: any = new (PDFDocument as any)({
    size: "A4",
    margin: 42,
    compress: true,
    info: {
      Title: `Invoice ${invoice.invoice_number}`,
      Subject: "Invoice generated from the issued financial snapshot",
      CreationDate: new Date(snapshot.issued_at),
      ModDate: new Date(snapshot.issued_at),
    },
  });
  const chunks: Uint8Array[] = [];
  const complete = new Promise<Uint8Array>((resolve, reject) => {
    doc.on("data", (chunk: Uint8Array) => chunks.push(new Uint8Array(chunk)));
    doc.on("end", () => {
      const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
      const result = new Uint8Array(total);
      let offset = 0;
      for (const chunk of chunks) {
        result.set(chunk, offset);
        offset += chunk.length;
      }
      resolve(result);
    });
    doc.on("error", reject);
  });
  doc.registerFont("Arabic", regular);
  doc.registerFont("ArabicBold", bold);
  const testOnly = invoice.invoice_type === "test_simplified";
  doc.font("ArabicBold").fontSize(20).text(
    shapeAndReorderRtl(
      testOnly
        ? "فاتورة اختبار / Test Invoice"
        : invoice.invoice_type === "receipt"
        ? "إيصال / Receipt"
        : "فاتورة ضريبية / Tax Invoice",
    ),
    { align: "center", features: [] },
  );
  if (testOnly) {
    doc.moveDown(0.2);
    doc.font("ArabicBold").fontSize(18).fillColor("#b00020").text(
      "TEST ONLY — NOT A TAX INVOICE",
      { align: "center", features: [] },
    );
    doc.fillColor("#000000");
  }
  doc.moveDown(0.7);
  const seller = snapshot.seller ?? {};
  const buyer = snapshot.buyer ?? {};
  const header: [string, unknown][] = [
    ["رقم الفاتورة / Invoice", invoice.invoice_number],
    ["التاريخ / Issue date", snapshot.issued_at],
    [
      "البائع / Seller",
      testOnly
        ? seller.seller_label
        : seller.legal_name || seller.name_ar || seller.name_en,
    ],
    ...(testOnly ? [] : [
      ["الرقم الضريبي / VAT number", seller.vat_number] as [string, unknown],
    ]),
    [
      "العنوان / Address",
      testOnly
        ? seller.address_label
        : seller.address_ar ?? seller.address_en ?? seller.address,
    ],
    ["العميل / Buyer", buyer.name],
    ["البريد / Email", buyer.email],
  ];
  for (const [label, value] of header) {
    if (nonEmpty(value)) writeLine(doc, `${label}: ${String(value)}`, true);
  }
  if (invoice.invoice_type === "simplified" || testOnly) {
    const payload = buildZatcaPhaseOneQrPayload(snapshot);
    const qrBytes = await (QRCode as any).toBuffer(payload, {
      type: "png",
      errorCorrectionLevel: "M",
      margin: 1,
      width: 160,
    });
    const qrTop = doc.y;
    doc.image(qrBytes, doc.page.margins.left, qrTop, { width: 88 });
    doc.y = qrTop + 96;
  }
  doc.moveDown(0.5);
  doc.font("ArabicBold").fontSize(11).text("الأصناف / Items", {
    align: "right",
  });
  doc.moveDown(0.25);
  for (const line of snapshot.lines as Json[]) {
    const title = line.name_ar || line.name_en || line.sku || "";
    const opts = Array.isArray(line.options)
      ? line.options.map((option: Json) => option.name_ar || option.name_en)
        .filter(Boolean).join("، ")
      : "";
    const detail = `${title}${opts ? ` (${opts})` : ""} — ${line.quantity} × ${
      money(line.unit_price, snapshot.currency_code)
    } = ${money(line.line_total, snapshot.currency_code)}`;
    writeLine(doc, detail, false);
    if (Number(line.discount ?? 0) > 0) {
      writeLine(
        doc,
        `خصم / Discount: ${money(line.discount, snapshot.currency_code)}`,
        false,
      );
    }
  }
  doc.moveDown(0.5);
  const totals: [string, unknown][] = [
    ["المجموع / Subtotal", snapshot.subtotal],
    ["الخصم / Discount", snapshot.discount_total],
    ["رسوم التوصيل / Delivery", snapshot.delivery_fee],
    ["الوعاء الضريبي / Taxable base", snapshot.taxable_base],
    [
      `ضريبة القيمة المضافة / VAT (${snapshot.tax_rate ?? 0}%)`,
      snapshot.vat_amount,
    ],
    ["إجمالي الضريبة / Total tax", snapshot.tax_total],
    ["الإجمالي / Total", snapshot.grand_total],
  ];
  for (const [label, value] of totals) {
    if (value !== null && value !== undefined) {
      writeLine(
        doc,
        `${label}: ${money(value, snapshot.currency_code)}`,
        label.startsWith("الإجمالي"),
      );
    }
  }
  const payments = Array.isArray(snapshot.payments)
    ? snapshot.payments as Json[]
    : [];
  if (payments.length) {
    doc.moveDown(0.5);
    doc.font("ArabicBold").fontSize(11).text("المدفوعات / Payments", {
      align: "right",
    });
    for (const payment of payments) {
      writeLine(
        doc,
        `${payment.provider ?? ""} ${payment.provider_reference ?? ""} — ${
          money(payment.amount, snapshot.currency_code)
        } (${payment.status ?? ""})`,
        false,
      );
    }
  }
  doc.end();
  const bytes = await complete;
  if (bytes.length > MAX_PDF_BYTES) throw new Error("generated_pdf_too_large");
  return bytes;
}

function writeLine(doc: any, text: string, bold: boolean): void {
  if (doc.y > 755) doc.addPage();
  doc.font(bold ? "ArabicBold" : "Arabic").fontSize(bold ? 11 : 9.5)
    .text(shapeAndReorderRtl(text), {
      align: "right",
      features: [],
      lineGap: 2,
    });
}

function stableJson(value: any): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${
      Object.keys(value).sort().map((key) =>
        `${JSON.stringify(key)}:${stableJson(value[key])}`
      ).join(",")
    }}`;
  }
  return JSON.stringify(value);
}

function money(value: unknown, currency: unknown): string {
  const parsed = Number(value ?? 0);
  if (!Number.isFinite(parsed)) throw new Error("invalid_invoice_amount");
  return `${parsed.toFixed(2)} ${String(currency ?? "")}`;
}

async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

function response(body: Json, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

export async function handleRequest(
  req: Request,
  fetcher: Fetcher = fetch,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return response({ error: "method_not_allowed" }, 405);
  }
  try {
    const body = await req.json();
    const invoiceId = typeof body.invoice_id === "string"
      ? body.invoice_id
      : "";
    if (!isInvoiceId(invoiceId)) {
      return response({ error: "invalid_invoice_id" }, 400);
    }
    const authorized = await authorize(req, invoiceId, fetcher);
    const claimed = await claim(invoiceId);
    if (claimed.status === "generating") {
      return response({ status: "generating", retry_after_seconds: 5 }, 202);
    }
    let path = claimed.object_path;
    if (claimed.status === "claimed") {
      try {
        const snapshot = claimed.snapshot as Json;
        if (stableJson(snapshot) !== stableJson(authorized.snapshot)) {
          throw new Error("invoice_snapshot_mismatch");
        }
        const invoice = { ...authorized, ...claimed };
        invoice.snapshot = snapshot;
        invoice.invoice_type = authorized.invoice_type;
        invoice.invoice_number = authorized.invoice_number;
        invoice.issued_at = authorized.issued_at;
        if (
          !HASH_RE.test(claimed.snapshot_sha256) ||
          !UUID_RE.test(claimed.invoice_id)
        ) {
          throw new Error("invalid_invoice_identity");
        }
        const expected = expectedObjectPath(
          claimed.invoice_id,
          claimed.snapshot_sha256,
        );
        if (path !== expected) throw new Error("invalid_storage_path");
        const bytes = await upload(path, await renderInvoice(invoice), fetcher);
        await rest("/rpc/complete_invoice_document_generation", {
          method: "POST",
          body: JSON.stringify({
            p_invoice_id: invoiceId,
            p_object_path: path,
            p_content_sha256: await sha256(bytes),
            p_content_length: bytes.length,
          }),
        });
      } catch (error) {
        const code =
          error instanceof Error && /^[a-z0-9_]{1,64}$/i.test(error.message)
            ? error.message
            : "generation_failed";
        try {
          await rest("/rpc/fail_invoice_document_generation", {
            method: "POST",
            body: JSON.stringify({
              p_invoice_id: invoiceId,
              p_error_code: code,
            }),
          });
        } catch { /* preserve the original safe failure response */ }
        return response({ error: code }, 503);
      }
    } else if (claimed.status !== "ready") {
      return response({ error: "document_unavailable" }, 503);
    } else {
      await verifyStoredObject(
        path,
        claimed.content_sha256,
        claimed.content_length,
        fetcher,
      );
    }
    const expected = expectedObjectPath(
      authorized.invoice_id,
      authorized.snapshot_sha256,
    );
    if (path !== expected) {
      return response({ error: "document_unavailable" }, 503);
    }
    return response({
      status: "ready",
      signed_url: await sign(path, fetcher),
      expires_in: URL_TTL_SECONDS,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "request_failed";
    if (message === "unauthorized") return response({ error: message }, 401);
    if (message === "forbidden" || message === "invoice_not_found") {
      return response({ error: message }, 404);
    }
    return response({
      error: /^[a-z0-9_]{1,64}$/i.test(message) ? message : "request_failed",
    }, 400);
  }
}

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info, x-supabase-api-version",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
  };
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    const result = await handleRequest(req);
    const headers = new Headers(result.headers);
    for (const [key, value] of Object.entries(corsHeaders())) {
      headers.set(key, value);
    }
    return new Response(result.body, { status: result.status, headers });
  });
}
