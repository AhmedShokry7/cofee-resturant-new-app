import {
  amountInMinorUnits,
  getUserFromRequest,
  serviceFetch,
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
  if ((!orderId && !subscriptionId) || (orderId && subscriptionId)) {
    return json({ error: "Provide one payment target" }, 400);
  }

  let amount: unknown;
  let currency: string;
  let targetId: string;
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
      `/subscriptions?select=id,user_id,status,plan:plans(price,currency_code)&id=eq.${
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
