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
  const tokenId = String(body?.tokenId ?? "").trim();
  if (!/^token_[A-Za-z0-9_-]{8,}$/.test(tokenId)) {
    return json({ error: "Invalid token" }, 400);
  }
  let token: any;
  try {
    token = await moyasarApiRequest(`tokens/${encodeURIComponent(tokenId)}`);
  } catch {
    return json({ error: "Token verification unavailable" }, 502);
  }
  if (token?.id !== tokenId || token?.status !== "active") {
    return json({ error: "Card verification pending", status: token?.status }, 409);
  }
  if (token?.metadata?.user_id !== user.id) {
    return json({ error: "Forbidden" }, 403);
  }
  const last4 = String(token?.last_four ?? "");
  if (!/^\d{4}$/.test(last4)) return json({ error: "Invalid token details" }, 409);
  try {
    const existing = await serviceFetch(
      `/saved_card_provider?select=id,brand,last4,expiry_month,expiry_year,holder_name,provider&user_id=eq.${encodeURIComponent(user.id)}&provider=eq.moyasar&moyasar_token_id=eq.${encodeURIComponent(tokenId)}&limit=1`,
    );
    if (Array.isArray(existing) && existing.length > 0) {
      return json(existing[0], 200);
    }
    const rows = await serviceFetch("/saved_card_provider", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        user_id: user.id,
        provider: "moyasar",
        moyasar_token_id: tokenId,
        brand: token.brand === "master" ? "mastercard" : token.brand ?? null,
        last4,
        expiry_month: String(token.month ?? "").padStart(2, "0"),
        expiry_year: String(token.year ?? ""),
        holder_name: token.name ?? null,
        is_active: true,
      }),
    });
    if (!Array.isArray(rows) || !rows[0]?.id) throw new Error("Insert failed");
    return json(rows[0], 201);
  } catch {
    return json({ error: "Card storage failed" }, 503);
  }
}

if (import.meta.main) Deno.serve(handleRequest);
