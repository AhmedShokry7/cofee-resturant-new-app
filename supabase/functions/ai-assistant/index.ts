// Supabase Edge Function: ai-assistant
// Server-side proxy to an OpenAI-compatible LLM provider. The provider API key
// is read from function secrets and never exposed to the Flutter client.

import { getUserFromRequest } from "../_shared/tap.ts";

const MAX_MESSAGES = 20;
const MAX_CONTENT_CHARS = 4000;
const MAX_TOTAL_CHARS = 12000;
const REQUEST_TIMEOUT_MS = 15000;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function normalizeBaseUrl(raw: string): string {
  const trimmed = raw.trim().replace(/\/+$/, "");
  if (!trimmed) return "";
  if (trimmed.endsWith("/v1")) return trimmed;
  return `${trimmed}/v1`;
}

function validMessage(value: unknown): value is { role: string; content: string } {
  if (!value || typeof value !== "object") return false;
  const role = (value as any).role;
  const content = (value as any).content;
  return typeof role === "string" &&
    (role === "system" || role === "user" || role === "assistant") &&
    typeof content === "string" &&
    content.length > 0 &&
    content.length <= MAX_CONTENT_CHARS;
}

Deno.serve(async (req) => {
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

  // Optional authentication: guests are allowed, but a supplied token must be valid.
  const authHeader = req.headers.get("Authorization");
  if (authHeader?.startsWith("Bearer ")) {
    const user = await getUserFromRequest(req);
    if (!user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
  }

  const baseUrl = normalizeBaseUrl(Deno.env.get("LLM_BASE_URL") ?? "");
  const apiKey = (Deno.env.get("LLM_API_KEY") ?? "").trim();
  const model = (Deno.env.get("LLM_MODEL") ?? "").trim();
  if (!baseUrl || !model) {
    return jsonResponse({ error: "LLM provider is not configured" }, 503);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };
    if (apiKey) headers["Authorization"] = `Bearer ${apiKey}`;

    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        model,
        temperature: 0.3,
        max_tokens: 260,
        messages: rawMessages,
      }),
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
      return jsonResponse({ error: "Provider request failed" }, 502);
    }

    const choices = Array.isArray(json?.choices) ? json.choices : [];
    const first = choices.length > 0 ? choices[0] : null;
    const content = first?.message?.content;
    const reply = typeof content === "string" ? content.trim() : "";
    if (!reply) {
      return jsonResponse({ error: "Empty provider response" }, 502);
    }

    return jsonResponse({ text: reply, topic: "llm" }, 200);
  } catch (error) {
    const aborted = String(error).includes("AbortError");
    return jsonResponse(
      { error: aborted ? "Provider timeout" : "Provider request failed" },
      aborted ? 504 : 502,
    );
  } finally {
    clearTimeout(timeout);
  }
});