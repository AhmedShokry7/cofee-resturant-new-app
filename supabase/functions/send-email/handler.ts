// Supabase Edge Function: send-email — handler
//
// Sends one in-app notification to the e-mail address of the customer it
// belongs to, through Brevo.
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
//   BREVO_API_KEY        - the restricted transactional-email API key
//   EMAIL_FROM           - the verified sender, e.g. "New Coffee <mail@domain>"
//   EMAIL_REPLY_TO       - optional, where a reply goes

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  type BrevoEmail,
  type BrevoResult,
  sendEmail,
} from "../_shared/brevo.ts";
import {
  type ResendEmail,
  type ResendResult,
  sendEmail as sendWithResend,
} from "../_shared/resend.ts";
import { publicImageUrlOf, storageHostOf } from "../_shared/storage_url.ts";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

type AuthHookPayload = {
  user?: { email?: string; user_metadata?: Record<string, unknown> };
  email_data?: {
    token?: string;
    token_hash?: string;
    redirect_to?: string;
    site_url?: string;
    email_action_type?: string;
  };
};

const authEmailTemplates: Record<
  string,
  { subject: string; title: string; text: string }
> = {
  signup: {
    subject: "New Coffee | Confirm your email",
    title: "Confirm your email",
    text: "Enter the code below in the app to finish creating your account.",
  },
  recovery: {
    subject: "New Coffee | Reset your password",
    title: "Reset your password",
    text: "Use the link below to choose a new password.",
  },
  magiclink: {
    subject: "New Coffee | Sign in",
    title: "Sign in to New Coffee",
    text: "Use the one-time code or sign-in link below.",
  },
  email: {
    subject: "New Coffee | Confirm your email",
    title: "Confirm your email",
    text: "Use the code or confirmation link below to verify this address.",
  },
  invite: {
    subject: "New Coffee | You are invited",
    title: "You are invited",
    text: "Use the link below to accept your invitation.",
  },
  email_change: {
    subject: "New Coffee | Confirm your new email",
    title: "Confirm your new email",
    text: "Use the code or link below to confirm this change.",
  },
  reauthentication: {
    subject: "New Coffee | Verify your identity",
    title: "Verify your identity",
    text: "Use this one-time code to verify your identity.",
  },
};

function escapeAuthHtml(value: string): string {
  return value.replace(/[&<>"']/g, (char) =>
    ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[char]!);
}

type EmailDesign = Record<string, string>;
const defaultEmailDesign: EmailDesign = {
  appNameAr: "غيم وسحب",
  appNameEn: "Ghem & Sohob",
  logoUrl: "",
  logoWidth: "160",
  cardRadius: "18",
  layoutStyle: "centered",
  showLogo: "true",
  primaryColor: "#078A75",
  buttonColor: "#078A75",
  otpCodeColor: "#078A75",
  backgroundColor: "#F3F6F5",
  surfaceColor: "#FFFFFF",
  textColor: "#172522",
  footerAr:
    "\u{647}\u{630}\u{647}\u{20}\u{631}\u{633}\u{627}\u{644}\u{629}\u{20}\u{622}\u{644}\u{64a}\u{629}\u{20}\u{645}\u{646}\u{20}\u{4e}\u{65}\u{77}\u{20}\u{43}\u{6f}\u{66}\u{66}\u{65}\u{65}\u{2e}",
  footerEn: "This is an automated message from New Coffee.",
  signupSubjectAr:
    "\u{62a}\u{623}\u{643}\u{64a}\u{62f}\u{20}\u{627}\u{644}\u{628}\u{631}\u{64a}\u{62f}\u{20}\u{627}\u{644}\u{625}\u{644}\u{643}\u{62a}\u{631}\u{648}\u{646}\u{64a}\u{20}\u{7c}\u{20}\u{4e}\u{65}\u{77}\u{20}\u{43}\u{6f}\u{66}\u{66}\u{65}\u{65}",
  signupTitleAr:
    "\u{62a}\u{623}\u{643}\u{64a}\u{62f}\u{20}\u{628}\u{631}\u{64a}\u{62f}\u{643}\u{20}\u{627}\u{644}\u{625}\u{644}\u{643}\u{62a}\u{631}\u{648}\u{646}\u{64a}",
  signupBodyAr:
    "\u{623}\u{62f}\u{62e}\u{644}\u{20}\u{631}\u{645}\u{632}\u{20}\u{627}\u{644}\u{62a}\u{62d}\u{642}\u{642}\u{20}\u{627}\u{644}\u{62a}\u{627}\u{644}\u{64a}\u{20}\u{641}\u{64a}\u{20}\u{627}\u{644}\u{62a}\u{637}\u{628}\u{64a}\u{642}\u{20}\u{644}\u{625}\u{643}\u{645}\u{627}\u{644}\u{20}\u{625}\u{646}\u{634}\u{627}\u{621}\u{20}\u{62d}\u{633}\u{627}\u{628}\u{643}\u{2e}",
  signupBodyEn: "Enter the code below to finish creating your account.",
};

async function readEmailDesign(
  env: (name: string) => string | undefined,
  fetcher: typeof fetch,
): Promise<EmailDesign> {
  const url = env("SUPABASE_URL")?.replace(/\/$/, "");
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return defaultEmailDesign;
  try {
    const response = await fetcher(
      `${url}/rest/v1/email_design_settings?id=eq.default&select=config`,
      { headers: { apikey: key, Authorization: `Bearer ${key}` } },
    );
    if (!response.ok) return defaultEmailDesign;
    const rows = await response.json();
    const stored = Array.isArray(rows) && rows[0]?.config &&
        typeof rows[0].config === "object"
      ? rows[0].config as Record<string, unknown>
      : {};
    const design = Object.fromEntries(
      Object.entries(defaultEmailDesign).map((
        [name, fallback],
      ) => [
        name,
        typeof stored[name] === "string"
          ? (stored[name] as string).slice(0, 2048)
          : fallback,
      ]),
    );
    const appResponse = await fetcher(
      `${url}/rest/v1/app_settings?key=eq.app_design_published&select=value&limit=1`,
      {
        headers: { apikey: key, Authorization: `Bearer ${key}` },
      },
    );
    if (appResponse.ok) {
      const appRows = await appResponse.json();
      const appDesign = Array.isArray(appRows) && appRows[0]?.value &&
          typeof appRows[0].value === "object"
        ? appRows[0].value as Record<string, unknown>
        : {};
      const theme = appDesign["theme"] && typeof appDesign["theme"] === "object"
        ? appDesign["theme"] as Record<string, unknown>
        : {};
      const brand = theme["brand"] && typeof theme["brand"] === "object"
        ? theme["brand"] as Record<string, unknown>
        : {};
      const appLogo = brand["logo_url"];
      if (
        !design.logoUrl && typeof appLogo === "string" &&
        /^https:\/\//i.test(appLogo)
      ) design.logoUrl = appLogo.slice(0, 2048);
      const appNameAr = brand["name_ar"];
      const appNameEn = brand["name_en"];
      if (
        design.appNameAr === defaultEmailDesign.appNameAr &&
        typeof appNameAr === "string"
      ) design.appNameAr = appNameAr.slice(0, 180);
      if (
        design.appNameEn === defaultEmailDesign.appNameEn &&
        typeof appNameEn === "string"
      ) design.appNameEn = appNameEn.slice(0, 180);
    }
    return design;
  } catch {
    return defaultEmailDesign;
  }
}

function emailShellHtml(
  content: string,
  design: EmailDesign,
  direction: "rtl" | "ltr",
): string {
  const safeColor = (name: string, fallback: string) =>
    /^#[0-9a-f]{6}$/i.test(design[name] ?? "") ? design[name] : fallback;
  const logoWidth = Math.max(
    48,
    Math.min(320, Number.parseInt(design.logoWidth ?? "160") || 160),
  );
  const radius = Math.max(
    0,
    Math.min(32, Number.parseInt(design.cardRadius ?? "18") || 0),
  );
  const logo =
    design.showLogo !== "false" && /^https:\/\//i.test(design.logoUrl ?? "")
      ? `<img src="${
        escapeAuthHtml(design.logoUrl)
      }" alt="" width="${logoWidth}" style="max-width:100%;max-height:100px;height:auto;margin:0 auto 18px">`
      : "";
  const appName = direction === "rtl" ? design.appNameAr : design.appNameEn;
  const footer = (direction === "rtl" ? design.footerAr : design.footerEn)
    .replaceAll("{{app_name}}", appName);
  const align = design.layoutStyle === "simple" ? "left" : "center";
  return `<!doctype html><html dir="${direction}"><body style="margin:0;padding:24px;background:${
    safeColor("backgroundColor", "#F3F6F5")
  };font-family:Arial,sans-serif;color:${
    safeColor("textColor", "#172522")
  }"><div style="max-width:560px;margin:auto;padding:28px;background:${
    safeColor("surfaceColor", "#FFFFFF")
  };border-radius:${radius}px;text-align:${align}">${logo}<div style="color:${
    safeColor("primaryColor", "#078A75")
  };font-weight:bold">${
    escapeAuthHtml(appName)
  }</div>${content}<p style="margin-top:26px;color:#73807d;font-size:12px">${
    escapeAuthHtml(footer)
  }</p></div></body></html>`;
}

function replaceTemplate(
  value: string,
  variables: Record<string, string>,
): string {
  return value.replace(
    /\{\{(customer_name|app_name|email|otp)\}\}/g,
    (_, name: string) => variables[name] ?? "",
  );
}

/// Supabase Auth Send Email Hook. Its signed request is verified before any
/// address, token or redirect is used, then the server sends through Brevo.
export async function handleAuthEmailHook(
  req: Request,
  deps: {
    env: (name: string) => string | undefined;
    fetch?: typeof fetch;
    verify?: (
      secret: string,
      body: string,
      headers: Headers,
    ) => AuthHookPayload;
  },
): Promise<Response> {
  if (req.method !== "POST") return fail("method_not_allowed", 405);
  const secret = deps.env("SEND_EMAIL_HOOK_SECRET") ?? "";
  const apiKey = deps.env("BREVO_API_KEY") ?? "";
  const from = deps.env("EMAIL_FROM") ?? "";
  if (!secret || !apiKey || !from) return fail("email_not_configured", 503);

  let payload: AuthHookPayload;
  try {
    const raw = await req.text();
    const verify = deps.verify ??
      ((key, body, headers) =>
        new Webhook(key.replace(/^v1,whsec_/, ""))
          .verify(body, Object.fromEntries(headers)) as AuthHookPayload);
    payload = verify(secret, raw, req.headers);
  } catch {
    return fail("unauthorized", 401);
  }

  const action = payload.email_data?.email_action_type ?? "";
  const fetcher = deps.fetch ?? fetch;
  const design = await readEmailDesign(deps.env, fetcher);
  const language = String(
    payload.user?.user_metadata?.["language"] ??
      payload.user?.user_metadata?.["locale"] ?? "ar",
  ).toLowerCase();
  const arabic = language.startsWith("ar");
  let template = authEmailTemplates[action];
  if (action === "signup") {
    template = {
      subject: arabic ? design.signupSubjectAr : design.signupSubjectEn,
      title: arabic ? design.signupTitleAr : design.signupTitleEn,
      text: arabic ? design.signupBodyAr : design.signupBodyEn,
    };
  }
  const address = payload.user?.email?.trim() ?? "";
  const token = payload.email_data?.token ?? "";
  const tokenHash = payload.email_data?.token_hash ?? "";
  if (!template || !address || !token || !tokenHash) {
    return fail("invalid_auth_email_payload", 400);
  }
  const customerName = String(
    payload.user?.user_metadata?.["full_name"] ??
      payload.user?.user_metadata?.["name"] ?? "",
  ).slice(0, 160);
  const appName = arabic ? design.appNameAr : design.appNameEn;
  const variables = {
    customer_name: customerName,
    app_name: appName,
    email: address,
    otp: token,
  };
  template = {
    subject: replaceTemplate(template.subject, variables),
    title: replaceTemplate(template.title, variables),
    text: replaceTemplate(template.text, variables),
  };
  const otpLabel = arabic ? design.otpLabelAr : design.otpLabelEn;
  const redirect = payload.email_data?.redirect_to ||
    payload.email_data?.site_url || "";
  const link = action !== "signup" && redirect
    ? `${redirect}${redirect.includes("?") ? "&" : "?"}token_hash=${
      encodeURIComponent(tokenHash)
    }&type=${encodeURIComponent(action)}`
    : "";
  const result = await sendEmail(apiKey, {
    from,
    to: address,
    subject: template.subject,
    text: `${template.title}\n\n${template.text}\n\n${token}${
      link ? `\n\n${link}` : ""
    }`,
    html: emailShellHtml(
      `<h1>${escapeAuthHtml(template.title)}</h1><p>${
        escapeAuthHtml(template.text)
      }</p>${
        template.text.includes(token)
          ? ""
          : `<p style="font-size:14px">${
            escapeAuthHtml(otpLabel)
          }</p><p style="font-size:32px;letter-spacing:8px;font-weight:bold;color:${
            /^#[0-9a-f]{6}$/i.test(design.otpCodeColor ?? "")
              ? design.otpCodeColor
              : "#078A75"
          }">${escapeAuthHtml(token)}</p>`
      }${link ? `<p><a href="${escapeAuthHtml(link)}">Open link</a></p>` : ""}`,
      design,
      arabic ? "rtl" : "ltr",
    ),
    replyTo: deps.env("EMAIL_REPLY_TO") ?? null,
  }, fetcher);
  return result.ok
    ? new Response("{}", {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
    : fail("email_delivery_failed", 502);
}

type InvitationRpcResult = {
  ok?: boolean;
  reason?: string;
  invitation_id?: string;
  token?: string;
  email?: string;
  full_name?: string;
  role_code?: string;
  branch_id?: string | null;
  expires_at?: string;
};

export type InvitationEmailDeps = {
  env: (name: string) => string | undefined;
  fetch?: typeof fetch;
  send?: (apiKey: string, email: ResendEmail) => Promise<ResendResult>;
};

const invitationReasons = new Set([
  "invalid_email",
  "invalid_name",
  "unknown_role",
  "owner_only",
  "not_your_branch",
  "unknown_branch",
  "already_invited",
  "already_staff",
]);
const invitationTokenPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function invitationPublishableKey(
  env: (name: string) => string | undefined,
): string {
  const direct = env("SUPABASE_PUBLISHABLE_KEY") ?? env("SUPABASE_ANON_KEY");
  if (direct) return direct;
  try {
    const keys = JSON.parse(env("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
    return typeof keys.default === "string" ? keys.default : "";
  } catch {
    return "";
  }
}

function invitationBaseUrl(value: string | undefined): URL | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (
      url.protocol !== "https:" || url.username || url.password ||
      url.search || url.hash || url.searchParams.has("invite")
    ) return null;
    return url;
  } catch {
    return null;
  }
}

function invitationLink(base: URL, token: string): string {
  const url = new URL(base.toString());
  url.searchParams.set("invite", token);
  return url.toString();
}

function safeInvitationFailure(reason: string): Response {
  return jsonResponse(
    { ok: false, reason },
    reason === "unauthorized" ? 401 : 200,
    invitationCorsHeaders(),
  );
}

/// Creates an invitation through the caller's own permission-checked RPC, then
/// sends the one-time link server-side. The service role is never returned to
/// or used on behalf of the caller for the invitation RPC.
export async function handleInvitationRequest(
  req: Request,
  deps: InvitationEmailDeps = { env: (name) => Deno.env.get(name) },
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: invitationCorsHeaders() });
  }
  if (req.method !== "POST") return safeInvitationFailure("method_not_allowed");

  const env = deps.env;
  const supabaseUrl = env("SUPABASE_URL")?.replace(/\/$/, "") ?? "";
  const apiKey = invitationPublishableKey(env);
  const resendKey = env("RESEND_API_KEY") ?? "";
  const brevoKey = env("BREVO_API_KEY") ?? "";
  const from = env("EMAIL_FROM") ?? "";
  if (!supabaseUrl || !apiKey || (!resendKey && !brevoKey) || !from) {
    return safeInvitationFailure("email_not_configured");
  }

  const accessToken = req.headers.get("Authorization")?.match(
    /^Bearer\s+(.+)$/i,
  )?.[1];
  if (!accessToken) return safeInvitationFailure("unauthorized");

  let body: any;
  try {
    body = await req.json();
  } catch {
    return safeInvitationFailure("invalid_payload");
  }
  if (
    !body || typeof body.email !== "string" ||
    typeof body.full_name !== "string" ||
    typeof body.role_code !== "string" ||
    (body.branch_id !== null && body.branch_id !== undefined &&
      typeof body.branch_id !== "string")
  ) {
    return safeInvitationFailure("invalid_payload");
  }

  // Keep the deployed app's subpath (GitHub Pages hosts it below /admin/).
  // Accept a client URL only when its host matches the browser Origin; native
  // builds use the explicit HTTPS ADMIN_APP_URL secret.
  const originUrl = invitationBaseUrl(req.headers.get("origin") ?? undefined);
  const requestedAppUrl = invitationBaseUrl(body.application_url);
  const sameOriginAppUrl = requestedAppUrl && originUrl &&
      requestedAppUrl.host === originUrl.host
    ? requestedAppUrl
    : null;
  const appUrl = invitationBaseUrl(env("ADMIN_APP_URL")) ??
    sameOriginAppUrl ??
    invitationBaseUrl(req.headers.get("referer") ?? undefined) ?? originUrl;
  if (!appUrl) return safeInvitationFailure("email_not_configured");

  const fetcher = deps.fetch ?? fetch;
  try {
    const authResponse = await fetcher(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: apiKey, Authorization: `Bearer ${accessToken}` },
    });
    if (!authResponse.ok) return safeInvitationFailure("unauthorized");

    // Preserve caller identity and RLS/permission enforcement. Never substitute
    // the service role for this RPC, even though the mailer needs it later.
    const rpcResponse = await fetcher(
      `${supabaseUrl}/rest/v1/rpc/admin_invite_staff`,
      {
        method: "POST",
        headers: {
          apikey: apiKey,
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_email: body.email,
          p_full_name: body.full_name,
          p_role_code: body.role_code,
          p_branch_id: body.branch_id ?? null,
        }),
      },
    );
    if (!rpcResponse.ok) {
      if (rpcResponse.status === 401 || rpcResponse.status === 403) {
        return safeInvitationFailure("permission_denied");
      }
      // PostgREST commonly reports SECURITY DEFINER authorization failures as
      // HTTP 400 with SQLSTATE 42501. Read only the code; never expose details.
      try {
        const error = await rpcResponse.json();
        if (error?.code === "42501") {
          return safeInvitationFailure("permission_denied");
        }
      } catch {
        // Keep all other backend response bodies private.
      }
      return safeInvitationFailure("failed");
    }

    const invitation = await rpcResponse.json() as InvitationRpcResult;
    if (invitation.ok !== true) {
      const reason = typeof invitation.reason === "string" &&
          invitationReasons.has(invitation.reason)
        ? invitation.reason
        : "failed";
      return jsonResponse(
        { ok: false, reason, invitation_id: invitation.invitation_id ?? null },
        200,
        invitationCorsHeaders(),
      );
    }
    if (
      typeof invitation.token !== "string" ||
      !invitationTokenPattern.test(invitation.token) ||
      typeof invitation.email !== "string" ||
      typeof invitation.full_name !== "string"
    ) {
      return safeInvitationFailure("failed");
    }

    const link = invitationLink(appUrl, invitation.token);
    const design = await readEmailDesign(env, fetcher);
    const name = escapeAuthHtml(invitation.full_name);
    const safeLink = escapeAuthHtml(link);
    const title = "دعوة للانضمام إلى فريق العمل | Staff invitation";
    const text =
      `مرحبًا ${invitation.full_name}،\nتمت دعوتك للانضمام إلى فريق العمل. افتح الرابط التالي للتحقق من الدعوة وإكمال إنشاء حسابك:\n${link}\n\nHello ${invitation.full_name},\nYou have been invited to join the staff team. Open this link to verify the invitation and finish setting up your account:\n${link}\n\nالرابط صالح لمرة واحدة ولمدة سبعة أيام. This link is single-use and expires in seven days.`;
    let emailSent = false;
    try {
      const email: ResendEmail = {
          from,
          to: invitation.email,
          subject: title,
          text,
          html: emailShellHtml(
            `<h1>${title}</h1><p>مرحبًا ${name}، تمت دعوتك للانضمام إلى فريق العمل.</p><p>Hello ${name}, you have been invited to join the staff team.</p><p><a href="${safeLink}" style="display:inline-block;padding:12px 20px;background:#078A75;color:#fff;text-decoration:none;border-radius:8px">فتح الدعوة / Open invitation</a></p><p>الرابط صالح لمرة واحدة ولمدة سبعة أيام.<br>This link is single-use and expires in seven days.</p>`,
            design,
            "rtl",
          ),
          replyTo: env("EMAIL_REPLY_TO") ?? null,
        };
      const result = deps.send
        ? await deps.send(resendKey || brevoKey, email)
        : resendKey
        ? await sendWithResend(resendKey, email, fetcher)
        : await sendEmail(brevoKey, email, fetcher);
      emailSent = result.ok;
    } catch {
      emailSent = false;
    }
    return jsonResponse(
      {
        ok: true,
        email_sent: emailSent,
        acceptance_url: link,
        invitation: {
          invitation_id: invitation.invitation_id,
          token: invitation.token,
          email: invitation.email,
          expires_at: invitation.expires_at,
        },
      },
      200,
      invitationCorsHeaders(),
    );
  } catch {
    return safeInvitationFailure("failed");
  }
}

export function invitationCorsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info, x-supabase-api-version",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
  };
}

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
  fullName?: string | null;
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
  send: (apiKey: string, email: BrevoEmail) => Promise<BrevoResult>;
  /// The HMAC of an unsubscribe link.
  unsubscribeToken: (userId: string, secret: string) => Promise<string>;
};

export type MarketingConsentStatus = "granted" | "revoked" | "missing";

export type MarketingConsentCheck = {
  status: MarketingConsentStatus;
};

export type VerifiedEmailCheck = {
  address: string;
  authEmail: string | null;
  verified: boolean;
  matchesProfile: boolean;
} | null;

/// The database side of the handler.
export type EmailStore = {
  readCustomer: (userId: string) => Promise<EmailCustomer | null>;
  readPreferences: (userId: string) => Promise<EmailPreferences | null>;
  recordDelivery: (delivery: EmailDeliveryRecord) => Promise<void>;
  /// Turns the mail gate off, the one thing an unsubscribe link is allowed to
  /// change without a session.
  setEmailDisabled: (userId: string) => Promise<boolean>;
  readMarketingConsent?: (
    userId: string,
    channel: "email",
    purpose: "promotions" | "loyalty_marketing",
  ) => Promise<MarketingConsentCheck>;
  readVerifiedEmail?: (userId: string) => Promise<VerifiedEmailCheck>;
  readMarketingRecipient?: (
    notificationId: string,
  ) => Promise<{ channel: string; purpose: string } | null>;
};

async function marketingChannelSkip(
  store: EmailStore,
  notificationId: string,
): Promise<string | null> {
  if (!store.readMarketingRecipient) return null;
  const recipient = await store.readMarketingRecipient(notificationId);
  if (!recipient) return null;
  return recipient.channel === "email" ? null : "channel_not_targeted";
}

function marketingPurposeFor(
  type: string,
): "promotions" | "loyalty_marketing" | null {
  if (type === "promo") return "promotions";
  if (type === "loyalty") return "loyalty_marketing";
  return null;
}

async function marketingEmailSkipReason(
  store: EmailStore,
  userId: string,
  type: string,
): Promise<string | null> {
  const purpose = marketingPurposeFor(type);
  if (!purpose) return null;
  if (!store.readMarketingConsent) return "marketing_consent_required";
  const check = await store.readMarketingConsent(userId, "email", purpose);
  if (check.status !== "granted") {
    return check.status === "revoked"
      ? "marketing_consent_revoked"
      : "marketing_consent_required";
  }
  const verified = store.readVerifiedEmail
    ? await store.readVerifiedEmail(userId)
    : null;
  const verifiedOk = verified !== null && verified.verified &&
    verified.matchesProfile;
  return verifiedOk ? null : "email_not_verified";
}

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
  variables: Record<string, string> = {},
): { subject: string; body: string } {
  return {
    subject: replaceTemplate(
      textOf(language, notification.titleAr, notification.titleEn),
      variables,
    ),
    body: replaceTemplate(
      textOf(language, notification.bodyAr, notification.bodyEn),
      variables,
    ),
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
  design: EmailDesign = defaultEmailDesign,
  customerName = "",
  address = "",
): string {
  const appName = wantsArabic(language) ? design.appNameAr : design.appNameEn;
  const content = emailContentOf(notification, language, {
    customer_name: customerName,
    app_name: appName,
    email: address,
  });
  const rtl = wantsArabic(language);
  const image = notification.imageUrl
    ? `<p style="margin:16px 0"><img src="${
      escapeHtml(notification.imageUrl)
    }" alt="" width="560" style="max-width:100%;border-radius:12px;display:block"></p>`
    : "";
  const heading =
    `<h1 style="font-family:system-ui,sans-serif;font-size:18px;margin:0 0 8px">${
      escapeHtml(content.subject)
    }</h1>`;
  const paragraph =
    `<p style="font-family:system-ui,sans-serif;font-size:15px;line-height:1.6;margin:0;white-space:pre-wrap">${
      escapeHtml(content.body)
    }</p>`;
  const footer =
    `<p style="font-family:system-ui,sans-serif;font-size:12px;color:#6b7280;margin:24px 0 0">` +
    (rtl
      ? `<a href="${escapeHtml(unsubscribeUrl)}">إيقاف رسائل البريد</a>`
      : `<a href="${escapeHtml(unsubscribeUrl)}">Stop these e-mails</a>`) +
    `</p>`;
  return emailShellHtml(
    heading + image + paragraph + footer,
    design,
    rtl ? "rtl" : "ltr",
  );
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

  const marketingSkip =
    (await marketingChannelSkip(store, notification.notificationId)) ??
      await marketingEmailSkipReason(
        store,
        notification.userId,
        notification.type,
      );
  if (marketingSkip) {
    await store.recordDelivery({
      notificationId: notification.notificationId,
      userId: notification.userId,
      status: "skipped",
      error: marketingSkip,
    });
    return { sent: 0, failed: 0, skipped: true, reason: marketingSkip };
  }

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

  const apiKey = deps.env("BREVO_API_KEY") ?? "";
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
  const design = await readEmailDesign(deps.env, deps.fetch);
  const token = await deps.unsubscribeToken(notification.userId, secret);
  const appName = wantsArabic(customer!.language)
    ? design.appNameAr
    : design.appNameEn;
  const vars = {
    customer_name: customer!.fullName ?? "",
    app_name: appName,
    email: address,
  };
  const content = emailContentOf(notification, customer!.language, vars);
  const unsubscribe = unsubscribeUrlOf(
    requestUrl,
    notification.userId,
    token,
  );

  const email: BrevoEmail = {
    from,
    to: address,
    subject: content.subject,
    text: `${content.subject}\n\n${content.body}\n\n${unsubscribe}`,
    html: emailHtmlOf(
      notification,
      customer!.language,
      unsubscribe,
      design,
      customer!.fullName ?? "",
      address,
    ),
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
      '<html><body dir="rtl"><p>رابط غير صالح</p></body></html>',
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
    `<html><body dir="${
      arabic ? "rtl" : "ltr"
    }"><p>${message}</p></body></html>`,
    {
      status: done ? 200 : 404,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    },
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
        .select("email, language, full_name")
        .eq("id", userId)
        .maybeSingle();
      if (error) throw new Error(`read customer: ${error.message}`);
      if (!data) return null;
      return {
        address: (data.email ?? "").trim(),
        language: (data.language as string | null) ?? null,
        fullName: (data.full_name as string | null) ?? null,
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

    async readMarketingRecipient(notificationId) {
      const { data, error } = await (client as any)
        .schema("marketing")
        .from("campaign_recipients")
        .select("channel, purpose")
        .eq("notification_id", notificationId)
        .maybeSingle();
      if (error || !data) return null;
      return { channel: data.channel, purpose: data.purpose };
    },

    async readMarketingConsent(userId, channel, purpose) {
      const { data, error } = await (client as any)
        .schema("marketing")
        .from("consent_states")
        .select("status")
        .eq("user_id", userId)
        .eq("channel", channel)
        .eq("purpose", purpose)
        .maybeSingle();
      if (error) return { status: "missing" as const };
      if (!data) return { status: "missing" as const };
      return { status: data.status === "granted" ? "granted" : "revoked" };
    },

    async readVerifiedEmail(userId: string) {
      const { data: profileData, error: profileError } = await client
        .from("profiles")
        .select("email")
        .eq("id", userId)
        .maybeSingle();
      if (profileError || !profileData) return null;
      const profileEmail = ((profileData as any).email ?? "").trim();
      try {
        const { data: userData, error: userError } = await (client as any).auth
          .admin.getUserById(userId);
        if (userError || !userData?.user) return null;
        const authEmail = ((userData.user.email ?? "") as string).trim();
        const confirmed = (userData.user as any).email_confirmed_at != null;
        return {
          address: profileEmail,
          authEmail: authEmail || null,
          verified: confirmed,
          matchesProfile:
            authEmail.toLowerCase() === profileEmail.toLowerCase() &&
            profileEmail !== "",
        };
      } catch {
        return null;
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

function jsonResponse(
  body: unknown,
  status = 200,
  headers: HeadersInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...Object.fromEntries(new Headers(headers)),
    },
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

  const store = deps?.store ??
    createSupabaseStore(
      env("SUPABASE_URL") ?? "",
      env("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

  const resolved: EmailDeps = {
    env,
    fetch: deps?.fetch ?? fetch,
    store,
    send: deps?.send ??
      ((apiKey, email) => sendEmail(apiKey, email, deps?.fetch ?? fetch)),
    unsubscribeToken: deps?.unsubscribeToken ??
      ((userId, secret) => unsubscribeTokenFor(userId, secret)),
  };

  try {
    const result = await deliverEmail(notification, resolved, req.url);
    console.log(
      `email ${notification.notificationId} -> sent=${result.sent} failed=${result.failed} skipped=${
        result.skipped ? 1 : 0
      }`,
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
