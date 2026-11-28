import {
  amountInMinorUnits,
  getUserFromRequest,
  serviceFetch,
  userRpc,
} from "../_shared/moyasar.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

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
  const orderId = String(body?.orderId ?? "").trim();
  const subscriptionId = String(body?.subscriptionId ?? "").trim();
  const checkout = body?.checkout;
  const isCheckout = checkout !== null && typeof checkout === "object" &&
    !Array.isArray(checkout);
  if (isCheckout && (orderId || subscriptionId)) {
    return json({ error: "Checkout cannot be combined with another target" }, 400);
  }
  if (!isCheckout && ((!orderId && !subscriptionId) || (orderId && subscriptionId))) {
    return json({ error: "Provide one payment target" }, 400);
  }

  let amount: unknown;
  let currency: string;
  let targetId: string;

  if (isCheckout) {
    const branchId = String(checkout.branch_id ?? "").trim();
    const lines = checkout.lines;
    const fulfillmentType = String(checkout.fulfillment_type ?? "");
    const paymentMethodCode = String(checkout.payment_method_code ?? "card").trim().toLowerCase();
    const idempotencyKey = String(checkout.idempotency_key ?? "").trim();
    const zoneId = String(checkout.delivery_zone_id ?? "").trim();
    const addressId = String(checkout.address_id ?? "").trim();
    const couponCode = String(checkout.coupon_code ?? "").trim();
    const scheduledPickupAt = String(checkout.scheduled_pickup_at ?? "").trim();
    const subscriptionRunId = String(checkout.subscription_run_id ?? "").trim();
    if (!/^[0-9a-f-]{36}$/i.test(branchId) || !Array.isArray(lines) ||
      lines.length === 0 || lines.length > 100 || !idempotencyKey ||
      !["pickup", "delivery"].includes(fulfillmentType) ||
      !["card", "mada", "stc_pay", "apple_pay", "samsung_pay"].includes(paymentMethodCode)) {
      return json({ error: "Invalid checkout details" }, 400);
    }
    if (fulfillmentType === "delivery" &&
      (!/^[0-9a-f-]{36}$/i.test(zoneId) || !/^[0-9a-f-]{36}$/i.test(addressId))) {
      return json({ error: "Delivery details are incomplete" }, 400);
    }
    const quoteRows = await userRpc(req, "quote_checkout", {
      p_branch_id: branchId,
      p_lines: lines,
      p_fulfillment_type: fulfillmentType,
      ...(zoneId ? { p_delivery_zone_id: zoneId } : {}),
      ...(couponCode ? { p_coupon_code: couponCode } : {}),
      ...(addressId ? { p_address_id: addressId } : {}),
    });
    const quote = Array.isArray(quoteRows) ? quoteRows[0] : null;
    if (!quote) return json({ error: "Checkout quote unavailable" }, 409);
    const methods = await serviceFetch(
      `/payment_methods?select=id,code,is_online,is_active&code=eq.${encodeURIComponent(paymentMethodCode)}&limit=1`,
    );
    const method = Array.isArray(methods) ? methods[0] : null;
    if (!method?.is_active || !method?.is_online) {
      return json({ error: "Payment method is unavailable" }, 409);
    }
    amount = quote.grand_total;
    currency = String(quote.currency_code ?? "SAR").toUpperCase();
    targetId = branchId;
    const minorAmount = amountInMinorUnits(amount, currency);
    if (minorAmount < 100) return json({ error: "Invalid payment amount" }, 400);

    const existing = await serviceFetch(
      `/moyasar_checkout_intents?select=payment_id,amount,currency_code,status&user_id=eq.${encodeURIComponent(user.id)}&checkout_key=eq.${encodeURIComponent(idempotencyKey)}&status=in.(pending,captured,finalized)&limit=1`,
    );
    const prior = Array.isArray(existing) ? existing[0] : null;
    if (prior) {
      return json({
        paymentId: prior.payment_id,
        amount: amountInMinorUnits(prior.amount, prior.currency_code),
        currency: prior.currency_code,
        description: "Coffee checkout",
      });
    }

    const paymentId = crypto.randomUUID();
    const checkoutPayload = {
      branch_id: branchId,
      lines,
      fulfillment_type: fulfillmentType,
      payment_method_code: paymentMethodCode,
      idempotency_key: idempotencyKey,
      ...(zoneId ? { delivery_zone_id: zoneId } : {}),
      ...(addressId ? { address_id: addressId } : {}),
      ...(couponCode ? { coupon_code: couponCode } : {}),
      ...(scheduledPickupAt ? { scheduled_pickup_at: scheduledPickupAt } : {}),
      ...(subscriptionRunId ? { subscription_run_id: subscriptionRunId } : {}),
    };
    await serviceFetch("/moyasar_checkout_intents", {
      method: "POST",
      headers: { "Prefer": "return=minimal" },
      body: JSON.stringify({
        payment_id: paymentId,
        user_id: user.id,
        checkout_payload: checkoutPayload,
        checkout_key: idempotencyKey,
        amount,
        currency_code: currency,
        status: "pending",
      }),
    });
    return json({
      paymentId,
      amount: minorAmount,
      currency,
      description: `Coffee checkout ${targetId}`,
    });
  }

  if (orderId) {
    const orderFilter = `id=eq.${encodeURIComponent(orderId)}`;
    let rows: any[];
    try {
      rows = await serviceFetch(
        `/orders?select=id,user_id,grand_total,currency_code,payment_status,test_only&${orderFilter}`,
      );
    } catch (error) {
      // The optional test marker is absent in older production schemas. In
      // that case, retry the same owner and price lookup without the column.
      const message = error instanceof Error ? error.message : String(error);
      if (!message.includes("column orders.test_only does not exist")) throw error;
      rows = await serviceFetch(
        `/orders?select=id,user_id,grand_total,currency_code,payment_status&${orderFilter}`,
      );
    }
    const order = Array.isArray(rows) ? rows[0] : null;
    if (!order || order.user_id !== user.id) {
      return json({ error: "Order not found" }, 404);
    }
    if (order.test_only === true) {
      return json({ error: "Test orders cannot use Moyasar" }, 409);
    }
    if (order.payment_status === "paid") {
      return json({ error: "Order already paid" }, 409);
    }
    amount = order.grand_total;
    currency = String(order.currency_code ?? "SAR").toUpperCase();
    targetId = orderId;
  } else {
    const rows = await serviceFetch(
      `/subscriptions?select=id,user_id,status,plan&id=eq.${
        encodeURIComponent(subscriptionId)
      }`,
    );
    const subscription = Array.isArray(rows) ? rows[0] : null;
    if (!subscription || subscription.user_id !== user.id) {
      return json({ error: "Subscription not found" }, 404);
    }
    if (subscription.status !== "pending_payment") {
      return json({ error: "Subscription is not pending payment" }, 409);
    }
    amount = subscription.plan?.price;
    currency = String(subscription.plan?.currency_code ?? "SAR").toUpperCase();
    targetId = subscriptionId;
  }

  const minorAmount = amountInMinorUnits(amount, currency);
  if (minorAmount < 100) return json({ error: "Invalid payment amount" }, 400);

  // A fresh provider id is created for every attempt. It also ties the SDK
  // payment to this server-priced order before card details are entered.
  const paymentId = crypto.randomUUID();
  const methods = await serviceFetch(
    "/payment_methods?select=id&code=eq.card&limit=1",
  );
  const methodId = Array.isArray(methods) ? methods[0]?.id : null;
  if (orderId && methodId) {
    await serviceFetch("/payment_attempts", {
      method: "POST",
      headers: { "Prefer": "return=minimal" },
      body: JSON.stringify({
        order_id: orderId,
        method_id: methodId,
        status: "initiated",
        client_initiated: true,
        idempotency_key: paymentId,
      }),
    });
  }
  await serviceFetch("/payment_transactions", {
    method: "POST",
    headers: { "Prefer": "return=minimal" },
    body: JSON.stringify({
      ...(orderId
        ? { order_id: orderId }
        : { subscription_id: subscriptionId }),
      provider: "moyasar",
      provider_reference: paymentId,
      amount,
      currency_code: currency,
      status: "pending",
      verified_by_server: false,
    }),
  });

  return json({
    paymentId,
    amount: minorAmount,
    currency,
    description: `Coffee order ${targetId}`,
  });
}

if (import.meta.main) Deno.serve(handleRequest);
