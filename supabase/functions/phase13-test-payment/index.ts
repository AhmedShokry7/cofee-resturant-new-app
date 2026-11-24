// Isolated simulated payment adapter for Phase 1.3 acceptance tests.
// This is not Tap, does not contact a payment provider, and fails closed unless
// deployed to the single explicitly authorized test project.
type Json = Record<string, unknown>;
type Fetcher = typeof fetch;

const AUTHORIZED_PROJECT_HOST = "webzzasosevzymftgszn.supabase.co";
const UUID_RE =
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

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error("missing_configuration");
  return value;
}

function publicApiKey(): string {
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

function serviceRoleKey(): string {
  const direct = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    if (typeof keys.default === "string" && keys.default.length > 0) {
      return keys.default;
    }
  } catch {
    // Fail closed below without returning configuration values.
  }
  throw new Error("missing_configuration");
}

export async function handleRequest(
  req: Request,
  fetcher: Fetcher = fetch,
): Promise<Response> {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let projectUrl: URL;
  try {
    projectUrl = new URL(env("SUPABASE_URL"));
  } catch {
    return json({ error: "harness_not_configured" }, 503);
  }
  if (
    projectUrl.protocol !== "https:" ||
    projectUrl.hostname !== AUTHORIZED_PROJECT_HOST
  ) {
    return json({ error: "test_project_only" }, 403);
  }

  const apiKey = publicApiKey();
  if (!apiKey) return json({ error: "harness_not_configured" }, 503);

  const authorization = req.headers.get("authorization") ?? "";
  const bearer = /^Bearer\s+([^\s]+)$/i.exec(authorization)?.[1];
  if (!bearer) return json({ error: "unauthorized" }, 401);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "invalid_request" }, 400);
  }
  const input = body as Record<string, unknown>;
  if (
    Object.keys(input).length !== 1 || typeof input.order_id !== "string" ||
    !UUID_RE.test(input.order_id)
  ) {
    return json({ error: "invalid_order_id" }, 400);
  }

  let authResponse: Response;
  try {
    authResponse = await fetcher(`${projectUrl.origin}/auth/v1/user`, {
      headers: { apikey: apiKey, authorization: `Bearer ${bearer}` },
    });
  } catch {
    return json({ error: "authentication_unavailable" }, 503);
  }
  if (!authResponse.ok) return json({ error: "unauthorized" }, 401);

  let user: Json;
  try {
    user = await authResponse.json() as Json;
  } catch {
    return json({ error: "unauthorized" }, 401);
  }
  if (typeof user.id !== "string" || !UUID_RE.test(user.id)) {
    return json({ error: "unauthorized" }, 401);
  }

  let serviceKey: string;
  try {
    serviceKey = serviceRoleKey();
  } catch {
    return json({ error: "harness_not_configured" }, 503);
  }

  let paymentResponse: Response;
  try {
    paymentResponse = await fetcher(
      `${projectUrl.origin}/rest/v1/rpc/complete_phase13_test_payment`,
      {
        method: "POST",
        headers: {
          apikey: serviceKey,
          authorization: `Bearer ${serviceKey}`,
          "content-profile": "public",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          p_order_id: input.order_id,
          p_actor_user_id: user.id,
        }),
      },
    );
  } catch {
    return json({ error: "test_payment_unavailable" }, 503);
  }

  if (!paymentResponse.ok) {
    if (paymentResponse.status === 401 || paymentResponse.status === 403) {
      return json({ error: "test_customer_not_authorized" }, 403);
    }
    if (paymentResponse.status === 404) {
      return json({ error: "test_order_not_found" }, 404);
    }
    if (paymentResponse.status === 400 || paymentResponse.status === 409) {
      return json({ error: "test_order_not_eligible" }, 409);
    }
    return json({ error: "test_payment_failed" }, 500);
  }

  let result: Json;
  try {
    result = await paymentResponse.json() as Json;
  } catch {
    return json({ error: "test_payment_failed" }, 500);
  }
  if (
    result.simulated_test_payment !== true ||
    result.provider !== "codex_phase13_test"
  ) {
    return json({ error: "unexpected_test_payment_result" }, 500);
  }
  return json({ ...result, environment: "test", real_payment: false });
}

if (import.meta.main) Deno.serve((req) => handleRequest(req));
