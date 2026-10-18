// supabase/functions/tap-verify-charge/index.ts
import { getUserFromRequest, serviceFetch, tapRequest, hmacSha256Hex } from "../_shared/tap.ts";

function mapTapStatus(status: string): string {
  const s = (status || "").toUpperCase();
  if (s === "CAPTURED") return "captured";
  if (s === "AUTHORIZED") return "authorized";
  if (s === "FAILED" || s === "DECLINED" || s === "RESTRICTED" || s === "TIMEDOUT" || s === "ABANDONED") return "failed";
  if (s === "CANCELLED" || s === "VOID") return "voided";
  return "pending";
}

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
  const chargeId = String(body?.chargeId ?? "").trim();
  if (!chargeId) {
    return new Response(JSON.stringify({ error: "chargeId is required" }), { status: 400 });
  }

  // Ensure the charge belongs to this user.
  const txRows = await serviceFetch(
    `/payment_transactions?select=id,order_id,subscription_id,status&provider=eq.tap&provider_reference=eq.${encodeURIComponent(chargeId)}`,
  );
  const tx = Array.isArray(txRows) ? txRows[0] : null;
  if (!tx) {
    return new Response(JSON.stringify({ error: "Transaction not found" }), { status: 404 });
  }
  let ownerId = null;
  if (tx.order_id) {
    const orderRows = await serviceFetch(
      `/orders?select=id,user_id&id=eq.${encodeURIComponent(tx.order_id)}`,
    );
    const order = Array.isArray(orderRows) ? orderRows[0] : null;
    ownerId = order?.user_id ?? null;
  } else if (tx.subscription_id) {
    const subRows = await serviceFetch(
      `/subscriptions?select=id,user_id&id=eq.${encodeURIComponent(tx.subscription_id)}`,
    );
    const sub = Array.isArray(subRows) ? subRows[0] : null;
    ownerId = sub?.user_id ?? null;
  }
  if (ownerId !== user.id) {
    return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403 });
  }

  let charge: any;
  try {
    charge = await tapRequest(`/charges/${chargeId}`, { method: "GET" });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 502 });
  }

  const tapStatus = String(charge?.status ?? "");
  const newStatus = mapTapStatus(tapStatus);
  const verified = newStatus === "captured" || newStatus === "authorized";
  const now = new Date().toISOString();

  await serviceFetch(
    `/payment_transactions?provider=eq.tap&provider_reference=eq.${encodeURIComponent(chargeId)}`,
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

  // Update target payment status.
  const targetPaymentStatus = verified ? "paid" : (newStatus === "failed" ? "failed" : "pending");
  if (tx.order_id) {
    await serviceFetch(
      `/orders?id=eq.${encodeURIComponent(tx.order_id)}`,
      {
        method: "PATCH",
        body: JSON.stringify({ payment_status: targetPaymentStatus }),
      },
    ).catch(() => undefined);
  }
  if (verified && tx.subscription_id) {
    await serviceFetch("/rpc/activate_subscription", {
      method: "POST",
      body: JSON.stringify({
        p_subscription_id: tx.subscription_id,
        p_payment_reference: chargeId,
      }),
    }).catch(() => undefined);
  }

  // Persist saved card if Tap returned one and save_card was requested.
  const savedCard = charge?.card;
  const paymentAgreement = charge?.payment_agreement;
  const customerId = charge?.customer?.id;
  if (verified && saveCardRequested(charge) && savedCard?.id && customerId) {
    await upsertSavedCard(user.id, customerId, savedCard, paymentAgreement);
  }

  return new Response(JSON.stringify({
    chargeId,
    status: tapStatus,
    verified,
    orderPaymentStatus,
  }), { status: 200, headers: { "Content-Type": "application/json" } });
});

function saveCardRequested(charge: any): boolean {
  return charge?.save_card === true;
}

async function upsertSavedCard(userId: string, tapCustomerId: string, card: any, agreement: any) {
  // Ensure tap_customers row.
  await serviceFetch("/tap_customers", {
    method: "POST",
    headers: { "Prefer": "resolution=merge-duplicates" },
    body: JSON.stringify({ user_id: userId, tap_customer_id: tapCustomerId }),
  }).catch(() => undefined);

  const last4 = String(card.last_four ?? "").slice(-4);
  const payload = {
    user_id: userId,
    tap_customer_id: tapCustomerId,
    tap_card_id: card.id,
    payment_agreement_id: agreement?.id ?? null,
    brand: card.brand ?? card.scheme ?? null,
    last4: last4.length === 4 ? last4 : null,
    expiry_month: card.expiry_month ?? null,
    expiry_year: card.expiry_year ?? null,
    holder_name: card.name ?? null,
    is_active: true,
  };
  await serviceFetch("/saved_cards", {
    method: "POST",
    headers: { "Prefer": "resolution=merge-duplicates" },
    body: JSON.stringify(payload),
  }).catch(() => undefined);
}
