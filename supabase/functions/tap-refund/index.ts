// Staff-initiated Tap refunds. Financial reservations and final state changes
// are serialized by the database RPCs; this function only calls Tap with the
// amount returned by the successful reservation.
import {
  getUserFromRequest,
  serviceFetch,
  tapRequest,
} from "../_shared/tap.ts";

const REQUIRED_PERMISSION = "orders.read";
const REFUNDABLE_STATUS = "captured";
const TAP_REASON_CODES = new Set([
  "duplicate",
  "fraudulent",
  "requested_by_customer",
]);

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
    `/staff_members?select=id&user_id=eq.${
      encodeURIComponent(userId)
    }&status=eq.active&limit=1`,
  );
  if (!Array.isArray(staffRows) || staffRows.length === 0) {
    return { authorized: false, reason: "Not an active staff member" };
  }

  const staffId = staffRows[0].id;
  const staffRoleRows = await fetch(
    `/staff_roles?select=role_id,branch_id&staff_id=eq.${
      encodeURIComponent(staffId)
    }`,
  );
  if (!Array.isArray(staffRoleRows) || staffRoleRows.length === 0) {
    return { authorized: false, reason: "No staff roles assigned" };
  }

  const roleIds = staffRoleRows.map((row: any) => row.role_id);
  const roleIdList = roleIds.map((id: string) => `"${id}"`).join(",");
  const roleRows = await fetch(`/roles?select=code&id=in.(${roleIdList})`);
  const isOwner = Array.isArray(roleRows) &&
    roleRows.some((row: any) => row.code === "owner");

  const managesBranch = staffRoleRows.some(
    (row: any) => row.branch_id === null || row.branch_id === orderBranchId,
  );
  if (!managesBranch) {
    return { authorized: false, reason: "Does not manage this branch" };
  }
  if (isOwner) return { authorized: true, reason: "Owner" };

  if (roleIds.length === 0) {
    return { authorized: false, reason: "No staff roles assigned" };
  }
  const permRows = await fetch(
    `/role_permissions?select=permission_id&role_id=in.(${roleIdList})`,
  );
  if (!Array.isArray(permRows) || permRows.length === 0) {
    return { authorized: false, reason: "No permissions assigned" };
  }

  const permIds = permRows.map((row: any) => row.permission_id);
  const permIdList = permIds.map((id: string) => `"${id}"`).join(",");
  const permCheck = await fetch(
    `/permissions?select=code&id=in.(${permIdList})&code=eq.${REQUIRED_PERMISSION}&limit=1`,
  );
  if (!Array.isArray(permCheck) || permCheck.length === 0) {
    return {
      authorized: false,
      reason: `Missing required permission: ${REQUIRED_PERMISSION}`,
    };
  }

  return { authorized: true, reason: "Authorized" };
}

interface PaymentInfo {
  id: string;
  order_id: string;
  provider_reference: string;
  amount: number;
  currency_code: string;
  status: string;
  branch_id: string | null;
}

export async function getPaymentInfo(
  chargeId: string,
  fetch: typeof serviceFetch,
): Promise<PaymentInfo | null> {
  const rows = await fetch(
    `/payment_transactions?select=id,order_id,provider_reference,amount,currency_code,status&provider=eq.tap&provider_reference=eq.${
      encodeURIComponent(chargeId)
    }&limit=1`,
  );
  if (!Array.isArray(rows) || rows.length === 0) return null;

  const tx = rows[0];
  const orderRows = await fetch(
    `/orders?select=branch_id&id=eq.${encodeURIComponent(tx.order_id)}&limit=1`,
  );
  const order = Array.isArray(orderRows) ? orderRows[0] : null;
  if (!order || !tx.id || !tx.order_id || !tx.provider_reference) return null;
  return {
    id: String(tx.id),
    order_id: String(tx.order_id),
    provider_reference: String(tx.provider_reference),
    amount: Number(tx.amount),
    currency_code: String(tx.currency_code ?? "SAR"),
    status: String(tx.status ?? ""),
    branch_id: order.branch_id == null ? null : String(order.branch_id),
  };
}

type RefundOutcome = "succeeded" | "pending" | "failed" | "unknown";

export function mapTapRefundStatus(status: unknown): RefundOutcome {
  switch (String(status ?? "").toUpperCase()) {
    case "REFUNDED":
      return "succeeded";
    case "PENDING":
    case "ACCEPTED":
      return "pending";
    case "DECLINED":
    case "FAILED":
    case "RESTRICTED":
    case "REJECTED":
      return "failed";
    default:
      return "unknown";
  }
}

function parseRequestedAmount(value: unknown): number | null | undefined {
  if (value == null) return null;
  if (typeof value !== "number" && typeof value !== "string") return undefined;
  const raw = String(value).trim();
  if (!/^\d+(?:\.\d{1,2})?$/.test(raw)) return undefined;
  const amount = Number(raw);
  return Number.isFinite(amount) && amount > 0 ? amount : undefined;
}

function tapReason(value: unknown): string {
  const reason = typeof value === "string" ? value.trim() : "";
  return TAP_REASON_CODES.has(reason) ? reason : "requested_by_customer";
}

function safeProviderMetadata(refund: any): Record<string, unknown> {
  if (!refund || typeof refund !== "object" || Array.isArray(refund)) return {};
  const allowed = [
    "id",
    "object",
    "api_version",
    "live_mode",
    "amount",
    "charge_id",
    "created",
    "date",
    "currency",
    "status",
    "reference",
    "response",
    "method",
    "transaction",
    "reason",
  ];
  return Object.fromEntries(
    allowed.filter((key) => refund[key] !== undefined).map((
      key,
    ) => [key, refund[key]]),
  );
}

function parseProviderAmount(value: unknown): number | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  const raw = String(value).trim();
  if (!/^\d+(?:\.\d{1,2})?$/.test(raw)) return null;
  const amount = Number(raw);
  return Number.isFinite(amount) && amount > 0 ? amount : null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function completeRefund(
  refundId: string,
  outcome: RefundOutcome,
  confirmedAmount: number | null,
  providerRefundId: string | null,
  metadata: Record<string, unknown>,
  fetch: typeof serviceFetch,
): Promise<boolean> {
  const result = await fetch("/rpc/complete_payment_refund", {
    method: "POST",
    body: JSON.stringify({
      p_refund_id: refundId,
      p_status: outcome,
      p_confirmed_amount: confirmedAmount,
      p_provider_refund_id: providerRefundId,
      p_provider_metadata: metadata,
    }),
  });
  return result?.ok === true;
}

export async function handleRequest(
  req: Request,
  deps: Dependencies = defaultDeps,
): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const user = await deps.getUser(req);
  if (!user) return json({ error: "Unauthorized" }, 401);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const chargeId = String(body?.chargeId ?? "").trim();
  const idempotencyKey = String(body?.idempotencyKey ?? "").trim();
  const requestedAmount = parseRequestedAmount(body?.amount);
  if (!chargeId) return json({ error: "chargeId is required" }, 400);
  if (!idempotencyKey || idempotencyKey.length > 128) {
    return json({ error: "A valid idempotencyKey is required" }, 400);
  }
  if (requestedAmount === undefined) {
    return json({
      error: "Amount must be positive and have at most 2 decimals",
    }, 400);
  }

  const payment = await getPaymentInfo(chargeId, deps.fetch);
  if (!payment) return json({ error: "Transaction not found" }, 404);

  const auth = await checkStaffAuthorization(
    user.id,
    payment.branch_id,
    deps.fetch,
  );
  if (!auth.authorized) {
    return json({ error: "Forbidden", reason: auth.reason }, 403);
  }

  if (payment.status !== REFUNDABLE_STATUS) {
    return json({
      error: "Only captured transactions can be refunded",
      status: payment.status,
    }, 409);
  }

  // The database locks the captured payment, reserves this amount against all
  // successful/pending/unknown refunds, and returns its authoritative amount.
  let claim: any;
  try {
    claim = await deps.fetch("/rpc/claim_payment_refund", {
      method: "POST",
      body: JSON.stringify({
        p_transaction_id: payment.id,
        p_amount: requestedAmount ?? payment.amount,
        p_reason: tapReason(body?.reason),
        p_idempotency_key: idempotencyKey,
        p_staff_user_id: user.id,
      }),
    });
  } catch {
    return json({ error: "Could not reserve refund" }, 503);
  }

  if (claim?.ok !== true || !claim?.refund_id) {
    return json({
      error: "Refund could not be reserved",
      reason: claim?.reason ?? null,
    }, 409);
  }

  const refundId = String(claim.refund_id);
  const amount = parseProviderAmount(claim.amount);
  const providerChargeId = String(claim.charge_id ?? "");
  const currency = String(claim.currency_code ?? "");
  if (
    !amount ||
    !providerChargeId ||
    providerChargeId !== payment.provider_reference ||
    currency.toUpperCase() !== payment.currency_code.toUpperCase() ||
    String(claim.order_id ?? "") !== payment.order_id ||
    String(claim.branch_id ?? "") !== String(payment.branch_id ?? "")
  ) {
    // Do not send a provider request if the reservation does not match the
    // authorized, locally stored payment. Keep the ledger for investigation.
    await completeRefund(refundId, "failed", null, null, {
      reason: "reservation_mismatch",
    }, deps.fetch).catch(() => false);
    return json({ error: "Refund reservation did not match the payment" }, 409);
  }

  // A reused idempotency key represents the same provider request. Pending or
  // ambiguous attempts must wait for Tap's signed callback/reconciliation;
  // submitting them again could create a second refund with Tap.
  if (claim.reused === true) {
    const priorStatus = String(claim.status ?? "unknown").toLowerCase();
    if (priorStatus === "succeeded") {
      return json({
        refundId,
        status: "succeeded",
        amount,
        currency,
        reused: true,
      });
    }
    if (priorStatus === "pending" || priorStatus === "unknown") {
      return json({
        refundId,
        status: priorStatus,
        reused: true,
      }, 202);
    }
  }

  let providerRefund: any;
  try {
    const webhookUrl = Deno.env.get("TAP_WEBHOOK_URL");
    providerRefund = await deps.tap("/refunds", {
      method: "POST",
      body: JSON.stringify({
        charge_id: providerChargeId,
        amount,
        currency,
        reason: tapReason(body?.reason),
        reference: { merchant: refundId },
        metadata: { udf1: refundId },
        ...(webhookUrl ? { post: { url: webhookUrl } } : {}),
      }),
    });
  } catch {
    // A timeout is ambiguous: Tap may have accepted the request. Keep its
    // amount reserved as unknown and never release it for an automatic retry.
    const saved = await completeRefund(
      refundId,
      "unknown",
      null,
      null,
      { outcome: "provider_request_ambiguous" },
      deps.fetch,
    ).catch(() => false);
    return json({
      refundId,
      status: "unknown",
      recorded: saved,
    }, 202);
  }

  const metadata = safeProviderMetadata(providerRefund);
  const outcome = mapTapRefundStatus(providerRefund?.status);
  const providerId = typeof providerRefund?.id === "string"
    ? providerRefund.id
    : null;
  let confirmedAmount: number | null = null;
  let finalOutcome = outcome;
  if (outcome === "succeeded") {
    const reportedAmount = parseProviderAmount(providerRefund?.amount);
    const reportedCurrency = String(providerRefund?.currency ?? "")
      .toUpperCase();
    if (
      reportedAmount === amount && reportedCurrency === currency.toUpperCase()
    ) {
      confirmedAmount = reportedAmount;
    } else {
      // A nominal success with inconsistent provider totals is not a confirmed
      // financial success. It remains reserved for reconciliation.
      finalOutcome = "unknown";
      metadata.reconciliation_required = true;
    }
  }

  const recorded = await completeRefund(
    refundId,
    finalOutcome,
    confirmedAmount,
    providerId,
    metadata,
    deps.fetch,
  ).catch(() => false);

  if (finalOutcome === "pending" || finalOutcome === "unknown" || !recorded) {
    return json({
      refundId,
      providerRefundId: providerId,
      status: finalOutcome === "unknown" || !recorded ? "unknown" : "pending",
      recorded,
    }, 202);
  }

  return json({
    refundId,
    providerRefundId: providerId,
    status: finalOutcome,
    amount: confirmedAmount,
    currency,
    recorded,
  });
}

if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
