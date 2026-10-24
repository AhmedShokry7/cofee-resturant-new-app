// supabase/functions/rate-limit/index.test.ts
import { assertEquals, assert } from "jsr:@std/assert";
import { handleRequest, getLimit } from "./index.ts";

function createDeps(overrides: {
  caller?: string | null;
  rpcResult?: any;
  rpcError?: any;
  calls?: { userId: string; endpoint: string }[];
}) {
  const calls = overrides.calls ?? [];

  const store = {
    from: () => { throw new Error('rate limit must not run a per-request cleanup query'); },
    rpc: async (name: string, args: any) => {
      calls.push({ userId: args.p_user_id, endpoint: args.p_endpoint });
      if (overrides.rpcError) return { data: null, error: overrides.rpcError };
      return {
        data: overrides.rpcResult ?? [
          { allowed: true, remaining: 9, reset_at: "2026-01-01T00:00:00Z" },
        ],
        error: null,
      };
    },
  };

  return {
    deps: {
      store,
      caller: async () => (overrides.caller === undefined ? "user-1" : overrides.caller),
      now: () => "2026-01-01T00:00:00Z",
    },
    calls,
  };
}

function createRequest(body: any): Request {
  return new Request("https://example.com/rate-limit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("1. a non POST request is rejected", async () => {
  const req = new Request("https://example.com/rate-limit", { method: "GET" });
  const { deps } = createDeps({});
  const res = await handleRequest(req, deps as any);
  assertEquals(res.status, 405);
});

Deno.test("2. an invalid body is rejected", async () => {
  const req = new Request("https://example.com/rate-limit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "not json",
  });
  const { deps } = createDeps({});
  const res = await handleRequest(req, deps as any);
  assertEquals(res.status, 400);
});

Deno.test("3. the bucket is the caller, never the user id in the body", async () => {
  const { deps, calls } = createDeps({ caller: "verified-user" });
  const res = await handleRequest(
    createRequest({ user_id: "someone-else", endpoint: "place_order" }),
    deps as any,
  );
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);
  assertEquals(calls[0].userId, "verified-user");
});

Deno.test("4. a request without a resolvable caller is refused", async () => {
  const { deps, calls } = createDeps({ caller: null });
  const res = await handleRequest(
    createRequest({ user_id: "someone-else", endpoint: "place_order" }),
    deps as any,
  );
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0, "no counter may be touched for an unknown caller");
});

Deno.test("5. an exhausted quota answers 429", async () => {
  const { deps } = createDeps({
    rpcResult: [{ allowed: false, remaining: 0, reset_at: "2026-01-01T00:00:00Z" }],
  });
  const res = await handleRequest(
    createRequest({ endpoint: "place_order" }),
    deps as any,
  );
  assertEquals(res.status, 429);
  const body = await res.json();
  assertEquals(body.allowed, undefined);
  assertEquals(body.error, "Too many requests");
});

Deno.test("6. a broken counter fails open so the app stays usable", async () => {
  const { deps } = createDeps({ rpcError: { message: "down" } });
  const res = await handleRequest(
    createRequest({ endpoint: "search" }),
    deps as any,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.allowed, true);
});

Deno.test("7. the limit per endpoint is the documented one", () => {
  assertEquals(getLimit("place_order"), 10);
  assertEquals(getLimit("replace_cart"), 60);
  assertEquals(getLimit("search"), 120);
  assertEquals(getLimit("something-else"), 60);
});
