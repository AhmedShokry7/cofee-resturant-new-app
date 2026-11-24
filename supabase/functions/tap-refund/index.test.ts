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
import { handleRequest, mapTapRefundStatus } from "./index.ts";

const user = { id: "staff-user", email: "staff@example.test" };
const payment = {
  id: "tx-1",
  order_id: "order-1",
  provider_reference: "ch_1",
  amount: 100,
  currency_code: "SAR",
  status: "captured",
  branch_id: "branch-1",
};
const authorizedStaff = {
  staffRows: [{ id: "staff-1" }],
  staffRoleRows: [{ role_id: "role-1", branch_id: null }],
  roleRows: [{ code: "owner" }],
};

interface Overrides {
  user?: any | null;
  paymentRows?: any[];
  orderRows?: any[];
  staffRows?: any[];
  staffRoleRows?: any[];
  roleRows?: any[];
  permRows?: any[];
  permCheck?: any[];
  claim?: any;
  claimError?: Error;
  completion?: any;
  completionError?: Error;
  tapResponse?: any;
  tapError?: Error;
}

function createDeps(overrides: Overrides = {}) {
  const calls: Array<{ path: string; init?: any }> = [];
  const fetch = async (path: string, init?: any): Promise<any> => {
    calls.push({ path, init });
    if (path.includes("/staff_members")) {
      return overrides.staffRows ?? authorizedStaff.staffRows;
    }
    if (path.includes("/staff_roles")) {
      return overrides.staffRoleRows ?? authorizedStaff.staffRoleRows;
    }
    if (path.startsWith("/roles")) {
      return overrides.roleRows ?? authorizedStaff.roleRows;
    }
    if (path.includes("/role_permissions")) return overrides.permRows ?? [];
    if (path.startsWith("/permissions")) return overrides.permCheck ?? [];
    if (path.startsWith("/payment_transactions")) {
      return overrides.paymentRows ?? [payment];
    }
    if (path.startsWith("/orders")) {
      return overrides.orderRows ?? [{ branch_id: "branch-1" }];
    }
    if (path === "/rpc/claim_payment_refund") {
      if (overrides.claimError) throw overrides.claimError;
      return overrides.claim ?? {
        ok: true,
        refund_id: "refund-internal-1",
        amount: 100,
        currency_code: "SAR",
        charge_id: "ch_1",
        order_id: "order-1",
        branch_id: "branch-1",
      };
    }
    if (path === "/rpc/complete_payment_refund") {
      if (overrides.completionError) throw overrides.completionError;
      return overrides.completion ?? { ok: true };
    }
    return null;
  };
  const tapCalls: Array<{ path: string; init?: any }> = [];
  const tap = async (path: string, init?: any) => {
    tapCalls.push({ path, init });
    if (overrides.tapError) throw overrides.tapError;
    return overrides.tapResponse ?? {
      id: "re_1",
      status: "REFUNDED",
      amount: 100,
      currency: "SAR",
      charge_id: "ch_1",
    };
  };
  const getUser = async () =>
    overrides.user === undefined ? user : overrides.user;
  return { fetch, tap, getUser, calls, tapCalls };
}

function request(body: Record<string, unknown> = {}): Request {
  return new Request("https://example.test/tap-refund", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chargeId: "ch_1",
      idempotencyKey: "request-1",
      ...body,
    }),
  });
}

function rpcBody(call: { init?: any }): Record<string, any> {
  return JSON.parse(call.init.body);
}

Deno.test("requires authentication and a transaction belonging to an order", async () => {
  const unauthenticated = createDeps({ user: null });
  assertEquals(
    (await handleRequest(request(), unauthenticated as any)).status,
    401,
  );

  const missing = createDeps({ paymentRows: [] });
  assertEquals((await handleRequest(request(), missing as any)).status, 404);
});

Deno.test("keeps staff permission and branch authorization before claiming", async () => {
  const noBranch = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: "other-branch" }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
  });
  const response = await handleRequest(request(), noBranch as any);
  assertEquals(response.status, 403);
  assertEquals(
    noBranch.calls.some((call) => call.path === "/rpc/claim_payment_refund"),
    false,
  );

  const noPermission = createDeps({
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [],
  });
  assertEquals(
    (await handleRequest(request(), noPermission as any)).status,
    403,
  );
});

Deno.test("only captured payments can be reserved for refund", async () => {
  const deps = createDeps({
    paymentRows: [{ ...payment, status: "authorized" }],
  });
  const response = await handleRequest(request(), deps as any);
  assertEquals(response.status, 409);
  assertEquals(deps.tapCalls.length, 0);
  assertEquals(
    deps.calls.some((call) => call.path === "/rpc/claim_payment_refund"),
    false,
  );
});

Deno.test("requires an idempotency key and valid SAR precision", async () => {
  const missingKey = createDeps();
  assertEquals(
    (await handleRequest(request({ idempotencyKey: "" }), missingKey as any))
      .status,
    400,
  );

  const extraPrecision = createDeps();
  assertEquals(
    (await handleRequest(request({ amount: 10.005 }), extraPrecision as any))
      .status,
    400,
  );

  const invalidAmount = createDeps();
  assertEquals(
    (await handleRequest(request({ amount: 0 }), invalidAmount as any)).status,
    400,
  );
});

Deno.test("claims through the database RPC and uses its amount for Tap", async () => {
  const deps = createDeps({
    claim: {
      ok: true,
      refund_id: "refund-internal-1",
      amount: 45,
      currency_code: "SAR",
      charge_id: "ch_1",
      order_id: "order-1",
      branch_id: "branch-1",
    },
    tapResponse: {
      id: "re_1",
      status: "REFUNDED",
      amount: 45,
      currency: "SAR",
      charge_id: "ch_1",
    },
  });
  const response = await handleRequest(request({ amount: 50 }), deps as any);
  assertEquals(response.status, 200);
  const claimCall = deps.calls.find((call) =>
    call.path === "/rpc/claim_payment_refund"
  );
  assert(claimCall);
  assertEquals(rpcBody(claimCall).p_amount, 50);
  assertEquals(deps.tapCalls.length, 1);
  const tapBody = JSON.parse(deps.tapCalls[0].init.body);
  assertEquals(tapBody.amount, 45);
  assertEquals(tapBody.metadata.udf1, "refund-internal-1");
  const completeCall = deps.calls.find((call) =>
    call.path === "/rpc/complete_payment_refund"
  );
  assert(completeCall);
  assertEquals(rpcBody(completeCall).p_status, "succeeded");
  assertEquals(rpcBody(completeCall).p_confirmed_amount, 45);
});

Deno.test("defaults to full refund amount from the server payment record", async () => {
  const deps = createDeps();
  const response = await handleRequest(
    request({ amount: undefined }),
    deps as any,
  );
  assertEquals(response.status, 200);
  const claimCall = deps.calls.find((call) =>
    call.path === "/rpc/claim_payment_refund"
  );
  assert(claimCall);
  assertEquals(rpcBody(claimCall).p_amount, payment.amount);
});

Deno.test("does not call Tap when the atomic claim fails", async () => {
  const deps = createDeps({
    claim: { ok: false, reason: "refund_limit_exceeded" },
  });
  const response = await handleRequest(request({ amount: 30 }), deps as any);
  assertEquals(response.status, 409);
  assertEquals(deps.tapCalls.length, 0);
});

Deno.test("reused pending and unknown requests never submit a duplicate Tap refund", async () => {
  for (const status of ["pending", "unknown"]) {
    const deps = createDeps({
      claim: {
        ok: true,
        reused: true,
        status,
        refund_id: "refund-internal-1",
        amount: 100,
        currency_code: "SAR",
        charge_id: "ch_1",
        order_id: "order-1",
        branch_id: "branch-1",
      },
    });
    const response = await handleRequest(request(), deps as any);
    assertEquals(response.status, 202);
    assertEquals(deps.tapCalls.length, 0);
    assertEquals(
      deps.calls.some((call) => call.path === "/rpc/complete_payment_refund"),
      false,
    );
  }
});

Deno.test("a reused successful idempotency key returns the prior result", async () => {
  const deps = createDeps({
    claim: {
      ok: true,
      reused: true,
      status: "succeeded",
      refund_id: "refund-internal-1",
      amount: 100,
      currency_code: "SAR",
      charge_id: "ch_1",
      order_id: "order-1",
      branch_id: "branch-1",
    },
  });
  const response = await handleRequest(request(), deps as any);
  assertEquals(response.status, 200);
  assertEquals(deps.tapCalls.length, 0);
  assertEquals((await response.json()).status, "succeeded");
});

Deno.test("maps official Tap refund response statuses", () => {
  assertEquals(mapTapRefundStatus("REFUNDED"), "succeeded");
  assertEquals(mapTapRefundStatus("PENDING"), "pending");
  assertEquals(mapTapRefundStatus("ACCEPTED"), "pending");
  for (const status of ["DECLINED", "FAILED", "RESTRICTED", "REJECTED"]) {
    assertEquals(mapTapRefundStatus(status), "failed");
  }
  assertEquals(mapTapRefundStatus("TIMED_OUT"), "unknown");
  assertEquals(mapTapRefundStatus("unexpected"), "unknown");
});

Deno.test("pending provider outcome is recorded as pending, not success", async () => {
  const deps = createDeps({
    tapResponse: {
      id: "re_1",
      status: "ACCEPTED",
      amount: 30,
      currency: "SAR",
    },
    claim: {
      ok: true,
      refund_id: "refund-internal-1",
      amount: 30,
      currency_code: "SAR",
      charge_id: "ch_1",
      order_id: "order-1",
      branch_id: "branch-1",
    },
  });
  const response = await handleRequest(request({ amount: 30 }), deps as any);
  assertEquals(response.status, 202);
  assertEquals((await response.json()).status, "pending");
  const completeCall = deps.calls.find((call) =>
    call.path === "/rpc/complete_payment_refund"
  );
  assert(completeCall);
  assertEquals(rpcBody(completeCall).p_status, "pending");
  assertEquals(rpcBody(completeCall).p_confirmed_amount, null);
});

Deno.test("failed provider outcome is recorded as failed", async () => {
  const deps = createDeps({ tapResponse: { id: "re_1", status: "DECLINED" } });
  const response = await handleRequest(request({ amount: 30 }), deps as any);
  assertEquals(response.status, 200);
  const completeCall = deps.calls.find((call) =>
    call.path === "/rpc/complete_payment_refund"
  );
  assert(completeCall);
  assertEquals(rpcBody(completeCall).p_status, "failed");
  assertEquals(rpcBody(completeCall).p_confirmed_amount, null);
});

Deno.test("unknown Tap outcome is reserved for reconciliation", async () => {
  const deps = createDeps({
    tapResponse: { id: "re_1", status: "UNRECOGNIZED" },
  });
  const response = await handleRequest(request({ amount: 30 }), deps as any);
  assertEquals(response.status, 202);
  const completeCall = deps.calls.find((call) =>
    call.path === "/rpc/complete_payment_refund"
  );
  assert(completeCall);
  assertEquals(rpcBody(completeCall).p_status, "unknown");
});

Deno.test("REFUNDED response must match reserved amount and currency", async () => {
  const mismatch = createDeps({
    tapResponse: {
      id: "re_1",
      status: "REFUNDED",
      amount: 29,
      currency: "SAR",
    },
    claim: {
      ok: true,
      refund_id: "refund-internal-1",
      amount: 30,
      currency_code: "SAR",
      charge_id: "ch_1",
      order_id: "order-1",
      branch_id: "branch-1",
    },
  });
  const response = await handleRequest(
    request({ amount: 30 }),
    mismatch as any,
  );
  assertEquals(response.status, 202);
  const completeCall = mismatch.calls.find((call) =>
    call.path === "/rpc/complete_payment_refund"
  );
  assert(completeCall);
  assertEquals(rpcBody(completeCall).p_status, "unknown");
  assertEquals(rpcBody(completeCall).p_confirmed_amount, null);
});

Deno.test("provider timeout remains unknown and does not release the reservation", async () => {
  const deps = createDeps({
    tapError: new Error("sensitive provider response must not leak"),
  });
  const response = await handleRequest(request({ amount: 30 }), deps as any);
  assertEquals(response.status, 202);
  const body = await response.text();
  assert(body.includes('"status":"unknown"'));
  assertEquals(body.includes("sensitive provider response"), false);
  const completeCall = deps.calls.find((call) =>
    call.path === "/rpc/complete_payment_refund"
  );
  assert(completeCall);
  assertEquals(rpcBody(completeCall).p_status, "unknown");
  assertEquals(rpcBody(completeCall).p_confirmed_amount, null);
});

Deno.test("provider completion metadata is allowlisted", async () => {
  const deps = createDeps({
    tapResponse: {
      id: "re_1",
      status: "REFUNDED",
      amount: 100,
      currency: "SAR",
      secret: "must-not-be-stored",
      card: { number: "must-not-be-stored" },
    },
  });
  await handleRequest(request(), deps as any);
  const completeCall = deps.calls.find((call) =>
    call.path === "/rpc/complete_payment_refund"
  );
  assert(completeCall);
  const metadata = rpcBody(completeCall).p_provider_metadata;
  assertEquals(metadata.id, "re_1");
  assertEquals("secret" in metadata, false);
  assertEquals("card" in metadata, false);
});

Deno.test("RPC failures do not trigger a Tap request or report success", async () => {
  const claimFailure = createDeps({ claimError: new Error("db unavailable") });
  assertEquals(
    (await handleRequest(request(), claimFailure as any)).status,
    503,
  );
  assertEquals(claimFailure.tapCalls.length, 0);

  const completionFailure = createDeps({
    completionError: new Error("db unavailable"),
  });
  const response = await handleRequest(request(), completionFailure as any);
  assertEquals(response.status, 202);
  assertEquals((await response.json()).status, "unknown");
  assertEquals(completionFailure.tapCalls.length, 1);
});

Deno.test("supports only POST", async () => {
  const deps = createDeps();
  const response = await handleRequest(
    new Request("https://example.test", { method: "GET" }),
    deps as any,
  );
  assertEquals(response.status, 405);
});
