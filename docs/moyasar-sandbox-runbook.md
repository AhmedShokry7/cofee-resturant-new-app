# Moyasar sandbox checkout

The app can use Moyasar's Flutter credit-card SDK for card entry and 3-D Secure.
Supabase prices each attempt from the order or subscription, creates its
payment record, and verifies the payment with Moyasar before updating the
order. The secret key stays in Supabase Edge Function Secrets.

## Sandbox setup

In the Moyasar dashboard, stay in **Test Environment**. In the project's
Supabase **Edge Function Secrets**, add:

```text
MOYASAR_MODE=sandbox
MOYASAR_SECRET_KEY=<Moyasar test secret key>
```

The key must start with `sk_test_`. Never put it in `.env`, Flutter defines,
source files, or chat. Deploy `moyasar-prepare-payment` and
`moyasar-verify-payment` from this project with JWT verification enabled.

For a local app run, `.env` can contain the public key and provider switch:

```text
USE_MOYASAR=true
MOYASAR_PUBLISHABLE_KEY=pk_test_...
```

The local Flutter config generator only passes a `pk_test_` key to the app
when `USE_MOYASAR=true`. Keep the existing Supabase URL and publishable key in
the same `.env` file. The regular Tap integration remains selected when
`USE_MOYASAR=false` or the variable is unset.

## Try a payment

Run the app with its usual **new_cofee (Supabase)** launch profile, create a
normal development order, choose an online card method, and use one of the
current Moyasar sandbox cards from the [official test-card guide](https://docs.moyasar.com/guides/card-payments/test-cards).
The SDK handles the card form and 3-D Secure step. The app accepts success only
after the `moyasar-verify-payment` Edge Function confirms payment ID, amount,
currency, and paid status with Moyasar.

Do not test with a live card or a live key. Moving to production needs a
separate review of the live account, API key, allowed server IPs, payment
methods, callback setup, and deployment configuration.
