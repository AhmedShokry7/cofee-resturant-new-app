import {
  buildZatcaPhaseOneQrPayload,
  expectedObjectPath,
  isInvoiceId,
  validateInvoiceSnapshot,
} from "./contract.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function assertThrows(action: () => unknown, message: string): void {
  try {
    action();
  } catch (error) {
    if (error instanceof Error && error.message.includes(message)) return;
    throw error;
  }
  throw new Error(`Expected error containing ${message}`);
}

Deno.test("document paths are deterministic and bound to invoice snapshot identity", () => {
  const id = "123e4567-e89b-42d3-a456-426614174000";
  const hash = "a".repeat(64);
  assertEquals(expectedObjectPath(id, hash), `invoices/${id}/${hash}.pdf`);
  assertThrows(
    () => expectedObjectPath("../other", hash),
    "invalid_invoice_identity",
  );
  assertThrows(() => expectedObjectPath(id, "bad"), "invalid_invoice_identity");
  assertEquals(isInvoiceId("../../another-invoice"), false);
});

Deno.test("registered invoices fail closed when seller legal or VAT data is missing", () => {
  const snapshot = {
    seller: {
      legal_name: "Cafe",
      vat_number: "310000000000003",
      address_en: "Riyadh",
    },
    issued_at: "2026-11-01T10:00:00Z",
    currency_code: "SAR",
    lines: [{ name_ar: "قهوة", quantity: 1, unit_price: 10, line_total: 10 }],
  };
  validateInvoiceSnapshot(snapshot, "simplified");
  assertThrows(
    () =>
      validateInvoiceSnapshot(
        { ...snapshot, seller: { legal_name: "Cafe" } },
        "simplified",
      ),
    "seller_tax_configuration_missing",
  );
  assertThrows(
    () => validateInvoiceSnapshot({ ...snapshot, lines: [] }, "simplified"),
    "invoice_line_name_missing",
  );
  assertThrows(
    () =>
      validateInvoiceSnapshot({
        ...snapshot,
        seller: { legal_name: "Cafe", vat_number: "123", address_en: "Riyadh" },
      }, "simplified"),
    "seller_vat_number_invalid",
  );
  assertThrows(
    () =>
      validateInvoiceSnapshot({
        ...snapshot,
        seller: { legal_name: "Cafe", vat_number: "310000000000003" },
      }, "simplified"),
    "seller_address_missing",
  );
  validateInvoiceSnapshot(
    { ...snapshot, seller: { name_ar: "مقهى" } },
    "receipt",
  );
});

Deno.test("simplified invoice QR uses ZATCA Phase 1 five-tag TLV values", () => {
  const snapshot = {
    seller: {
      legal_name: "مقهى",
      vat_number: "310000000000003",
      address_ar: "الرياض",
    },
    issued_at: "2026-11-01T10:00:01.456Z",
    grand_total: 115,
    vat_amount: 15,
  };
  const bytes = Uint8Array.from(
    atob(buildZatcaPhaseOneQrPayload(snapshot)),
    (character) => character.charCodeAt(0),
  );
  const fields: string[] = [];
  let offset = 0;
  while (offset < bytes.length) {
    const tag = bytes[offset++];
    const length = bytes[offset++];
    if (tag !== fields.length + 1) throw new Error(`Unexpected QR tag ${tag}`);
    fields.push(new TextDecoder().decode(bytes.slice(offset, offset + length)));
    offset += length;
  }
  assertEquals(fields, [
    "مقهى",
    "310000000000003",
    "2026-11-01T10:00:01Z",
    "115.00",
    "15.00",
  ]);
});

Deno.test("test invoice QR is structure-only and uses no legal VAT identifier", () => {
  const snapshot = {
    test_only: true,
    test_run_id: "b105bd82-18df-4e6a-9b10-306d5ed5e1bc",
    test_qr_structure_only: true,
    document_watermark: "TEST ONLY — NOT A TAX INVOICE",
    seller: {
      seller_label: "TEST ONLY — NOT A LEGAL SELLER",
      address_label: "TEST ONLY — NOT A REAL ADDRESS",
      tax_identity_status: "not_a_legal_registration",
    },
    issued_at: "2026-11-24T10:00:01.456Z",
    grand_total: 115,
    vat_amount: 15,
    currency_code: "SAR",
    lines: [{
      name_en: "Test item",
      quantity: 1,
      unit_price: 100,
      line_total: 100,
    }],
  };
  validateInvoiceSnapshot(snapshot, "test_simplified");
  const bytes = Uint8Array.from(
    atob(buildZatcaPhaseOneQrPayload(snapshot)),
    (character) => character.charCodeAt(0),
  );
  const fields: string[] = [];
  let offset = 0;
  while (offset < bytes.length) {
    const tag = bytes[offset++];
    const length = bytes[offset++];
    if (tag !== fields.length + 1) throw new Error(`Unexpected QR tag ${tag}`);
    fields.push(new TextDecoder().decode(bytes.slice(offset, offset + length)));
    offset += length;
  }
  assertEquals(fields, [
    "TEST ONLY — NOT A LEGAL SELLER",
    "TEST ONLY — NOT A LEGAL VAT NUMBER",
    "2026-11-24T10:00:01Z",
    "115.00",
    "15.00",
  ]);
  assertThrows(
    () =>
      validateInvoiceSnapshot(
        { ...snapshot, test_qr_structure_only: false },
        "test_simplified",
      ),
    "invalid_test_invoice_snapshot",
  );
});
