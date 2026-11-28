import {
  getUserFromRequest,
  moyasarApiRequest,
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
  const cardId = String(body?.cardId ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(cardId)) return json({ error: "Invalid card" }, 400);
  const rows = await serviceFetch(
    `/saved_card_provider?select=id,provider,moyasar_token_id,user_id,is_active&id=eq.${encodeURIComponent(cardId)}&user_id=eq.${encodeURIComponent(user.id)}&limit=1`,
  );
  const card = Array.isArray(rows) ? rows[0] : null;
  if (!card) return json({ error: "Card not found" }, 404);
  if (card.provider !== "moyasar") return json({ error: "Unsupported card provider" }, 409);
  if (!card.is_active) return json({ deleted: true });
  try {
    await moyasarApiRequest(`tokens/${encodeURIComponent(card.moyasar_token_id)}`, {
      method: "DELETE",
    });
  } catch (error) {
    if (!String(error).includes("404")) return json({ error: "Token deletion failed" }, 502);
  }
  await serviceFetch(
    `/saved_card_provider?id=eq.${encodeURIComponent(cardId)}&user_id=eq.${encodeURIComponent(user.id)}&provider=eq.moyasar`,
    { method: "PATCH", body: JSON.stringify({ is_active: false, is_default: false }) },
  );
  return json({ deleted: true });
}

if (import.meta.main) Deno.serve(handleRequest);
