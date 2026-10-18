// supabase/functions/tap-tokenize-card/index.ts
//
// Tokenizes a card the customer typed in and stores it as a reusable saved
// card, so "add card" works from anywhere in the app and not only as a side
// effect of paying.
//
// Card data (number, CVV) goes straight to Tap and is never written here or
// anywhere in Postgres: the row keeps only the provider token plus the display
// fields the list needs. That is the same shape `tap-verify-charge` produces,
// so charging a saved card later needs no special case.
//
// Failures answer with a stable `code` the app can map to its own language;
// the raw provider text never leaves the function.
import { getUserFromRequest, serviceFetch, tapRequest } from "../_shared/tap.ts";

function digits(value: unknown): string {
  return String(value ?? "").replace(/\D/g, "");
}

function fail(code: string, status: number, detail?: string): Response {
  return new Response(JSON.stringify({ error: code, detail: detail ?? null }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return fail("method_not_allowed", 405);
  }
  const user = await getUserFromRequest(req);
  if (!user) {
    return fail("unauthorized", 401);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return fail("invalid_json", 400);
  }

  const number = digits(body?.number);
  const expiryMonth = digits(body?.expiryMonth).padStart(2, "0");
  const expiryYear = digits(body?.expiryYear);
  const cvv = digits(body?.cvv);
  const holderName = String(body?.holderName ?? "").trim();

  if (number.length < 12 || number.length > 19) {
    return fail("invalid_card_number", 400);
  }
  if (expiryMonth.length !== 2 || Number(expiryMonth) < 1 || Number(expiryMonth) > 12) {
    return fail("invalid_expiry", 400);
  }
  if (expiryYear.length < 2) {
    return fail("invalid_expiry", 400);
  }
  if (cvv.length < 3 || cvv.length > 4) {
    return fail("invalid_cvv", 400);
  }
  if (!holderName) {
    return fail("missing_holder_name", 400);
  }

  // Reuse this customer's Tap customer, or create one so the card can be
  // charged again later without re-entering the number.
  let tapCustomerId: string | null = null;
  const customers = await serviceFetch(
    `/tap_customers?select=tap_customer_id&user_id=eq.${encodeURIComponent(user.id)}`,
  );
  if (Array.isArray(customers) && customers.length > 0) {
    tapCustomerId = customers[0].tap_customer_id;
  }
  if (!tapCustomerId) {
    try {
      const customer = await tapRequest("/customers", {
        method: "POST",
        body: JSON.stringify({
          first_name: user.email?.split("@")[0] ?? "Customer",
          email: user.email,
        }),
      });
      tapCustomerId = customer?.id ?? null;
    } catch (error) {
      return fail("provider_error", 502, String(error));
    }
    if (!tapCustomerId) {
      return fail("provider_error", 502);
    }
    await serviceFetch("/tap_customers", {
      method: "POST",
      headers: { "Prefer": "resolution=merge-duplicates" },
      body: JSON.stringify({ user_id: user.id, tap_customer_id: tapCustomerId }),
    }).catch(() => undefined);
  }

// `save_card: true` is a *charge*-level parameter in Tap's API, not a token
  // one. Passing it to /tokens caused the validator to reject the request, so
  // the card never tokenized. The customer_id alone is what asks Tap to store
  // the card on the customer for later reuse.
  try {
    token = await tapRequest("/tokens", {
      method: "POST",
      body: JSON.stringify({
        customer_id: tapCustomerId,
        card: {
          number,
          holder_name: holderName,
          expiry_month: Number(expiryMonth),
          expiry_year: 2000 + Number(expiryYear.slice(-2)),
          cvv,
        },
      }),
    });
  } catch (error) {
    // Tap declined the card or could not read it. Both are the customer's next
    // action, not ours, and neither is worth showing verbatim.
    return fail("card_declined", 422, String(error));
  }

  const card = token?.card;
  if (!token?.id || !card?.id) {
    return fail("provider_error", 502);
  }

  const last4 = String(card.last_four ?? "").slice(-4);
  const payload = {
    user_id: user.id,
    tap_customer_id: tapCustomerId,
    tap_card_id: card.id,
    payment_agreement_id: card.payment_agreement?.id ?? token?.payment_agreement?.id ?? null,
    brand: card.brand ?? card.scheme ?? null,
    last4: last4.length === 4 ? last4 : null,
    expiry_month: card.expiry_month != null ? String(card.expiry_month).padStart(2, "0") : expiryMonth,
    expiry_year: card.expiry_year != null ? String(card.expiry_year).slice(-2) : expiryYear.slice(-2),
    holder_name: card.name ?? holderName,
    is_active: true,
  };

  let saved: any;
  try {
    // `return=representation` is what makes PostgREST hand back the row, so
    // the app can reference the new card straight away.
    saved = await serviceFetch("/saved_cards", {
      method: "POST",
      headers: { "Prefer": "resolution=merge-duplicates,return=representation" },
      body: JSON.stringify(payload),
    });
  } catch (error) {
    return fail("provider_error", 500, String(error));
  }

  const row = Array.isArray(saved) ? saved[0] : saved;
  return new Response(JSON.stringify({
    id: row?.id ?? null,
    brand: payload.brand,
    last4: payload.last4,
    expiryMonth: payload.expiry_month,
    expiryYear: payload.expiry_year,
    holderName: payload.holder_name,
  }), { status: 201, headers: { "Content-Type": "application/json" } });
});