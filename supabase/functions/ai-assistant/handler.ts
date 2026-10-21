// Supabase Edge Function: ai-assistant — handler
//
// Server-side proxy to an OpenAI-compatible LLM provider. The provider API key
// is read from function secrets and never exposed to the Flutter client.
//
// Several free providers are supported. The first one that answers wins; if it
// is rate-limited (429) or down (5xx), the next one is tried. That is what
// makes the assistant reliable on a free tier: one provider running out of its
// daily quota does not take the feature down.
//
// Guests are welcome: the assistant answers a customer who is not signed in.
// The function is therefore deployed with --no-verify-jwt and does its own
// check (a token that is present must be a real user token). A per-address
// limit protects the provider's free quota from being drained.
//
// The limiter never fails open. If the counter cannot give a trustworthy
// answer, the request is refused with 503 instead of being forwarded to a
// paid provider: the Flutter app keeps its own local answer in that case, so
// the customer is not left without a reply, and the provider quota is not
// open to an unbounded number of requests.
//
// Secrets (set them with `supabase secrets set`):
//   LLM_BASE_URL / LLM_API_KEY / LLM_MODEL  - any OpenAI-compatible endpoint
//   GROQ_API_KEY        (+ GROQ_MODEL)      - Groq, free tier, open weights
//   OPENROUTER_API_KEY (+ OPENROUTER_MODEL) - OpenRouter free models
//   GEMINI_API_KEY     (+ GEMINI_MODEL)     - Google AI Studio free tier

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getUserFromRequest } from "../_shared/tap.ts";
import {
  buildCallerIdentity,
  interpretQuotaRow,
  limitFor,
  retryAfterSeconds,
  RATE_LIMIT_WINDOW_SECONDS,
  type CallerIdentity,
  type QuotaFailureReason,
  type QuotaResult,
} from "../_shared/assistant-guard.ts";

const MAX_MESSAGES = 20;
const MAX_CONTENT_CHARS = 4000;
const MAX_TOTAL_CHARS = 12000;
const REQUEST_TIMEOUT_MS = 15000;

/** How long the counter may take before the request is treated as a failure. */
const QUOTA_TIMEOUT_MS = 3000;

export type Provider = {
  name: string;
  baseUrl: string;
  apiKey: string;
  model: string;
};

export type Message = { role: string; content: string };

type ProviderAnswer =
  | { text: string }
  | { error: string; status: number };

/**
 * A diagnostic entry. It carries a category and a few numbers, never an
 * address, a token, a key or a message from the customer.
 */
export type Diagnostic = {
  event: string;
  category?: string;
  reason?: QuotaFailureReason;
  status?: number;
  provider?: string;
  limit?: number;
  remaining?: number;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function normalizeBaseUrl(raw: string): string {
  const trimmed = raw.trim().replace(/\/+$/, "");
  if (!trimmed) return "";
  // A base that already carries a version segment is used as it is: Groq is
  // ".../openai/v1", Gemini is ".../v1beta/openai", OpenRouter is
  // ".../api/v1". Appending another "/v1" to those breaks the request.
  try {
    const path = new URL(trimmed).pathname;
    if (/\/v\d+[a-z]*(\/|$)/i.test(path)) return trimmed;
  } catch {
    // Not a parseable URL: fall through to the plain rule.
  }
  return `${trimmed}/v1`;
}

function envOrEmpty(env: (name: string) => string | undefined, name: string): string {
  return (env(name) ?? "").trim();
}

/// The providers to try, in order. The explicit configuration comes first,
/// then the built-in free providers.
function resolveProviders(env: (name: string) => string | undefined): Provider[] {
  const providers: Provider[] = [];

  const baseUrl = envOrEmpty(env, "LLM_BASE_URL");
  const model = envOrEmpty(env, "LLM_MODEL");
  const apiKey = envOrEmpty(env, "LLM_API_KEY");
  if (baseUrl && model) {
    providers.push({
      name: "configured",
      baseUrl: normalizeBaseUrl(baseUrl),
      apiKey,
      model,
    });
  }

  const groqKey = envOrEmpty(env, "GROQ_API_KEY");
  if (groqKey) {
    providers.push({
      name: "groq",
      baseUrl: "https://api.groq.com/openai/v1",
      apiKey: groqKey,
      model: envOrEmpty(env, "GROQ_MODEL") || "openai/gpt-oss-120b",
    });
  }

  // Gemini comes before OpenRouter: it answers every time, while the
  // OpenRouter free router picks a different free model on every call and
  // some of them answer with nothing at all.
  const geminiKey = envOrEmpty(env, "GEMINI_API_KEY");
  if (geminiKey) {
    providers.push({
      name: "gemini",
      baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai",
      apiKey: geminiKey,
      model: envOrEmpty(env, "GEMINI_MODEL") || "gemini-3.8-flash",
    });
  }

  const openRouterKey = envOrEmpty(env, "OPENROUTER_API_KEY");
  if (openRouterKey) {
    providers.push({
      name: "openrouter",
      baseUrl: "https://openrouter.ai/api/v1",
      apiKey: openRouterKey,
      model: envOrEmpty(env, "OPENROUTER_MODEL") || "openrouter/free",
    });
  }

  return providers;
}

function validMessage(value: unknown): value is Message {
  if (!value || typeof value !== "object") return false;
  const role = (value as any).role;
  const content = (value as any).content;
  return typeof role === "string" &&
    (role === "system" || role === "user" || role === "assistant") &&
    typeof content === "string" &&
    content.length > 0 &&
    content.length <= MAX_CONTENT_CHARS;
}

/// The user token, when the request carries one.
///
/// A request from a guest carries the project's publishable key, which is not
/// a user token: it must not be treated as a failed sign-in. A real user
/// token is a JWT, so it is the only thing worth validating.
function readUserToken(req: Request): string | null {
  const header = req.headers.get("Authorization");
  if (!header || !header.startsWith("Bearer ")) return null;
  const token = header.slice("Bearer ".length).trim();
  if (!token) return null;
  if (token.startsWith("sb_")) return null; // publishable or secret key
  if (token.split(".").length !== 3) return null; // not a JWT
  return token;
}

/// The body sent to an OpenAI-compatible endpoint.
///
/// The budget has to be generous: the free models that reason out loud
/// (gpt-oss, nemotron) spend most of `max_tokens` on their own thinking, and
/// a reply that runs out of budget arrives empty. An empty reply is treated as
/// a failure, so a tight budget silently cost the shop its best provider.
export function buildRequestBody(
  provider: Provider,
  messages: Message[],
): Record<string, unknown> {
  const body: Record<string, unknown> = {
    model: provider.model,
    temperature: 0.3,
    max_tokens: 500,
    messages,
  };
  // Groq's open reasoning models answer faster and leave more room for the
  // answer when the thinking is kept short. Only sent where it is known to be
  // accepted: a provider that rejects the field is skipped by the chain
  // anyway, but there is no reason to risk it.
  if (provider.name === "groq") {
    body.reasoning_effort = "low";
  }
  return body;
}

/// Asks one provider for a reply. Returns the text, or an error when that
/// provider could not answer (rate limit, outage, timeout, empty reply).
async function askProvider(
  provider: Provider,
  messages: Message[],
): Promise<ProviderAnswer> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };
    if (provider.apiKey) headers["Authorization"] = `Bearer ${provider.apiKey}`;

    const response = await fetch(`${provider.baseUrl}/chat/completions`, {
      method: "POST",
      headers,
      body: JSON.stringify(buildRequestBody(provider, messages)),
      signal: controller.signal,
    });

    const text = await response.text();
    let json: any = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = { raw: text };
    }

    if (!response.ok) {
      // 429 means the free quota is spent; the next provider takes over.
      return {
        error: `Provider ${provider.name} failed with ${response.status}`,
        status: 502,
      };
    }

    const choices = Array.isArray(json?.choices) ? json.choices : [];
    const first = choices.length > 0 ? choices[0] : null;
    const content = first?.message?.content;
    const reply = typeof content === "string" ? content.trim() : "";
    if (!reply) {
      return { error: `Provider ${provider.name} returned an empty reply`, status: 502 };
    }
    return { text: reply };
  } catch (error) {
    const aborted = String(error).includes("AbortError");
    return {
      error: aborted
        ? `Provider ${provider.name} timed out`
        : `Provider ${provider.name} could not be reached`,
      status: 502,
    };
  } finally {
    clearTimeout(timeout);
  }
}

// ---------------------------------------------------------------------------
// The limiter
// ---------------------------------------------------------------------------

/** The shape of the counter RPC answer, as the Supabase client returns it. */
export type RpcOutcome = {
  data?: unknown;
  error?: { message?: string; code?: string } | null;
};

export type RpcCall = (input: {
  bucketKey: string;
  limit: number;
  windowSeconds: number;
}) => Promise<RpcOutcome>;

/** A remembered answer, and how the question was found. */
export type RecalledAnswer = {
  answer: string;
  provider?: string | null;
  topic?: string | null;
  score?: number | null;
};

/** Looks a question up in the learned answers. Null when there is none. */
export type RecallCall = (questionKey: string) => Promise<RecalledAnswer | null>;

/** Stores an answer so the next customer gets it without a model call. */
export type RememberCall = (input: {
  questionKey: string;
  questionText: string;
  answer: string;
  provider?: string | null;
  topic?: string | null;
}) => Promise<void>;

export type AssistantDeps = {
  env: (name: string) => string | undefined;
  now: () => Date;
  resolveUser: (req: Request) => Promise<{ id: string } | null>;
  rpc: RpcCall;
  recall: RecallCall;
  remember: RememberCall;
  providers: () => Provider[];
  askProvider: (provider: Provider, messages: Message[]) => Promise<ProviderAnswer>;
  log: (entry: Diagnostic) => void;
  quotaTimeoutMs: number;
};

function defaultDeps(): AssistantDeps {
  return {
    env: (name: string) => Deno.env.get(name),
    now: () => new Date(),
    resolveUser: (req: Request) => getUserFromRequest(req),
    rpc: async ({ bucketKey, limit, windowSeconds }) => {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      if (!supabaseUrl || !serviceKey) {
        return { error: { message: "missing configuration" } };
      }
      const supabase = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false },
      });
      const { data, error } = await supabase.rpc("increment_assistant_rate_limit", {
        p_bucket_key: bucketKey,
        p_limit: limit,
        p_window_seconds: windowSeconds,
      });
      return { data, error: error as any };
    },
    providers: () => resolveProviders((name) => Deno.env.get(name)),
    askProvider,
    recall: async (questionKey) => {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      if (!supabaseUrl || !serviceKey) return null;
      const supabase = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false },
      });
      const { data, error } = await supabase.rpc("recall_learned_answer", {
        p_question_key: questionKey,
      });
      if (error) return null;
      const rows = Array.isArray(data) ? data : [];
      const row = rows[0] as any;
      if (!row || typeof row.answer !== "string" || row.answer.trim() === "") {
        return null;
      }
      return {
        answer: row.answer,
        provider: row.provider ?? null,
        topic: row.topic ?? null,
        score: row.score ?? null,
      };
    },
    remember: async ({ questionKey, questionText, answer, provider, topic }) => {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      if (!supabaseUrl || !serviceKey) return;
      const supabase = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false },
      });
      await supabase.rpc("remember_answer", {
        p_question_key: questionKey,
        p_question_text: questionText,
        p_answer: answer,
        p_provider: provider ?? null,
        p_topic: topic ?? "learned",
      });
    },
    log: (entry: Diagnostic) => {
      // Structured and free of anything that identifies a caller: no address,
      // no token, no key, no message content.
      console.log(JSON.stringify(entry));
    },
    quotaTimeoutMs: QUOTA_TIMEOUT_MS,
  };
}

class QuotaTimeout extends Error {}

/**
 * Counts one question against the caller's window.
 *
 * The answer is one of three things, and "unavailable" is never silently
 * turned into "allowed":
 *   * allow      - the caller is inside the limit,
 *   * deny       - the caller is over the limit for this window,
 *   * unavailable - the counter could not be reached or did not answer in a
 *                  shape this function understands.
 */
export async function consumeQuota(
  deps: AssistantDeps,
  identity: CallerIdentity,
): Promise<QuotaResult> {
  if (identity.kind === "unidentified" || !identity.key) {
    return { kind: "unavailable", reason: "unidentified_caller" };
  }

  const limit = limitFor(identity);

  const supabaseUrl = envOrEmpty(deps.env, "SUPABASE_URL");
  const serviceKey = envOrEmpty(deps.env, "SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return { kind: "unavailable", reason: "missing_env" };
  }

  let outcome: RpcOutcome;
  try {
    outcome = await withTimeout(
      deps.rpc({
        bucketKey: identity.key,
        limit,
        windowSeconds: RATE_LIMIT_WINDOW_SECONDS,
      }),
      deps.quotaTimeoutMs,
    );
  } catch (error) {
    if (error instanceof QuotaTimeout) {
      return { kind: "unavailable", reason: "rpc_timeout" };
    }
    return { kind: "unavailable", reason: "rpc_error" };
  }

  if (outcome.error) {
    const code = outcome.error.code ?? "";
    const reason: QuotaFailureReason = code === "42501"
      ? "permission_denied"
      : "rpc_error";
    return { kind: "unavailable", reason };
  }

  const rows = Array.isArray(outcome.data) ? outcome.data : [];
  if (rows.length === 0) {
    return { kind: "unavailable", reason: "malformed_response" };
  }
  return interpretQuotaRow(rows[0], limit);
}

async function withTimeout<T>(work: Promise<T>, ms: number): Promise<T> {
  // The timer handle is typed from the runtime, so this compiles under both
  // Deno and a Node type environment.
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => reject(new QuotaTimeout("quota timeout")), ms);
  });
  try {
    return await Promise.race([work, timeout]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// The handler
// ---------------------------------------------------------------------------

export async function handleRequest(
  req: Request,
  deps: AssistantDeps = defaultDeps(),
): Promise<Response> {
  // A health check: which providers are configured, without their keys.
  if (req.method === "GET") {
    const providers = deps.providers().map((provider) => ({
      name: provider.name,
      baseUrl: provider.baseUrl,
      model: provider.model,
    }));
    return jsonResponse(
      { ok: providers.length > 0, providers },
      providers.length > 0 ? 200 : 503,
    );
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const rawMessages = body?.messages;
  if (!Array.isArray(rawMessages) || rawMessages.length === 0 || rawMessages.length > MAX_MESSAGES) {
    return jsonResponse({ error: "messages must be a non-empty array of at most " + MAX_MESSAGES }, 400);
  }
  if (!rawMessages.every(validMessage)) {
    return jsonResponse({ error: "Invalid message shape or size" }, 400);
  }
  const totalChars = rawMessages.reduce((sum: number, m: any) => sum + String(m.content).length, 0);
  if (totalChars > MAX_TOTAL_CHARS) {
    return jsonResponse({ error: "Request too large" }, 413);
  }

  // Authentication is optional: a guest is answered, but a token that is
  // present has to be a real one. The function is deployed with
  // --no-verify-jwt so that the guest path is possible at all.
  const token = readUserToken(req);
  let userId: string | null = null;
  if (token) {
    const user = await deps.resolveUser(req);
    if (!user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
    userId = user.id;
  }

  // Who is asking. A signed-in customer is counted under their verified id;
  // a guest under a hash of the address the platform reported.
  const identity = await buildCallerIdentity(userId, req);

  // The memory comes before the limiter. A question the assistant already
  // knows costs the provider nothing, so it must not spend the customer's
  // hourly allowance either.
  const questionKey = typeof body?.questionKey === "string"
    ? body.questionKey.trim()
    : "";
  const mayLearn = body?.learn !== false;
  if (questionKey) {
    // The memory is an optimisation, never a dependency: if it is down the
    // assistant still answers.
    let remembered: RecalledAnswer | null = null;
    try {
      remembered = await deps.recall(questionKey);
    } catch (error) {
      deps.log({
        event: "assistant_memory_unavailable",
        category: "memory",
        status: 500,
      });
    }
    if (remembered) {
      deps.log({
        event: "assistant_memory_hit",
        category: "memory",
        provider: remembered.provider ?? undefined,
        status: 200,
      });
      return jsonResponse(
        {
          text: remembered.answer,
          topic: remembered.topic ?? "learned",
          provider: "memory",
        },
        200,
      );
    }
  }

  // One question per call is one unit of the provider's free quota.
  const quota = await consumeQuota(deps, identity);

  if (quota.kind === "unavailable") {
    // The limiter could not be trusted. Refuse the provider call rather than
    // let an unbounded number of paid requests through.
    deps.log({
      event: "assistant_rate_limit_unavailable",
      category: "limiter",
      reason: quota.reason,
    });
    return jsonResponse(
      { error: "The assistant is temporarily unavailable. Please try again shortly." },
      503,
    );
  }

  if (quota.kind === "deny") {
    const retryAfter = retryAfterSeconds(quota.resetAt, deps.now());
    deps.log({
      event: "assistant_rate_limited",
      category: "limiter",
      limit: limitFor(identity),
      remaining: 0,
      status: 429,
    });
    return jsonResponse(
      {
        // The window is one hour, so the answer says so instead of guessing.
        error: "Too many questions. The assistant answers again in about an hour.",
        remaining: 0,
        ...(retryAfter === null ? {} : { retryAfterSeconds: retryAfter }),
      },
      429,
    );
  }

  const providers = deps.providers();
  if (providers.length === 0) {
    return jsonResponse({ error: "LLM provider is not configured" }, 503);
  }

  const failures: Array<{ provider: string; status: number }> = [];
  for (const provider of providers) {
    const result = await deps.askProvider(provider, rawMessages);
    if ("text" in result) {
      // The answer is remembered so the next customer who asks the same
      // question gets it without a model call. A question about the
      // customer's own order is never learned: its answer goes stale.
      if (mayLearn && questionKey) {
        const lastUser = [...rawMessages].reverse().find((m) => m.role === "user");
        try {
          await deps.remember({
            questionKey,
            questionText: lastUser?.content ?? questionKey,
            answer: result.text,
            provider: provider.name,
            topic: "learned",
          });
          deps.log({
            event: "assistant_memory_learned",
            category: "memory",
            provider: provider.name,
            status: 200,
          });
        } catch (error) {
          // Not remembering is a loss, not a failure: the answer still goes out.
          deps.log({
            event: "assistant_memory_write_failed",
            category: "memory",
            provider: provider.name,
            status: 500,
          });
        }
      }
      return jsonResponse(
        { text: result.text, topic: "llm", provider: provider.name },
        200,
      );
    }
    failures.push({ provider: provider.name, status: result.status });
    deps.log({
      event: "assistant_provider_failed",
      category: "provider",
      provider: provider.name,
      status: result.status,
    });
  }

  // Every provider refused. The app keeps its own answer, so the client is
  // told only that the assistant is unavailable; which provider failed is a
  // diagnostic for the dashboard, not a message for the customer.
  deps.log({
    event: "assistant_providers_failed",
    category: "provider",
    status: 502,
  });
  return jsonResponse({ error: "The assistant is temporarily unavailable. Please try again shortly." }, 502);
}
