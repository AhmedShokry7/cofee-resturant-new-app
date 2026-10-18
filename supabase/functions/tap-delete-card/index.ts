// supabase/functions/tap-delete-card/index.ts
import { getUserFromRequest, serviceFetch, tapRequest } from "../_shared/tap.ts";

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
  const cardRowId = String(body?.cardId ?? "").trim();
  if (!cardRowId) {
    return new Response(JSON.stringify({ error: "cardId is required" }), { status: 400 });
  }

  const rows = await serviceFetch(
    `/saved_cards?select=id,tap_customer_id,tap_card_id,user_id,is_active&id=eq.${encodeURIComponent(cardRowId)}&user_id=eq.${encodeURIComponent(user.id)}`,
  );
  const card = Array.isArray(rows) ? rows[0] : null;
  if (!card) {
    return new Response(JSON.stringify({ error: "Card not found" }), { status: 404 });
  }

  // Delete at Tap first. If the provider delete fails, do not deactivate
  // locally or report success: the card may still be chargeable.
  let providerDeleted = false;
  try {
    await tapRequest(`/cards/${card.tap_card_id}`, { method: "DELETE" });
    providerDeleted = true;
  } catch (error) {
    const message = String(error);
    // Treat a 404 as already deleted.
    if (message.includes("404")) providerDeleted = true;
    else {
      return new Response(JSON.stringify({ error: message, deleted: false }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  if (providerDeleted) {
    await serviceFetch(
      `/saved_cards?id=eq.${encodeURIComponent(cardRowId)}`,
      {
        method: "PATCH",
        body: JSON.stringify({ is_active: false }),
      },
    ).catch(() => undefined);
  }

  return new Response(JSON.stringify({ deleted: providerDeleted }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
