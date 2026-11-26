import {
  amountInMinorUnits,
  getUserFromRequest,
  moyasarRequest,
  serviceFetch,
} from "../_shared/moyasar.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

export function normalizedStatus(
  status: unknown,
): "captured" | "failed" | "pending" {
  if (status === "paid") return "captured";
  if (status === "failed" || status === "expired" || status === "canceled") {
    return "failed";
  }
  return "pending";
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
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  const paymentId = String(body?.paymentId ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(paymentId)) {
    return json({ error: "Invalid payment id" }, 400);
  }

  const rows = await serviceFetch(
    `/payment_transactions?select=id,order_id,subscription_id,status,amount,currency_code,provider_reference&provider=eq.moyasar&provider_reference=eq.${
      encodeURIComponent(paymentId)
    }`,
  );
  const tx = Array.isArray(rows) ? rows[0] : null;
  if (!tx) return json({ error: "Transaction not found" }, 404);
  let ownerId: string | null = null;
  if (tx.order_id) {
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

  let payment: any;
  try {
    payment = await moyasarRequest(paymentId);
  } catch {
    return json({ error: "Payment verification unavailable" }, 502);
  }
  if (!paymentMatchesTransaction(payment, tx, paymentId)) {
    return json(
      { error: "Payment amount, currency or reference mismatch" },
      409,
    );
  }

  const status = normalizedStatus(payment?.status);
  const verified = status === "captured";
  const targetPaymentStatus = verified
    ? "paid"
    : status === "failed"
    ? "failed"
    : "pending";
  const now = new Date().toISOString();
  try {
    await serviceFetch(
      `/payment_transactions?provider=eq.moyasar&provider_reference=eq.${
        encodeURIComponent(paymentId)
      }`,
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
    if (tx.order_id) {
      await serviceFetch(`/orders?id=eq.${encodeURIComponent(tx.order_id)}`, {
        method: "PATCH",
        body: JSON.stringify({ payment_status: targetPaymentStatus }),
      });
    }
    if (verified && tx.subscription_id) {
      await serviceFetch("/rpc/activate_subscription", {
        method: "POST",
        body: JSON.stringify({
          p_subscription_id: tx.subscription_id,
          p_payment_reference: paymentId,
        }),
      });
    }
  } catch {
    return json({
      error: "Payment recorded by provider; local confirmation pending",
    }, 503);
  }
  return json({
    paymentId,
    status: payment?.status ?? "unknown",
    verified,
    orderPaymentStatus: targetPaymentStatus,
  });
}

if (import.meta.main) Deno.serve(handleRequest);
