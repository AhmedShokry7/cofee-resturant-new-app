// supabase/functions/send-push/index.test.ts
//
// The delivery rules of the Edge Function, tested without a database and
// without sending anything: the store and the sender are injected.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  deliver,
  handleRequest,
  parseNotification,
  type DeliveryRecord,
  type DeviceToken,
  type PushDeps,
  type PushNotification,
  type PushPreferences,
  type PushStore,
} from "./handler.ts";

function makeNotification(
  overrides: Partial<PushNotification> = {},
): PushNotification {
  return {
    notificationId: "11111111-1111-1111-1111-111111111111",
    userId: "22222222-2222-2222-2222-222222222222",
    type: "order_status",
    titleAr: "تحديث حالة الطلب",
    titleEn: "Order updated",
    bodyAr: "حالة طلبك الآن: جاهز",
    bodyEn: "Your order status is now: ready",
    relatedEntityType: "order",
    relatedEntityId: "33333333-3333-3333-3333-333333333333",
    ...overrides,
  };
}

type FakeStore = PushStore & {
  deliveries: DeliveryRecord[];
  deletedTokens: string[];
  preferences: PushPreferences | null;
  tokens: DeviceToken[];
};

function makeStore(
  overrides: Partial<{
    preferences: PushPreferences | null;
    tokens: DeviceToken[];
  }> = {},
): FakeStore {
  const deliveries: DeliveryRecord[] = [];
  const deletedTokens: string[] = [];
  const store: FakeStore = {
    deliveries,
    deletedTokens,
    preferences: overrides.preferences === undefined
      ? {
        pushEnabled: true,
        orderStatus: true,
        promo: true,
        loyalty: true,
        system: true,
      }
      : overrides.preferences,
    tokens: overrides.tokens ?? [{
      token: "device-token-1",
      platform: "android",
      locale: "ar",
    }],
    async readPreferences() {
      return store.preferences;
    },
    async readTokens() {
      return store.tokens;
    },
    async recordDelivery(delivery) {
      deliveries.push(delivery);
    },
    async deleteToken(token) {
      deletedTokens.push(token);
    },
  };
  return store;
}

function makeDeps(store: FakeStore, send?: PushDeps["send"]): PushDeps {
  return {
    env: (name: string) =>
      name === "PUSH_WEBHOOK_SECRET"
        ? "secret"
        : name === "FIREBASE_SERVICE_ACCOUNT"
        ? JSON.stringify({
          project_id: "project",
          client_email: "sa@project.iam.gserviceaccount.com",
          private_key: "-----BEGIN PRIVATE KEY-----\nx\n-----END PRIVATE KEY-----",
        })
        : undefined,
    fetch: fetch,
    store,
    send: send ?? (async () => ({ ok: true, messageId: "message-1" })),
    accessToken: async () => "access-token",
  };
}

Deno.test("parseNotification reads the body of the trigger", () => {
  const parsed = parseNotification({
    notification_id: "a",
    user_id: "b",
    type: "promo",
    title_ar: "ar",
    title_en: "en",
  });
  assertEquals(parsed?.notificationId, "a");
  assertEquals(parsed?.userId, "b");
  assertEquals(parsed?.type, "promo");
});

Deno.test("parseNotification rejects a body without ids", () => {
  assertEquals(parseNotification({}), null);
  assertEquals(parseNotification(null), null);
});

Deno.test("a request without the secret is refused", async () => {
  const store = makeStore();
  const response = await handleRequest(
    new Request("http://localhost/send-push", { method: "POST", body: "{}" }),
    makeDeps(store),
  );
  assertEquals(response.status, 401);
});

Deno.test("only POST is accepted", async () => {
  const store = makeStore();
  const response = await handleRequest(
    new Request("http://localhost/send-push", { method: "GET" }),
    makeDeps(store),
  );
  assertEquals(response.status, 405);
});

Deno.test("a customer who did not enable push gets nothing", async () => {
  const store = makeStore({
    preferences: {
      pushEnabled: false,
      orderStatus: true,
      promo: true,
      loyalty: true,
      system: true,
    },
  });
  const result = await deliver(makeNotification(), makeDeps(store));
  assertEquals(result.skipped, true);
  assertEquals(result.reason, "push_disabled");
  assertEquals(store.deliveries.length, 0);
});

Deno.test("a switched off type is not delivered", async () => {
  const store = makeStore({
    preferences: {
      pushEnabled: true,
      orderStatus: false,
      promo: true,
      loyalty: true,
      system: true,
    },
  });
  const result = await deliver(makeNotification(), makeDeps(store));
  assertEquals(result.skipped, true);
  assertEquals(result.reason, "type_disabled");
});

Deno.test("a customer without a device gets a skipped log row", async () => {
  const store = makeStore({ tokens: [] });
  const result = await deliver(makeNotification(), makeDeps(store));
  assertEquals(result.skipped, true);
  assertEquals(result.reason, "no_device_token");
  assertEquals(store.deliveries.length, 1);
  assertEquals(store.deliveries[0].status, "skipped");
});

Deno.test("the message is written in the language of the device", async () => {
  const store = makeStore();
  let sentTitle = "";
  let sentBody = "";
  const deps = makeDeps(store, async (_token, _project, _device, message) => {
    sentTitle = message.title;
    sentBody = message.body;
    return { ok: true, messageId: "message-1" };
  });
  const result = await deliver(makeNotification(), deps);
  assertEquals(result.sent, 1);
  assertEquals(sentTitle, "تحديث حالة الطلب");
  assertEquals(sentBody, "حالة طلبك الآن: جاهز");
  assertEquals(store.deliveries[0].status, "sent");
  assertEquals(store.deliveries[0].providerMessageId, "message-1");
});

Deno.test("an english device gets the english text", async () => {
  const store = makeStore({
    tokens: [{ token: "device-token-1", platform: "android", locale: "en" }],
  });
  let sentTitle = "";
  const deps = makeDeps(store, async (_token, _project, _device, message) => {
    sentTitle = message.title;
    return { ok: true };
  });
  await deliver(makeNotification(), deps);
  assertEquals(sentTitle, "Order updated");
});

Deno.test("a dead token is removed instead of retried", async () => {
  const store = makeStore();
  const deps = makeDeps(store, async () => ({
    ok: false,
    invalidToken: true,
    error: "FCM 404: UNREGISTERED",
  }));
  const result = await deliver(makeNotification(), deps);
  assertEquals(result.failed, 1);
  assertEquals(store.deletedTokens, ["device-token-1"]);
  assertEquals(store.deliveries[0].status, "invalid_token");
});

Deno.test("one broken device does not stop the others", async () => {
  const store = makeStore({
    tokens: [
      { token: "broken", platform: "android", locale: "en" },
      { token: "working", platform: "android", locale: "en" },
    ],
  });
  const deps = makeDeps(store, async (_token, _project, device) =>
    device === "broken"
      ? { ok: false, error: "FCM 500" }
      : { ok: true, messageId: "message-2" }
  );
  const result = await deliver(makeNotification(), deps);
  assertEquals(result.sent, 1);
  assertEquals(result.failed, 1);
  assertEquals(store.deliveries.length, 2);
});

Deno.test("a missing service account is reported, not hidden", async () => {
  const store = makeStore();
  const deps = makeDeps(store);
  const result = await deliver(makeNotification(), {
    ...deps,
    env: (name: string) => (name === "PUSH_WEBHOOK_SECRET" ? "secret" : undefined),
  });
  assertEquals(result.failed, 1);
  assertEquals(result.reason, "service_account_not_configured");
  assertEquals(store.deliveries[0].error, "service_account_not_configured");
});
