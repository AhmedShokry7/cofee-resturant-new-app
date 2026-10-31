// supabase/functions/send-email/handler.test.ts
//
// The delivery rules of the mail function, tested without a database and
// without sending anything: the store, the provider and the environment are
// injected.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sendEmail, type ResendEmail } from "../_shared/resend.ts";
import {
  deliverEmail,
  emailContentOf,
  emailHtmlOf,
  handleEmailRequest,
  handleUnsubscribe,
  parseEmailNotification,
  unsubscribeTokenFor,
  unsubscribeUrlOf,
  type EmailDeliveryRecord,
  type EmailDeps,
  type EmailNotification,
  type EmailPreferences,
  type EmailStore,
} from "./handler.ts";

const STORAGE_HOST = "project.supabase.co";
const PUBLIC_IMAGE =
  `https://${STORAGE_HOST}/storage/v1/object/public/product-images/products/notifications/offer.jpg`;
const USER_ID = "22222222-2222-2222-2222-222222222222";
const NOTIFICATION_ID = "11111111-1111-1111-1111-111111111111";
const FUNCTION_URL = "https://project.supabase.co/functions/v1/send-email";

function makeNotification(
  overrides: Partial<EmailNotification> = {},
): EmailNotification {
  return {
    notificationId: NOTIFICATION_ID,
    userId: USER_ID,
    type: "order_status",
    titleAr: "تحديث حالة الطلب",
    titleEn: "Order updated",
    bodyAr: "حالة طلبك الآن: جاهز",
    bodyEn: "Your order status is now: ready",
    imageUrl: null,
    ...overrides,
  };
}

type FakeStore = EmailStore & {
  deliveries: EmailDeliveryRecord[];
  disabled: string[];
  customer: { address: string; language: string | null } | null;
  preferences: EmailPreferences | null;
};

function makeStore(
  overrides: Partial<{
    customer: { address: string; language: string | null } | null;
    preferences: EmailPreferences | null;
  }> = {},
): FakeStore {
  const store: FakeStore = {
    customer: overrides.customer === undefined
      ? { address: "customer@example.com", language: "ar" }
      : overrides.customer ?? null,
    preferences: "preferences" in overrides
      ? overrides.preferences ?? null
      : {
        emailEnabled: true,
        orderStatus: true,
        promo: true,
        loyalty: true,
        system: true,
      },
    deliveries: [],
    disabled: [],
    async readCustomer() {
      return store.customer;
    },
    async readPreferences() {
      return store.preferences;
    },
    async recordDelivery(delivery) {
      store.deliveries.push(delivery);
    },
    async setEmailDisabled(userId) {
      store.disabled.push(userId);
      return true;
    },
  };
  return store;
}

/// The deps of a delivery that never touches the network.
function makeDeps(
  store: FakeStore,
  options: {
    env?: Record<string, string>;
    send?: (apiKey: string, email: ResendEmail) => Promise<{ ok: boolean; id?: string; error?: string }>;
  } = {},
): EmailDeps & { sent: ResendEmail[]; keys: string[] } {
  const envValues: Record<string, string> = {
    RESEND_API_KEY: "re_secret",
    EMAIL_FROM: "New Coffee <mail@example.com>",
    EMAIL_WEBHOOK_SECRET: "webhook-secret",
    ...options.env,
  };
  const sent: ResendEmail[] = [];
  const keys: string[] = [];
  return {
    sent,
    keys,
    env: (name) => envValues[name],
    fetch: fetch,
    store,
    async send(apiKey, email) {
      keys.push(apiKey);
      sent.push(email);
      return options.send
        ? options.send(apiKey, email)
        : Promise.resolve({ ok: true, id: "resend-id" });
    },
    unsubscribeToken: unsubscribeTokenFor,
  };
}

Deno.test("a customer without an address is skipped, not failed", async () => {
  const store = makeStore({ customer: null });
  const deps = makeDeps(store);
  const result = await deliverEmail(makeNotification(), deps, FUNCTION_URL);
  assertEquals(result, { sent: 0, failed: 0, skipped: true, reason: "no_address" });
  assertEquals(store.deliveries[0]?.status, "skipped");
  assertEquals(store.deliveries[0]?.error, "no_address");
  assertEquals(deps.sent.length, 0);
});

Deno.test("an empty address is a skip too", async () => {
  const store = makeStore({ customer: { address: "  ", language: "ar" } });
  const result = await deliverEmail(makeNotification(), makeDeps(store), FUNCTION_URL);
  assertEquals(result.reason, "no_address");
});

Deno.test("the mail gate is off by default, so a customer without a row gets nothing", async () => {
  const store = makeStore({ preferences: null });
  const deps = makeDeps(store);
  const result = await deliverEmail(makeNotification(), deps, FUNCTION_URL);
  assertEquals(result.reason, "email_disabled");
  assertEquals(deps.sent.length, 0);
});

Deno.test("the type switch closes one kind and leaves the others open", async () => {
  const store = makeStore();
  store.preferences = {
    emailEnabled: true,
    orderStatus: false,
    promo: true,
    loyalty: true,
    system: true,
  };
  const skipped = makeDeps(store);
  assertEquals(
    (await deliverEmail(makeNotification(), skipped, FUNCTION_URL)).reason,
    "type_disabled",
  );
  assertEquals(skipped.sent.length, 0);

  const other = makeDeps(store);
  assertEquals((await deliverEmail(makeNotification({ type: "promo" }), other, FUNCTION_URL)).sent, 1);
});

Deno.test("the customer's language decides the subject and the body", async () => {
  const arabic = makeDeps(makeStore());
  await deliverEmail(makeNotification(), arabic, FUNCTION_URL);
  assertEquals(arabic.sent[0].subject, "تحديث حالة الطلب");
  assertEquals(arabic.sent[0].text.startsWith("تحديث حالة الطلب"), true);

  const english = makeDeps(makeStore({ customer: { address: "a@example.com", language: "en" } }));
  await deliverEmail(makeNotification(), english, FUNCTION_URL);
  assertEquals(english.sent[0].subject, "Order updated");
});

Deno.test("a missing translation falls back to the other language", () => {
  const content = emailContentOf(
    makeNotification({ titleAr: "", bodyAr: "" }),
    "ar",
  );
  assertEquals(content.subject, "Order updated");
  assertEquals(content.body, "Your order status is now: ready");
});

Deno.test("the picture is shown only when it is a public object of this project", () => {
  const withImage = emailHtmlOf(
    makeNotification({ imageUrl: PUBLIC_IMAGE }),
    "en",
    "https://project.supabase.co/functions/v1/send-email/unsubscribe",
  );
  assertEquals(withImage.includes(`<img src="${PUBLIC_IMAGE}"`), true);

  const textOnly = emailHtmlOf(makeNotification(), "en", "https://x/y");
  assertEquals(textOnly.includes("<img"), false);

  const parsed = parseEmailNotification(
    {
      notification_id: NOTIFICATION_ID,
      user_id: USER_ID,
      type: "promo",
      payload: { image_url: "https://evil.example.com/offer.jpg" },
    },
    STORAGE_HOST,
  );
  assertEquals(parsed?.imageUrl, null);
});

Deno.test("text written by an admin cannot open a tag in the mail", () => {
  const html = emailHtmlOf(
    makeNotification({ titleEn: `</h1><script>alert(1)</script>`, bodyEn: `a"b` }),
    "en",
    "https://project.supabase.co/functions/v1/send-email/unsubscribe",
  );
  assertEquals(html.includes("<script>"), false);
  assertEquals(html.includes("&lt;script&gt;"), true);
  assertEquals(html.includes("a&quot;b"), true);
});

Deno.test("the Arabic mail is written right to left and the English one left to right", () => {
  const url = "https://project.supabase.co/functions/v1/send-email/unsubscribe";
  assertEquals(emailHtmlOf(makeNotification(), "ar", url).includes('dir="rtl"'), true);
  assertEquals(emailHtmlOf(makeNotification(), "en", url).includes('dir="ltr"'), true);
});

Deno.test("one-click unsubscribe rides in the headers and matches the link in the body", async () => {
  const store = makeStore();
  const deps = makeDeps(store);
  await deliverEmail(makeNotification(), deps, FUNCTION_URL);
  const email = deps.sent[0];
  const token = await unsubscribeTokenFor(USER_ID, "webhook-secret");
  const expected = unsubscribeUrlOf(FUNCTION_URL, USER_ID, token);
  assertEquals(email.headers?.["List-Unsubscribe"], `<${expected}>`);
  assertEquals(email.headers?.["List-Unsubscribe-Post"], "List-Unsubscribe=One-Click");
  assertEquals(email.html.includes(expected.replace(/&/g, "&amp;")), true);
  assertEquals(email.text.includes(expected), true);
});

Deno.test("an unconfigured provider is a recorded failure, not a crash", async () => {
  const store = makeStore();
  const result = await deliverEmail(
    makeNotification(),
    makeDeps(store, { env: { RESEND_API_KEY: "", EMAIL_FROM: "" } }),
    FUNCTION_URL,
  );
  assertEquals(result.reason, "email_not_configured");
  assertEquals(store.deliveries[0]?.status, "failed");
  assertEquals(store.deliveries[0]?.error, "email_not_configured");
});

Deno.test("a provider refusal is stored with its reason", async () => {
  const store = makeStore();
  const result = await deliverEmail(
    makeNotification(),
    makeDeps(store, {
      send: () => Promise.resolve({ ok: false, error: "resend 422: invalid sender" }),
    }),
    FUNCTION_URL,
  );
  assertEquals(result.failed, 1);
  assertEquals(store.deliveries[0]?.status, "failed");
  assertEquals(store.deliveries[0]?.error, "resend 422: invalid sender");
});

Deno.test("the request route checks the shared secret", async () => {
  const store = makeStore();
  const deps = makeDeps(store, { env: {} });
  const body = JSON.stringify({
    notification_id: NOTIFICATION_ID,
    user_id: USER_ID,
    type: "promo",
    payload: {},
  });

  const noHeader = await handleEmailRequest(
    new Request(FUNCTION_URL, { method: "POST", body, headers: { "Content-Type": "application/json" } }),
    deps,
  );
  assertEquals(noHeader.status, 401);

  const wrong = await handleEmailRequest(
    new Request(FUNCTION_URL, {
      method: "POST",
      body,
      headers: { "Content-Type": "application/json", "x-email-secret": "guess" },
    }),
    deps,
  );
  assertEquals(wrong.status, 401);

  const accepted = await handleEmailRequest(
    new Request(FUNCTION_URL, {
      method: "POST",
      body,
      headers: { "Content-Type": "application/json", "x-email-secret": "webhook-secret" },
    }),
    deps,
  );
  assertEquals(accepted.status, 200);
  assertEquals(deps.sent.length, 1);
});

Deno.test("a body without the two ids is refused before anything is read", async () => {
  const deps = makeDeps(makeStore());
  const response = await handleEmailRequest(
    new Request(FUNCTION_URL, {
      method: "POST",
      body: JSON.stringify({ type: "promo" }),
      headers: { "Content-Type": "application/json", "x-email-secret": "webhook-secret" },
    }),
    deps,
  );
  assertEquals(response.status, 400);
});

Deno.test("a valid unsubscribe link switches the mail off once", async () => {
  const store = makeStore();
  const token = await unsubscribeTokenFor(USER_ID, "webhook-secret");
  const url = unsubscribeUrlOf(FUNCTION_URL, USER_ID, token);
  const response = await handleUnsubscribe(new Request(url), {
    env: (name) => name === "EMAIL_WEBHOOK_SECRET" ? "webhook-secret" : undefined,
    store,
    unsubscribeToken: unsubscribeTokenFor,
  });
  assertEquals(response.status, 200);
  assertEquals(store.disabled, [USER_ID]);
  assertEquals((await response.text()).includes("تم إيقاف رسائل البريد"), true);
});

Deno.test("a forged unsubscribe link changes nothing", async () => {
  const store = makeStore();
  const response = await handleUnsubscribe(
    new Request(`${FUNCTION_URL}/unsubscribe?user_id=${USER_ID}&token=${"0".repeat(64)}`),
    {
      env: (name) => name === "EMAIL_WEBHOOK_SECRET" ? "webhook-secret" : undefined,
      store,
      unsubscribeToken: unsubscribeTokenFor,
    },
  );
  assertEquals(response.status, 400);
  assertEquals(store.disabled, []);
});

Deno.test("the token of one customer does not open the link of another", async () => {
  const other = "33333333-3333-3333-3333-333333333333";
  const token = await unsubscribeTokenFor(other, "webhook-secret");
  const store = makeStore();
  const response = await handleUnsubscribe(
    new Request(unsubscribeUrlOf(FUNCTION_URL, USER_ID, token)),
    {
      env: (name) => name === "EMAIL_WEBHOOK_SECRET" ? "webhook-secret" : undefined,
      store,
      unsubscribeToken: unsubscribeTokenFor,
    },
  );
  assertEquals(response.status, 400);
  assertEquals(store.disabled, []);
});

Deno.test("a missing secret refuses every unsubscribe click", async () => {
  const store = makeStore();
  const token = await unsubscribeTokenFor(USER_ID, "webhook-secret");
  const response = await handleUnsubscribe(
    new Request(unsubscribeUrlOf(FUNCTION_URL, USER_ID, token)),
    {
      env: () => undefined,
      store,
      unsubscribeToken: unsubscribeTokenFor,
    },
  );
  assertEquals(response.status, 400);
  assertEquals(store.disabled, []);
});

Deno.test("the provider call is one JSON POST with the key only in the bearer header", async () => {
  const calls: { url: string; init: RequestInit }[] = [];
  const result = await sendEmail(
    "re_secret",
    {
      from: "New Coffee <mail@example.com>",
      to: "customer@example.com",
      subject: "Order updated",
      text: "ready",
      html: "<p>ready</p>",
    },
    (input, init) => {
      calls.push({ url: String(input), init: init ?? {} });
      return Promise.resolve(
        new Response(JSON.stringify({ id: "resend-id" }), { status: 200 }),
      );
    },
  );
  assertEquals(result, { ok: true, id: "resend-id" });
  assertEquals(calls[0].url, "https://api.resend.com/emails");
  const headers = calls[0].init.headers as Record<string, string>;
  assertEquals(headers.Authorization, "Bearer re_secret");
  assertEquals(JSON.parse(String(calls[0].init.body)).to, ["customer@example.com"]);
});

Deno.test("a provider error keeps a short description of its own", async () => {
  const body = JSON.stringify({
    name: "validation_error",
    message: "the sending domain is not verified",
    extra: "x".repeat(500),
  });
  const result = await sendEmail(
    "re_secret",
    {
      from: "a@example.com",
      to: "b@example.com",
      subject: "s",
      text: "t",
      html: "h",
    },
    () => Promise.resolve(new Response(body, { status: 422 })),
  );
  assertEquals(result.ok, false);
  assertEquals(
    result.error,
    "resend 422: validation_error: the sending domain is not verified",
  );
});

Deno.test("a body that is not json still gives a bounded reason", async () => {
  const result = await sendEmail(
    "re_secret",
    { from: "a@example.com", to: "b@example.com", subject: "s", text: "t", html: "h" },
    () => Promise.resolve(new Response("<html>502</html>".repeat(30), { status: 502 })),
  );
  assertEquals(result.ok, false);
  assertEquals(result.error!.length <= "resend 502: ".length + 200, true);
});
