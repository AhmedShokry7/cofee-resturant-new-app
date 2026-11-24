# Tap isolated sandbox setup

Tap selects sandbox versus live processing by the API key. Test keys and live
keys are separate; the backend must never infer a mode from a URL or Flutter
configuration. The current Edge Functions require an explicit `TAP_ENV` and
check that its `TAP_SECRET_KEY` prefix matches the selected mode.

For an isolated local/staging project, set secrets only in that project's
function environment or a git-ignored local env file:

```dotenv
TAP_ENV=sandbox
TAP_SECRET_KEY=sk_test_REPLACE_WITH_TAP_DASHBOARD_TEST_KEY
TAP_WEBHOOK_URL=https://YOUR-ISOLATED-PROJECT.supabase.co/functions/v1/tap-webhook
TAP_REDIRECT_URL=https://YOUR-ISOLATED-APP.example/payment/return
```

Configure the corresponding webhook endpoint in Tap's **test** environment and
use only the project's test key. Do not copy test values into production or set
`TAP_ENV=production` for this run. For production, configure a separate
deployment with `TAP_ENV=production`, a live key, and its own webhook/redirect
URLs. Never add either environment's secret key to Flutter, Git, or logs.

Local commands, after installing the Supabase CLI and creating a local test env
file, are:

```powershell
supabase functions serve tap-create-charge tap-verify-charge tap-refund tap-webhook --env-file supabase/functions/.env.local
deno test --allow-env --allow-net supabase/functions/tap-refund/index.test.ts supabase/functions/tap-webhook/index.test.ts
```

Required isolated sandbox cases: captured/failed/pending payment, full refund,
multiple partial refunds, duplicate and delayed webhook, invalid hashstring,
Tap API failure and retry, and over-refund rejection. The repository's current
automated tests exercise handler logic with mocked Tap responses; they do not
send requests to Tap. No sandbox credentials or webhook endpoint were present
in this environment, so no provider scenario was executed here.

Tap documentation: [Test and live API keys](https://developers.tap.company/docs/get-started),
[API authentication](https://developers.tap.company/reference/api-endpoint).
