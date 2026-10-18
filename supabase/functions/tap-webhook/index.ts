// supabase/functions/tap-webhook/index.ts
import { serviceFetch, tapSecretKey, hmacSha256Hex } from "../_shared/tap.ts";

function mapTapStatus(status: string): string {
  const s = (status || "").toUpperCase();
  if (s === "CAPTURED") return "captured";
  if (s === "AUTHORIZED") return "authorized";
  if (s === "FAILED" || s === "DECLINED" || s === "RESTRICTED" || s === "TIMEDOUT" || s === "ABANDONED") return "failed";
  if (s === "CANCELLED" || s === "VOID") return "voided";
  return "pending";
}

function roundAmount(amount: number, currency: string): string {
  const decimals = ["BHD", "KWD", "OMR", "JOD"].includes(currency.toUpperCase()) ? 3 : 2;
  return Number(amount).toFixed(decimals);
}

Deno.serve(async (req) => {
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

  const secretKey = tapSecretKey();
  const postedHash = req.headers.get("hashstring") ?? req.headers.get("hash") ?? "";

  const id = String(charge?.id ?? "");
  const amount = roundAmount(charge?.amount ?? 0, String(charge?.currency ?? "SAR"));
  const currency = String(charge?.currency ?? "SAR");
  const gatewayRef = String(charge?.reference?.gateway ?? "");
  const paymentRef = String(charge?.reference?.payment ?? "");
  const status = String(charge?.status ?? "");
  const created = String(charge?.transaction?.created ?? charge?.created ?? "");

  const toBeHashed = `x_id${id}x_amount${amount}x_currency${currency}x_gateway_reference${gatewayRef}x_payment_reference${paymentRef}x_status${status}x_created${created}`;
  const computed = await hmacSha256Hex(toBeHashed, secretKey);

  if (!postedHash || computed.toLowerCase() !== postedHash.toLowerCase()) {
    return new Response("Invalid signature", { status: 401 });
  }

  const eventId = `${id}:${status}:${created}`;
  // Dedup.
  try {
    await serviceFetch("/payment_events", {
      method: "POST",
      body: JSON.stringify({
        provider: "tap",
        event_id: eventId,
        charge_id: id,
        payload: charge,
      }),
    });
  } catch {
    // Duplicate event: already processed.
    return new Response(JSON.stringify({ received: true, duplicate: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const newStatus = mapTapStatus(status);
  const verified = newStatus === "captured" || newStatus === "authorized";
  const now = new Date().toISOString();

  await serviceFetch(
    `/payment_transactions?provider=eq.tap&provider_reference=eq.${encodeURIComponent(id)}`,
    {
      method: "PATCH",
      body: JSON.stringify({
        status: newStatus,
        verified_by_server: verified,
        card_brand: charge?.card?.brand ?? null,
        card_last4: charge?.card?.last_four ?? null,
        card_holder_name: charge?.card?.name ?? null,
        paid_at: verified ? now : null,
      }),
    },
  ).catch(() => undefined);

  // Find target from transaction.
  const txRows = await serviceFetch(
    `/payment_transactions?select=order_id,subscription_id&provider=eq.tap&provider_reference=eq.${encodeURIComponent(id)}&limit=1`,
  );
  const tx = Array.isArray(txRows) && txRows[0] ? txRows[0] : null;
  const orderId = tx?.order_id ?? null;
  const subscriptionId = tx?.subscription_id ?? null;

  // Validate the webhook against the trusted local transaction/order before
  // applying any state transition.
  if (!tx || tx.provider_reference !== id) {
    return new Response(JSON.stringify({ received: true, ignored: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const expectedAmount = Number(tx.amount ?? 0);
  const expectedCurrency = String(tx.currency_code ?? "SAR");
  const postedAmount = Number(charge?.amount ?? 0);
  const postedCurrency = String(charge?.currency ?? "");
  if (!Number.isFinite(expectedAmount) || expectedAmount <= 0 ||
      !Number.isFinite(postedAmount) ||
      roundAmount(postedAmount, postedCurrency) !== roundAmount(expectedAmount, expectedCurrency) ||
      postedCurrency.toUpperCase() !== expectedCurrency.toUpperCase()) {
    return new Response(JSON.stringify({ received: true, rejected: "amount_or_currency_mismatch" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (orderId) {
    const orderRows = await serviceFetch(
      `/orders?select=id,grand_total,currency_code&id=eq.${encodeURIComponent(orderId)}&limit=1`,
    );
    const order = Array.isArray(orderRows) ? orderRows[0] : null;
    if (!order ||
        roundAmount(Number(order.grand_total ?? 0), String(order.currency_code ?? "SAR")) !== roundAmount(expectedAmount, expectedCurrency) ||
        String(order.currency_code ?? "SAR").toUpperCase() !== expectedCurrency.toUpperCase()) {
      return new Response(JSON.stringify({ received: true, rejected: "order_amount_or_currency_mismatch" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
  }
  if (subscriptionId) {
    const subRows = await serviceFetch(
      `/subscriptions?select=id,plan:plans(price,currency_code)&id=eq.${encodeURIComponent(subscriptionId)}&limit=1`,
    );
    const sub = Array.isArray(subRows) ? subRows[0] : null;
    const planPrice = Number(sub?.plan?.price ?? 0);
    const planCurrency = String(sub?.plan?.currency_code ?? "SAR");
    if (!sub || roundAmount(planPrice, planCurrency) !== roundAmount(expectedAmount, expectedCurrency) ||
        planCurrency.toUpperCase() !== expectedCurrency.toUpperCase()) {
      return new Response(JSON.stringify({ received: true, rejected: "subscription_amount_or_currency_mismatch" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  if (orderId) {
    const orderPaymentStatus = verified ? "paid" : (newStatus === "failed" ? "failed" : "pending");
    await serviceFetch(
      `/orders?id=eq.${encodeURIComponent(orderId)}`,
      {
        method: "PATCH",
        body: JSON.stringify({ payment_status: orderPaymentStatus }),
      },
    ).catch(() => undefined);
  }
  if (verified && subscriptionId) {
    await serviceFetch("/rpc/activate_subscription", {
      method: "POST",
      body: JSON.stringify({
        p_subscription_id: subscriptionId,
        p_payment_reference: id,
      }),
    }).catch(() => undefined);
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
