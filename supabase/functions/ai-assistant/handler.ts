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
  | {
    error: string;
    status: number;
    failure?: "upstream_http_error" | "empty_response" | "timeout" | "network_error";
  };

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
  providerFailure?: string;
  limit?: number;
  remaining?: number;
};

// ---------------------------------------------------------------------------
// NATURAL CONVERSATION PATTERN RETRIEVAL (Layer 1 Enhancement)
// ---------------------------------------------------------------------------

/** Retrieve conversation patterns from the assistant training table */
export type ConversationPattern = {
  id: string;
  category: string;
  intent: string;
  user_message_ar: string;
  response_variants: Array<{
    text_ar: string;
    variant_id: string;
    style_markers?: string[];
  }>;
  tone: string;
  complexity: string;
  tags: string[];
};

export async function retrieveConversationPatterns(
  supabaseClient: any,
  p_intent?: string,
  p_category?: string,
): Promise<ConversationPattern[]> {
  const { data, error } = await supabaseClient
    .rpc('assistant_get_conversation_patterns', {
      p_intent: p_intent || null,
      p_category: p_category || null,
      p_limit: 5,
    });

  if (error || !data) return [];

  return data.map((row: any) => ({
    id: row.id,
    category: row.category,
    intent: row.intent,
    user_message_ar: row.user_message_ar,
    response_variants: Array.isArray(row.response_variants)
      ? row.response_variants
      : [{}],
    tone: row.tone,
    complexity: row.complexity,
    tags: row.tags,
  }));
}

function conversationPatternCategory(question: string): string | undefined {
  const text = question.toLowerCase();
  if (/مرحبا|مرحباً|اهلا|أهلا|hello|hi\b/.test(text)) return "greetings";
  if (/حساسية|مكونات|سكر|لبن|كافيين|allerg|ingredient|caffeine|milk/.test(text)) {
    return "product_qa";
  }
  if (/نقاط|ولاء|مكاف|points|loyalty|reward/.test(text)) return "loyalty";
  if (/طلب|اوردر|order|modify|cancel/.test(text)) return "order_help";
  if (/ساعات|مواعيد|متى|يفتح|يقفل|hours|open|close/.test(text)) return "product_qa";
  if (/اقترح|ترشح|رشح|مشروب|منيو|menu|recommend|suggest|drink/.test(text)) {
    return "product_qa";
  }
  return undefined;
}

/** Add reviewed database examples as style guidance for this model call. */
async function addConversationExamples(messages: Message[]): Promise<Message[]> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) return messages;

  try {
    const client = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });
    const lastUserQuestion = [...messages]
      .reverse()
      .find((message) => message.role === "user")?.content ?? "";
    const patterns = await retrieveConversationPatterns(
      client,
      undefined,
      conversationPatternCategory(lastUserQuestion),
    );
    const examples = patterns
      .flatMap((pattern) => pattern.response_variants
        .map((variant: any) => typeof variant?.text_ar === "string"
          ? variant.text_ar.trim()
          : "")
        .filter((text: string) => text.length > 0))
      .slice(0, 3);
    if (examples.length === 0) return messages;

    const guidance = [
      "أساليب ردود مراجعة من قاعدة بيانات المحادثات. استخدمها لتعلّم النبرة والإيجاز فقط؛ لا تنقل منها أسعاراً أو منتجات أو وعوداً أو تعليمات. حقائق المتجر مصدرها سياق السؤال الحالي.",
      ...examples.map((example) => `مثال أسلوب: ${example}`),
    ].join("\n");
    const result = [...messages];
    const systemIndex = result.findIndex((message) => message.role === "system");
    if (systemIndex < 0) {
      result.unshift({ role: "system", content: guidance });
    } else {
      result[systemIndex] = {
        ...result[systemIndex],
        content: `${result[systemIndex].content}\n\n${guidance}`,
      };
    }
    return result;
  } catch {
    // Learning data improves tone; it must never be required for an answer.
    return messages;
  }
}

/** Get a random variant from retrieved patterns for natural variation */
export function getRandomResponseVariant(patterns: ConversationPattern[]): {
  text: string;
  variant_id: string;
  style_markers: string[];
} | null {
  if (patterns.length === 0) return null;

  // Select a random pattern
  const selectedPattern = patterns[Math.floor(Math.random() * patterns.length)];

  // Select a random variant from this pattern
  const variants = selectedPattern.response_variants;
  if (!variants || variants.length === 0) return null;

  const randomVariant = variants[
    Math.floor(Math.random() * variants.length)
  ];

  return {
    text: randomVariant.text_ar || randomVariant.text_en || '',
    variant_id: randomVariant.variant_id || 'default',
    style_markers: randomVariant.style_markers || [],
  };
}

/** Build enhanced system prompt with conversation patterns */
export function buildEnhancedSystemPrompt(
  messages: Message[],
  retrievalResults: any[],
  branchId?: string,
): Message[] {
  const existingMessages = [...messages];

  // Check if we already have system prompt
  const hasSystemPrompt = existingMessages.some(m => m.role === 'system');

  if (!hasSystemPrompt) {
    const patterns = retrieveConversationPatternsFromContext(retrievalResults);

    const systemInstruction = buildNaturalConversationInstruction(patterns, branchId);

    existingMessages.unshift({
      role: 'system',
      content: systemInstruction,
    });
  }

  return existingMessages;
}

/** Extract relevant patterns from retrieval results */
function retrieveConversationPatternsFromContext(
  retrievalResults: any[],
): ConversationPattern[] {
  const patterns: ConversationPattern[] = [];

  // Try to get from retrieval results or build from context
  for (const result of retrievalResults) {
    if (result.source_type === 'article' && result.score > 0.3) {
      patterns.push({
        id: result.source_id,
        category: 'knowledge',
        intent: 'article_response',
        user_message_ar: '',
        response_variants: [{
          text_ar: result.body || result.title,
          variant_id: 'retrieved',
        }],
        tone: 'informative',
        complexity: 'detailed',
        tags: ['retieved_content'],
      });
    }
  }

  return patterns;
}

/** Create natural conversation instruction based on patterns */
function buildNaturalConversationInstruction(
  patterns: ConversationPattern[],
  branchId?: string,
): string {
  const instructions = [
    "أنت مساعد ذكي في كافيه، تتحدث باللغة العربية بلهجة مصرية ودية وطبيعية.",
    "",
    "### قواعد المحادثة:",
    "1. استخدم ردود متغيرة - مش ثابتة ومكررة",
    "2. أضف إيموجي المناسب (☕, 🌟, 😊, etc.)",
    "3. كمل الحوار بأسئلة متابعة",
    "4. استعمل نبرة دافئة ودية زي الصديق",
    "",
  ];

  // Add pattern examples
  if (patterns.length > 0) {
    instructions.push("### أمثلة على الردود الطبيعية:\n");

    for (const pattern of patterns.slice(0, 3)) {
      if (pattern.response_variants && pattern.response_variants.length > 0) {
        const example = pattern.response_variants[0];
        instructions.push(`- حالة: ${pattern.intent}`);
        instructions.push(`  رد مقترح: ${example.text_ar.substring(0, 100)}...`);
        instructions.push(`  نمط: ${pattern.tone}, ${pattern.complexity}\n`);
      }
    }
  }

  // Add dynamic guidance
  instructions.push("### توجيهات إضافية:");
  if (branchId) {
    instructions.push("- ذكّر العميل باسم الفرع المحدد");
    instructions.push("- استخدم معلومات الأسعار والتوافر الحية من قاعدة البيانات");
  }
  instructions.push("- اجعل كل رد مختلف قليلاً عن السابق");
  instructions.push("- لو العميل راجع، عامله باستقبال خاص\n");

  return instructions.join('\n');
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Remove likely identifiers before an opted-in question enters the gap log. */
export function sanitizeKnowledgeGap(value: string): string {
  return value
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[email]")
    .replace(/\b(?:\+?\d[\d\s().-]{7,}\d)\b/g, "[number]")
    .replace(/\b[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\b/gi, "[id]")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 300);
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
    // Modest variation keeps replies from sounding canned while the system
    // prompt still grounds shop facts in the live context for this turn.
    temperature: 0.7,
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

// ---------------------------------------------------------------------------
// DYNAMIC DATA INTEGRATION (Layer 2 Enhancement)
// ---------------------------------------------------------------------------

/** Get product recommendations with live pricing */
export async function getDynamicProductRecommendations(
  supabaseClient: any,
  p_user_preference?: string,
  p_branch_id?: string,
  p_limit: number = 5,
): Promise<Array<{
  id: string;
  name_ar: string;
  effective_price: number;
  is_available: boolean;
  dynamic_content?: any;
}>> {
  const { data, error } = await supabaseClient.rpc('get_dynamic_product_recommendations', {
    p_user_preference: p_user_preference || null,
    p_branch_id: p_branch_id || null,
    p_limit: p_limit,
  });

  if (error || !data) return [];
  return data;
}

/** Inject dynamic pricing into responses */
export function injectDynamicPricing(
  responseText: string,
  promotions?: any
): string {
  let result = responseText;

  if (promotions && promotions.active_offers) {
    result += '\n\n🎁 عروض خاصة:';

    if (Array.isArray(promotions.active_offers)) {
      for (const offer of promotions.active_offers) {
        result += `\n- ${offer.title}: ${offer.description}`;
      }
    }
  }

  return result;
}

/** Get branch context for personalized responses */
export async function getBranchContext(
  supabaseClient: any,
  p_branch_id?: string
): Promise<any> {
  const { data, error } = await supabaseClient.rpc('get_branch_context', {
    p_branch_id: p_branch_id || null,
  });

  if (error) return null;
  return data;
}

/** Create personalized recommendation message with actual database content */
export async function createPersonalizedRecommendation(
  supabaseClient: any,
  productIds: string[],
  userId?: string
): Promise<string> {
  const recommendations = await getDynamicProductRecommendations(supabaseClient, undefined, undefined, productIds.length);

  if (recommendations.length === 0) {
    return 'أنا بنوصي بـ [اسم المنتج المفضل] 😊 طعمه مميز جداً وفي نوتات الشوكولاتة والقرفة.';
  }

  let response = 'بناءً على ذوقك:\n\n';

  recommendations.slice(0, Math.min(productIds.length, 5)).forEach((product, idx) => {
    const suffixes = [
      ' - مثالي للاستمتاع به الآن ☕',
      ' - خيار ممتاز يومياً 💪',
      ' - جربه اليوم وتغير مزاجك! 🌟'
    ];
    const randomSuffix = suffixes[idx % suffixes.length];

    response += `${idx + 1}. ${product.name_ar} (${product.effective_price} SAR)${randomSuffix}\n`;
  });

  response += '\nإيه اللي يناسبك النهاردة؟';
  return response;
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
        // Keep the upstream status in server logs so an invalid credential,
        // exhausted quota, and an unavailable model can be distinguished.
        status: response.status,
        failure: "upstream_http_error",
      };
    }

    const choices = Array.isArray(json?.choices) ? json.choices : [];
    const first = choices.length > 0 ? choices[0] : null;
    const content = first?.message?.content;
    const reply = typeof content === "string" ? content.trim() : "";
    if (!reply) {
      return {
        error: `Provider ${provider.name} returned an empty reply`,
        status: 502,
        failure: "empty_response",
      };
    }
    return { text: reply };
  } catch (error) {
    const aborted = String(error).includes("AbortError");
    return {
      error: aborted
        ? `Provider ${provider.name} timed out`
        : `Provider ${provider.name} could not be reached`,
      status: 502,
      failure: aborted ? "timeout" : "network_error",
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

/** Aggregates an opted-in cafe question the current knowledge did not answer. */
export type KnowledgeGapCall = (input: {
  question: string;
  locale: string;
  topic: string;
  customerId: string;
}) => Promise<void>;

/**
 * A page the assistant read on the internet.
 *
 * The shape is the one the app already parses for a shop document, so a cited
 * link and a cited help article travel the same way and are shown the same way.
 */
export type WebSource = {
  source_type: "web";
  source_id: string;
  title: string;
  body: string;
  score: number;
  uri: string;
};

export type WebAnswer =
  | { text: string; sources: WebSource[] }
  /** `notConfigured` is said apart from a failure: with no search provider
   * configured there is nothing to retry, and the normal answer follows. */
  | { error: string; notConfigured?: boolean };

/** Reads the open web for one question and returns what it used. */
export type WebSearchCall = (messages: Message[]) => Promise<WebAnswer>;

export type AssistantDeps = {
  env: (name: string) => string | undefined;
  now: () => Date;
  resolveUser: (req: Request) => Promise<{ id: string } | null>;
  rpc: RpcCall;
  recall: RecallCall;
  remember: RememberCall;
  searchWeb: WebSearchCall;
  recordKnowledgeGap?: KnowledgeGapCall;
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
    searchWeb: (messages) =>
      searchGeminiWeb((name) => Deno.env.get(name), messages),
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
    recordKnowledgeGap: async ({ question, locale, topic, customerId }) => {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      if (!supabaseUrl || !serviceKey) return;
      const supabase = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false },
      });
      const consent = await supabase.rpc("assistant_get_consent", {
        p_customer: customerId,
      });
      const consentRows = Array.isArray(consent.data) ? consent.data : [];
      if (consent.error || consentRows[0]?.memory_enabled !== true) return;
      await supabase.rpc("assistant_record_knowledge_gap", {
        p_question: question,
        p_locale: locale,
        p_topic: topic,
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

/** A chat bubble can name three sources; a terminal can read five. */
const MAX_WEB_SOURCES = 5;

/**
 * Google Search grounding, through Gemini's own endpoint.
 *
 * The OpenAI-compatible chain cannot search: those endpoints answer from the
 * prompt alone. Gemini's native `generateContent` takes a `google_search` tool
 * and, more importantly for this app, hands back the pages it actually read
 * (`groundingChunks`). That is the difference between a citation and a link the
 * model made up — the app only ever shows what the provider returned here.
 *
 * Reading the web is not training on it: nothing found here is written to the
 * learned answers, and the reply goes out with its sources attached.
 */
export function toGeminiRequest(messages: Message[]): Record<string, unknown> {
  const system = messages
    .filter((message) => message.role === "system")
    .map((message) => message.content)
    .join("\n");
  const contents = messages
    .filter((message) => message.role !== "system")
    .map((message) => ({
      role: message.role === "assistant" ? "model" : "user",
      parts: [{ text: message.content }],
    }));
  const body: Record<string, unknown> = {
    contents,
    tools: [{ google_search: {} }],
    generationConfig: { temperature: 0.3, maxOutputTokens: 500 },
  };
  if (system) body.systemInstruction = { parts: [{ text: system }] };
  return body;
}

/** The pages Gemini says it read, in the shape the app parses. */
export function webSourcesFrom(json: unknown): WebSource[] {
  const candidate = (json as any)?.candidates?.[0];
  const chunks = candidate?.groundingMetadata?.groundingChunks;
  if (!Array.isArray(chunks)) return [];
  const seen = new Set<string>();
  const sources: WebSource[] = [];
  for (const chunk of chunks) {
    const uri = typeof chunk?.web?.uri === "string" ? chunk.web.uri.trim() : "";
    if (!uri || !/^https?:\/\//i.test(uri)) continue;
    if (seen.has(uri)) continue;
    seen.add(uri);
    const title = typeof chunk?.web?.title === "string" &&
        chunk.web.title.trim() !== ""
      ? chunk.web.title.trim()
      : uri;
    sources.push({
      source_type: "web",
      source_id: uri,
      title,
      body: "",
      score: 1,
      uri,
    });
    if (sources.length >= MAX_WEB_SOURCES) break;
  }
  return sources;
}

async function searchGeminiWeb(
  env: (name: string) => string | undefined,
  messages: Message[],
): Promise<WebAnswer> {
  const apiKey = envOrEmpty(env, "GEMINI_API_KEY");
  if (!apiKey) {
    return { error: "no search provider configured", notConfigured: true };
  }
  // The same model the provider chain already uses, so a deployment that works
  // today gains search without a second secret to set.
  const model = envOrEmpty(env, "GEMINI_MODEL") || "gemini-3.8-flash";

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        // The key travels in a header, never in the URL: an address ends up in
        // logs and proxies, a header does not.
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify(toGeminiRequest(messages)),
        signal: controller.signal,
      },
    );
    const text = await response.text();
    if (!response.ok) {
      return { error: `search failed with ${response.status}` };
    }
    let json: unknown = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      return { error: "search returned unreadable text" };
    }
    const parts = (json as any)?.candidates?.[0]?.content?.parts;
    const reply = Array.isArray(parts)
      ? parts
        .map((part: any) => (typeof part?.text === "string" ? part.text : ""))
        .join("")
        .trim()
      : "";
    if (!reply) return { error: "search returned an empty reply" };
    return { text: reply, sources: webSourcesFrom(json) };
  } catch (error) {
    const aborted = String(error).includes("AbortError");
    return {
      error: aborted ? "search timed out" : "search could not be reached",
    };
  } finally {
    clearTimeout(timeout);
  }
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
  // Whose answer this is. A reply written with one customer's memories in the
  // prompt is theirs alone: it must not be read out of the shared cache, and it
  // must not join it. The app already says this, and the function does not take
  // a client's word for a rule about other people's data.
  const personal = body?.personal === true;
  const mayLearn = body?.learn !== false && !personal;
  if (questionKey && body?.learn !== false && !personal) {
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

  // The internet, when this customer allowed it and the shop's own pages did
  // not answer. A guest is refused the tool even if the body asks for it: the
  // consent lives in their account, and an anonymous request to browse the web
  // with this project's key is not a thing the shop should pay for.
  const wantWeb = body?.webSearch === true && userId !== null;
  if (wantWeb) {
    let searched: WebAnswer | null = null;
    try {
      searched = await deps.searchWeb(rawMessages);
    } catch (error) {
      deps.log({ event: "assistant_web_search_failed", category: "search" });
    }
    if (searched && "text" in searched) {
      deps.log({
        event: "assistant_web_searched",
        category: "search",
        provider: "gemini",
        status: 200,
      });
      // Read, not learned: a page can change tomorrow, and an answer built on
      // it belongs to this conversation only.
      return jsonResponse(
        {
          text: searched.text,
          topic: "web",
          provider: "gemini",
          sources: searched.sources,
        },
        200,
      );
    }
    if (searched && "error" in searched) {
      deps.log({
        event: searched.notConfigured
          ? "assistant_web_search_unconfigured"
          : "assistant_web_search_failed",
        category: "search",
        status: 502,
      });
    }
  }

  // Only opt-in, cafe-related questions from the client enter the knowledge
  // gap queue. Strip common identifiers before storage; the queue is for
  // improving shop knowledge, not building customer profiles.
  if (body?.captureKnowledgeGap === true && userId !== null) {
    const lastUserText = [...rawMessages]
      .reverse()
      .find((message: Message) => message.role === "user")?.content ?? "";
    const question = sanitizeKnowledgeGap(lastUserText);
    if (question) {
      try {
        await deps.recordKnowledgeGap?.({
          question,
          locale: /[\u0600-\u06ff]/.test(lastUserText) ? "ar" : "en",
          topic: "cafe",
          customerId: userId,
        });
        deps.log({ event: "assistant_knowledge_gap_recorded", category: "learning" });
      } catch {
        deps.log({ event: "assistant_knowledge_gap_failed", category: "learning" });
      }
    }
  }

  const failures: Array<{ provider: string; status: number }> = [];
  const modelMessages = await addConversationExamples(rawMessages);
  for (const provider of providers) {
    const result = await deps.askProvider(provider, modelMessages);
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
      providerFailure: result.failure,
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
