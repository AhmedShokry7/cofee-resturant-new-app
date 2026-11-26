import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!url || !anonKey || !serviceKey || !token) return reply({ error: "unauthorized" }, 401);

  const caller = createClient(url, anonKey, { global: { headers: { Authorization: `Bearer ${token}` } } });
  const { data: userData, error: authError } = await caller.auth.getUser(token);
  if (authError || !userData.user) return reply({ error: "unauthorized" }, 401);
  const { request_id: requestId } = await request.json().catch(() => ({}));
  if (typeof requestId !== "string") return reply({ error: "request_id_required" }, 400);

  // This RPC checks the caller's admin permission before transitioning the
  // request. The service key is used only after that authorization succeeds.
  const { data: subjectId, error: claimError } = await caller.rpc("admin_claim_account_deletion", { p_id: requestId });
  if (claimError || typeof subjectId !== "string") return reply({ error: "not_allowed_or_request_closed" }, 403);

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  try {
    const { error: signOutError } = await admin.auth.admin.signOut(subjectId, "global");
    if (signOutError) throw signOutError;
    // Auth deletion cascades into the profile. A profile-delete trigger first
    // detaches historical orders, keeps financial rows, cancels future
    // reservations/subscriptions, and removes contact data transactionally.
    const { error: deleteError } = await admin.auth.admin.deleteUser(subjectId);
    if (deleteError) throw deleteError;
    const { error: finishError } = await admin.rpc("service_finish_account_deletion", {
      p_id: requestId,
      p_user: subjectId,
      p_error: null,
    });
    if (finishError) throw finishError;
    return reply({ status: "completed" }, 200);
  } catch (_error) {
    // Do not return or log personal or provider details. The request is made
    // retryable and the server records a generic failure reason.
    await admin.rpc("service_finish_account_deletion", {
      p_id: requestId,
      p_user: subjectId,
      p_error: "Account revocation failed; retry required",
    });
    return reply({ status: "pending", error: "processing_failed_retry_available" }, 503);
  }
});

function reply(body: Record<string, string>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
