# Resend setup — Auth mail and campaign mail

Two different jobs, two different pipes, one verified sender.

| What | Who sends it | Pipe | Where the key lives |
| --- | --- | --- | --- |
| Sign-in codes, signup confirmation, password reset | **Supabase Auth (GoTrue)** | Custom SMTP → Resend | Supabase → Authentication → Sign In / Up → SMTP settings |
| Campaigns and order messages (the in-app notification) | **Edge Function `send-email`** | Resend REST API (`/emails`) | `supabase secrets set RESEND_API_KEY=...` |

Nothing in this repository holds a Resend key. `RESEND_API_KEY` is a function
secret, the SMTP password is a Supabase secret, and the Flutter app talks to
neither — see [supabase/functions/_shared/resend.ts](../functions/_shared/resend.ts),
which reads the key only inside the Edge Function.

## 0. One prerequisite nothing else works without

**The sending domain is `send.getnewcoffee.com`**, added in Resend on 2026-11-02
(region ap-northeast-1, Tokyo). The parent `getnewcoffee.com` still has to be
registered — measured available at Cloudflare Registrar for $11.17 a year at the
time of writing; nothing was purchased.

Then publish these records in the DNS zone of `getnewcoffee.com`, with the names
exactly as a registrar asks for them (the zone suffix left off):

| Type | Name | Value | TTL |
| --- | --- | --- | --- |
| TXT | `resend._domainkey.send` | `p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCtFzxFD9f7Q2SIisujOB5jG1P1/DR61snZPs814REdi1g9tqWO1Nf4GKP3wfb0Vp6N8xIg5hkwP77r3Q4dAkrVnMybesM0tjaB5ms/3LvbgnAcYdSNCiizs+fAr/xx+0lQTGCpfgnbX8eDAmjXOX2O/6fo4VDQWv5va8OGaRJEhQIDAQAB` | Auto |
| CNAME | `rsend.send` | `rsend-apne1.forge.rmta.net` | Auto |
| CNAME | `send.send` | `send.forge.rmta.net` | Auto |
| TXT | `_dmarc.send` | `v=DMARC1; p=none;` — optional, and cheap protection | Auto |

The TXT under `resend._domainkey` verifies the domain; the two CNAMEs are the
sending path (SPF and the return path) that Resend's newer Forge setup publishes
instead of the old MX record. Press **Verify DNS records** once they resolve.

Until that is green in Resend, every send — Auth or campaign — is refused, and
the campaign side records the refusal verbatim in `engagement.email_deliveries`.
This is the same wall migration 219 hit on 2026-10-31, when the then-proposed
`ofoq.com` was added to Resend and left *Not Started*. That domain is retired:
measured on 2026-11-02, no `ofoq` string exists in `lib/`, `app/admin_app/lib`
or `supabase/functions`, so nothing in the shipped code has to change.

Use a `from` address **on the verified domain itself** for both pipes — to
Resend, `mail@newcoffee.com` is a different domain from `mail@send.newcoffee.com`:
`no-reply@send.getnewcoffee.com` for Auth mail, and `New Coffee <mail@send.getnewcoffee.com>`
for the campaign function's `EMAIL_FROM` secret.

## 1. Auth mail: Custom SMTP with Resend

Supabase → your project → **Authentication → Sign In / Up → SMTP settings**:

| Field | Value |
| --- | --- |
| SMTP host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | your Resend **API key** (`re_...`) |
| Sender email | `no-reply@send.getnewcoffee.com` |
| Sender name | `New Coffee` |

Save, then press **Send test email** and check the inbox and the spam folder.
Resend's own SMTP documentation gives the same five values:
https://resend.com/docs/send-with-supabase-smtp

Why this step is not optional: without Custom SMTP, Auth mail leaves through
Supabase's built-in sender, which is rate-limited to a couple of messages an
hour and is not your domain. A customer waiting for a sign-in code does not get
one.

## 2. Auth templates: paste these files

Supabase → **Authentication → Sign In / Up → Email templates**. For each tab,
replace the Subject and the Body, then Save.

| Dashboard tab | File | Subject to paste |
| --- | --- | --- |
| Magic link | [01_otp_magic_link.html](01_otp_magic_link.html) | `New Coffee — رمز الدخول / Your sign-in code` |
| Confirm signup | [02_confirm_signup.html](02_confirm_signup.html) | `New Coffee — أكّد بريدك / Confirm your e-mail` |
| Reset password | [03_reset_password.html](03_reset_password.html) | `New Coffee — إعادة تعيين كلمة المرور / Reset your password` |

**The Magic link template is what turns the mail into a code.** GoTrue reads the
template to decide the form the message takes: a template containing
`{{ .Token }}` sends a 6-digit code, a template containing
`{{ .ConfirmationURL }}` sends a link. The app's e-mail code screen
(`EmailAuthPage` → `EmailOtpPage`) expects the **code**, so
`01_otp_magic_link.html` carries `{{ .Token }}` and no `{{ .ConfirmationURL }}`
anywhere — adding the link variable would silently turn the customer's code
screen into a wait for a code that never comes.
Confirmed against https://supabase.com/docs/guides/auth/auth-email-passwordless

Code lifetime and the request interval are settings, not template text:
Authentication → **Providers → Email → Email OTP expiration**. The app asks for
six digits, so leave the length at 6; an expiry over 86400 seconds is refused by
the provider to blunt guessing.

The e-mail door itself is already open, measured on this project on 2026-11-02:
`POST /auth/v1/otp` with an address asked in the shape the app asks it
(`create_user: true`, the same the phone path uses) answers with the provider's
own address validation — `validation_failed: invalid format` for a malformed
address and `email_address_invalid` for a blocked one — which means the request
reached the mail step rather than being refused as a disabled provider. The one
answer that is *not* a blocker is easy to misread: `otp_disabled / "Signups not
allowed for otp"` is what the endpoint says when `create_user` is `false` and the
address has no account yet, not when the provider is switched off.

The three templates are Arabic-first with the English name of the app in the
header, and none of the three carries an unsubscribe link: a sign-in code is not
marketing. Campaign mail is where the unsubscribe lives, and it already has one.

## 3. Campaign mail: already built, check the four secrets

The admin panel's campaign → `engagement.notifications` row → the
`tr_notifications_dispatch_email` trigger → `send-email` → Resend path is
deployed and live. Verified on 2026-11-02: `POST /functions/v1/send-email`
answers `401 {"error":"unauthorized"}` — that body is the function's own secret
check, so the function is running and its JWT verification is off, as intended.

Check the secrets with `supabase secrets list` (needs a valid access token), or
set them:

```
supabase secrets set RESEND_API_KEY=re_xxx
supabase secrets set EMAIL_FROM="New Coffee <mail@send.getnewcoffee.com>"
supabase secrets set EMAIL_REPLY_TO="support@send.getnewcoffee.com"   # optional
supabase secrets set EMAIL_WEBHOOK_SECRET=<same value as the Vault secret>
```

`EMAIL_WEBHOOK_SECRET` must equal the `email_webhook_secret` in Vault, because
the database trigger signs each request with it. `core.app_settings.email_function_url`
already holds the function URL in this project — measured 2026-11-02.

## 4. Eligibility: who a campaign may reach

Enforced per recipient inside `send-email`, in this order, and each refusal is
written to `engagement.email_deliveries` so the panel can tell the three apart:

1. no address on `profiles` → `no_address`
2. `notification_preferences.email_enabled` false → `email_disabled`
3. the type switch off (promo / loyalty / order_status / system) → `type_disabled`

`email_enabled` defaults to **false** in migration 219: nobody is mailed until
they say yes. The unsubscribe link in every campaign flips it back to false
through `public.unsubscribe_email`, and RFC 8058 `List-Unsubscribe` +
`List-Unsubscribe-Post` are set on the message, so a one-click unsubscribe in
the mail client is honoured without a session. A customer who unsubscribed stops
receiving campaign mail immediately and keeps receiving order mail only if they
switch the channel on again.

Campaign and Auth mail never share a code path: the customer's
`notification_preferences` row is not consulted by GoTrue, and the Auth templates
carry no unsubscribe header. That separation is deliberate — a reader who
unsubscribes from offers must still get their sign-in code.

## 5. What is not built, and why

- **Scheduling.** No column, RPC or cron exists for a future send time on
  campaigns; delivery is immediate on send. Adding it means a migration, a
  publisher and a requeue path. Say the word and it becomes its own task.
- **A raw HTML body editor.** The campaign mail is assembled from the Arabic /
  English title and body plus the campaign image, with the HTML written in
  `emailHtmlOf` and every value escaped. Admins do not type HTML today.
- **An "e-mail eligible" audience filter.** `admin_send_notification` selects
  its audience by the type switch only, so rows for customers with the mail
  channel off are created and then skipped one by one. The outcome is the same
  — nobody unqualified gets a message — and pruning at selection would need a
  migration for a count the panel can already read from
  `admin_notification_metrics`.
- **Any migration at all in this change.** Nothing here required schema work.

## 6. Two numbers that decide whether any of this reaches a person

Measured against this project on 2026-11-02 through the REST layer:

- rows in `profiles` with a non-null e-mail: **0**
- rows in `notification_preferences`: **0**

An address that never signed up by e-mail or Google is not in `profiles`, and the
mail switch defaults to off, so today a campaign has no eligible recipient at
all. The e-mail code sign-in added here is what puts real addresses in the
database: `identity.handle_new_user()` copies the address of a new account into
`identity.profiles`, and the customer then opts into mail from the notification
settings screen.
