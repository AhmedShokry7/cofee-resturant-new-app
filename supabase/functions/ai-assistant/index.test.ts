// supabase/functions/ai-assistant/index.test.ts
//
// F2 (the counter contract as the function uses it) and F3 (what happens
// when the limiter cannot be trusted).
//
// Nothing here touches the network, the database or a provider: the counter
// RPC and the provider call are both injected.
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildRequestBody,
  consumeQuota,
  handleRequest,
  type AssistantDeps,
  type Diagnostic,
  type Provider,
} from "./handler.ts";

const BRANCH = "branch";

function provider(): Provider {
  return {
    name: "configured",
    baseUrl: "https://provider.test/v1",
    apiKey: "secret-key",
    model: "test-model",
  };
}

type Overrides = {
  env?: Record<string, string>;
  rpc?: AssistantDeps["rpc"];
  askProvider?: AssistantDeps["askProvider"];
  resolveUser?: AssistantDeps["resolveUser"];
  now?: () => Date;
  quotaTimeoutMs?: number;
  providers?: AssistantDeps["providers"];
  recall?: AssistantDeps["recall"];
  remember?: AssistantDeps["remember"];
};

function deps(overrides: Overrides = {}) {
  const diagnostics: Diagnostic[] = [];
  let providerCalls = 0;
  const remembered: Array<{ questionKey: string; answer: string }> = [];

  const base: AssistantDeps = {
    // An override replaces the whole environment, so a test can remove a
    // variable instead of inheriting it.
    env: (name) =>
      overrides.env
        ? overrides.env[name]
        : ({
          SUPABASE_URL: "https://project.test",
          SUPABASE_SERVICE_ROLE_KEY: "service-key",
        } as Record<string, string>)[name],
    now: overrides.now ?? (() => new Date("2026-10-20T12:00:00.000Z")),
    resolveUser: overrides.resolveUser ?? (async () => null),
    rpc: overrides.rpc ??
      (async () => ({ data: [{ allowed: true, remaining: 14 }] })),
    recall: overrides.recall ?? (async () => null),
    remember: overrides.remember ??
      (async (input) => {
        remembered.push({
          questionKey: input.questionKey,
          answer: input.answer,
        });
      }),
    providers: overrides.providers ?? (() => [provider()]),
    askProvider: overrides.askProvider ??
      (async () => {
        providerCalls++;
        return { text: "hello" };
      }),
    log: (entry) => diagnostics.push(entry),
    quotaTimeoutMs: overrides.quotaTimeoutMs ?? 200,
  };

  return {
    deps: base,
    diagnostics,
    providerCalls: () => providerCalls,
    remembered,
  };
}

function postRequest(
  body: unknown = { messages: [{ role: "user", content: "hello" }] },
  headers: Record<string, string> = {},
  withAddress = true,
): Request {
  return new Request("https://project.test/functions/v1/ai-assistant", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      // The platform reports the caller's address. Without it the caller
      // cannot be identified and the request is refused, which is the point
      // of the unidentified case below.
      ...(withAddress ? { "x-forwarded-for": "203.0.113.9" } : {}),
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

// ---------------------------------------------------------------------------
// F2 â€” the policy the function enforces
// ---------------------------------------------------------------------------

Deno.test("a guest is allowed 15 questions an hour and a user 60", async () => {
  const guest = deps({
    rpc: async ({ limit }) => ({
      data: [{ allowed: limit >= 15, remaining: limit - 1 }],
    }),
  });
  const guestQuota = await consumeQuota(guest.deps, {
    kind: "guest",
    key: "guest:hash",
  });
  assertEquals(guestQuota.kind, "allow");

  const user = deps({
    rpc: async ({ limit }) => ({
      data: [{ allowed: true, remaining: limit - 1 }],
    }),
  });
  const userQuota = await consumeQuota(user.deps, {
    kind: "user",
    key: "user:123",
  });
  assertEquals(userQuota.kind, "allow");

  const asked: number[] = [];
  await consumeQuota(
    deps({
      rpc: async ({ limit }) => {
        asked.push(limit);
        return { data: [{ allowed: true, remaining: 0 }] };
      },
    }).deps,
    { kind: "guest", key: "guest:hash" },
  );
  await consumeQuota(
    deps({
      rpc: async ({ limit }) => {
        asked.push(limit);
        return { data: [{ allowed: true, remaining: 0 }] };
      },
    }).deps,
    { kind: "user", key: "user:123" },
  );
  assertEquals(asked, [15, 60]);
});

Deno.test("a request at the limit is allowed and the next one is refused", async () => {
  const atLimit = deps({
    rpc: async () => ({ data: [{ allowed: true, remaining: 0 }] }),
  });
  const allowed = await consumeQuota(atLimit.deps, { kind: "guest", key: "guest:h" });
  assertEquals(allowed.kind, "allow");
  assertEquals(allowed.kind === "allow" ? allowed.remaining : -1, 0);

  const overLimit = deps({
    rpc: async () => ({
      data: [{ allowed: false, remaining: 0, reset_at: "2026-10-20T13:00:00.000Z" }],
    }),
  });
  const denied = await consumeQuota(overLimit.deps, { kind: "guest", key: "guest:h" });
  assertEquals(denied.kind, "deny");
  assertEquals(denied.kind === "deny" ? denied.remaining : -1, 0);
});

Deno.test("a refused request answers 429 with the window the counter reported", async () => {
  const { deps: d, diagnostics } = deps({
    rpc: async () => ({
      data: [{ allowed: false, remaining: 0, reset_at: "2026-10-20T12:30:00.000Z" }],
    }),
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 429);
  const body = await response.json();
  assertEquals(body.remaining, 0);
  assertEquals(body.retryAfterSeconds, 1800);
  assertEquals(
    diagnostics.some((entry) => entry.event === "assistant_rate_limited"),
    true,
  );
});

Deno.test("a guest is counted without an address the caller can pick", async () => {
  const asked: string[] = [];
  const { deps: d } = deps({
    rpc: async ({ bucketKey }) => {
      asked.push(bucketKey);
      return { data: [{ allowed: true, remaining: 10 }] };
    },
  });

  await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "hello" }] },
      { "x-forwarded-for": "10.0.0.1, 203.0.113.9" },
    ),
    d,
  );
  await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "hello" }] },
      { "x-forwarded-for": "10.0.0.2, 203.0.113.9" },
    ),
    d,
  );

  assertEquals(asked.length, 2);
  assertEquals(asked[0], asked[1], "a forged header must not move the caller");
  assertEquals(asked[0].startsWith("guest:"), true);
  assertEquals(asked[0].includes("203.0.113.9"), false);
});

// ---------------------------------------------------------------------------
// F3 â€” what happens when the limiter cannot be trusted
// ---------------------------------------------------------------------------

Deno.test("a missing configuration fails closed", async () => {
  const { deps: d, providerCalls, diagnostics } = deps({ env: {} });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 503);
  assertEquals(providerCalls(), 0, "a provider request went out without a limiter");
  assertEquals(diagnostics[0]?.reason, "missing_env");
});

Deno.test("a missing service role key fails closed", async () => {
  const { deps: d, providerCalls, diagnostics } = deps({
    env: { SUPABASE_URL: "https://project.test" },
  });
  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 503);
  assertEquals(providerCalls(), 0);
  assertEquals(diagnostics[0]?.reason, "missing_env");
});

Deno.test("an RPC error fails closed", async () => {
  const { deps: d, providerCalls, diagnostics } = deps({
    rpc: async () => ({ error: { message: "boom", code: "P0001" } }),
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 503);
  assertEquals(providerCalls(), 0);
  assertEquals(diagnostics[0]?.reason, "rpc_error");
});

Deno.test("a permission failure fails closed and is reported as such", async () => {
  const { deps: d, providerCalls, diagnostics } = deps({
    rpc: async () => ({ error: { message: "denied", code: "42501" } }),
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 503);
  assertEquals(providerCalls(), 0);
  assertEquals(diagnostics[0]?.reason, "permission_denied");
});

Deno.test("a hanging counter fails closed instead of waiting forever", async () => {
  const { deps: d, providerCalls, diagnostics } = deps({
    rpc: () => new Promise(() => {}),
    quotaTimeoutMs: 30,
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 503);
  assertEquals(providerCalls(), 0);
  assertEquals(diagnostics[0]?.reason, "rpc_timeout");
});

Deno.test("a malformed counter answer fails closed", async () => {
  for (const data of [null, [], [{ allowed: "yes" }], [{ allowed: true }]]) {
    const { deps: d, providerCalls } = deps({ rpc: async () => ({ data }) });
    const response = await handleRequest(postRequest(), d);
    assertEquals(response.status, 503);
    assertEquals(providerCalls(), 0);
  }
});

Deno.test("a caller without a usable address is refused, not counted", async () => {
  let rpcCalls = 0;
  const { deps: d, providerCalls, diagnostics } = deps({
    rpc: async () => {
      rpcCalls++;
      return { data: [{ allowed: true, remaining: 1 }] };
    },
  });

  const response = await handleRequest(postRequest(undefined, {}, false), d);
  assertEquals(response.status, 503);
  assertEquals(providerCalls(), 0);
  assertEquals(rpcCalls, 0);
  assertEquals(diagnostics[0]?.reason, "unidentified_caller");
});

Deno.test("the failure answer is a service error, not a quota error", async () => {
  const { deps: d } = deps({ rpc: async () => ({ error: { message: "x" } }) });
  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 503);
  const body = await response.json();
  assertEquals(body.remaining, undefined);
  assert(String(body.error).length > 0);
  assertEquals(String(body.error).toLowerCase().includes("too many"), false);
});

Deno.test("the diagnostics never carry an address, a key or a message", async () => {
  const { deps: d, diagnostics } = deps({
    rpc: async () => ({ error: { message: "secret details" } }),
  });

  await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "my card number is 4111" }] },
      { "x-forwarded-for": "203.0.113.9", authorization: "Bearer eyJhbGciOi.test" },
    ),
    d,
  );

  const serialised = JSON.stringify(diagnostics);
  assertEquals(serialised.includes("203.0.113.9"), false);
  assertEquals(serialised.includes("4111"), false);
  assertEquals(serialised.includes("eyJhbGciOi"), false);
  assertEquals(serialised.includes("service-key"), false);
  assertEquals(serialised.includes("secret-key"), false);
});

Deno.test("the client is not told which provider failed", async () => {
  const { deps: d } = deps({
    askProvider: async () => ({ error: "Provider configured failed with 429", status: 502 }),
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 502);
  const body = await response.json();
  assertEquals(body.details, undefined);
  assertEquals(String(body.error).includes("Provider"), false);
  assertEquals(String(body.error).toLowerCase().includes("groq"), false);
});

Deno.test("a working limiter still answers", async () => {
  const { deps: d, providerCalls } = deps({
    rpc: async () => ({ data: [{ allowed: true, remaining: 14 }] }),
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.text, "hello");
  assertEquals(providerCalls(), 1);
});

Deno.test("a signed-in customer is counted under their id", async () => {
  const asked: string[] = [];
  const { deps: d } = deps({
    resolveUser: async () => ({ id: "user-123" }),
    rpc: async ({ bucketKey }) => {
      asked.push(bucketKey);
      return { data: [{ allowed: true, remaining: 59 }] };
    },
  });

  const response = await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "hello" }] },
      { authorization: "Bearer a.b.c" },
    ),
    d,
  );
  assertEquals(response.status, 200);
  assertEquals(asked, ["user:user-123"]);
});

Deno.test("a token that is present but not valid is refused", async () => {
  const { deps: d, providerCalls } = deps({
    resolveUser: async () => null,
  });

  const response = await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "hello" }] },
      { authorization: "Bearer a.b.c" },
    ),
    d,
  );
  assertEquals(response.status, 401);
  assertEquals(providerCalls(), 0);
});

// ---------------------------------------------------------------------------
// The memory
//
// The assistant remembers what it had to ask the model, so the next customer
// who asks the same question gets the answer without a model call.
// ---------------------------------------------------------------------------

Deno.test("a remembered question is answered without the provider", async () => {
  const { deps: d, providerCalls } = deps({
    recall: async (key) =>
      key === "ايه الطقس"
        ? { answer: "مش عارف الجو", provider: "memory", topic: "learned" }
        : null,
  });

  const response = await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "ايه الطقس" }], questionKey: "ايه الطقس" },
    ),
    d,
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.text, "مش عارف الجو");
  assertEquals(body.provider, "memory");
  assertEquals(providerCalls(), 0);
});

Deno.test("a remembered question does not spend the provider's quota", async () => {
  let quotaCalls = 0;
  const { deps: d } = deps({
    recall: async () => ({ answer: "محفوظ", provider: "memory" }),
    rpc: async () => {
      quotaCalls++;
      return { data: [{ allowed: true, remaining: 14 }] };
    },
  });

  const response = await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "ايه الطقس" }], questionKey: "ايه الطقس" },
    ),
    d,
  );
  assertEquals(response.status, 200);
  assertEquals(quotaCalls, 0);
});

Deno.test("the answer the provider gave is remembered", async () => {
  const { deps: d, remembered } = deps({
    askProvider: async () => ({ text: "الجو اليوم بارد" }),
  });

  const response = await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "ايه الطقس" }], questionKey: "ايه الطقس" },
    ),
    d,
  );
  assertEquals(response.status, 200);
  assertEquals(remembered.length, 1);
  assertEquals(remembered[0].questionKey, "ايه الطقس");
  assertEquals(remembered[0].answer, "الجو اليوم بارد");
});

Deno.test("an answer that must not be reused is not remembered", async () => {
  const { deps: d, remembered } = deps({
    askProvider: async () => ({ text: "طلبك في الطريق" }),
  });

  await handleRequest(
    postRequest(
      {
        messages: [{ role: "user", content: "فين طلبي" }],
        questionKey: "فين طلبي",
        learn: false,
      },
    ),
    d,
  );
  assertEquals(remembered.length, 0);
});

Deno.test("a failing memory does not stop the answer", async () => {
  let providerCalls = 0;
  const { deps: d } = deps({
    recall: async () => {
      throw new Error("the memory is down");
    },
    askProvider: async () => {
      providerCalls++;
      return { text: "hello" };
    },
  });

  const response = await handleRequest(
    postRequest(
      { messages: [{ role: "user", content: "ايه الطقس" }], questionKey: "ايه الطقس" },
    ),
    d,
  );
  assertEquals(response.status, 200);
  assertEquals(providerCalls, 1);
});

Deno.test("the request carries a budget the reasoning models can use", () => {
  // The free models that think out loud spend most of a small budget on their
  // own reasoning, and the reply then arrives empty.
  const body = buildRequestBody(
    { ...provider(), name: "groq", model: "openai/gpt-oss-120b" },
    [{ role: "user", content: "hello" }],
  );
  assert((body.max_tokens as number) >= 400);
  assertEquals(body.model, "openai/gpt-oss-120b");
  assertEquals(body.reasoning_effort, "low");
});

Deno.test("the reasoning hint is only sent where it is accepted", () => {
  const body = buildRequestBody(
    { ...provider(), name: "gemini" },
    [{ role: "user", content: "hello" }],
  );
  assertEquals(body.reasoning_effort, undefined);
});

Deno.test("the three free providers are tried in order and the first one answers", async () => {
  const asked: string[] = [];
  const { deps: d } = deps({
    providers: () => [
      { ...provider(), name: "groq" },
      { ...provider(), name: "openrouter" },
      { ...provider(), name: "gemini" },
    ],
    askProvider: async (p) => {
      asked.push(p.name);
      return { text: `hello from ${p.name}` };
    },
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.text, "hello from groq");
  assertEquals(body.provider, "groq");
  assertEquals(asked, ["groq"]);
});

Deno.test("a rate-limited provider hands over to the next one", async () => {
  const asked: string[] = [];
  const { deps: d } = deps({
    providers: () => [
      { ...provider(), name: "groq" },
      { ...provider(), name: "openrouter" },
      { ...provider(), name: "gemini" },
    ],
    askProvider: async (p) => {
      asked.push(p.name);
      if (p.name === "groq") return { error: "rate limited", status: 429 };
      return { text: `hello from ${p.name}` };
    },
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.text, "hello from openrouter");
  assertEquals(body.provider, "openrouter");
  assertEquals(asked, ["groq", "openrouter"]);
});

Deno.test("the last provider answers when the first two are down", async () => {
  const asked: string[] = [];
  const { deps: d } = deps({
    providers: () => [
      { ...provider(), name: "groq" },
      { ...provider(), name: "openrouter" },
      { ...provider(), name: "gemini" },
    ],
    askProvider: async (p) => {
      asked.push(p.name);
      if (p.name === "gemini") return { text: "hello from gemini" };
      return { error: "provider down", status: 503 };
    },
  });

  const response = await handleRequest(postRequest(), d);
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.text, "hello from gemini");
  assertEquals(asked, ["groq", "openrouter", "gemini"]);
});

Deno.test("the client is not told which provider failed", async () => {
  const { deps: d } = deps({
    providers: () => [
      { ...provider(), name: "groq" },
      { ...provider(), name: "openrouter" },
    ],
    askProvider: async (p) =>
      p.name === "groq"
        ? { error: "quota exhausted for secret-key", status: 429 }
        : { text: "hello" },
  });

  const response = await handleRequest(postRequest(), d);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.text, "hello");
  assert(
    !JSON.stringify(body).includes("secret-key"),
    "the answer must not carry the provider key or its error",
  );
});