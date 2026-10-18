// supabase/functions/tap-refund/index.ts
import { getUserFromRequest, serviceFetch, tapRequest } from "../_shared/tap.ts";

const REQUIRED_PERMISSION = "orders.read";
const REFUNDABLE_STATUSES = new Set(["captured", "authorized"]);

interface Dependencies {
  fetch: typeof serviceFetch;
  tap: typeof tapRequest;
  getUser: typeof getUserFromRequest;
}

const defaultDeps: Dependencies = {
  fetch: serviceFetch,
  tap: tapRequest,
  getUser: getUserFromRequest,
};

interface StaffAuthorizationResult {
  authorized: boolean;
  reason: string;
}

export async function checkStaffAuthorization(
  userId: string,
  orderBranchId: string | null,
  fetch: typeof serviceFetch,
): Promise<StaffAuthorizationResult> {
  const staffRows = await fetch(
    `/staff_members?select=id&user_id=eq.${userId}&status=eq.active&limit=1`,
  );
  if (!Array.isArray(staffRows) || staffRows.length === 0) {
    return { authorized: false, reason: "Not an active staff member" };
  }

  const staffId = staffRows[0].id;

  const staffRoleRows = await fetch(
    `/staff_roles?select=role_id,branch_id&staff_id=eq.${staffId}`,
  );
  if (!Array.isArray(staffRoleRows) || staffRoleRows.length === 0) {
    return { authorized: false, reason: "No staff roles assigned" };
  }

  const roleIds = staffRoleRows.map((r: any) => r.role_id);
  const roleIdList = roleIds.map((id: string) => `"${id}"`).join(",");

  const roleRows = await fetch(`/roles?select=code&id=in.(${roleIdList})`);
  if (
    Array.isArray(roleRows) &&
    roleRows.some((r: any) => r.code === "owner")
  ) {
    return { authorized: true, reason: "Owner" };
  }

  const permRows = await fetch(
    `/role_permissions?select=permission_id&role_id=in.(${roleIdList})`,
  );
  if (!Array.isArray(permRows) || permRows.length === 0) {
    return { authorized: false, reason: "No permissions assigned" };
  }

  const permIds = permRows.map((p: any) => p.permission_id);
  const permIdList = permIds.map((id: string) => `"${id}"`).join(",");

  const permCheck = await fetch(
    `/permissions?select=code&id=in.(${permIdList})&code=eq.${REQUIRED_PERMISSION}&limit=1`,
  );
  if (!Array.isArray(permCheck) || permCheck.length === 0) {
    return { authorized: false, reason: "Missing required permission: " + REQUIRED_PERMISSION };
  }

  const managesBranch = staffRoleRows.some(
    (r: any) => r.branch_id === null || r.branch_id === orderBranchId,
  );
  if (!managesBranch) {
    return { authorized: false, reason: "Does not manage this branch" };
  }

  return { authorized: true, reason: "Authorized" };
}

interface TransactionInfo {
  id: string;
  order_id: string;
  amount: number;
  currency_code: string;
  status: string;
  refunded_at: string | null;
  branch_id: string | null;
}

export async function getTransactionInfo(
  chargeId: string,
  fetch: typeof serviceFetch,
): Promise<TransactionInfo | null> {
  const rows = await fetch(
    `/payment_transactions?select=id,order_id,amount,currency_code,status,refunded_at&provider=eq.tap&provider_reference=eq.${encodeURIComponent(chargeId)}&limit=1`,
  );
  if (!Array.isArray(rows) || rows.length === 0) {
    return null;
  }
  const tx = rows[0];
  const orderRows = await fetch(
    `/orders?select=branch_id&id=eq.${encodeURIComponent(tx.order_id)}&limit=1`,
  );
  const branchId = Array.isArray(orderRows) && orderRows.length > 0
    ? orderRows[0].branch_id
    : null;
  return {
    id: tx.id,
    order_id: tx.order_id,
    amount: Number(tx.amount),
    currency_code: tx.currency_code,
    status: tx.status,
    refunded_at: tx.refunded_at,
    branch_id: branchId,
  };
}

export function validateRefundAmount(
  requestedAmount: number | null,
  transactionAmount: number,
): { valid: boolean; amount: number; reason: string } {
  const amount = requestedAmount ?? transactionAmount;
  if (!Number.isFinite(amount) || amount <= 0) {
    return { valid: false, amount: 0, reason: "Amount must be positive" };
  }
  if (amount > transactionAmount) {
    return {
      valid: false,
      amount: 0,
      reason: "Amount exceeds original transaction amount",
    };
  }
  return { valid: true, amount, reason: "Valid" };
}

export async function claimRefund(
  transactionId: string,
  fetch: typeof serviceFetch,
): Promise<boolean> {
  const result = await fetch(
    `/payment_transactions?id=eq.${transactionId}&refunded_at=is.null`,
    {
      method: "PATCH",
      body: JSON.stringify({ refunded_at: new Date().toISOString() }),
    },
  );
  return Array.isArray(result) && result.length > 0;
}

export async function releaseRefundClaim(
  transactionId: string,
  fetch: typeof serviceFetch,
): Promise<void> {
  await fetch(`/payment_transactions?id=eq.${transactionId}`, {
    method: "PATCH",
    body: JSON.stringify({ refunded_at: null }),
  });
}

export async function markRefunded(
  transactionId: string,
  fetch: typeof serviceFetch,
): Promise<void> {
  await fetch(`/payment_transactions?id=eq.${transactionId}`, {
    method: "PATCH",
    body: JSON.stringify({ status: "refunded" }),
  });
}

export async function handleRequest(
  req: Request,
  deps: Dependencies = defaultDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    });
  }

  const user = await deps.getUser(req);
  if (!user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
    });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
    });
  }

  const chargeId = String(body?.chargeId ?? "").trim();
  const requestedAmount = body?.amount != null ? Number(body.amount) : null;

  if (!chargeId) {
    return new Response(JSON.stringify({ error: "chargeId is required" }), {
      status: 400,
    });
  }

  const tx = await getTransactionInfo(chargeId, deps.fetch);
  if (!tx) {
    return new Response(
      JSON.stringify({ error: "Transaction not found" }),
      { status: 404 },
    );
  }

  const auth = await checkStaffAuthorization(user.id, tx.branch_id, deps.fetch);
  if (!auth.authorized) {
    return new Response(
      JSON.stringify({ error: "Forbidden", reason: auth.reason }),
      { status: 403 },
    );
  }

  if (tx.status !== "captured" && tx.status !== "authorized") {
    return new Response(
      JSON.stringify({
        error: "Transaction status does not allow refund",
        status: tx.status,
      }),
      { status: 409 },
    );
  }

  if (tx.refunded_at !== null) {
    return new Response(
      JSON.stringify({ error: "Transaction already refunded" }),
      { status: 409 },
    );
  }

  const amountValidation = validateRefundAmount(requestedAmount, tx.amount);
  if (!amountValidation.valid) {
    return new Response(
      JSON.stringify({ error: amountValidation.reason }),
      { status: 400 },
    );
  }

  const claimed = await claimRefund(tx.id, deps.fetch);
  if (!claimed) {
    return new Response(
      JSON.stringify({ error: "Refund already in progress or completed" }),
      { status: 409 },
    );
  }

  let refund: any;
  try {
    refund = await deps.tap("/refunds", {
      method: "POST",
      body: JSON.stringify({
        charge_id: chargeId,
        amount: amountValidation.amount,
      }),
    });
  } catch (error) {
    await releaseRefundClaim(tx.id, deps.fetch);
    return new Response(
      JSON.stringify({ error: "Provider error", detail: String(error) }),
      { status: 502 },
    );
  }

  if (!refund?.id) {
    await releaseRefundClaim(tx.id, deps.fetch);
    return new Response(
      JSON.stringify({ error: "Provider did not return a refund id" }),
      { status: 502 },
    );
  }

  await markRefunded(tx.id, deps.fetch);

  return new Response(
    JSON.stringify({
      refundId: refund.id,
      status: refund.status,
      chargeId,
      amount: amountValidation.amount,
      currency: tx.currency_code,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

Deno.serve((req) => handleRequest(req));
