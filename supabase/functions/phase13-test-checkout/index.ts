// Authenticated, run-pinned checkout for the single Phase 1.3 test project.
// The customer JWT is forwarded to PostgREST; no service-role checkout occurs.
type Json = Record<string, unknown>;
type Fetcher = typeof fetch;

const HOST = "webzzasosevzymftgszn.supabase.co";
const RUN = "b105bd82-18df-4e6a-9b10-306d5ed5e1bc";
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: Json, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function apiKey(): string {
  const direct = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY");
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
    return typeof keys.default === "string" ? keys.default : "";
  } catch {
    return "";
  }
}

export async function handleRequest(
  req: Request,
  fetcher: Fetcher = fetch,
): Promise<Response> {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const projectValue = Deno.env.get("SUPABASE_URL") ?? "";
  let project: URL;
  try {
    project = new URL(projectValue);
  } catch {
    return json({ error: "harness_not_configured" }, 503);
  }
  if (project.protocol !== "https:" || project.hostname !== HOST) {
    return json({ error: "test_project_only" }, 403);
  }
  const key = apiKey();
  if (!key) return json({ error: "harness_not_configured" }, 503);
  const bearer = /^Bearer\s+([^\s]+)$/i.exec(
    req.headers.get("authorization") ?? "",
  )?.[1];
  if (!bearer) return json({ error: "unauthorized" }, 401);

  let input: unknown;
  try {
    input = await req.json();
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return json({ error: "invalid_request" }, 400);
  }
  const body = input as Record<string, unknown>;
  if (
    Object.keys(body).length !== 2 || body.run_id !== RUN ||
    typeof body.idempotency_key !== "string" || !UUID.test(body.idempotency_key)
  ) {
    return json({ error: "invalid_request" }, 400);
  }

  let auth: Response;
  try {
    auth = await fetcher(`${project.origin}/auth/v1/user`, {
      headers: { apikey: key, authorization: `Bearer ${bearer}` },
    });
  } catch {
    return json({ error: "authentication_unavailable" }, 503);
  }
  if (!auth.ok) return json({ error: "unauthorized" }, 401);
  let user: Json;
  try {
    user = await auth.json() as Json;
  } catch {
    return json({ error: "unauthorized" }, 401);
  }
  if (typeof user.id !== "string" || !UUID.test(user.id)) {
    return json({ error: "unauthorized" }, 401);
  }

  let result: Response;
  try {
    result = await fetcher(
      `${project.origin}/rest/v1/rpc/phase13_test_checkout`,
      {
        method: "POST",
        headers: {
          apikey: key,
          authorization: `Bearer ${bearer}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          p_run_id: RUN,
          p_idempotency_key: body.idempotency_key,
        }),
      },
    );
  } catch {
    return json({ error: "checkout_unavailable" }, 503);
  }
  if (!result.ok) {
    if (result.status === 401 || result.status === 403) {
      return json({ error: "test_customer_not_authorized" }, 403);
    }
    if (result.status === 404) {
      return json({ error: "test_fixtures_unavailable" }, 404);
    }
    if (
      result.status === 400 || result.status === 409 || result.status === 422
    ) return json({ error: "test_checkout_rejected" }, 409);
    return json({ error: "test_checkout_failed" }, 500);
  }
  let order: Json;
  try {
    order = await result.json() as Json;
  } catch {
    return json({ error: "test_checkout_failed" }, 500);
  }
  if (
    order.test_only !== true || order.run_id !== RUN ||
    typeof order.order_id !== "string"
  ) {
    return json({ error: "unexpected_checkout_result" }, 500);
  }
  return json({ ...order, environment: "test", real_payment: false });
}

if (import.meta.main) Deno.serve((req) => handleRequest(req));
