// supabase/functions/tap-webhook/index.test.ts
function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function assertEquals(actual: unknown, expected: unknown, message?: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      message ??
        `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
import {
  handleRequest,
  mapTapRefundStatus,
  mapTapStatus,
  roundAmount,
} from "./index.ts";
import { testCustomer, testOrder } from "./fixtures.ts";
import { hmacSha256Hex, verifyTapWebhookHash } from "../_shared/tap.ts";

const TEST_SECRET = "local-only-webhook-test-secret";

const charge = {
  id: "ch_123",
  amount: 100,
  currency: "SAR",
  status: "CAPTURED",
  reference: { transaction: testOrder.id, gateway: "gw_1", payment: "pay_1" },
  transaction: { created: "2026-01-01T00:00:00Z" },
  card: { brand: "Visa", last_four: "4242", name: "A Customer" },
};

const transaction = {
  provider_reference: "ch_123",
  amount: testOrder.grand_total,
  currency_code: testOrder.currency_code,
  order_id: testOrder.id,
  subscription_id: null,
};

function createDeps(overrides: {
  txRows?: any[];
  orderRows?: any[];
  subRows?: any[];
  refundRows?: any[];
}) {
  const calls: { path: string; method: string; body: any }[] = [];
  const eventIds = new Set<string>();

  const fetch = async (path: string, init?: any) => {
    calls.push({ path, method: init?.method ?? "GET", body: init?.body });

    if (path.includes("payment_transactions")) {
      if (init?.method === "PATCH") return [];
      return overrides.txRows ?? [transaction];
    }
    if (path.includes("payment_refunds")) return overrides.refundRows ?? [];
    if (path.includes("complete_payment_refund")) return { ok: true };
    if (path.includes("payment_events")) {
      const eventId = JSON.parse(init?.body ?? "{}").event_id;
      if (eventIds.has(eventId)) {
        throw new Error("duplicate key value violates unique constraint");
      }
      eventIds.add(eventId);
      return [];
    }
    if (path.includes("/orders")) {
      if (init?.method === "PATCH") return [];
      return overrides.orderRows ?? [
        testOrder,
      ];
    }
    if (path.includes("/subscriptions")) {
      return overrides.subRows ?? [];
    }
    if (path.includes("activate_subscription")) return {};
    return [];
  };

  return {
    fetch,
    verifyHash: verifyTapWebhookHash,
    secret: () => TEST_SECRET,
    calls,
  };
}

async function createRequest(body: any, hash?: string): Promise<Request> {
  const currency = String(body?.currency ?? "SAR");
  const decimals = ["BHD", "KWD", "OMR", "JOD"].includes(currency.toUpperCase())
    ? 3
    : 2;
  const amount = Number(body?.amount ?? 0).toFixed(decimals);
  const message = `x_id${
    body?.id ?? ""
  }x_amount${amount}x_currency${currency}x_gateway_reference${
    body?.reference?.gateway ?? ""
  }x_payment_reference${body?.reference?.payment ?? ""}x_status${
    body?.status ?? ""
  }x_created${body?.transaction?.created ?? body?.created ?? ""}`;
  const signature = hash ?? await hmacSha256Hex(message, TEST_SECRET);
  return new Request("https://example.com/webhook", {
    method: "POST",
    headers: { "Content-Type": "application/json", hashstring: signature },
    body: JSON.stringify(body),
  });
}

Deno.test("1. a non POST request is rejected", async () => {
  const req = new Request("https://example.com/webhook", { method: "GET" });
  const res = await handleRequest(req, createDeps({}) as any);
  assertEquals(res.status, 405);
});

Deno.test("2. an invalid body is rejected", async () => {
  const req = new Request("https://example.com/webhook", {
    method: "POST",
    headers: { "Content-Type": "application/json", hashstring: "x" },
    body: "not json",
  });
  const res = await handleRequest(req, createDeps({}) as any);
  assertEquals(res.status, 400);
});

Deno.test("3. a wrong signature is rejected", async () => {
  const res = await handleRequest(
    await createRequest(charge, "0".repeat(64)),
    createDeps({}) as any,
  );
  assertEquals(res.status, 401);
  const deps = createDeps({});
  await handleRequest(await createRequest(charge, "0".repeat(64)), deps as any);
  assertEquals(
    deps.calls.length,
    0,
    "invalid signatures must cause no database calls",
  );
});

Deno.test("4. a captured event marks the order as paid", async () => {
  assertEquals(testCustomer.email.endsWith(".invalid"), true);
  const deps = createDeps({});
  const res = await handleRequest(await createRequest(charge), deps as any);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.received, true);
  assertEquals(body.ignored, undefined);

  const orderPatch = deps.calls.find(
    (call) => call.method === "PATCH" && call.path.startsWith("/orders"),
  );
  assert(orderPatch, "the order must be updated");
  assertEquals(JSON.parse(orderPatch.body).payment_status, "paid");
});

Deno.test("5. the transaction is marked captured and verified", async () => {
  const deps = createDeps({});
  await handleRequest(await createRequest(charge), deps as any);
  const txPatch = deps.calls.find(
    (call) =>
      call.method === "PATCH" && call.path.includes("payment_transactions"),
  );
  assert(txPatch, "the transaction must be updated");
  const body = JSON.parse(txPatch.body);
  assertEquals(body.status, "captured");
  assertEquals(body.verified_by_server, true);
  assertEquals(body.last_four, undefined);
  assertEquals(body.card_last4, "4242");
});

Deno.test("6. an event for an unknown charge is ignored", async () => {
  const deps = createDeps({ txRows: [] });
  const res = await handleRequest(await createRequest(charge), deps as any);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.ignored, true);
  assert(
    !deps.calls.some((call) => call.method === "PATCH"),
    "nothing may be written for an unknown charge",
  );
});

Deno.test("7. a transaction whose reference does not match is ignored", async () => {
  const deps = createDeps({
    txRows: [{ ...transaction, provider_reference: "ch_other" }],
  });
  const res = await handleRequest(await createRequest(charge), deps as any);
  const body = await res.json();
  assertEquals(body.ignored, true);
  assert(
    !deps.calls.some((call) => call.method === "PATCH"),
    "nothing may be written for a mismatched reference",
  );
});

Deno.test("8. an amount that does not match the transaction is rejected", async () => {
  const deps = createDeps({ txRows: [{ ...transaction, amount: 50 }] });
  const res = await handleRequest(await createRequest(charge), deps as any);
  const body = await res.json();
  assertEquals(body.rejected, "amount_or_currency_mismatch");
  assert(
    !deps.calls.some((call) => call.method === "PATCH"),
    "nothing may be written for a mismatched amount",
  );
});

Deno.test("9. an order total that does not match the charge is rejected", async () => {
  const deps = createDeps({
    orderRows: [{ ...testOrder, grand_total: 42 }],
  });
  const res = await handleRequest(await createRequest(charge), deps as any);
  const body = await res.json();
  assertEquals(body.rejected, "order_amount_or_currency_mismatch");
  assert(!deps.calls.some((call) => call.method === "PATCH"));
});

Deno.test("10. a charge reference cannot update a different order", async () => {
  const deps = createDeps({
    txRows: [{ ...transaction, order_id: "tap-test-order-0002" }],
  });
  const res = await handleRequest(await createRequest(charge), deps as any);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).rejected, "order_reference_mismatch");
  assert(!deps.calls.some((call) => call.method === "PATCH"));
});

Deno.test("11. a failed charge marks the order as failed", async () => {
  const deps = createDeps({});
  const res = await handleRequest(
    await createRequest({ ...charge, status: "FAILED" }),
    deps as any,
  );
  assertEquals(res.status, 200);
  const orderPatch = deps.calls.find(
    (call) => call.method === "PATCH" && call.path.startsWith("/orders"),
  );
  assert(orderPatch);
  assertEquals(JSON.parse(orderPatch.body).payment_status, "failed");
});

Deno.test("12. re-sending the same event is idempotent", async () => {
  const deps = createDeps({});
  const req = await createRequest(charge);
  const first = await handleRequest(req.clone(), deps as any);
  const second = await handleRequest(req.clone(), deps as any);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals((await second.json()).duplicate, true);
  assertEquals(
    deps.calls.filter((call) => call.path.includes("payment_events")).length,
    2,
  );
});

Deno.test("13. the event is recorded after the state was applied", async () => {
  const deps = createDeps({});
  await handleRequest(await createRequest(charge), deps as any);
  const orderIndex = deps.calls.findIndex(
    (call) => call.method === "PATCH" && call.path.startsWith("/orders"),
  );
  const eventIndex = deps.calls.findIndex((call) =>
    call.path.includes("payment_events")
  );
  assert(orderIndex >= 0, "the order must be updated");
  assert(eventIndex >= 0, "the event must be recorded");
  assert(
    orderIndex < eventIndex,
    "the event may only be recorded once the state was applied",
  );
});

Deno.test("14. a captured subscription payment activates the subscription", async () => {
  const deps = createDeps({
    txRows: [{ ...transaction, order_id: null, subscription_id: "sub-1" }],
    subRows: [{ id: "sub-1", plan: { price: 100, currency_code: "SAR" } }],
  });
  const res = await handleRequest(await createRequest(charge), deps as any);
  assertEquals(res.status, 200);
  const activation = deps.calls.find((call) =>
    call.path.includes("activate_subscription")
  );
  assert(activation, "the subscription must be activated");
  assertEquals(
    JSON.parse(activation.body).p_subscription_id,
    "sub-1",
  );
});

Deno.test("15. the status mapping covers the provider states", () => {
  assertEquals(mapTapStatus("CAPTURED"), "captured");
  assertEquals(mapTapStatus("AUTHORIZED"), "authorized");
  assertEquals(mapTapStatus("DECLINED"), "failed");
  assertEquals(mapTapStatus("VOID"), "voided");
  assertEquals(mapTapStatus("SOMETHING_NEW"), "pending");
});

Deno.test("16. the amount rounding follows the currency", () => {
  assertEquals(roundAmount(10, "SAR"), "10.00");
  assertEquals(roundAmount(10.5, "SAR"), "10.50");
  assertEquals(roundAmount(10.5, "KWD"), "10.500");
});

const refund = {
  id: "re_123",
  object: "refund",
  amount: 45,
  currency: "SAR",
  status: "REFUNDED",
  charge_id: "ch_123",
  created: "2026-01-01T00:00:00Z",
  metadata: { udf1: "refund-internal-1" },
  reference: { gateway: "gw_1", payment: "pay_1" },
};

function refundDeps(overrides: { status?: string } = {}) {
  return createDeps({
    txRows: [{ ...transaction, id: "tx-1" }],
    refundRows: [{
      id: "refund-internal-1",
      payment_transaction_id: "tx-1",
      order_id: testOrder.id,
      requested_amount: 45,
      currency_code: "SAR",
      status: overrides.status ?? "pending",
      provider_refund_id: null,
    }],
  });
}

Deno.test("17. a signed completed refund is reconciled through the trusted RPC", async () => {
  assertEquals(mapTapRefundStatus("REFUNDED"), "succeeded");
  const deps = refundDeps();
  const response = await handleRequest(
    await createRequest(refund),
    deps as any,
  );
  assertEquals(response.status, 200);
  const completion = deps.calls.find((call) =>
    call.path.includes("complete_payment_refund")
  );
  assert(completion);
  const body = JSON.parse(completion.body);
  assertEquals(body.p_refund_id, "refund-internal-1");
  assertEquals(body.p_status, "succeeded");
  assertEquals(body.p_confirmed_amount, 45);
  assertEquals(body.p_provider_refund_id, "re_123");
  assertEquals(body.p_provider_metadata.card, undefined);
});

Deno.test("18. an accepted refund stays pending until Tap confirms completion", async () => {
  assertEquals(mapTapRefundStatus("ACCEPTED"), "pending");
  const deps = refundDeps();
  const response = await handleRequest(
    await createRequest({ ...refund, status: "ACCEPTED" }),
    deps as any,
  );
  assertEquals(response.status, 200);
  const completion = deps.calls.find((call) =>
    call.path.includes("complete_payment_refund")
  );
  assert(completion);
  const body = JSON.parse(completion.body);
  assertEquals(body.p_status, "pending");
  assertEquals(body.p_confirmed_amount, null);
});

Deno.test("19. duplicate refund completion webhooks are idempotent", async () => {
  const deps = refundDeps();
  const request = await createRequest(refund);
  const first = await handleRequest(request.clone(), deps as any);
  const second = await handleRequest(request.clone(), deps as any);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals((await second.json()).duplicate, true);
  assertEquals(
    deps.calls.filter((call) => call.path.includes("complete_payment_refund"))
      .length,
    2,
  );
});
