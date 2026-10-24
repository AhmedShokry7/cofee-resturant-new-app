// supabase/functions/tap-webhook/index.test.ts
import { assertEquals, assert } from "jsr:@std/assert";
import { handleRequest, mapTapStatus, roundAmount } from "./index.ts";

const charge = {
  id: "ch_123",
  amount: 100,
  currency: "SAR",
  status: "CAPTURED",
  reference: { gateway: "gw_1", payment: "pay_1" },
  transaction: { created: "2026-01-01T00:00:00Z" },
  card: { brand: "Visa", last_four: "4242", name: "A Customer" },
};

const transaction = {
  provider_reference: "ch_123",
  amount: 100,
  currency_code: "SAR",
  order_id: "order-1",
  subscription_id: null,
};

function createDeps(overrides: {
  txRows?: any[];
  orderRows?: any[];
  subRows?: any[];
  eventInsertFails?: boolean;
  hash?: string;
}) {
  const calls: { path: string; method: string; body: any }[] = [];

  const fetch = async (path: string, init?: any) => {
    calls.push({ path, method: init?.method ?? "GET", body: init?.body });

    if (path.includes("payment_transactions")) {
      if (init?.method === "PATCH") return [];
      return overrides.txRows ?? [transaction];
    }
    if (path.includes("payment_events")) {
      if (overrides.eventInsertFails) throw new Error("duplicate key");
      return [];
    }
    if (path.includes("/orders")) {
      if (init?.method === "PATCH") return [];
      return overrides.orderRows ?? [
        { id: "order-1", grand_total: 100, currency_code: "SAR" },
      ];
    }
    if (path.includes("/subscriptions")) {
      return overrides.subRows ?? [];
    }
    if (path.includes("activate_subscription")) return {};
    return [];
  };

  const hash = async () => overrides.hash ?? "computed-hash";

  return { fetch, hash, secret: () => "secret", calls };
}

function createRequest(body: any, hash = "computed-hash"): Request {
  return new Request("https://example.com/webhook", {
    method: "POST",
    headers: { "Content-Type": "application/json", hashstring: hash },
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
    createRequest(charge, "wrong-hash"),
    createDeps({}) as any,
  );
  assertEquals(res.status, 401);
});

Deno.test("4. a captured event marks the order as paid", async () => {
  const deps = createDeps({});
  const res = await handleRequest(createRequest(charge), deps as any);
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
  await handleRequest(createRequest(charge), deps as any);
  const txPatch = deps.calls.find(
    (call) => call.method === "PATCH" && call.path.includes("payment_transactions"),
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
  const res = await handleRequest(createRequest(charge), deps as any);
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
  const res = await handleRequest(createRequest(charge), deps as any);
  const body = await res.json();
  assertEquals(body.ignored, true);
  assert(
    !deps.calls.some((call) => call.method === "PATCH"),
    "nothing may be written for a mismatched reference",
  );
});

Deno.test("8. an amount that does not match the transaction is rejected", async () => {
  const deps = createDeps({ txRows: [{ ...transaction, amount: 50 }] });
  const res = await handleRequest(createRequest(charge), deps as any);
  const body = await res.json();
  assertEquals(body.rejected, "amount_or_currency_mismatch");
  assert(
    !deps.calls.some((call) => call.method === "PATCH"),
    "nothing may be written for a mismatched amount",
  );
});

Deno.test("9. an order total that does not match the charge is rejected", async () => {
  const deps = createDeps({
    orderRows: [{ id: "order-1", grand_total: 42, currency_code: "SAR" }],
  });
  const res = await handleRequest(createRequest(charge), deps as any);
  const body = await res.json();
  assertEquals(body.rejected, "order_amount_or_currency_mismatch");
});

Deno.test("10. a failed charge marks the order as failed", async () => {
  const deps = createDeps({});
  const res = await handleRequest(
    createRequest({ ...charge, status: "FAILED" }),
    deps as any,
  );
  assertEquals(res.status, 200);
  const orderPatch = deps.calls.find(
    (call) => call.method === "PATCH" && call.path.startsWith("/orders"),
  );
  assert(orderPatch);
  assertEquals(JSON.parse(orderPatch.body).payment_status, "failed");
});

Deno.test("11. a duplicated event is answered as a duplicate", async () => {
  const deps = createDeps({ eventInsertFails: true });
  const res = await handleRequest(createRequest(charge), deps as any);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.duplicate, true);
});

Deno.test("12. the event is recorded after the state was applied", async () => {
  const deps = createDeps({});
  await handleRequest(createRequest(charge), deps as any);
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

Deno.test("13. a captured subscription payment activates the subscription", async () => {
  const deps = createDeps({
    txRows: [{ ...transaction, order_id: null, subscription_id: "sub-1" }],
    subRows: [{ id: "sub-1", plan: { price: 100, currency_code: "SAR" } }],
  });
  const res = await handleRequest(createRequest(charge), deps as any);
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

Deno.test("14. the status mapping covers the provider states", () => {
  assertEquals(mapTapStatus("CAPTURED"), "captured");
  assertEquals(mapTapStatus("AUTHORIZED"), "authorized");
  assertEquals(mapTapStatus("DECLINED"), "failed");
  assertEquals(mapTapStatus("VOID"), "voided");
  assertEquals(mapTapStatus("SOMETHING_NEW"), "pending");
});

Deno.test("15. the amount rounding follows the currency", () => {
  assertEquals(roundAmount(10, "SAR"), "10.00");
  assertEquals(roundAmount(10.5, "SAR"), "10.50");
  assertEquals(roundAmount(10.5, "KWD"), "10.500");
});
