import {
  monotonicPaymentStatus,
  normalizedStatus,
  paymentMatchesTransaction,
} from "./index.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}

Deno.test("Moyasar payment must match server price, currency, and ID", () => {
  const id = "a6fc1e70-d080-4eb7-9570-9d6e5a267b9e";
  const tx = { amount: 12.5, currency_code: "SAR" };
  const payment = { id, amount: 1250, currency: "SAR" };
  assertEquals(paymentMatchesTransaction(payment, tx, id), true);
  assertEquals(
    paymentMatchesTransaction({ ...payment, amount: 1249 }, tx, id),
    false,
  );
  assertEquals(
    paymentMatchesTransaction({ ...payment, currency: "USD" }, tx, id),
    false,
  );
  assertEquals(
    paymentMatchesTransaction(payment, tx, "another-payment-id"),
    false,
  );
});

Deno.test("Moyasar minor units handle three and zero decimal currencies", () => {
  assertEquals(
    paymentMatchesTransaction(
      { id: "jod-id", amount: 12345, currency: "JOD" },
      { amount: 12.345, currency_code: "JOD" },
      "jod-id",
    ),
    true,
  );
  assertEquals(
    paymentMatchesTransaction(
      { id: "jpy-id", amount: 10, currency: "JPY" },
      { amount: 10, currency_code: "JPY" },
      "jpy-id",
    ),
    true,
  );
});

Deno.test("Only completed Moyasar payments are captured", () => {
  assertEquals(normalizedStatus("paid"), "captured");
  assertEquals(normalizedStatus("failed"), "failed");
  assertEquals(normalizedStatus("expired"), "failed");
  assertEquals(normalizedStatus("initiated"), "pending");
  assertEquals(normalizedStatus("authorized"), "pending");
});

Deno.test("A captured payment cannot be downgraded by a stale verification", () => {
  assertEquals(monotonicPaymentStatus("captured", "initiated"), "captured");
  assertEquals(monotonicPaymentStatus("captured", "failed"), "captured");
  assertEquals(monotonicPaymentStatus("pending", "failed"), "failed");
  assertEquals(monotonicPaymentStatus("pending", "paid"), "captured");
});
