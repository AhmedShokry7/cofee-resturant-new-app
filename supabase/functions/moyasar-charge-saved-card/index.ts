import {
  amountInMinorUnits,
  getUserFromRequest,
  moyasarApiRequest,
  moyasarRequest,
  serviceFetch,
  userRpc,
} from "../_shared/moyasar.ts";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "Content-Type": "application/json" },
});

export async function savedCardAttemptId(target: string, failedId = ""): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`moyasar-saved-card:${target}:${failedId}`),
  ));
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = [...digest.slice(0, 16)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
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
  const checkout = body?.checkout;
  const savedCardId = String(body?.savedCardId ?? "").trim();
  if (!savedCardId || !checkout || typeof checkout !== "object" || Array.isArray(checkout)) {
    return json({ error: "Checkout and saved card are required" }, 400);
  }

  const cardRows = await serviceFetch(
    `/saved_card_provider?select=id,user_id,provider,moyasar_token_id,is_active` +
      `&id=eq.${encodeURIComponent(savedCardId)}&user_id=eq.${encodeURIComponent(user.id)}` +
      `&provider=eq.moyasar&limit=1`,
  );
  const card = Array.isArray(cardRows) ? cardRows[0] : null;
  if (!card?.is_active || !String(card.moyasar_token_id ?? "")) {
    return json({ error: "Saved card not found" }, 404);
  }

  const branchId = String(checkout.branch_id ?? "").trim();
  const lines = checkout.lines;
  const fulfillmentType = String(checkout.fulfillment_type ?? "");
  const methodCode = String(checkout.payment_method_code ?? "card").toLowerCase();
  const checkoutKey = String(checkout.idempotency_key ?? "").trim();
  const zoneId = String(checkout.delivery_zone_id ?? "").trim();
  const addressId = String(checkout.address_id ?? "").trim();
  const couponCode = String(checkout.coupon_code ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(branchId) || !Array.isArray(lines) || !lines.length ||
    lines.length > 100 || !checkoutKey || !["pickup", "delivery"].includes(fulfillmentType) ||
    !["card", "mada"].includes(methodCode) ||
    (fulfillmentType === "delivery" && (!zoneId || !addressId))) {
    return json({ error: "Invalid checkout details" }, 400);
  }

  const quoteRows = await userRpc(req, "quote_checkout", {
    p_branch_id: branchId,
    p_lines: lines,
    p_fulfillment_type: fulfillmentType,
    ...(zoneId ? { p_delivery_zone_id: zoneId } : {}),
    ...(addressId ? { p_address_id: addressId } : {}),
    ...(couponCode ? { p_coupon_code: couponCode } : {}),
  });
  const quote = Array.isArray(quoteRows) ? quoteRows[0] : null;
  if (!quote) return json({ error: "Checkout quote unavailable" }, 409);
  const methodRows = await serviceFetch(
    `/payment_methods?select=id,code,is_online,is_active&code=eq.${methodCode}&limit=1`,
  );
  const method = Array.isArray(methodRows) ? methodRows[0] : null;
  if (!method?.is_active || !method?.is_online) return json({ error: "Payment method unavailable" }, 409);

  const amount = quote.grand_total;
  const currency = String(quote.currency_code ?? "SAR").toUpperCase();
  const minorAmount = amountInMinorUnits(amount, currency);
  if (minorAmount < 100) return json({ error: "Invalid payment amount" }, 400);

  const oldRows = await serviceFetch(
    `/moyasar_checkout_intents?select=payment_id,status,amount,currency_code` +
      `&user_id=eq.${encodeURIComponent(user.id)}&checkout_key=eq.${encodeURIComponent(checkoutKey)}` +
      `&status=in.(pending,captured,finalized)&limit=1`,
  );
  const old = Array.isArray(oldRows) ? oldRows[0] : null;
  if (old?.status === "finalized") return json({ error: "Checkout already paid" }, 409);

  let paymentId = String(old?.payment_id ?? crypto.randomUUID());
  let payment: any;
  if (old?.status === "pending") {
    try {
      payment = await moyasarRequest(paymentId);
    } catch {
      return json({ chargeId: paymentId, status: "pending", reused: true }, 200);
    }
    if (payment?.status === "paid") {
      return json({ chargeId: paymentId, status: "paid", reused: true }, 200);
    }
    if (payment?.status === "initiated") {
      return json({
        chargeId: paymentId,
        status: "initiated",
        transactionUrl: payment?.source?.transaction_url ?? null,
        requiresRedirect: Boolean(payment?.source?.transaction_url),
        reused: true,
      }, 200);
    }
    if (payment?.status !== "failed") {
      return json({ chargeId: paymentId, status: "pending", reused: true }, 200);
    }
    paymentId = crypto.randomUUID();
  }

  if (!old || paymentId !== String(old.payment_id)) {
    await serviceFetch("/moyasar_checkout_intents", {
      method: "POST",
      headers: { "Prefer": "return=minimal" },
      body: JSON.stringify({
        payment_id: paymentId,
        user_id: user.id,
        checkout_key: checkoutKey,
        checkout_payload: checkout,
        amount,
        currency_code: currency,
        status: "pending",
      }),
    });
  }

  try {
    payment = await moyasarApiRequest("payments", {
      method: "POST",
      body: JSON.stringify({
        given_id: paymentId,
        amount: minorAmount,
        currency,
        description: `Saved card checkout ${branchId}`,
        metadata: { user_id: user.id },
        source: { type: "token", token: card.moyasar_token_id, "3ds": true },
      }),
    });
    return json({
      chargeId: payment?.id ?? paymentId,
      status: payment?.status ?? "pending",
      transactionUrl: payment?.source?.transaction_url ?? null,
      requiresRedirect: Boolean(payment?.source?.transaction_url),
    });
  } catch {
    // Reconcile by the same id on retry; never mint a second charge on timeout.
    return json({ chargeId: paymentId, status: "pending", reused: true });
  }
}

if (import.meta.main) Deno.serve(handleRequest);
