// Supabase Edge Function: send-push — handler
//
// Delivers one in-app notification to the devices of the customer it belongs
// to, through Firebase Cloud Messaging.
//
// The caller is the database, not the app: the trigger
// engagement.dispatch_push_notification() queues the request through pg_net
// when a row is inserted into engagement.notifications. Because the caller
// is not a signed-in customer, the function is deployed with --no-verify-jwt
// and checks a shared secret instead.
//
// The in-app record is the source of truth. This function only delivers it:
// when it fails, the customer still finds the notification in the app, and
// engagement.push_deliveries keeps the reason.
//
// The campaign picture and the screen a tap opens ride inside the `payload`
// column the database already hands over, so neither needs a new column.
//
// Secrets (set them with `supabase secrets set`):
//   PUSH_WEBHOOK_SECRET     - shared with the database trigger (kept in Vault)
//   FIREBASE_SERVICE_ACCOUNT - the service account key file of the Firebase project

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createAccessToken,
  parseServiceAccount,
  sendToToken,
  type FcmMessage,
  type FcmSendResult,
  type ServiceAccount,
} from "../_shared/fcm.ts";
import {
  publicImageUrlOf,
  storageHostOf,
} from "../_shared/storage_url.ts";

/// The notification as the database hands it over.
export type PushNotification = {
  notificationId: string;
  userId: string;
  type: string;
  titleAr: string;
  titleEn: string;
  bodyAr: string;
  bodyEn: string;
  relatedEntityType: string | null;
  relatedEntityId: string | null;
  /// The public picture of the campaign, already checked by [pushImageUrlOf].
  imageUrl: string | null;
  /// The screen the app opens on a tap, as a code the app knows.
  destination: string | null;
};

/// The push switches of one customer.
export type PushPreferences = {
  pushEnabled: boolean;
  orderStatus: boolean;
  promo: boolean;
  loyalty: boolean;
  system: boolean;
};

/// One device that can receive a push.
export type DeviceToken = {
  token: string;
  platform: string;
  locale: string | null;
};

/// One delivery attempt, written to engagement.push_deliveries.
export type DeliveryRecord = {
  notificationId: string | null;
  userId: string;
  platform: string;
  status: "sent" | "failed" | "skipped" | "invalid_token";
  providerMessageId: string | null;
  error: string | null;
};

/// Everything the handler needs from the outside world.
///
/// The store is an interface so the behaviour can be tested without a
/// database, and the fetcher is injected so no request leaves the machine
/// during a test.
export type PushDeps = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  store: PushStore;
  /// Sends one message to one token.
  send: (
    accessToken: string,
    projectId: string,
    token: string,
    message: FcmMessage,
  ) => Promise<FcmSendResult>;
  /// Exchanges the service account for an access token.
  accessToken: (serviceAccount: ServiceAccount) => Promise<string>;
};

/// The database side of the handler.
export type PushStore = {
  readPreferences: (userId: string) => Promise<PushPreferences | null>;
  readTokens: (userId: string) => Promise<DeviceToken[]>;
  recordDelivery: (delivery: DeliveryRecord) => Promise<void>;
  deleteToken: (token: string) => Promise<void>;
};

export type HandleResult = {
  sent: number;
  failed: number;
  skipped: boolean;
  reason?: string;
};

const MAX_TOKENS = 100;

/// The type of the notification decides which switch applies.
function preferenceKeyFor(type: string): keyof PushPreferences | null {
  switch (type) {
    case "order_status":
      return "orderStatus";
    case "promo":
      return "promo";
    case "loyalty":
      return "loyalty";
    case "system":
      return "system";
    default:
      return null;
  }
}

/// Picks the text of the language the device reads.
function textFor(
  locale: string | null,
  arabic: string,
  english: string,
): string {
  const wantsArabic = (locale ?? "").toLowerCase().startsWith("ar");
  const primary = wantsArabic ? arabic : english;
  const secondary = wantsArabic ? english : arabic;
  return primary.trim() || secondary.trim();
}

/// Which picture may travel to a device is a rule the mail channel needs in
/// exactly the same form, so it lives in one shared file. The name the push
/// has always used stays here, so its callers and its tests are untouched.
export const pushImageUrlOf = publicImageUrlOf;
export { storageHostOf };

/// The screen code of a campaign, or null when it is not a usable one.
///
/// The app owns the list of screens it can open; this only keeps a wild string
/// out of the payload so a campaign cannot smuggle a navigation path.
export function destinationOf(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const text = raw.trim().toLowerCase();
  return /^[a-z0-9_-]{1,64}$/.test(text) ? text : null;
}

/// Reads the notification out of the request body.
export function parseNotification(
  body: any,
  allowedImageHost: string | null = null,
): PushNotification | null {
  if (!body || typeof body !== "object") return null;
  const notificationId = body.notification_id ?? body.notificationId;
  const userId = body.user_id ?? body.userId;
  if (typeof notificationId !== "string" || typeof userId !== "string") return null;
  const payload = body.payload && typeof body.payload === "object"
    ? body.payload
    : {};
  return {
    notificationId,
    userId,
    type: typeof body.type === "string" ? body.type : "system",
    titleAr: typeof body.title_ar === "string" ? body.title_ar : "",
    titleEn: typeof body.title_en === "string" ? body.title_en : "",
    bodyAr: typeof body.body_ar === "string" ? body.body_ar : "",
    bodyEn: typeof body.body_en === "string" ? body.body_en : "",
    relatedEntityType:
      typeof body.related_entity_type === "string"
        ? body.related_entity_type
        : null,
    relatedEntityId:
      typeof body.related_entity_id === "string" ? body.related_entity_id : null,
    imageUrl: pushImageUrlOf(payload.image_url, allowedImageHost),
    destination: destinationOf(payload.destination),
  };
}

/// The data payload that travels with the message.
///
/// FCM only accepts strings, so every value is stringified. The app reads the
/// notification id from here to open the right screen, and it re-reads the
/// row from the database, so the text in the payload is only a fallback.
function dataFor(notification: PushNotification): Record<string, string> {
  return {
    notification_id: notification.notificationId,
    type: notification.type,
    title_ar: notification.titleAr,
    title_en: notification.titleEn,
    body_ar: notification.bodyAr,
    body_en: notification.bodyEn,
    related_entity_type: notification.relatedEntityType ?? "",
    related_entity_id: notification.relatedEntityId ?? "",
    // A tap is handled before the app has read the row, so the picture and the
    // screen travel with the message too. An empty value is left out rather
    // than sent as "", so the app cannot read a blank as a real choice.
    ...(notification.imageUrl ? { image_url: notification.imageUrl } : {}),
    ...(notification.destination
      ? { destination: notification.destination }
      : {}),
  };
}

/// The devices a skip is logged against.
///
/// `push_deliveries.platform` only accepts ios, android and web, so a customer
/// without a single registered device is logged on the platform the app
/// registers first. The row is what the admin needs: proof the message was not
/// delivered and why, not a guess about the device.
function skipTargets(tokens: DeviceToken[]): DeviceToken[] {
  return tokens.length > 0
    ? tokens
    : [{ token: "", platform: "android", locale: null }];
}

/// The whole delivery of one notification.
export async function deliver(
  notification: PushNotification,
  deps: PushDeps,
): Promise<HandleResult> {
  const tokens = await deps.store.readTokens(notification.userId);
  const preferences = await deps.store.readPreferences(notification.userId);
  // A customer who never touched the switches has no row at all, and the app
  // registers a device only after the operating system granted notifications,
  // so the token itself is the opt-in. Reading a missing row as "off" is what
  // kept every message from the admin from ever reaching a phone: the switch
  // screen had never been opened, so nothing had been switched on.
  const effective: PushPreferences = preferences ?? {
    pushEnabled: tokens.length > 0,
    orderStatus: true,
    promo: true,
    loyalty: true,
    system: true,
  };

  const preferenceKey = preferenceKeyFor(notification.type);
  // The missing device comes first because it is the fact a sender cannot work
  // around: with no token there is nothing to deliver to, whatever the switches
  // say, and "no_device_token" tells the admin more than "push_disabled" does.
  const skipReason = tokens.length === 0
    ? "no_device_token"
    : !effective.pushEnabled
    ? "push_disabled"
    : preferenceKey !== null && effective[preferenceKey] === false
    ? "type_disabled"
    : null;

  if (skipReason) {
    // A skip is a delivery state of its own, so it is written like one. Without
    // the row the admin reads "no device answered" for a customer who simply
    // switched the messages off.
    for (const device of skipTargets(tokens).slice(0, MAX_TOKENS)) {
      await deps.store.recordDelivery({
        notificationId: notification.notificationId,
        userId: notification.userId,
        platform: device.platform,
        status: "skipped",
        providerMessageId: null,
        error: skipReason,
      });
    }
    return { sent: 0, failed: 0, skipped: true, reason: skipReason };
  }

  const serviceAccount = parseServiceAccount(
    deps.env("FIREBASE_SERVICE_ACCOUNT"),
  );
  if (!serviceAccount) {
    // The delivery cannot be attempted. The reason is written to the log so
    // the missing configuration is visible instead of silent.
    for (const device of tokens.slice(0, MAX_TOKENS)) {
      await deps.store.recordDelivery({
        notificationId: notification.notificationId,
        userId: notification.userId,
        platform: device.platform,
        status: "failed",
        providerMessageId: null,
        error: "service_account_not_configured",
      });
    }
    return {
      sent: 0,
      failed: tokens.length,
      skipped: false,
      reason: "service_account_not_configured",
    };
  }

  let accessToken: string;
  try {
    accessToken = await deps.accessToken(serviceAccount);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    for (const device of tokens.slice(0, MAX_TOKENS)) {
      await deps.store.recordDelivery({
        notificationId: notification.notificationId,
        userId: notification.userId,
        platform: device.platform,
        status: "failed",
        providerMessageId: null,
        error: message,
      });
    }
    return { sent: 0, failed: tokens.length, skipped: false, reason: message };
  }

  let sent = 0;
  let failed = 0;
  for (const device of tokens.slice(0, MAX_TOKENS)) {
    const message = {
      title: textFor(device.locale, notification.titleAr, notification.titleEn),
      body: textFor(device.locale, notification.bodyAr, notification.bodyEn),
      data: dataFor(notification),
      imageUrl: notification.imageUrl,
    };

    const result = await deps.send(
      accessToken,
      serviceAccount.project_id,
      device.token,
      message,
    );

    if (result.ok) {
      sent += 1;
      await deps.store.recordDelivery({
        notificationId: notification.notificationId,
        userId: notification.userId,
        platform: device.platform,
        status: "sent",
        providerMessageId: result.messageId ?? null,
        error: null,
      });
      continue;
    }

    failed += 1;
    if (result.invalidToken) {
      // The token is dead: the app was uninstalled or the data was cleared.
      // Keeping it would send to it again on every notification.
      await deps.store.deleteToken(device.token);
    }
    await deps.store.recordDelivery({
      notificationId: notification.notificationId,
      userId: notification.userId,
      platform: device.platform,
      status: result.invalidToken ? "invalid_token" : "failed",
      providerMessageId: null,
      error: result.error ?? "unknown_error",
    });
  }

  return { sent, failed, skipped: false };
}

/// The Supabase side of the handler.
///
/// The service role key bypasses row level security, so the function reads
/// the rows of every customer it has to deliver to, and writes the log.
export function createSupabaseStore(
  url: string,
  serviceRoleKey: string,
): PushStore {
  const client = createClient(url, serviceRoleKey, {
    auth: { persistSession: false },
  });

  return {
    async readPreferences(userId: string) {
      const { data, error } = await client
        .from("notification_preferences")
        .select("push_enabled, order_status, promo, loyalty, system")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw new Error(`read preferences: ${error.message}`);
      if (!data) return null;
      return {
        pushEnabled: data.push_enabled === true,
        orderStatus: data.order_status !== false,
        promo: data.promo !== false,
        loyalty: data.loyalty !== false,
        system: data.system !== false,
      };
    },

    async readTokens(userId: string) {
      const { data, error } = await client
        .from("device_tokens")
        .select("token, platform, locale")
        .eq("user_id", userId)
        .limit(MAX_TOKENS);
      if (error) throw new Error(`read tokens: ${error.message}`);
      return (data ?? []).map((row: any) => ({
        token: row.token as string,
        platform: (row.platform as string) ?? "android",
        locale: (row.locale as string) ?? null,
      }));
    },

    async recordDelivery(delivery: DeliveryRecord) {
      const { error } = await client.from("push_deliveries").insert({
        notification_id: delivery.notificationId,
        user_id: delivery.userId,
        platform: delivery.platform,
        status: delivery.status,
        provider_message_id: delivery.providerMessageId,
        error: delivery.error,
      });
      if (error) {
        // The log is a diagnostic, never a reason to fail the delivery.
        console.error("push delivery log failed:", error.message);
      }
    },

    async deleteToken(token: string) {
      const { error } = await client
        .from("device_tokens")
        .delete()
        .eq("token", token);
      if (error) console.error("stale token delete failed:", error.message);
    },
  };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function fail(code: string, status: number, detail?: string): Response {
  return jsonResponse({ error: code, detail: detail ?? null }, status);
}

/// The entry point of the function.
export async function handleRequest(
  req: Request,
  deps?: PushDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return fail("method_not_allowed", 405);
  }

  const env = deps?.env ?? ((name: string) => Deno.env.get(name));
  const expected = env("PUSH_WEBHOOK_SECRET") ?? "";
  const provided = req.headers.get("x-push-secret") ?? "";
  if (!expected || provided !== expected) {
    return fail("unauthorized", 401);
  }

  let body: any = null;
  try {
    body = await req.json();
  } catch {
    return fail("invalid_json", 400);
  }

  const notification = parseNotification(
    body,
    storageHostOf(env("SUPABASE_URL")),
  );
  if (!notification) {
    return fail("invalid_payload", 400);
  }

  const url = env("SUPABASE_URL") ?? "";
  const serviceRoleKey = env("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const store =
    deps?.store ??
    createSupabaseStore(url, serviceRoleKey);

  const resolved: PushDeps = {
    env,
    fetch: deps?.fetch ?? fetch,
    store,
    send: deps?.send ?? sendToToken,
    accessToken:
      deps?.accessToken ??
      ((serviceAccount) => createAccessToken(serviceAccount)),
  };

  try {
    const result = await deliver(notification, resolved);
    console.log(
      `push ${notification.notificationId} -> sent=${result.sent} failed=${result.failed} skipped=${result.skipped}`,
    );
    return jsonResponse(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("push delivery failed:", message);
    // The notification itself is already stored, so a failure here is not an
    // error of the caller: the database must not retry it forever.
    return jsonResponse({ sent: 0, failed: 0, skipped: true, reason: message });
  }
}
