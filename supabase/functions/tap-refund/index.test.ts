// supabase/functions/tap-refund/index.test.ts
import { assertEquals, assert } from "jsr:@std/assert";
import { handleRequest } from "./index.ts";

const mockUser = { id: "user-123", email: "staff@test.com" };
const mockTransaction = {
  id: "tx-456",
  order_id: "order-789",
  amount: 100.0,
  currency_code: "SAR",
  status: "captured",
  refunded_at: null,
  branch_id: "branch-001",
};

function createDeps(overrides: {
  user?: any | null;
  staffRows?: any[];
  staffRoleRows?: any[];
  roleRows?: any[];
  permRows?: any[];
  permCheck?: any[];
  txRows?: any[];
  orderRows?: any[];
  claimResult?: any[];
  tapResponse?: any;
  tapError?: Error;
  markResult?: any[];
}) {
  const calls: string[] = [];

  const fetch = async (path: string, _init?: any) => {
    calls.push(path);

    if (path.includes("staff_members")) {
      return overrides.staffRows ?? [];
    }
    if (path.includes("staff_roles")) {
      return overrides.staffRoleRows ?? [];
    }
    if (path.includes("/roles")) {
      return overrides.roleRows ?? [];
    }
    if (path.includes("role_permissions")) {
      return overrides.permRows ?? [];
    }
    if (path.includes("/permissions")) {
      return overrides.permCheck ?? [];
    }
    if (path.includes("payment_transactions")) {
      if (_init?.method === "PATCH") {
        if (path.includes("refunded_at=is.null")) {
          return overrides.claimResult ?? [];
        }
        return overrides.markResult ?? [];
      }
      return overrides.txRows ?? [];
    }
    if (path.includes("/orders")) {
      return overrides.orderRows ?? [];
    }
    return [];
  };

  const tap = async () => {
    if (overrides.tapError) throw overrides.tapError;
    return overrides.tapResponse ?? { id: "refund-001", status: "refunded" };
  };

  const getUser = async () => overrides.user !== undefined ? overrides.user : mockUser;

  return { fetch, tap, getUser, calls };
}

function createRequest(body: any, headers: Record<string, string> = {}): Request {
  return new Request("https://example.com/refund", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

Deno.test("1. Request without authentication is rejected", async () => {
  const deps = createDeps({ user: null });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 401);
});

Deno.test("2. Authenticated user without staff permission is rejected", async () => {
  const deps = createDeps({
    staffRows: [],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 403);
  const body = await res.json();
  assert(body.reason.includes("Not an active staff member"));
});

Deno.test("3. Regular user cannot refund another user's payment", async () => {
  const deps = createDeps({
    staffRows: [],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 403);
});

Deno.test("4. Staff with permission but non-existent transaction is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [],
    orderRows: [],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_nonexistent" }), deps as any);
  assertEquals(res.status, 404);
});

Deno.test("5. chargeId not matching transaction is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [],
    orderRows: [],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_wrong" }), deps as any);
  assertEquals(res.status, 404);
});

Deno.test("6. Zero or negative amount is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123", amount: 0 }), deps as any);
  assertEquals(res.status, 400);
  const body = await res.json();
  assert(body.error.includes("positive"));
});

Deno.test("7. Amount exceeding refundable balance is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123", amount: 999 }), deps as any);
  assertEquals(res.status, 400);
  const body = await res.json();
  assert(body.error.includes("exceeds"));
});

Deno.test("8. Duplicate refund attempt is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [{ ...mockTransaction, refunded_at: "2026-01-01T00:00:00Z" }],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 409);
  const body = await res.json();
  assert(body.error.includes("already refunded"));
});

Deno.test("9. Concurrent refund - second claim fails", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
    claimResult: [],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 409);
  const body = await res.json();
  assert(body.error.includes("already in progress"));
});

Deno.test("10. Tap rejection does not record success", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
    claimResult: [mockTransaction],
    tapError: new Error("Tap API 402: insufficient funds"),
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 502);
});

Deno.test("11. Network failure does not assume success", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
    claimResult: [mockTransaction],
    tapError: new Error("Network timeout"),
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 502);
});

Deno.test("12. Valid staff, valid transaction, valid amount passes with mocked Tap", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
    claimResult: [mockTransaction],
    tapResponse: { id: "refund-001", status: "refunded" },
    markResult: [],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123", amount: 50 }), deps as any);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refundId, "refund-001");
  assertEquals(body.amount, 50);
});

Deno.test("13. No real Tap request is sent during tests", async () => {
  let tapCalled = false;
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
    claimResult: [mockTransaction],
    tapResponse: { id: "refund-001", status: "refunded" },
    markResult: [],
  });
  const originalTap = deps.tap;
  deps.tap = async () => {
    tapCalled = true;
    return originalTap();
  };
  await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assert(tapCalled, "Tap mock should have been called");
});

Deno.test("14. Non-POST method is rejected", async () => {
  const req = new Request("https://example.com/refund", { method: "GET" });
  const deps = createDeps({});
  const res = await handleRequest(req, deps as any);
  assertEquals(res.status, 405);
});

Deno.test("15. Invalid JSON is rejected", async () => {
  const req = new Request("https://example.com/refund", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "not valid json",
  });
  const deps = createDeps({});
  const res = await handleRequest(req, deps as any);
  assertEquals(res.status, 400);
});

Deno.test("16. Missing chargeId is rejected", async () => {
  const deps = createDeps({});
  const res = await handleRequest(createRequest({}), deps as any);
  assertEquals(res.status, 400);
});

Deno.test("17. Transaction with non-refundable status is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [{ ...mockTransaction, status: "pending" }],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 409);
});

Deno.test("18. Staff without branch management is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: "branch-999" }],
    roleRows: [{ code: "manager" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [{ code: "orders.read" }],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 403);
  const body = await res.json();
  assert(body.reason.includes("Does not manage this branch"));
});

Deno.test("19. Owner role bypasses permission check", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "owner" }],
    permRows: [],
    permCheck: [],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
    claimResult: [mockTransaction],
    tapResponse: { id: "refund-001", status: "refunded" },
    markResult: [],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 200);
});

Deno.test("20. Missing required permission is rejected", async () => {
  const deps = createDeps({
    staffRows: [{ id: "staff-1" }],
    staffRoleRows: [{ role_id: "role-1", branch_id: null }],
    roleRows: [{ code: "cashier" }],
    permRows: [{ permission_id: "perm-1" }],
    permCheck: [],
    txRows: [mockTransaction],
    orderRows: [{ branch_id: "branch-001" }],
  });
  const res = await handleRequest(createRequest({ chargeId: "ch_123" }), deps as any);
  assertEquals(res.status, 403);
  const body = await res.json();
  assert(body.reason.includes("Missing required permission"));
});
