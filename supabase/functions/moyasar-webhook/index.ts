import { env, moyasarApiRequest, moyasarRequest, serviceFetch } from "../_shared/moyasar.ts";
import {
  monotonicPaymentStatus,
  paymentMatchesTransaction,
} from "../moyasar-verify-payment/index.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function safeEqual(left: string, right: string): boolean {
  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index++) {
    difference |= (left.charCodeAt(index) || 0) ^
      (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  let event: any;
  try {
    event = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const expectedToken = env("MOYASAR_WEBHOOK_SECRET_TOKEN");
  if (
    typeof event?.secret_token !== "string" ||
    !safeEqual(event.secret_token, expectedToken)
  ) return json({ error: "Unauthorized" }, 401);

  if (event.type === "webhook_verification") {
    const webhookId = String(event?.data?.webhook_id ?? "");
    const code = String(event?.data?.verification_code ?? "");
    if (!/^[0-9a-f-]{36}$/i.test(webhookId) || !/^\d{6}$/.test(code)) {
      return json({ error: "Invalid verification event" }, 400);
    }
    try {
      await moyasarApiRequest(`webhooks/${encodeURIComponent(webhookId)}/verify`, {
        method: "POST",
        body: JSON.stringify({ code }),
      });
      return json({ received: true, verification: true });
    } catch {
      return json({ error: "Webhook verification failed" }, 502);
    }
  }
  const mode = env("MOYASAR_MODE");
  if (
    typeof event?.live !== "boolean" || event.live !== (mode === "production")
  ) {
    return json({ error: "Wrong payment environment" }, 403);
  }
  if (!String(event?.type ?? "").startsWith("payment_")) {
    return json({ received: true, ignored: true });
  }

  const paymentId = String(event?.data?.id ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(paymentId)) {
    return json({ received: true, ignored: true });
  }
  const intents = await serviceFetch(
    `/moyasar_checkout_intents?select=payment_id,user_id,amount,currency_code,status,order_id&payment_id=eq.${encodeURIComponent(paymentId)}&limit=1`,
  );
  const intent: any = Array.isArray(intents) ? intents[0] : null;
  const rows = intent ? [] : await serviceFetch(
    `/payment_transactions?select=id,order_id,subscription_id,status,amount,currency_code,provider_reference&provider=eq.moyasar&provider_reference=eq.${encodeURIComponent(paymentId)}&limit=1`,
  );
  const tx = Array.isArray(rows) ? rows[0] : null;
  if (!intent && !tx) return json({ received: true, ignored: true });
  if (intent?.status === "refunded") {
    return json({ received: true, ignored: true, status: "refunded" });
  }

  // The notification is only a prompt to reconcile. Confirm the payment with
  // Moyasar directly and bind it to the server-priced internal transaction.
  const payment = await moyasarRequest(paymentId);
  if (!paymentMatchesTransaction(payment, intent ?? tx, paymentId)) {
    return json({ received: true, rejected: "payment_mismatch" }, 409);
  }
  const priorStatus = intent
    ? intent.status === "finalized" ? "captured" : intent.status
    : tx.status;
  const status = monotonicPaymentStatus(priorStatus, payment.status);
  const verified = status === "captured";
  const orderPaymentStatus = verified
    ? "paid"
    : status === "failed"
    ? "failed"
    : "pending";
  const eventId = String(
    event?.id ?? `${event.type}:${paymentId}:${event?.created_at ?? ""}`,
  );

  if (intent) {
    if (intent.status !== "finalized") {
      await serviceFetch(
        `/moyasar_checkout_intents?payment_id=eq.${encodeURIComponent(paymentId)}&status=neq.finalized`,
        {
          method: "PATCH",
          body: JSON.stringify({ status, updated_at: new Date().toISOString() }),
        },
      );
    }
    if (verified) {
      await serviceFetch("/rpc/finalize_moyasar_checkout", {
        method: "POST",
        body: JSON.stringify({
          p_payment_id: paymentId,
          p_user_id: intent.user_id,
        }),
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
          ...(verified ? { paid_at: new Date().toISOString() } : {}),
          card_brand: payment?.source?.company ?? null,
          card_last4: String(payment?.source?.number ?? "").slice(-4) || null,
          card_holder_name: payment?.source?.name ?? null,
        }),
      },
    );
  }
  if (!intent && tx.order_id) {
    const filter = verified
      ? `id=eq.${encodeURIComponent(tx.order_id)}`
      : `id=eq.${encodeURIComponent(tx.order_id)}&payment_status=neq.paid`;
    await serviceFetch(`/orders?${filter}`, {
      method: "PATCH",
      body: JSON.stringify({ payment_status: orderPaymentStatus }),
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
  // Persist only a small allowlist. The provider payload can contain a saved
  // token and is deliberately never written to the event table.
  try {
    await serviceFetch("/payment_events", {
      method: "POST",
      body: JSON.stringify({
        provider: "moyasar",
        event_id: eventId,
        charge_id: paymentId,
        payload: {
          type: event.type,
          payment_id: paymentId,
          status: payment.status,
          amount: payment.amount,
          currency: payment.currency,
        },
      }),
    });
  } catch (error) {
    if (!String(error).includes("23505")) throw error;
  }
  return json({ received: true, status: payment.status });
}

if (import.meta.main) Deno.serve(handleRequest);
