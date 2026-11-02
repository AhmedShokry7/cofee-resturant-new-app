// supabase/functions/send-sms/handler.test.ts
//
// The rules of the SMS hook, tested without a provider account and without
// sending anything: the environment, the reader and the provider are injected,
// and the requests are signed the way GoTrue signs them.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  deliverSms,
  handleSmsRequest,
  parseSmsRequest,
  smsTextOf,
  verifyHookPayload,
  webhookKeyOf,
  type SmsDeps,
  type SmsRequest,
} from "./handler.ts";
import {
  destinationOf,
  infobipHostOf,
  sendSms,
  type SmsMessage,
} from "../_shared/infobip.ts";

/// A 32-byte secret in the base64 form the dashboard generates.
const SECRET = "JclN8JPCT/A4c21ISz18aNo/PJTvjD36/6F6hGnMTKs=";
const HOOK_URL = "https://project.supabase.co/functions/v1/send-sms";
const PHONE = "+966501234567";
const OTP = "123456";

function hookBody(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    user: { id: "u1", phone: PHONE, ...overrides },
    sms: { otp: OTP },
  });
}

/// The headers of a signed hook call, built the way the standard defines it:
/// the HMAC of `<id>.<timestamp>.<raw body>` with the shared secret.
async function signedHeaders(
  payload: string,
  secret: string = SECRET,
  options: { id?: string; timestamp?: number } = {},
): Promise<Record<string, string>> {
  const key = await crypto.subtle.importKey(
    "raw",
    Uint8Array.from(atob(secret), (c) => c.charCodeAt(0)),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const id = options.id ?? crypto.randomUUID();
  const timestamp = String(options.timestamp ?? Math.floor(Date.now() / 1000));
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${id}.${timestamp}.${payload}`),
  );
  const encoded = btoa(
    String.fromCharCode(...new Uint8Array(signature)),
  );
  return {
    "content-type": "application/json",
    "webhook-id": id,
    "webhook-timestamp": timestamp,
    "webhook-signature": `v1,${encoded},t=${timestamp}`,
  };
}

type FakeDeps = SmsDeps & { sent: SmsMessage[]; keys: string[] };

function makeDeps(
  options: {
    env?: Record<string, string | undefined>;
    result?: { ok: boolean; messageId?: string; error?: string };
  } = {},
): FakeDeps {
  const envValues: Record<string, string | undefined> = {
    SEND_SMS_HOOK_SECRET: `v1,whsec_${SECRET}`,
    INFOBIP_API_KEY: "infobip-key",
    INFOBIP_BASE_URL: "acme.infobip.com",
    INFOBIP_SENDER: "GhaimSohob",
    ...options.env,
  };
  const sent: SmsMessage[] = [];
  const keys: string[] = [];
  return {
    sent,
    keys,
    env: (name) => envValues[name],
    fetch: globalThis.fetch,
    readBody: (req) => req.text(),
    async send(apiKey, baseUrl, message) {
      keys.push(`${apiKey}@${baseUrl}`);
      sent.push(message);
      return options.result ?? { ok: true, messageId: "777" };
    },
  };
}


// --- the signature -----------------------------------------------------------

Deno.test("a request signed by this project is accepted and delivers", async () => {
  const body = hookBody();
  const deps = makeDeps();
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body, headers: await signedHeaders(body) }),
    deps,
  );
  assertEquals(response.status, 200);
  assertEquals(deps.sent.length, 1);
  assertEquals(deps.sent[0].to, "966501234567");
  assertEquals(deps.sent[0].text.includes(OTP), true);
});

Deno.test("a request signed with another secret is refused before the provider", async () => {
  const body = hookBody();
  const other = "0IM2z8BpYQnEjO7yL3oE4cG9ZpF1sW2vX6hN8kR0tYs=";
  const deps = makeDeps();
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body, headers: await signedHeaders(body, other) }),
    deps,
  );
  assertEquals(response.status, 401);
  assertEquals(deps.sent.length, 0);
});

Deno.test("a body changed after signing is refused", async () => {
  const body = hookBody();
  const headers = await signedHeaders(body);
  const tampered = hookBody({ phone: "+966509999999" });
  const deps = makeDeps();
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body: tampered, headers }),
    deps,
  );
  assertEquals(response.status, 401);
  assertEquals(deps.sent.length, 0);
});

Deno.test("a captured request is refused once it is old", async () => {
  const body = hookBody();
  const headers = await signedHeaders(body, SECRET, {
    timestamp: Math.floor(Date.now() / 1000) - 3600,
  });
  const deps = makeDeps();
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body, headers }),
    deps,
  );
  assertEquals(response.status, 401);
  assertEquals(deps.sent.length, 0);
});

Deno.test("an unsigned request is refused", async () => {
  const deps = makeDeps();
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body: hookBody(), headers: { "content-type": "application/json" } }),
    deps,
  );
  assertEquals(response.status, 401);
  assertEquals(deps.sent.length, 0);
});

Deno.test("a missing hook secret refuses every request", async () => {
  const body = hookBody();
  const deps = makeDeps({ env: { SEND_SMS_HOOK_SECRET: undefined } });
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body, headers: await signedHeaders(body) }),
    deps,
  );
  assertEquals(response.status, 401);
  assertEquals(deps.sent.length, 0);
});

Deno.test("only a POST is a hook call", async () => {
  const response = await handleSmsRequest(new Request(HOOK_URL), makeDeps());
  assertEquals(response.status, 405);
});

Deno.test("the secret is read from every form the dashboard shows it in", () => {
  assertEquals(webhookKeyOf(SECRET), SECRET);
  assertEquals(webhookKeyOf(`whsec_${SECRET}`), SECRET);
  assertEquals(webhookKeyOf(`v1,whsec_${SECRET}`), SECRET);
  assertEquals(webhookKeyOf(`  v1,whsec_${SECRET}  `), SECRET);
});

Deno.test("a secret that is not a key is refused rather than half-trusted", () => {
  assertEquals(webhookKeyOf(undefined), null);
  assertEquals(webhookKeyOf(""), null);
  assertEquals(webhookKeyOf("whsec_"), null);
  assertEquals(webhookKeyOf("not base64 at all !!"), null);
  // Copy-paste that lost characters decodes to a short key.
  assertEquals(webhookKeyOf(btoa("too short")), null);
});

Deno.test("verification names a replay apart from a wrong key", async () => {
  const body = hookBody();
  const stale = await signedHeaders(body, SECRET, {
    timestamp: Math.floor(Date.now() / 1000) - 3600,
  });
  const expired = await verifyHookPayload(body, stale, SECRET);
  assertEquals("error" in expired, true);

  const other = "0IM2z8BpYQnEjO7yL3oE4cG9ZpF1sW2vX6hN8kR0tYs=";
  const wrongKey = await signedHeaders(body, other);
  assertEquals(
    (await verifyHookPayload(body, wrongKey, SECRET) as { error: string }).error,
    "signature_mismatch",
  );
});

// --- the payload -------------------------------------------------------------

Deno.test("the code and the number are taken from the hook body", () => {
  assertEquals(parseSmsRequest({ user: { phone: PHONE }, sms: { otp: OTP } }), {
    to: "966501234567",
    otp: OTP,
  });
});

Deno.test("an empty or foreign destination is refused", () => {
  assertEquals(parseSmsRequest({ user: {}, sms: { otp: OTP } })?.to, null);
  assertEquals(
    parseSmsRequest({ user: { phone: "call me" }, sms: { otp: OTP } })?.to,
    null,
  );
});

Deno.test("a code that is not digits is refused outright", () => {
  // The text goes out under a registered sender ID, so nothing that is not a
  // code may be composed into it.
  assertEquals(parseSmsRequest({ user: { phone: PHONE }, sms: { otp: "" } }), null);
  assertEquals(
    parseSmsRequest({
      user: { phone: PHONE },
      sms: { otp: "https://example.com" },
    }),
    null,
  );
  assertEquals(
    parseSmsRequest({ user: { phone: PHONE }, sms: { otp: "12" } }),
    null,
  );
  assertEquals(
    parseSmsRequest({ user: { phone: PHONE }, sms: { otp: "1234" } })?.otp,
    "1234",
  );
});

Deno.test("a signed body without the two fields is a 400, not a send", async () => {
  const body = JSON.stringify({ user: {}, sms: {} });
  const deps = makeDeps();
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body, headers: await signedHeaders(body) }),
    deps,
  );
  assertEquals(response.status, 400);
  assertEquals(deps.sent.length, 0);
});

Deno.test("the message is Arabic, carries the code, and fits one segment", () => {
  const text = smsTextOf(OTP);
  assertEquals(text.includes(OTP), true);
  assertEquals(text.includes("+966"), false);
  // UCS-2 parts at 70 characters: a longer text is billed twice.
  assertEquals(text.length <= 70, true);
  assertEquals(/[؀-ۿ]/.test(text), true);
});

// --- the delivery ------------------------------------------------------------

const request: SmsRequest = { to: "966501234567", otp: OTP };

Deno.test("a number the hook cannot route is refused before the provider", async () => {
  const deps = makeDeps();
  const outcome = await deliverSms({ to: null, otp: OTP }, deps);
  assertEquals(outcome.status, 400);
  assertEquals(outcome.body.error, "invalid_phone_number");
  assertEquals(deps.sent.length, 0);
});

Deno.test("a provider without its key is a 503, and nothing is sent", async () => {
  const deps = makeDeps({ env: { INFOBIP_API_KEY: "" } });
  const outcome = await deliverSms(request, deps);
  assertEquals(outcome.status, 503);
  assertEquals(outcome.body.error, "sms_not_configured");
  assertEquals(deps.sent.length, 0);

  const noHost = makeDeps({ env: { INFOBIP_BASE_URL: "" } });
  assertEquals((await deliverSms(request, noHost)).status, 503);
});

Deno.test("the sender ID is passed when the account has one", async () => {
  const deps = makeDeps();
  await deliverSms(request, deps);
  assertEquals(deps.sent[0].sender, "GhaimSohob");

  const bare = makeDeps({ env: { INFOBIP_SENDER: undefined } });
  await deliverSms(request, bare);
  assertEquals(bare.sent[0].sender, null);
});

Deno.test("a provider refusal is answered as a failure", async () => {
  const deps = makeDeps({
    result: { ok: false, error: "infobip 400: invalid destination address" },
  });
  const outcome = await deliverSms(request, deps);
  assertEquals(outcome.status, 502);
  assertEquals(outcome.body.error, "sms_provider_rejected");
  assertEquals(
    outcome.body.detail,
    "infobip 400: invalid destination address",
  );
});

Deno.test("the answer never repeats the credential", async () => {
  const body = hookBody();
  const deps = makeDeps({
    result: { ok: false, error: "infobip 401: unauthorized" },
  });
  const response = await handleSmsRequest(
    new Request(HOOK_URL, { method: "POST", body, headers: await signedHeaders(body) }),
    deps,
  );
  const text = await response.text();
  assertEquals(response.status, 502);
  assertEquals(text.includes("infobip-key"), false);
});

// --- the Infobip client ------------------------------------------------------

Deno.test("the provider call is one JSON POST with the key only in the App header", async () => {
  const calls: { url: string; init: RequestInit }[] = [];
  const result = await sendSms(
    "infobip-key",
    "acme.infobip.com",
    { to: "966501234567", sender: "GhaimSohob", text: "كود التحقق: 123456" },
    (input, init) => {
      calls.push({ url: String(input), init: init ?? {} });
      return Promise.resolve(
        new Response(JSON.stringify({ smsCount: 1, messageId: 777 }), { status: 200 }),
      );
    },
  );
  assertEquals(result.ok, true);
  assertEquals(calls[0].url, "https://acme.infobip.com/sms/3/messages");
  const headers = calls[0].init.headers as Record<string, string>;
  assertEquals(headers.Authorization, "App infobip-key");
  const body = JSON.parse(String(calls[0].init.body));
  assertEquals(body.messages[0].destinations, [{ to: "966501234567" }]);
  assertEquals(body.messages[0].sender, "GhaimSohob");
  assertEquals(body.messages[0].content.text, "كود التحقق: 123456");
});

Deno.test("a sender the account does not override is left out of the body", async () => {
  let sent: any = null;
  await sendSms(
    "infobip-key",
    "https://acme.infobip.com",
    { to: "966501234567", sender: null, text: "x" },
    (_input, init) => {
      sent = JSON.parse(String(init?.body));
      return Promise.resolve(new Response("{}", { status: 200 }));
    },
  );
  assertEquals("sender" in sent.messages[0], false);
});

Deno.test("the key is only ever sent to an Infobip host", () => {
  assertEquals(infobipHostOf("acme.infobip.com"), "acme.infobip.com");
  assertEquals(infobipHostOf("https://acme.infobip.com"), "acme.infobip.com");
  assertEquals(infobipHostOf("acme.infobip.com/sms/3/messages"), "acme.infobip.com");
  assertEquals(infobipHostOf("ACME.Infobip.COM"), "acme.infobip.com");
  assertEquals(infobipHostOf("evil.example.com"), null);
  assertEquals(infobipHostOf("acme.infobip.com.evil.example"), null);
  assertEquals(infobipHostOf("infobip.com"), null);
  assertEquals(infobipHostOf(undefined), null);
});

Deno.test("a host that is not Infobip stops the call before the key", async () => {
  let called = 0;
  const result = await sendSms(
    "infobip-key",
    "evil.example.com",
    { to: "966501234567", sender: null, text: "x" },
    () => {
      called++;
      return Promise.resolve(new Response("{}", { status: 200 }));
    },
  );
  assertEquals(called, 0);
  assertEquals(result, { ok: false, error: "infobip_base_url_invalid" });
});

Deno.test("a 200 whose destination was rejected is not reported as sent", async () => {
  const result = await sendSms(
    "infobip-key",
    "acme.infobip.com",
    { to: "966501234567", sender: null, text: "x" },
    () =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            smsCount: 1,
            messageStatus: [
              { to: 966501234567, status: { description: "ERROR", name: "error" } },
            ],
          }),
          { status: 200 },
        ),
      ),
  );
  assertEquals(result.ok, false);
  assertEquals(result.error, "infobip refused: ERROR");
});

Deno.test("a queued destination is a success", async () => {
  const result = await sendSms(
    "infobip-key",
    "acme.infobip.com",
    { to: "966501234567", sender: null, text: "x" },
    () =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            smsCount: 1,
            groupId: 777,
            messageStatus: [{ status: { description: "MESSAGE_QUEUED" } }],
          }),
          { status: 200 },
        ),
      ),
  );
  assertEquals(result.ok, true);
  assertEquals(result.messageId, "777");
});

Deno.test("a provider error keeps a short description and no key", async () => {
  const body = JSON.stringify({
    errorCode: 1001,
    errorMessage: "the free trial only sends to the verified number",
    traceId: "x".repeat(400),
  });
  const result = await sendSms(
    "infobip-key",
    "acme.infobip.com",
    { to: "966501234567", sender: null, text: "x" },
    () => Promise.resolve(new Response(body, { status: 400 })),
  );
  assertEquals(result.ok, false);
  assertEquals(
    result.error,
    "infobip 400: the free trial only sends to the verified number",
  );
  assertEquals(result.error!.includes("infobip-key"), false);
});

Deno.test("a non-json provider answer still gives a bounded reason", async () => {
  const result = await sendSms(
    "infobip-key",
    "acme.infobip.com",
    { to: "966501234567", sender: null, text: "x" },
    () => Promise.resolve(new Response("<html>503</html>".repeat(40), { status: 503 })),
  );
  assertEquals(result.ok, false);
  assertEquals(result.error!.length <= "infobip 503: ".length + 160, true);
});

Deno.test("a destination arrives as bare digits and nothing else passes", () => {
  assertEquals(destinationOf("+966 50 123 4567"), "966501234567");
  assertEquals(destinationOf("966501234567"), "966501234567");
  assertEquals(destinationOf("+96650123456789012345"), null);
  assertEquals(destinationOf(""), null);
  assertEquals(destinationOf(undefined), null);
});
