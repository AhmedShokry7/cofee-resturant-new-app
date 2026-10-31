// Supabase Edge Function: send-email — handler
//
// Sends one in-app notification to the e-mail address of the customer it
// belongs to, through Resend.
//
// The caller is the database, not the app: the trigger
// engagement.dispatch_email_notification() queues the request through pg_net
// when a row is inserted into engagement.notifications, exactly like the push
// trigger does. Because the caller is not a signed-in customer, the function
// is deployed with --no-verify-jwt and checks a shared secret instead.
//
// The in-app record stays the source of truth. When the mail cannot go out the
// customer still finds the message in the app and engagement.email_deliveries
// keeps the reason.
//
// Nothing about a customer is written to the console: no address, no provider
// key. The log line carries the notification id and the counts only.
//
// Secrets (set them with `supabase secrets set`):
//   EMAIL_WEBHOOK_SECRET - shared with the database trigger (kept in Vault too)
//   RESEND_API_KEY       - the API key of the Resend project
//   EMAIL_FROM           - the verified sender, e.g. "New Coffee <mail@domain>"
//   EMAIL_REPLY_TO       - optional, where a reply goes

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  sendEmail,
  type ResendEmail,
  type ResendResult,
} from "../_shared/resend.ts";
import { publicImageUrlOf, storageHostOf } from "../_shared/storage_url.ts";

/// The notification as the database hands it over.
export type EmailNotification = {
  notificationId: string;
  userId: string;
  type: string;
  titleAr: string;
  titleEn: string;
  bodyAr: string;
  bodyEn: string;
  /// The public picture of the campaign, checked by [publicImageUrlOf].
  imageUrl: string | null;
};

/// The mail switches of one customer.
///
/// [emailEnabled] is the master gate of this channel and it is separate from
/// the push gate on purpose: a customer can want the order receipts in the
/// mailbox and the promos nowhere.
export type EmailPreferences = {
  emailEnabled: boolean;
  orderStatus: boolean;
  promo: boolean;
  loyalty: boolean;
  system: boolean;
};

/// Where one customer is reachable by mail.
export type EmailCustomer = {
  address: string;
  language: string | null;
};

/// One delivery attempt, written to engagement.email_deliveries.
export type EmailDeliveryRecord = {
  notificationId: string | null;
  userId: string;
  status: "sent" | "failed" | "skipped";
  error: string | null;
};

/// Everything the handler needs from the outside world.
export type EmailDeps = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  store: EmailStore;
  /// Hands one message to the provider.
  send: (apiKey: string, email: ResendEmail) => Promise<ResendResult>;
  /// The HMAC of an unsubscribe link.
  unsubscribeToken: (userId: string, secret: string) => Promise<string>;
};

/// The database side of the handler.
export type EmailStore = {
  readCustomer: (userId: string) => Promise<EmailCustomer | null>;
  readPreferences: (userId: string) => Promise<EmailPreferences | null>;
  recordDelivery: (delivery: EmailDeliveryRecord) => Promise<void>;
  /// Turns the mail gate off, the one thing an unsubscribe link is allowed to
  /// change without a session.
  setEmailDisabled: (userId: string) => Promise<boolean>;
};

export type EmailResult = {
  sent: number;
  failed: number;
  skipped: boolean;
  reason?: string;
};

/// Reads the notification out of the request body.
export function parseEmailNotification(
  body: any,
  allowedImageHost: string | null = null,
): EmailNotification | null {
  if (!body || typeof body !== "object") return null;
  const notificationId = body.notification_id ?? body.notificationId;
  const userId = body.user_id ?? body.userId;
  if (typeof notificationId !== "string" || typeof userId !== "string") {
    return null;
  }
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
    imageUrl: publicImageUrlOf(payload.image_url, allowedImageHost),
  };
}

/// The type of the notification decides which switch applies.
function preferenceKeyFor(type: string): keyof EmailPreferences | null {
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

/// True when the customer reads Arabic.
function wantsArabic(language: string | null): boolean {
  return (language ?? "").toLowerCase().startsWith("ar");
}

/// The text of the language the customer reads, with the other one as the
/// fallback so a half-filled campaign still sends something readable.
function textOf(
  language: string | null,
  arabic: string,
  english: string,
): string {
  const [primary, secondary] = wantsArabic(language)
    ? [arabic, english]
    : [english, arabic];
  return primary.trim() || secondary.trim();
}

/// The only copy of a notification an address gets: the customer's language.
/// The other language is not appended, because a reader that did not ask for
/// it is noise in a mailbox.
export function emailContentOf(
  notification: EmailNotification,
  language: string | null,
): { subject: string; body: string } {
  return {
    subject: textOf(language, notification.titleAr, notification.titleEn),
    body: textOf(language, notification.bodyAr, notification.bodyEn),
  };
}

/// The HTML text of a value, so a title an admin wrote cannot open a tag.
function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/// The body of the message.
///
/// The picture is the same validated public URL the push shows, and it is left
/// out entirely when the campaign has none. A mail client cannot run scripts
/// from here, but it can still be fed a URL by an admin, so only the storage
/// objects of this project pass.
export function emailHtmlOf(
  notification: EmailNotification,
  language: string | null,
  unsubscribeUrl: string,
): string {
  const content = emailContentOf(notification, language);
  const rtl = wantsArabic(language);
  const image = notification.imageUrl
    ? `<p style="margin:16px 0"><img src="${escapeHtml(notification.imageUrl)}" alt="" width="560" style="max-width:100%;border-radius:12px;display:block"></p>`
    : "";
  const heading = `<h1 style="font-family:system-ui,sans-serif;font-size:18px;margin:0 0 8px">${
    escapeHtml(content.subject)
  }</h1>`;
  const paragraph = `<p style="font-family:system-ui,sans-serif;font-size:15px;line-height:1.6;margin:0;white-space:pre-wrap">${
    escapeHtml(content.body)
  }</p>`;
  const footer =
    `<p style="font-family:system-ui,sans-serif;font-size:12px;color:#6b7280;margin:24px 0 0">` +
    (rtl
      ? `<a href="${escapeHtml(unsubscribeUrl)}">إيقاف رسائل البريد</a>`
      : `<a href="${escapeHtml(unsubscribeUrl)}">Stop these e-mails</a>`) +
    `</p>`;
  return `<!doctype html><html dir="${rtl ? "rtl" : "ltr"}"><body style="margin:0;padding:24px;background:#f6f7f5">` +
    `<div style="max-width:600px;margin:0 auto;background:#ffffff;border-radius:16px;padding:24px">` +
    heading + image + paragraph + footer + `</div></body></html>`;
}

/// The hex HMAC-SHA256 of a user id.
///
/// The unsubscribe link is clicked without a session, so it has to carry its
/// own proof that it was made by this server for that customer. The secret
/// never appears in the link; only its digest over the user id does, which is
/// useless for any other customer.
export async function unsubscribeTokenFor(
  userId: string,
  secret: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(userId),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/// The link a reader is sent. It is the address of this function, so one
/// deployment serves both the delivery and the unsubscribe.
export function unsubscribeUrlOf(
  requestUrl: string,
  userId: string,
  token: string,
): string {
  const url = new URL(requestUrl);
  url.pathname = "/functions/v1/send-email/unsubscribe";
  url.search = new URLSearchParams({ user_id: userId, token }).toString();
  return url.toString();
}

/// True when two digests are equal, without leaking which byte differs.
function tokensEqual(a: string, b: string): boolean {
  if (a.length !== b.length || a.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/// The whole delivery of one notification.
export async function deliverEmail(
  notification: EmailNotification,
  deps: EmailDeps,
  requestUrl: string,
): Promise<EmailResult> {
  const store = deps.store;
  const customer = await store.readCustomer(notification.userId);
  const address = customer?.address.trim() ?? "";
  const preferences: EmailPreferences =
    (await store.readPreferences(notification.userId)) ?? {
      emailEnabled: false,
      orderStatus: true,
      promo: true,
      loyalty: true,
      system: true,
    };

  const preferenceKey = preferenceKeyFor(notification.type);
  const skipReason = !address
    ? "no_address"
    : preferences.emailEnabled !== true
    ? "email_disabled"
    : preferenceKey !== null && preferences[preferenceKey] === false
    ? "type_disabled"
    : null;

  if (skipReason) {
    // A skip is a delivery state of its own, so the admin can tell a customer
    // who switched the mail off from a send that broke.
    await store.recordDelivery({
      notificationId: notification.notificationId,
      userId: notification.userId,
      status: "skipped",
      error: skipReason,
    });
    return { sent: 0, failed: 0, skipped: true, reason: skipReason };
  }

  const apiKey = deps.env("RESEND_API_KEY") ?? "";
  const from = deps.env("EMAIL_FROM") ?? "";
  if (!apiKey || !from) {
    await store.recordDelivery({
      notificationId: notification.notificationId,
      userId: notification.userId,
      status: "failed",
      error: "email_not_configured",
    });
    return {
      sent: 0,
      failed: 1,
      skipped: false,
      reason: "email_not_configured",
    };
  }

  const secret = deps.env("EMAIL_WEBHOOK_SECRET") ?? "";
  const token = await deps.unsubscribeToken(notification.userId, secret);
  const content = emailContentOf(notification, customer!.language);
  const unsubscribe = unsubscribeUrlOf(
    requestUrl,
    notification.userId,
    token,
  );

  const email: ResendEmail = {
    from,
    to: address,
    subject: content.subject,
    text: `${content.subject}\n\n${content.body}\n\n${unsubscribe}`,
    html: emailHtmlOf(notification, customer!.language, unsubscribe),
    replyTo: deps.env("EMAIL_REPLY_TO") ?? null,
    // RFC 8058: a reader that presses "unsubscribe" once is off, without
    // visiting a page and without a session. The link is the same one the
    // body shows, so the two can never disagree.
    headers: {
      "List-Unsubscribe": `<${unsubscribe}>`,
      "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
    },
  };

  const result = await deps.send(apiKey, email);
  if (result.ok) {
    await store.recordDelivery({
      notificationId: notification.notificationId,
      userId: notification.userId,
      status: "sent",
      error: null,
    });
    return { sent: 1, failed: 0, skipped: false };
  }

  await store.recordDelivery({
    notificationId: notification.notificationId,
    userId: notification.userId,
    status: "failed",
    error: result.error ?? "unknown_error",
  });
  return { sent: 0, failed: 1, skipped: false, reason: result.error };
}

/// The unsubscribe route: a click from a mail client, with no session.
export async function handleUnsubscribe(
  req: Request,
  deps: Pick<EmailDeps, "env" | "store" | "unsubscribeToken">,
): Promise<Response> {
  const url = new URL(req.url);
  const userId = url.searchParams.get("user_id") ?? "";
  const token = url.searchParams.get("token") ?? "";
  const secret = deps.env("EMAIL_WEBHOOK_SECRET") ?? "";

  const valid = /^[0-9a-f-]{36}$/i.test(userId) &&
    secret.length > 0 &&
    tokensEqual(token, await deps.unsubscribeToken(userId, secret));
  if (!valid) {
    return new Response(
      "<html><body dir=\"rtl\"><p>رابط غير صالح</p></body></html>",
      { status: 400, headers: { "Content-Type": "text/html; charset=utf-8" } },
    );
  }

  const done = await deps.store.setEmailDisabled(userId);
  const arabic = wantsArabic(
    (await deps.store.readCustomer(userId))?.language ?? null,
  );
  const message = done
    ? arabic
      ? "تم إيقاف رسائل البريد لهذا الحساب."
      : "E-mails are off for this account."
    : arabic
    ? "لم يتم العثور على الحساب."
    : "That account was not found.";
  return new Response(
    `<html><body dir="${arabic ? "rtl" : "ltr"}"><p>${message}</p></body></html>`,
    { status: done ? 200 : 404, headers: { "Content-Type": "text/html; charset=utf-8" } },
  );
}

/// The Supabase side of the handler.
///
/// The service role key bypasses row level security, which is what a delivery
/// needs: the row of the customer is read without their session, and the log
/// is written without one. The address comes from the profile the customer
/// signed up with.
export function createSupabaseStore(
  url: string,
  serviceRoleKey: string,
): EmailStore {
  const client = createClient(url, serviceRoleKey, {
    auth: { persistSession: false },
  });

  return {
    async readCustomer(userId: string) {
      const { data, error } = await client
        .from("profiles")
        .select("email, language")
        .eq("id", userId)
        .maybeSingle();
      if (error) throw new Error(`read customer: ${error.message}`);
      if (!data) return null;
      return {
        address: (data.email ?? "").trim(),
        language: (data.language as string | null) ?? null,
      };
    },

    async readPreferences(userId: string) {
      const { data, error } = await client
        .from("notification_preferences")
        .select("email_enabled, order_status, promo, loyalty, system")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw new Error(`read preferences: ${error.message}`);
      if (!data) return null;
      return {
        emailEnabled: data.email_enabled === true,
        orderStatus: data.order_status !== false,
        promo: data.promo !== false,
        loyalty: data.loyalty !== false,
        system: data.system !== false,
      };
    },

    async recordDelivery(delivery: EmailDeliveryRecord) {
      const { error } = await client.from("email_deliveries").insert({
        notification_id: delivery.notificationId,
        user_id: delivery.userId,
        status: delivery.status,
        error: delivery.error,
      });
      if (error) {
        // The log is a diagnostic, never a reason to fail the delivery.
        console.error("email delivery log failed:", error.message);
      }
    },

    async setEmailDisabled(userId: string) {
      // A definer function, because the view of the preferences is read-only
      // for anything that has no session.
      const { data, error } = await client.rpc("unsubscribe_email", {
        p_user_id: userId,
      });
      if (error) {
        console.error("email unsubscribe failed:", error.message);
        return false;
      }
      return data === true;
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
export async function handleEmailRequest(
  req: Request,
  deps?: Partial<EmailDeps>,
): Promise<Response> {
  if (req.method !== "POST") {
    return fail("method_not_allowed", 405);
  }

  const env = deps?.env ?? ((name: string) => Deno.env.get(name));
  const expected = env("EMAIL_WEBHOOK_SECRET") ?? "";
  const provided = req.headers.get("x-email-secret") ?? "";
  if (!expected || provided !== expected) {
    return fail("unauthorized", 401);
  }

  let body: any = null;
  try {
    body = await req.json();
  } catch {
    return fail("invalid_json", 400);
  }

  const notification = parseEmailNotification(
    body,
    storageHostOf(env("SUPABASE_URL")),
  );
  if (!notification) {
    return fail("invalid_payload", 400);
  }

  const store =
    deps?.store ??
    createSupabaseStore(
      env("SUPABASE_URL") ?? "",
      env("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

  const resolved: EmailDeps = {
    env,
    fetch: deps?.fetch ?? fetch,
    store,
    send:
      deps?.send ??
      ((apiKey, email) => sendEmail(apiKey, email, deps?.fetch ?? fetch)),
    unsubscribeToken:
      deps?.unsubscribeToken ?? ((userId, secret) => unsubscribeTokenFor(userId, secret)),
  };

  try {
    const result = await deliverEmail(notification, resolved, req.url);
    console.log(
      `email ${notification.notificationId} -> sent=${result.sent} failed=${result.failed} skipped=${result.skipped ? 1 : 0}`,
    );
    return jsonResponse(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("email delivery failed:", message);
    // The notification itself is already stored, so a failure here is not an
    // error of the caller: the database must not retry it forever.
    return jsonResponse({ sent: 0, failed: 0, skipped: true, reason: message });
  }
}
