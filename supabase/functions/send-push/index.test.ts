// supabase/functions/send-push/index.test.ts
//
// The delivery rules of the Edge Function, tested without a database and
// without sending anything: the store and the sender are injected.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { FcmMessage } from "../_shared/fcm.ts";
import {
  deliver,
  destinationOf,
  handleRequest,
  parseNotification,
  pushImageUrlOf,
  storageHostOf,
  type DeliveryRecord,
  type DeviceToken,
  type PushDeps,
  type PushNotification,
  type PushPreferences,
  type PushStore,
} from "./handler.ts";

/// The host of this project's storage, the only place a push picture may come
/// from.
const STORAGE_HOST = "project.supabase.co";

const PUBLIC_IMAGE =
  `https://${STORAGE_HOST}/storage/v1/object/public/product-images/products/notifications/offer.jpg`;

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
    imageUrl: null,
    destination: null,
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
        : name === "SUPABASE_URL"
        ? `https://${STORAGE_HOST}`
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

Deno.test("a campaign picture and screen come out of the payload", () => {
  const parsed = parseNotification({
    notification_id: "a",
    user_id: "b",
    type: "promo",
    payload: { image_url: PUBLIC_IMAGE, destination: "offers" },
  }, STORAGE_HOST);
  assertEquals(parsed?.imageUrl, PUBLIC_IMAGE);
  assertEquals(parsed?.destination, "offers");
});

Deno.test("a payload without a picture keeps the message plain", () => {
  const parsed = parseNotification({
    notification_id: "a",
    user_id: "b",
    payload: {},
  }, STORAGE_HOST);
  assertEquals(parsed?.imageUrl, null);
  assertEquals(parsed?.destination, null);
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

Deno.test("a customer who did not enable push gets a skipped log row", async () => {
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
  assertEquals(store.deliveries.length, 1);
  assertEquals(store.deliveries[0].status, "skipped");
  assertEquals(store.deliveries[0].error, "push_disabled");
});

Deno.test("a switched off type is not delivered and says so", async () => {
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
  assertEquals(store.deliveries[0].status, "skipped");
  assertEquals(store.deliveries[0].error, "type_disabled");
});

Deno.test("a skip is logged on every device of the customer", async () => {
  const store = makeStore({
    preferences: {
      pushEnabled: true,
      orderStatus: true,
      promo: false,
      loyalty: true,
      system: true,
    },
    tokens: [
      { token: "a", platform: "android", locale: "ar" },
      { token: "b", platform: "ios", locale: "en" },
    ],
  });
  const result = await deliver(makeNotification({ type: "promo" }), makeDeps(store));
  assertEquals(result.reason, "type_disabled");
  assertEquals(store.deliveries.map((row) => row.platform), ["android", "ios"]);
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

Deno.test("the host of the project storage is read from its url", () => {
  assertEquals(storageHostOf(`https://${STORAGE_HOST}`), STORAGE_HOST);
  assertEquals(storageHostOf(`https://${STORAGE_HOST}/`), STORAGE_HOST);
  assertEquals(storageHostOf("not a url"), null);
  assertEquals(storageHostOf(undefined), null);
});

Deno.test("only an anonymously readable picture of this project is kept", () => {
  assertEquals(pushImageUrlOf(PUBLIC_IMAGE, STORAGE_HOST), PUBLIC_IMAGE);
  // Another host: the admin would be handing out a link to somebody else's
  // file, and the phone would fetch it from there.
  assertEquals(
    pushImageUrlOf(
      `https://elsewhere.example/storage/v1/object/public/product-images/a.jpg`,
      STORAGE_HOST,
    ),
    null,
  );
  // A private bucket: the phone has no credential, so the banner would fail.
  assertEquals(
    pushImageUrlOf(
      `https://${STORAGE_HOST}/storage/v1/object/public/avatars/a.jpg`,
      STORAGE_HOST,
    ),
    null,
  );
  // A signed url carries its own token in the query and dies in an hour.
  assertEquals(
    pushImageUrlOf(
      `https://${STORAGE_HOST}/storage/v1/object/sign/avatars/a.jpg?token=abc`,
      STORAGE_HOST,
    ),
    null,
  );
  // Credentials in the url are a secret in the payload.
  assertEquals(
    pushImageUrlOf(
      `https://user:pass@${STORAGE_HOST}/storage/v1/object/public/product-images/a.jpg`,
      STORAGE_HOST,
    ),
    null,
  );
  assertEquals(
    pushImageUrlOf(
      `http://${STORAGE_HOST}/storage/v1/object/public/product-images/a.jpg`,
      STORAGE_HOST,
    ),
    null,
  );
  assertEquals(pushImageUrlOf("", STORAGE_HOST), null);
  assertEquals(pushImageUrlOf(undefined, STORAGE_HOST), null);
  assertEquals(pushImageUrlOf({ url: PUBLIC_IMAGE }, STORAGE_HOST), null);
  // Without a known host nothing is trusted.
  assertEquals(pushImageUrlOf(PUBLIC_IMAGE, null), null);
});

Deno.test("a screen code is kept only when it cannot be a path", () => {
  assertEquals(destinationOf("offers"), "offers");
  assertEquals(destinationOf("  Loyalty  "), "loyalty");
  assertEquals(destinationOf("/orders"), null);
  assertEquals(destinationOf("orders?id=1"), null);
  assertEquals(destinationOf("a".repeat(65)), null);
  assertEquals(destinationOf(null), null);
});

Deno.test("the picture and the screen travel in the message", async () => {
  const store = makeStore();
  const sentMessages: FcmMessage[] = [];
  const deps = makeDeps(store, async (_token, _project, _device, message) => {
    sentMessages.push(message);
    return { ok: true, messageId: "message-1" };
  });
  const result = await deliver(
    makeNotification({ type: "promo", imageUrl: PUBLIC_IMAGE, destination: "offers" }),
    deps,
  );
  assertEquals(result.sent, 1);
  assertEquals(sentMessages.length, 1);
  assertEquals(sentMessages[0].imageUrl, PUBLIC_IMAGE);
  assertEquals(sentMessages[0].data.image_url, PUBLIC_IMAGE);
  assertEquals(sentMessages[0].data.destination, "offers");
});

Deno.test("a plain message sends no picture keys at all", async () => {
  const store = makeStore();
  const sentMessages: FcmMessage[] = [];
  const deps = makeDeps(store, async (_token, _project, _device, message) => {
    sentMessages.push(message);
    return { ok: true };
  });
  await deliver(makeNotification(), deps);
  assertEquals(sentMessages.length, 1);
  assertEquals(sentMessages[0].imageUrl, null);
  assertEquals("image_url" in sentMessages[0].data, false);
  assertEquals("destination" in sentMessages[0].data, false);
});

Deno.test("a request whose payload carries a foreign picture is delivered as text", async () => {
  const store = makeStore();
  const response = await handleRequest(
    new Request("http://localhost/send-push", {
      method: "POST",
      headers: { "x-push-secret": "secret", "Content-Type": "application/json" },
      body: JSON.stringify({
        notification_id: "a",
        user_id: "b",
        type: "promo",
        title_ar: "ar",
        body_ar: "body",
        payload: { image_url: "https://elsewhere.example/a.jpg" },
      }),
    }),
    { ...makeDeps(store), store },
  );
  assertEquals(response.status, 200);
  // The notification is still delivered: a bad picture is a cosmetic loss,
  // not a reason to leave the customer without the message.
  assertEquals(store.deliveries[0].status, "sent");
});
