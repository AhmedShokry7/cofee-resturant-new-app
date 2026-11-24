export const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const HASH_RE = /^[0-9a-f]{64}$/;

export function isInvoiceId(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

export function expectedObjectPath(
  invoiceId: string,
  snapshotHash: string,
): string {
  if (!isInvoiceId(invoiceId) || !HASH_RE.test(snapshotHash)) {
    throw new Error("invalid_invoice_identity");
  }
  return `invoices/${invoiceId}/${snapshotHash}.pdf`;
}

export function validateInvoiceSnapshot(
  snapshot: Record<string, any>,
  invoiceType: string,
): void {
  if (
    !snapshot || typeof snapshot !== "object" || !Array.isArray(snapshot.lines)
  ) {
    throw new Error("invalid_invoice_snapshot");
  }
  const seller = snapshot.seller ?? {};
  const testInvoice = invoiceType === "test_simplified";
  if (
    testInvoice &&
    (snapshot.test_only !== true || snapshot.test_qr_structure_only !== true ||
      snapshot.document_watermark !== "TEST ONLY — NOT A TAX INVOICE" ||
      !nonEmpty(seller.seller_label) || !nonEmpty(seller.address_label))
  ) {
    throw new Error("invalid_test_invoice_snapshot");
  }
  if (
    !nonEmpty(seller.legal_name) && !nonEmpty(seller.name_ar) &&
    !nonEmpty(seller.name_en) && !(testInvoice && nonEmpty(seller.seller_label))
  ) {
    throw new Error("seller_identity_missing");
  }
  if (
    invoiceType !== "receipt" && !testInvoice &&
    (!nonEmpty(seller.legal_name) || !nonEmpty(seller.vat_number))
  ) {
    throw new Error("seller_tax_configuration_missing");
  }
  if (
    invoiceType !== "receipt" && !testInvoice &&
    !/^[0-9]{15}$/.test(String(seller.vat_number ?? "").trim())
  ) {
    throw new Error("seller_vat_number_invalid");
  }
  if (
    invoiceType !== "receipt" && !testInvoice && !nonEmpty(seller.address_ar) &&
    !nonEmpty(seller.address_en) && !nonEmpty(seller.address)
  ) {
    throw new Error("seller_address_missing");
  }
  if (!nonEmpty(snapshot.issued_at) || !nonEmpty(snapshot.currency_code)) {
    throw new Error("invoice_header_incomplete");
  }
  if (
    snapshot.lines.length === 0 ||
    !snapshot.lines.every((line: Record<string, any>) =>
      nonEmpty(line.name_ar) || nonEmpty(line.name_en)
    )
  ) {
    throw new Error("invoice_line_name_missing");
  }
  if (
    invoiceType !== "receipt" && invoiceType !== "simplified" &&
    invoiceType !== "test_simplified" &&
    invoiceType !== "standard"
  ) {
    throw new Error("invalid_invoice_type");
  }
}

export function buildZatcaPhaseOneQrPayload(
  snapshot: Record<string, any>,
): string {
  const seller = snapshot.seller ?? {};
  if (snapshot.test_only === true && snapshot.test_qr_structure_only === true) {
    const issuedAt = new Date(snapshot.issued_at);
    if (!Number.isFinite(issuedAt.getTime())) {
      throw new Error("invoice_header_incomplete");
    }
    return encodeTlv([
      [1, String(seller.seller_label ?? "TEST ONLY")],
      [2, "TEST ONLY — NOT A LEGAL VAT NUMBER"],
      [3, issuedAt.toISOString().replace(/\.\d{3}Z$/, "Z")],
      [4, decimal(snapshot.grand_total)],
      [5, decimal(snapshot.vat_amount)],
    ]);
  }
  const issuedAt = new Date(snapshot.issued_at);
  if (
    !nonEmpty(seller.legal_name) ||
    !/^[0-9]{15}$/.test(String(seller.vat_number ?? "").trim()) ||
    !Number.isFinite(issuedAt.getTime())
  ) {
    throw new Error("seller_tax_configuration_missing");
  }
  const timestamp = issuedAt.toISOString().replace(/\.\d{3}Z$/, "Z");
  const fields: [number, string][] = [
    [1, seller.legal_name],
    [2, seller.vat_number],
    [3, timestamp],
    [4, decimal(snapshot.grand_total)],
    [5, decimal(snapshot.vat_amount)],
  ];
  return encodeTlv(fields);
}

function encodeTlv(fields: [number, string][]): string {
  const bytes: number[] = [];
  for (const [tag, value] of fields) {
    const encoded = new TextEncoder().encode(value.trim());
    if (encoded.length > 255) throw new Error(`zatca_qr_field_${tag}_too_long`);
    bytes.push(tag, encoded.length, ...encoded);
  }
  return btoa(String.fromCharCode(...bytes));
}

function decimal(value: unknown): string {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error("invalid_invoice_amount");
  }
  return parsed.toFixed(2);
}

function nonEmpty(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}
