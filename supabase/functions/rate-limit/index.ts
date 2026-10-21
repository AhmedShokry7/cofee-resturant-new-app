// supabase/functions/rate-limit/index.ts
//
// Middleware-style Edge Function for rate limiting.
// Protects high-traffic endpoints (place_order, search, cart replacement)
// from being flooded when the app scales to thousands/millions of users.
//
// Usage: call this function before the target business logic, passing the
// user id (from auth) and the endpoint name. It returns 429 Too Many Requests
// when the limit is exceeded.
//
// Limits are tracked per user per endpoint in a Supabase table
// `public.rate_limit_counters` (created by migration 091).
//
// In production on Supabase Pro+, replace the in-memory fallback with Redis
// or use Supabase's built-in API rate limiting in the Dashboard.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Maximum requests per window per user per endpoint.
const LIMITS: Record<string, number> = {
  "place_order": 10,        // 10 orders per hour per user
  "replace_cart": 60,       // 60 cart replacements per hour per user
  "search": 120,            // 120 searches per hour per user
  "default": 60,            // 60 requests per hour per user for anything else
};

// Window length in seconds (1 hour = 3600).
const WINDOW_SECONDS = 3600;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false },
});

function getLimit(endpoint: string): number {
  return LIMITS[endpoint] ?? LIMITS.default;
}

function nowIso(): string {
  return new Date().toISOString();
}

Deno.serve(async (req) => {
  // Only POST allowed.
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } },
    );
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const userId = String(body?.user_id ?? "").trim();
  const endpoint = String(body?.endpoint ?? "default").trim();
  const cost = Number(body?.cost ?? 1); // optional weight, default 1

  if (!userId) {
    return new Response(
      JSON.stringify({ error: "user_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const limit = getLimit(endpoint);

  try {
    // Clean up expired counters first (best-effort, non-blocking).
    await supabase
      .from("rate_limit_counters")
      .delete()
      .lt("expires_at", nowIso());

    // Try to increment the counter atomically using an upsert.
    const { data, error } = await supabase.rpc("increment_rate_limit", {
      p_user_id: userId,
      p_endpoint: endpoint,
      p_cost: cost,
      p_limit: limit,
      p_window_seconds: WINDOW_SECONDS,
    });

    if (error) throw error;

    const result: { allowed: boolean; remaining: number; reset_at: string } =
      data?.[0] ?? { allowed: false, remaining: 0, reset_at: nowIso() };

    if (!result.allowed) {
      return new Response(
        JSON.stringify({
          error: "Too many requests",
          limit,
          remaining: result.remaining,
          reset_at: result.reset_at,
        }),
        {
          status: 429,
          headers: {
            "Content-Type": "application/json",
            "Retry-After": String(
              Math.ceil(
                (new Date(result.reset_at).getTime() - Date.now()) / 1000,
              ),
            ),
          },
        },
      );
    }

    return new Response(
      JSON.stringify({
        allowed: true,
        limit,
        remaining: result.remaining,
        reset_at: result.reset_at,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    // If the rate-limit infrastructure is down, fail open (allow the request)
    // so the app stays usable. Log the error for investigation.
    console.error("rate-limit error:", err);
    return new Response(
      JSON.stringify({ allowed: true, remaining: limit - 1, reset_at: nowIso() }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }
});
