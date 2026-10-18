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

  // Find order id from transaction.
  const txRows = await serviceFetch(
    `/payment_transactions?select=order_id&provider=eq.tap&provider_reference=eq.${encodeURIComponent(id)}&limit=1`,
  );
  const orderId = Array.isArray(txRows) && txRows[0] ? txRows[0].order_id : null;
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

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
