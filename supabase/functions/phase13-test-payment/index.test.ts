import { handleRequest } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

async function withEnv<T>(fn: () => Promise<T>): Promise<T> {
  const previous = new Map<string, string | undefined>();
  for (
    const [key, value] of Object.entries({
      SUPABASE_URL: "https://webzzasosevzymftgszn.supabase.co",
      SUPABASE_PUBLISHABLE_KEY: "public-test-key",
      SUPABASE_SECRET_KEYS: JSON.stringify({ default: "server-test-key" }),
    })
  ) {
    previous.set(key, Deno.env.get(key));
    Deno.env.set(key, value);
  }
  try {
    return await fn();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

const orderId = "123e4567-e89b-42d3-a456-426614174000";
const userId = "123e4567-e89b-42d3-a456-426614174001";

Deno.test("fails closed outside the explicitly authorized TEST project", async () => {
  await withEnv(async () => {
    Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
    let requests = 0;
    const response = await handleRequest(
      new Request("https://function.test", {
        method: "POST",
        body: JSON.stringify({ order_id: orderId }),
      }),
      (() => {
        requests++;
        return Promise.resolve(new Response());
      }) as typeof fetch,
    );
    assertEquals(response.status, 403);
    assertEquals(requests, 0);
  });
});

Deno.test("requires an authenticated session and rejects client payment fields", async () => {
  await withEnv(async () => {
    const fetcher = (() => Promise.resolve(new Response())) as typeof fetch;
    const missing = await handleRequest(
      new Request("https://function.test", {
        method: "POST",
        body: JSON.stringify({ order_id: orderId }),
      }),
      fetcher,
    );
    assertEquals(missing.status, 401);
    const forged = await handleRequest(
      new Request("https://function.test", {
        method: "POST",
        headers: { authorization: "Bearer real-session-token" },
        body: JSON.stringify({ order_id: orderId, payment_status: "paid" }),
      }),
      fetcher,
    );
    assertEquals(forged.status, 400);
  });
});

Deno.test("validates the GoTrue user and invokes only the server-side test RPC", async () => {
  await withEnv(async () => {
    const calls: { url: string; init?: RequestInit }[] = [];
    const fetcher = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      calls.push({ url, init });
      if (url.endsWith("/auth/v1/user")) return Response.json({ id: userId });
      return Response.json({
        order_id: orderId,
        payment_transaction_id: userId,
        provider: "codex_phase13_test",
        provider_reference: `phase13-test:${orderId}`,
        status: "captured",
        verified_by_server: true,
        simulated_test_payment: true,
        idempotent_replay: false,
      });
    }) as typeof fetch;

    const response = await handleRequest(
      new Request("https://function.test", {
        method: "POST",
        headers: { authorization: "Bearer actual-go-true-session" },
        body: JSON.stringify({ order_id: orderId }),
      }),
      fetcher,
    );
    assertEquals(response.status, 200);
    const body = await response.json();
    assertEquals(body.real_payment, false);
    assertEquals(body.environment, "test");
    assertEquals(calls.length, 2);
    assertEquals(calls[0].url.endsWith("/auth/v1/user"), true);
    assertEquals(
      calls[1].url.endsWith("/rpc/complete_phase13_test_payment"),
      true,
    );
    assertEquals(JSON.parse(String(calls[1].init?.body)), {
      p_order_id: orderId,
      p_actor_user_id: userId,
    });
    assertEquals(
      new Headers(calls[1].init?.headers).get("authorization"),
      "Bearer server-test-key",
    );
    assertEquals(
      new Headers(calls[1].init?.headers).get("content-profile"),
      "public",
    );
  });
});

Deno.test("unauthenticated and non-allowlisted identities cannot reach success", async () => {
  await withEnv(async () => {
    const fetcher = (async (input: RequestInfo | URL) => {
      if (String(input).endsWith("/auth/v1/user")) {
        return Response.json({ id: userId });
      }
      return new Response("denied", { status: 403 });
    }) as typeof fetch;
    const response = await handleRequest(
      new Request("https://function.test", {
        method: "POST",
        headers: { authorization: "Bearer actual-go-true-session" },
        body: JSON.stringify({ order_id: orderId }),
      }),
      fetcher,
    );
    assertEquals(response.status, 403);
    assertEquals(await response.json(), {
      error: "test_customer_not_authorized",
    });
  });
});
