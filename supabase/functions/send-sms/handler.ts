// Supabase Edge Function: send-sms — handler
//
// Delivers the one-time code of a phone sign-in to the number GoTrue read from
// the account, through the SMS provider.
//
// The caller is GoTrue itself, not the app: Supabase calls this function as the
// "Send SMS" auth hook, and the hook is the only way to use a provider GoTrue
// does not ship. Its own integrations are Twilio, Bird, Vonage and TextLocal;
// for anything else - Infobip here, Unifonic if a Saudi contract is signed -
// this file owns the wire format and the provider credential.
//
// Two rules shape everything below:
//
// 1. The hook decides whether a customer gets a code. A signature that does not
//    verify is refused, so nobody who guesses the URL can spend the account's
//    credit or text an arbitrary number on this brand.
// 2. Nothing a customer can be identified by is written to the runtime log: no
//    phone number, no code. The log line carries the provider's reason only.
//
// The provider seam is `deps.send`, so replacing Infobip with Unifonic is one
// file in `_shared` plus the default below; no rule of this handler changes.
//
// Secrets (set them with `supabase secrets set`):
//   SEND_SMS_HOOK_SECRET - the signing secret the dashboard shows for the hook,
//                          with its `whsec_` prefix
//   INFOBIP_API_KEY      - the API key of the Infobip account
//   INFOBIP_BASE_URL     - the base URL the console prints, e.g. `xxx.infobip.com`
//   INFOBIP_SENDER       - optional, the registered sender ID; without it the
//                          account default (often a shared test sender) is used

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import {
  destinationOf,
  sendSms,
  type SmsMessage,
  type SmsResult,
} from "../_shared/infobip.ts";

/// The body GoTrue hands the hook.
export type SmsRequest = {
  /// The destination exactly as the provider needs it, or null when the
  /// account has no routable number.
  to: string | null;
  /// The code, already validated to be digits.
  otp: string;
};

/// Everything the handler needs from the outside world.
export type SmsDeps = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  /// Reads the raw text of a request before it is parsed, because the
  /// signature covers those exact bytes.
  readBody: (req: Request) => Promise<string>;
  /// Hands one message to the provider.
  send: (
    apiKey: string,
    baseUrl: string,
    message: SmsMessage,
  ) => Promise<SmsResult>;
};

export type SmsOutcome = {
  status: number;
  body: Record<string, unknown>;
  reason?: string;
};

/// The base64 key `standardwebhooks` wants, from whatever the dashboard
/// displayed.
///
/// Supabase presents the signing secret with its version and prefix attached
/// (`v1,whsec_…`) while the library takes only the base64 part, so both forms
/// arrive here as the same key. A value that is not base64 at all is refused
/// instead of being fed to the HMAC and reported as a bad signature.
export function webhookKeyOf(raw: string | undefined): string | null {
  const value = (raw ?? "").trim().replace(/^v1,/, "");
  const base64 = value.startsWith("whsec_")
    ? value.slice("whsec_".length)
    : value;
  if (!base64) return null;
  try {
    const decoded = atob(base64);
    // A 256-bit secret is what the generator issues; a shorter one would be a
    // copy-paste that lost characters.
    return decoded.length >= 32 ? base64 : null;
  } catch {
    return null;
  }
}

/// The hook body, read from the *verified* payload.
///
/// The OTP is checked rather than trusted: this text goes out under a registered
/// sender ID, so a body that was not signed by GoTrue must not be able to put a
/// link, or a sentence, into a message that looks like it came from this brand.
export function parseSmsRequest(payload: unknown): SmsRequest | null {
  if (!payload || typeof payload !== "object") return null;
  const body = payload as any;
  const phone = body?.user?.phone;
  const otp = String(body?.sms?.otp ?? "");
  if (!/^[0-9]{4,10}$/.test(otp)) return null;
  return { to: destinationOf(typeof phone === "string" ? phone : ""), otp };
}

/// The text of the message.
///
/// Arabic first, because that is the language the app is written in, and short:
/// Arabic is not in the GSM-7 alphabet, so every message leaves as UCS-2 and
/// anything past 70 characters is billed and delivered as a second part.
export function smsTextOf(otp: string): string {
  return `كود التحقق لتسجيل الدخول: ${otp}. لا تشاركه مع أي شخص.`;
}

/// Checks the signature of one hook call and returns its parsed body.
///
/// The raw text is what was signed, so it is verified first and parsed second -
/// re-serialising the JSON would change the bytes and break the digest.
export async function verifyHookPayload(
  rawBody: string,
  headers: Record<string, string>,
  secret: string,
): Promise<{ payload: unknown } | { error: string }> {
  const key = webhookKeyOf(secret);
  if (!key) return { error: "hook_secret_not_configured" };
  let wh: Webhook;
  try {
    wh = new Webhook(key);
  } catch {
    return { error: "hook_secret_invalid" };
  }
  try {
    return { payload: wh.verify(rawBody, headers) };
  } catch (error) {
    const name = error instanceof Error ? error.name : "";
    // An old timestamp means the request was captured and replayed, which is a
    // different answer from "someone signed with another key".
    const reason = name === "WebhookExpiredError"
      ? "signature_expired"
      : "signature_mismatch";
    return { error: reason };
  }
}

/// The whole delivery of one code.
export async function deliverSms(
  request: SmsRequest,
  deps: SmsDeps,
): Promise<SmsOutcome> {
  if (request.to === null) {
    return {
      status: 400,
      body: { error: "invalid_phone_number" },
      reason: "invalid_phone_number",
    };
  }

  const apiKey = deps.env("INFOBIP_API_KEY") ?? "";
  const baseUrl = deps.env("INFOBIP_BASE_URL") ?? "";
  if (!apiKey || !baseUrl) {
    // Configured later is not broken now: the answer says the provider is
    // missing, and GoTrue turns that into a failure the app can report.
    return {
      status: 503,
      body: { error: "sms_not_configured" },
      reason: "sms_not_configured",
    };
  }

  const message: SmsMessage = {
    to: request.to,
    sender: deps.env("INFOBIP_SENDER") ?? null,
    text: smsTextOf(request.otp),
  };

  const result = await deps.send(apiKey, baseUrl, message);
  if (result.ok) {
    return { status: 200, body: { sent: true, messageId: result.messageId ?? null } };
  }
  return {
    status: 502,
    body: { error: "sms_provider_rejected", detail: result.error ?? "unknown_error" },
    reason: result.error,
  };
}

function headerRecord(req: Request): Record<string, string> {
  const out: Record<string, string> = {};
  req.headers.forEach((value, name) => {
    out[name] = value;
  });
  return out;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// The entry point of the function.
export async function handleSmsRequest(
  req: Request,
  deps?: Partial<SmsDeps>,
): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const env = deps?.env ?? ((name: string) => Deno.env.get(name));
  let rawBody = "";
  try {
    rawBody = await (deps?.readBody ?? ((r) => r.text()))(req);
  } catch {
    return jsonResponse({ error: "unreadable_body" }, 400);
  }

  const verified = await verifyHookPayload(
    rawBody,
    headerRecord(req),
    env("SEND_SMS_HOOK_SECRET") ?? "",
  );
  if ("error" in verified) {
    // The reason is technical, so it goes to the runtime log the person
    // debugging the hook reads, and not into a body a customer might see.
    console.warn(`sms hook refused a request: ${verified.error}`);
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const request = parseSmsRequest(verified.payload);
  if (!request) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const resolved: SmsDeps = {
    env,
    fetch: deps?.fetch ?? fetch,
    readBody: deps?.readBody ?? ((r) => r.text()),
    send:
      deps?.send ??
      ((apiKey, baseUrl, message) =>
        sendSms(apiKey, baseUrl, message, deps?.fetch ?? fetch)),
  };

  try {
    const outcome = await deliverSms(request, resolved);
    console.log(
      `sms sent=${outcome.status < 300 ? 1 : 0} reason=${outcome.reason ?? ""}`,
    );
    return jsonResponse(outcome.body, outcome.status);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("sms delivery failed:", message);
    return jsonResponse(
      { error: "sms_delivery_failed", detail: message.slice(0, 160) },
      502,
    );
  }
}
