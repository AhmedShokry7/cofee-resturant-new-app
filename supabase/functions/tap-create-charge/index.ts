// supabase/functions/tap-create-charge/index.ts
import { getUserFromRequest, serviceFetch, tapRequest, env } from "../_shared/tap.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  const user = await getUserFromRequest(req);
  if (!user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400 });
  }

  const orderId = String(body?.orderId ?? "").trim();
  const sourceToken = String(body?.sourceToken ?? "").trim();
  const savedCardId = String(body?.savedCardId ?? "").trim();
  const idempotencyKey = String(body?.idempotencyKey ?? "").trim();
  const saveCard = body?.saveCard === true;

  if (!orderId) {
    return new Response(JSON.stringify({ error: "orderId is required" }), { status: 400 });
  }
  if (!sourceToken && !savedCardId) {
    return new Response(JSON.stringify({ error: "sourceToken or savedCardId is required" }), { status: 400 });
  }
  if (!idempotencyKey) {
    return new Response(JSON.stringify({ error: "idempotencyKey is required" }), { status: 400 });
  }

  // Load and validate the order.
  const orders = await serviceFetch(
    `/orders?select=id,user_id,grand_total,currency_code,status,payment_status,branch_id&id=eq.${encodeURIComponent(orderId)}`,
  );
  const order = Array.isArray(orders) ? orders[0] : null;
  if (!order || order.user_id !== user.id) {
    return new Response(JSON.stringify({ error: "Order not found" }), { status: 404 });
  }
  if (order.payment_status === "paid") {
    return new Response(JSON.stringify({ error: "Order already paid" }), { status: 409 });
  }

  // Idempotency: reuse an existing attempt with the same key.
  const existingAttempts = await serviceFetch(
    `/payment_attempts?select=id,order_id,status&idempotency_key=eq.${encodeURIComponent(idempotencyKey)}&order_id=eq.${encodeURIComponent(orderId)}`,
  );
  if (Array.isArray(existingAttempts) && existingAttempts.length > 0) {
    const existingTx = await serviceFetch(
      `/payment_transactions?select=provider_reference,status,amount,currency_code&order_id=eq.${encodeURIComponent(orderId)}&order=created_at.desc&limit=1`,
    );
    const tx = Array.isArray(existingTx) ? existingTx[0] : null;
    return new Response(JSON.stringify({
      reused: true,
      chargeId: tx?.provider_reference ?? null,
      status: tx?.status ?? "pending",
    }), { status: 200 });
  }

  // Resolve Tap customer id.
  let tapCustomerId: string | null = null;
  const customers = await serviceFetch(
    `/tap_customers?select=tap_customer_id&user_id=eq.${encodeURIComponent(user.id)}`,
  );
  if (Array.isArray(customers) && customers.length > 0) {
    tapCustomerId = customers[0].tap_customer_id;
  }

  // If charging a saved card, create a single-use token from it first.
  let resolvedSourceToken = sourceToken;
  if (savedCardId) {
    const cards = await serviceFetch(
      `/saved_cards?select=tap_customer_id,tap_card_id,is_active&user_id=eq.${encodeURIComponent(user.id)}&id=eq.${encodeURIComponent(savedCardId)}`,
    );
    const card = Array.isArray(cards) ? cards[0] : null;
    if (!card || !card.is_active) {
      return new Response(JSON.stringify({ error: "Saved card not found" }), { status: 404 });
    }
    const tokenResponse = await tapRequest("/tokens", {
      method: "POST",
      body: JSON.stringify({
        customer_id: card.tap_customer_id,
        card_id: card.tap_card_id,
      }),
    });
    resolvedSourceToken = tokenResponse?.id;
    tapCustomerId = card.tap_customer_id;
  }

  if (!tapCustomerId) {
    // Tap will create a customer; we store the returned id after the charge.
    tapCustomerId = "";
  }

  const amount = Number(order.grand_total);
  const currency = order.currency_code ?? "SAR";
  if (!Number.isFinite(amount) || amount <= 0) {
    return new Response(JSON.stringify({ error: "Invalid order amount" }), { status: 400 });
  }

  const chargePayload: any = {
    amount,
    currency,
    customer: tapCustomerId
      ? { id: tapCustomerId }
      : {
          id: "",
          first_name: user.email?.split("@")[0] ?? "Customer",
          email: user.email,
        },
    source: { id: resolvedSourceToken },
    save_card: saveCard,
    threeDSecure: true,
    redirect: {
      url: Deno.env.get("TAP_REDIRECT_URL") ?? "https://example.com/payment/return",
    },
    ...(Deno.env.get("TAP_WEBHOOK_URL")
      ? { post: { url: Deno.env.get("TAP_WEBHOOK_URL") } }
      : {}),
    reference: {
      transaction: orderId,
      order: orderId,
    },
    metadata: {
      order_id: orderId,
      user_id: user.id,
    },
  };

  let charge: any;
  try {
    charge = await tapRequest("/charges", {
      method: "POST",
      body: JSON.stringify(chargePayload),
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 502 });
  }

  const chargeId = charge?.id;
  if (!chargeId) {
    return new Response(JSON.stringify({ error: "Tap did not return a charge id" }), { status: 502 });
  }

  // Store tap customer id if returned.
  const returnedCustomerId = charge?.customer?.id;
  if (returnedCustomerId && !tapCustomerId) {
    await serviceFetch("/tap_customers", {
      method: "POST",
      headers: { "Prefer": "resolution=merge-duplicates" },
      body: JSON.stringify({ user_id: user.id, tap_customer_id: returnedCustomerId }),
    }).catch(() => undefined);
    tapCustomerId = returnedCustomerId;
  }

  // Resolve a payment_methods row for the card method (best effort).
  let methodId: string | null = null;
  const methods = await serviceFetch("/payment_methods?select=id&code=eq.card&limit=1");
  if (Array.isArray(methods) && methods.length > 0) methodId = methods[0].id;
  if (methodId) {
    await serviceFetch("/payment_attempts", {
      method: "POST",
      body: JSON.stringify({
        order_id: orderId,
        method_id: methodId,
        status: "initiated",
        client_initiated: true,
        idempotency_key: idempotencyKey,
      }),
    }).catch(() => undefined);
  }

  // Record payment transaction.
  await serviceFetch("/payment_transactions", {
    method: "POST",
    body: JSON.stringify({
      order_id: orderId,
      provider: "tap",
      provider_reference: chargeId,
      amount,
      currency_code: currency,
      status: "pending",
      verified_by_server: false,
      card_brand: charge?.card?.brand ?? null,
      card_last4: charge?.card?.last_four ?? null,
      card_holder_name: charge?.card?.name ?? null,
    }),
  }).catch(() => undefined);

  return new Response(JSON.stringify({
    chargeId,
    status: charge?.status ?? "INITIATED",
    transactionUrl: charge?.transaction?.url ?? charge?.redirect?.url ?? null,
    requiresRedirect: true,
    saveCard: charge?.save_card ?? saveCard,
  }), { status: 200, headers: { "Content-Type": "application/json" } });
});
