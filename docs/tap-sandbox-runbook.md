# Tap Sandbox Preparation

This runbook prepares the local Edge Function for Tap webhooks. No command
below has been run against the remote Supabase project, and no function has
been deployed.

## Local verification

Run the isolated webhook tests:

```powershell
deno test --allow-env supabase\functions\tap-webhook\index.test.ts
```

The customer/order in `supabase/functions/tap-webhook/fixtures.ts` are
synthetic in-memory fixtures. They do not create Supabase records, use real
customer data, or call a payment endpoint. The webhook tests simulate a
trusted payment transaction and confirm signature rejection, duplicate
delivery, amount/currency checks, and order reference matching.

The Flutter payment-flow regression suite is:

```powershell
flutter test --no-pub test/card_payment_cubit_test.dart test/card_payment_page_test.dart test/checkout_payment_flow_test.dart
```

## Secret handling

The Edge Functions read the backend secret using `Deno.env.get("TAP_SECRET_KEY")`
through `tapSecretKey()`. It is never a Dart define or mobile-app setting.

After receiving a Tap **Test** Secret Key, put it in an ignored local file
named `supabase/.env.tap-sandbox` (one line: `TAP_SECRET_KEY=...`). Do not
commit or print that file. When a remote secrets update is separately
approved, use:

```powershell
supabase secrets set --env-file supabase/.env.tap-sandbox --project-ref webzzasosevzymftgszn
```

Configure the Tap dashboard webhook URL as
`https://webzzasosevzymftgszn.supabase.co/functions/v1/tap-webhook` after the
function has been deployed and the remote JWT setting has been approved.

## Deployment command, not executed

The local `supabase/config.toml` sets `verify_jwt = false` only for
`tap-webhook`. The handler verifies Tap's HMAC `hashstring` before looking up
or changing any transaction, order, or subscription.

After separate approval to deploy:

```powershell
supabase functions deploy tap-webhook --project-ref webzzasosevzymftgszn
```

That deployment must be followed by a no-auth gateway probe (expect a
handler-level response, not the Supabase gateway's JWT 401), then signed
Tap webhook tests. Deploying `tap-create-charge` or `tap-verify-charge` is a
separate action and requires `TAP_SECRET_KEY` first.
