import {
  amountInMinorUnits,
  getUserFromRequest,
  moyasarApiRequest,
  moyasarRequest,
  serviceFetch,
  userRpc,
} from "../_shared/moyasar.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

export function normalizedStatus(
  status: unknown,
): "captured" | "failed" | "pending" {
  if (status === "paid" || status === "captured") return "captured";
  if (status === "failed" || status === "expired" || status === "canceled") {
    return "failed";
  }
  return "pending";
}

export function monotonicPaymentStatus(
  priorStatus: unknown,
  nextStatus: unknown,
): "captured" | "failed" | "pending" {
  const current = normalizedStatus(nextStatus);
  return priorStatus === "captured" && current !== "captured"
    ? "captured"
    : current;
}

export function paymentMatchesTransaction(
  payment: any,
  transaction: any,
  paymentId: string,
): boolean {
  const currency = String(transaction?.currency_code ?? "").toUpperCase();
  return String(payment?.id ?? "") === paymentId &&
    Number(payment?.amount) ===
      amountInMinorUnits(transaction?.amount, currency) &&
    String(payment?.currency ?? "").toUpperCase() === currency;
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const user = await getUserFromRequest(req);
  if (!user) return json({ error: "Unauthorized" }, 401);
  let body: any;
  let savedCard = false;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  const paymentId = String(body?.paymentId ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(paymentId)) {
    return json({ error: "Invalid payment id" }, 400);
  }

  // Checkout payments gain a transaction when the order is finalized. Always
  // prefer the intent, including after that transaction exists, so callers
  // receive the finalized order and can finish the UI flow.
  const intents = await serviceFetch(
    `/moyasar_checkout_intents?select=payment_id,user_id,amount,currency_code,status,order_id&payment_id=eq.${encodeURIComponent(paymentId)}&limit=1`,
  );
  const intent: any = Array.isArray(intents) ? intents[0] : null;
  const rows = intent ? [] : await serviceFetch(
    `/payment_transactions?select=id,order_id,subscription_id,status,amount,currency_code,provider_reference&provider=eq.moyasar&provider_reference=eq.${encodeURIComponent(paymentId)}&limit=1`,
  );
  const tx = Array.isArray(rows) ? rows[0] : null;
  if (!intent && !tx) return json({ error: "Payment not found" }, 404);
  let ownerId: string | null = null;
  if (intent) {
    ownerId = intent.user_id ?? null;
  } else if (tx.order_id) {
    const orders = await serviceFetch(
      `/orders?select=id,user_id&id=eq.${encodeURIComponent(tx.order_id)}`,
    );
    ownerId = Array.isArray(orders) ? orders[0]?.user_id ?? null : null;
  } else if (tx.subscription_id) {
    const subscriptions = await serviceFetch(
      `/subscriptions?select=id,user_id&id=eq.${
        encodeURIComponent(tx.subscription_id)
      }`,
    );
    ownerId = Array.isArray(subscriptions)
      ? subscriptions[0]?.user_id ?? null
      : null;
  }
  if (ownerId !== user.id) return json({ error: "Forbidden" }, 403);
  if (intent?.status === "refunded") {
    return json({
      paymentId,
      status: "refunded",
      verified: false,
      orderPaymentStatus: "failed",
      finalizedOrder: null,
      savedCardStatus: "not_requested",
    });
  }

  let payment: any;
  try {
    payment = await moyasarRequest(paymentId);
  } catch {
    return json({ error: "Payment verification unavailable" }, 502);
  }
  if (!paymentMatchesTransaction(payment, intent ?? tx, paymentId)) {
    return json(
      { error: "Payment amount, currency or reference mismatch" },
      409,
    );
  }

  // A delayed verification request must never turn an already captured
  // transaction back into pending/failed. Refunds have their own ledger and
  // must not be represented by regressing the original payment.
  const priorStatus = intent
    ? intent.status === "finalized" ? "captured" : intent.status
    : tx.status;
  const status = monotonicPaymentStatus(priorStatus, payment?.status);
  const verified = status === "captured";
  const targetPaymentStatus = verified
    ? "paid"
    : status === "failed"
    ? "failed"
    : "pending";
  const now = new Date().toISOString();
  let finalizedOrder: any = null;
  try {
    if (intent) {
      if (intent.status !== "finalized") {
        await serviceFetch(
          `/moyasar_checkout_intents?payment_id=eq.${encodeURIComponent(paymentId)}&status=neq.finalized`,
          {
            method: "PATCH",
            body: JSON.stringify({ status, updated_at: now }),
          },
        );
      }
      if (verified) {
        finalizedOrder = await userRpc(req, "finalize_moyasar_checkout", {
          p_payment_id: paymentId,
        });
      }
    } else {
      await serviceFetch(
        `/payment_transactions?provider=eq.moyasar&provider_reference=eq.${
          encodeURIComponent(paymentId)
        }${verified ? "" : "&status=neq.captured"}`,
        {
          method: "PATCH",
          body: JSON.stringify({
            status,
            verified_by_server: verified,
            paid_at: verified ? now : null,
            card_brand: payment?.source?.company ?? null,
            card_last4: String(payment?.source?.number ?? "").slice(-4) || null,
            card_holder_name: payment?.source?.name ?? null,
          }),
        },
      );
    }
    if (!intent && tx.order_id) {
      const orderFilter = verified
        ? `id=eq.${encodeURIComponent(tx.order_id)}`
        : `id=eq.${encodeURIComponent(tx.order_id)}&payment_status=neq.paid`;
      await serviceFetch(`/orders?${orderFilter}`, {
        method: "PATCH",
        body: JSON.stringify({ payment_status: targetPaymentStatus }),
      });
    }
    if (!intent && verified && tx.subscription_id) {
      await serviceFetch("/rpc/activate_subscription", {
        method: "POST",
        body: JSON.stringify({
          p_subscription_id: tx.subscription_id,
          p_payment_reference: paymentId,
        }),
      });
    }
  } catch {
    if (intent && verified) {
      // The SQL finalizer is atomic. A committed order changes the intent to
      // finalized; a captured intent with no order is safe to refund. If the
      // status read is unavailable, do not risk refunding a committed order.
      try {
        const latestRows = await serviceFetch(
          `/moyasar_checkout_intents?select=status,order_id&payment_id=eq.${encodeURIComponent(paymentId)}&limit=1`,
        );
        const latest = Array.isArray(latestRows) ? latestRows[0] : null;
        if (latest?.status === "finalized" && latest.order_id) {
          finalizedOrder = await userRpc(req, "finalize_moyasar_checkout", {
            p_payment_id: paymentId,
          });
        } else if (latest?.status === "captured" && !latest.order_id) {
          const refund = await moyasarApiRequest(
            `payments/${encodeURIComponent(paymentId)}/refund`,
            { method: "POST", body: JSON.stringify({}) },
          );
          if (Number(refund?.refunded ?? 0) >= Number(payment?.amount ?? 0)) {
            await serviceFetch(
              `/moyasar_checkout_intents?payment_id=eq.${encodeURIComponent(paymentId)}`,
              {
                method: "PATCH",
                body: JSON.stringify({ status: "refunded", updated_at: now }),
              },
            );
            return json({
              paymentId,
              status: "refunded",
              verified: false,
              orderPaymentStatus: "failed",
              finalizedOrder: null,
              savedCardStatus: "not_requested",
            });
          }
        }
      } catch {
        // Leave the captured intent retryable for the webhook or next verify.
      }
      if (!finalizedOrder) {
        return json({
          error: "Payment captured; checkout confirmation is being retried",
        }, 503);
      }
    } else {
    return json({
      error: "Payment recorded by provider; local confirmation pending",
    }, 503);
    }
  }
  // Saving a reusable token is an optional post-payment step. It must never
  // turn a verified payment into a failed checkout if card storage is delayed.
  let savedCardStatus = "not_requested";
  if (verified && payment?.metadata?.save_card_requested === "true") {
    savedCardStatus = "token_unavailable";
    try {
      let cardSource = payment?.source ?? {};
      let tokenId = String(cardSource.token ?? "").trim();
      if (!/^token_[A-Za-z0-9_-]+$/.test(tokenId)) {
        // The regular payment response can omit the token. Moyasar exposes
        // the token created by this exact payment through the extended source
        // endpoint, which lets us persist it without trusting a client value.
        const extendedSource = await moyasarApiRequest(
          `payments/${encodeURIComponent(paymentId)}/source`,
        );
        cardSource = { ...cardSource, ...extendedSource };
        tokenId = String(cardSource.token ?? "").trim();
      }
      if (/^token_[A-Za-z0-9_-]+$/.test(tokenId)) {
        savedCardStatus = "storage_failed";
        const existing = await serviceFetch(
          `/saved_card_provider?select=id&user_id=eq.${
            encodeURIComponent(user.id)
          }` +
            `&provider=eq.moyasar&moyasar_token_id=eq.${
              encodeURIComponent(tokenId)
            }&limit=1`,
        );
        if (!Array.isArray(existing) || existing.length === 0) {
          const maskedNumber = String(cardSource.number ?? "");
          const last4 = maskedNumber.replace(/\D/g, "").slice(-4);
          const rows = await serviceFetch("/saved_card_provider", {
            method: "POST",
            headers: { "Prefer": "return=representation" },
            body: JSON.stringify({
              user_id: user.id,
              provider: "moyasar",
              moyasar_token_id: tokenId,
              brand: cardSource.company === "master"
                ? "mastercard"
                : cardSource.company ?? null,
              last4: last4.length === 4 ? last4 : null,
              holder_name: cardSource.name ?? null,
              is_active: true,
            }),
          });
          savedCard = Array.isArray(rows) && rows.length > 0;
        } else {
          savedCard = true;
        }
        savedCardStatus = savedCard ? "saved" : "storage_failed";
      }
    } catch {
      savedCard = false;
      savedCardStatus = "storage_failed";
    }
  }
  return json({
    paymentId,
    status: payment?.status ?? "unknown",
    verified,
    savedCard,
    savedCardStatus,
    orderPaymentStatus: targetPaymentStatus,
    finalizedOrder,
  });
}

if (import.meta.main) Deno.serve(handleRequest);
