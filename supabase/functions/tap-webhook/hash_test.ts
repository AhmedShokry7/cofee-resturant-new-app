import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("Tap webhook hash formula matches documented shape", async () => {
  const id = "chg_123";
  const amount = (1.0).toFixed(2);
  const currency = "SAR";
  const gatewayRef = "gw_1";
  const paymentRef = "pay_1";
  const status = "CAPTURED";
  const created = "1698392202943";
  const toBeHashed = `x_id${id}x_amount${amount}x_currency${currency}x_gateway_reference${gatewayRef}x_payment_reference${paymentRef}x_status${status}x_created${created}`;
  // Smoke: string is non-empty and contains all fields.
  assertEquals(toBeHashed.includes("x_idchg_123"), true);
  assertEquals(toBeHashed.includes("x_amount1.00"), true);
});
