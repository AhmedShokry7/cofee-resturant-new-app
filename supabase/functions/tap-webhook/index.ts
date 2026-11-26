// Tap calls this endpoint without a Supabase JWT. Authentication is the
// required Tap `hashstring` HMAC, verified before any database mutation.
import {
  serviceFetch,
  tapSecretKey,
  verifyTapWebhookHash,
} from "../_shared/tap.ts";

type WebhookDeps = {
  fetch: typeof serviceFetch;
  verifyHash: typeof verifyTapWebhookHash;
  secret: typeof tapSecretKey;
};

const defaultDeps: WebhookDeps = {
  fetch: serviceFetch,
  verifyHash: verifyTapWebhookHash,
  secret: tapSecretKey,
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function mapTapStatus(status: string): string {
  const s = (status || "").toUpperCase();
  if (s === "CAPTURED") return "captured";
  if (s === "AUTHORIZED") return "authorized";
  if (
    ["FAILED", "DECLINED", "RESTRICTED", "TIMEDOUT", "ABANDONED"].includes(s)
  ) return "failed";
  if (["CANCELLED", "VOID"].includes(s)) return "voided";
  return "pending";
}

export function roundAmount(amount: number, currency: string): string {
  const decimals = ["BHD", "KWD", "OMR", "JOD"].includes(currency.toUpperCase())
    ? 3
    : 2;
  return Number(amount).toFixed(decimals);
}

export function mapTapRefundStatus(
  status: string,
): "succeeded" | "pending" | "failed" | "unknown" {
  const value = String(status ?? "").toUpperCase();
  if (value === "REFUNDED") return "succeeded";
  if (["ACCEPTED", "PENDING", "INITIATED"].includes(value)) return "pending";
  if (
    ["REJECTED", "DECLINED", "FAILED", "CANCELLED", "RESTRICTED"].includes(
      value,
    )
  ) return "failed";
  return "unknown";
}

function safeRefundMetadata(refund: any): Record<string, unknown> {
  const reference = refund?.reference ?? {};
  const response = refund?.response ?? {};
  const post = refund?.post ?? {};
  return {
    object: refund?.object,
    status: refund?.status,
    amount: refund?.amount,
    currency: refund?.currency,
    charge_id: refund?.charge_id,
    created: refund?.created,
    date: refund?.date,
    reference: {
      id: reference.id,
      gateway: reference.gateway,
      payment: reference.payment,
      acquirer: reference.acquirer,
    },
    response: { code: response.code, message: response.message },
    post: { status: post.status },
  };
}

async function handleRefundWebhook(
  refund: any,
  deps: WebhookDeps,
): Promise<Response> {
  const refundId = String(
    refund?.metadata?.udf1 ?? refund?.reference?.merchant ?? "",
  );
  if (!refundId) return json({ received: true, ignored: true });

  const rows = await deps.fetch(
    `/payment_refunds?select=id,payment_transaction_id,order_id,requested_amount,currency_code,status,provider_refund_id&provider=eq.tap&id=eq.${
      encodeURIComponent(refundId)
    }&limit=1`,
  );
  const record = Array.isArray(rows) ? rows[0] : null;
  if (!record || String(record.id) !== refundId) {
    return json({ received: true, ignored: true });
  }

  const transactionRows = await deps.fetch(
    `/payment_transactions?select=provider_reference,amount,currency_code&id=eq.${
      encodeURIComponent(String(record.payment_transaction_id))
    }&limit=1`,
  );
  const transaction = Array.isArray(transactionRows)
    ? transactionRows[0]
    : null;
  if (
    !transaction ||
    String(transaction.provider_reference) !== String(refund.charge_id ?? "")
  ) {
    return json({ received: true, rejected: "charge_reference_mismatch" });
  }

  const requestedAmount = Number(record.requested_amount);
  const amount = Number(refund.amount);
  const currency = String(refund.currency ?? "").toUpperCase();
  const expectedCurrency = String(record.currency_code ?? "").toUpperCase();
  if (
    !Number.isFinite(amount) || amount <= 0 ||
    !Number.isFinite(requestedAmount) ||
    roundAmount(amount, currency) !==
      roundAmount(requestedAmount, expectedCurrency) ||
    currency !== expectedCurrency ||
    currency !== String(transaction.currency_code ?? "").toUpperCase()
  ) {
    return json({ received: true, rejected: "amount_or_currency_mismatch" });
  }

  const status = mapTapRefundStatus(String(refund.status ?? ""));
  const metadata = safeRefundMetadata(refund);
  if (record.status === "succeeded" && status !== "succeeded") {
    return json({ received: true, stale: true });
  }
  const confirmedAmount = status === "succeeded" ? amount : null;
  await deps.fetch("/rpc/complete_payment_refund", {
    method: "POST",
    body: JSON.stringify({
      p_refund_id: refundId,
      p_status: status,
      p_confirmed_amount: confirmedAmount,
      p_provider_refund_id: String(refund.id ?? ""),
      p_provider_metadata: metadata,
    }),
  });

  const createdAt = String(refund.created ?? refund.date ?? "");
  const eventId = `refund:${refundId}:${String(refund.status)}:${createdAt}`;
  try {
    await deps.fetch("/payment_events", {
      method: "POST",
      body: JSON.stringify({
        provider: "tap",
        event_id: eventId,
        charge_id: String(refund.charge_id ?? ""),
        payload: metadata,
      }),
    });
  } catch (error) {
    if (isDuplicateEventError(error)) {
      return json({ received: true, duplicate: true });
    }
    return json({ error: "Could not persist refund webhook event" }, 500);
  }
  return json({ received: true, refund_id: refundId, status });
}

function isDuplicateEventError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return /(?:Supabase\s+409\b|duplicate key|unique constraint|23505)/i.test(
    message,
  );
}

export async function handleRequest(
  req: Request,
  deps: WebhookDeps = defaultDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const rawBody = await req.text();
  let charge: any;
  try {
    charge = JSON.parse(rawBody);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }
  if (!charge || typeof charge !== "object" || Array.isArray(charge)) {
    return new Response("Invalid charge", { status: 400 });
  }

  let secretKey: string;
  try {
    secretKey = deps.secret();
  } catch {
    return new Response("Webhook is not configured", { status: 503 });
  }
  const postedHash = req.headers.get("hashstring") ?? req.headers.get("hash") ??
    "";
  if (!postedHash) return new Response("Invalid signature", { status: 401 });

  const id = String(charge.id ?? "");
  const currency = String(charge.currency ?? "SAR");
  const amountValue = Number(charge.amount);
  const gatewayRef = String(charge.reference?.gateway ?? "");
  const paymentRef = String(charge.reference?.payment ?? "");
  const status = String(charge.status ?? "");
  const created = String(charge.transaction?.created ?? charge.created ?? "");
  if (!id || !status || !Number.isFinite(amountValue) || amountValue <= 0) {
    return new Response("Invalid charge", { status: 400 });
  }

  // Tap's documented hashstring payload uses these exact labels/order.
  const signedMessage = `x_id${id}x_amount${
    roundAmount(amountValue, currency)
  }x_currency${currency}x_gateway_reference${gatewayRef}x_payment_reference${paymentRef}x_status${status}x_created${created}`;
  if (!await deps.verifyHash(signedMessage, req.headers, secretKey)) {
    return new Response("Invalid signature", { status: 401 });
  }

  if (charge.object === "refund") {
    return await handleRefundWebhook(charge, deps);
  }

  // Resolve the charge through our trusted transaction record before any write.
  const txRows = await deps.fetch(
    `/payment_transactions?select=provider_reference,amount,currency_code,order_id,subscription_id&provider=eq.tap&provider_reference=eq.${
      encodeURIComponent(id)
    }&limit=1`,
  );
  const tx = Array.isArray(txRows) && txRows[0] ? txRows[0] : null;
  if (!tx || tx.provider_reference !== id) {
    return json({ received: true, ignored: true });
  }

  const orderId = tx.order_id ?? null;
  const subscriptionId = tx.subscription_id ?? null;
  if (
    orderId && charge.reference?.transaction &&
    String(charge.reference.transaction) !== String(orderId)
  ) {
    return json({ received: true, rejected: "order_reference_mismatch" });
  }

  const expectedAmount = Number(tx.amount);
  const expectedCurrency = String(tx.currency_code ?? "SAR");
  if (
    !Number.isFinite(expectedAmount) || expectedAmount <= 0 ||
    roundAmount(amountValue, currency) !==
      roundAmount(expectedAmount, expectedCurrency) ||
    currency.toUpperCase() !== expectedCurrency.toUpperCase()
  ) {
    return json({ received: true, rejected: "amount_or_currency_mismatch" });
  }

  if (orderId) {
    const orderRows = await deps.fetch(
      `/orders?select=id,grand_total,currency_code,test_only&id=eq.${
        encodeURIComponent(orderId)
      }&limit=1`,
    );
    const order = Array.isArray(orderRows) ? orderRows[0] : null;
    if (
      !order || order.test_only === true ||
      String(order.id) !== String(orderId) ||
      roundAmount(
          Number(order.grand_total),
          String(order.currency_code ?? "SAR"),
        ) !== roundAmount(expectedAmount, expectedCurrency) ||
      String(order.currency_code ?? "SAR").toUpperCase() !==
        expectedCurrency.toUpperCase()
    ) {
      return json({
        received: true,
        rejected: "order_amount_or_currency_mismatch",
      });
    }
  }

  if (subscriptionId) {
    const subRows = await deps.fetch(
      `/subscriptions?select=id,plan:plans(price,currency_code)&id=eq.${
        encodeURIComponent(subscriptionId)
      }&limit=1`,
    );
    const sub = Array.isArray(subRows) ? subRows[0] : null;
    const planPrice = Number(sub?.plan?.price ?? 0);
    const planCurrency = String(sub?.plan?.currency_code ?? "SAR");
    if (
      !sub ||
      roundAmount(planPrice, planCurrency) !==
        roundAmount(expectedAmount, expectedCurrency) ||
      planCurrency.toUpperCase() !== expectedCurrency.toUpperCase()
    ) {
      return json({
        received: true,
        rejected: "subscription_amount_or_currency_mismatch",
      });
    }
  }
  if (!orderId && !subscriptionId) {
    return json({ received: true, ignored: true });
  }

  const newStatus = mapTapStatus(status);
  // A payment authorization must not grant a prepaid entitlement.
  const verified = newStatus === "captured";
  const now = new Date().toISOString();
  await deps.fetch(
    `/payment_transactions?provider=eq.tap&provider_reference=eq.${
      encodeURIComponent(id)
    }`,
    {
      method: "PATCH",
      body: JSON.stringify({
        status: newStatus,
        verified_by_server: verified,
        card_brand: charge.card?.brand ?? null,
        card_last4: charge.card?.last_four ?? null,
        card_holder_name: charge.card?.name ?? null,
        paid_at: verified ? now : null,
      }),
    },
  );

  if (orderId) {
    const orderPaymentStatus = verified
      ? "paid"
      : (newStatus === "failed" ? "failed" : "pending");
    await deps.fetch(`/orders?id=eq.${encodeURIComponent(orderId)}`, {
      method: "PATCH",
      body: JSON.stringify({ payment_status: orderPaymentStatus }),
    });
  }
  if (verified && subscriptionId) {
    await deps.fetch("/rpc/activate_subscription", {
      method: "POST",
      body: JSON.stringify({
        p_subscription_id: subscriptionId,
        p_payment_reference: id,
      }),
    });
  }

  // Persist last: a delivery retry can safely repeat the idempotent state writes.
  const eventId = `${id}:${status}:${created}`;
  try {
    await deps.fetch("/payment_events", {
      method: "POST",
      body: JSON.stringify({
        provider: "tap",
        event_id: eventId,
        charge_id: id,
        payload: charge,
      }),
    });
  } catch (error) {
    if (isDuplicateEventError(error)) {
      return json({ received: true, duplicate: true });
    }
    return json({ error: "Could not persist webhook event" }, 500);
  }

  return json({ received: true });
}

if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
