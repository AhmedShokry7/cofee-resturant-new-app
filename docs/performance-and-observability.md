# Performance, load testing, and production monitoring

## Android and iOS release setup

Android's Gradle application ID (`com.example.new_coffee`) matches the Firebase Android client in `android/app/google-services.json`. The iOS target is not production-ready yet: its current Bundle ID is the Xcode template value `com.example.newCofee`, and this Firebase project has no iOS app configuration in the repository. The app initializes Firebase on iOS from the native `GoogleService-Info.plist`; `lib/firebase_options.dart` intentionally has no guessed iOS options. Until an iOS app is registered and the plist is installed, the guarded Firebase initialization and push setup cannot work on iOS.

Before the first iOS release, the owner needs to choose the permanent reverse-domain Bundle ID, register that exact ID as an iOS app in Firebase, add its `GoogleService-Info.plist` to `ios/Runner`, and update the Runner and RunnerTests bundle identifiers. Then enable Push Notifications for the App ID in Apple Developer, configure the APNs authentication key in Firebase Cloud Messaging, and enable the Push Notifications capability for the Xcode Runner target with the correct signing team. The iOS `Info.plist` already declares `remote-notification` background mode. Build and test on a signed physical iPhone; a simulator or this Windows environment cannot verify APNs delivery. Do not copy Android Firebase values into the iOS plist.

## What this repository can and cannot prove

The customer Flutter app uses lazy `BlocProvider` instances. Opening the app does not construct every feature cubit. A restored branch used to trigger the branch coordinator to construct several branch-aware cubits, each of which then reloaded after its initial load. Their providers now receive the branch already selected when each cubit is first created, avoiding that duplicate initial query. The home, search, cart, and catalogue features still fetch data when they are first needed.

The repository cannot establish production capacity by itself. No load test proves “one million users” without the actual Supabase project, plan, data volume, deployment region, traffic pattern, and an agreed concurrency target. Run the script below only against a dedicated staging project, first at low concurrency and then in steps. It exercises public branch and category reads; it does not test sign-in, personalized queries, order placement, payment, Edge Functions, FCM delivery, or Realtime fan-out.

The connected Supabase project was checked on 2026-11-08: database size was 32 MB, total index size 6.5 MB, and reported table/index cache hit rates were 1.00. `supabase db lint --linked` reported no schema errors, and the application schemas checked had RLS enabled on every ordinary table. These are useful health snapshots, not a concurrency or million-user capacity result.

## Staging load test

Install [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/), then set the staging URL and **publishable/anon key** in the current shell. Never use a service-role key. The script refuses to run unless the explicit staging confirmation is present.

```powershell
$env:SUPABASE_URL = 'https://<staging-project>.supabase.co'
$env:SUPABASE_ANON_KEY = '<staging-publishable-key>'
$env:LOAD_TEST_CONFIRM = 'staging-only'
k6 run tools/loadtest/supabase_public.js
```

Default stages ramp from 10 to 100 virtual users over eight minutes. To change them, use `K6_STAGES` as comma-separated `duration:vus` steps, for example `30s:5,2m:25,2m:50,30s:0`. Start lower than the expected target. Record the k6 summary with the test date, Supabase compute size, region, and deployed migration version. Stop if errors increase, database CPU/IO saturates, connection pressure grows, or latency becomes unstable. The script thresholds (1% errors, p95 800 ms, p99 2 s) are initial guardrails, not a capacity guarantee.

## Supabase database and API monitoring

During and after each staging run, capture the Supabase Dashboard metrics for CPU, memory, disk I/O, database connections/pooler use, API request latency/errors, and Realtime connections. Inspect Performance Advisor and the slow-query view before adding indexes. Compare the same window against the baseline before increasing virtual users.

If `pg_stat_statements` is enabled, run this in the SQL editor to find queries consuming the most database time:

```sql
select
  queryid,
  calls,
  round(total_exec_time::numeric, 1) as total_exec_ms,
  round(mean_exec_time::numeric, 1) as mean_exec_ms,
  rows,
  left(query, 240) as query_sample
from pg_stat_statements
order by total_exec_time desc
limit 20;
```

Check for indexes that receive no scans (do not drop anything from this report without reviewing write cost, query plans, and the observation period):

```sql
select
  schemaname,
  relname as table_name,
  indexrelname as index_name,
  idx_scan
from pg_stat_user_indexes
where idx_scan = 0
order by schemaname, relname, indexrelname;
```

Use `EXPLAIN (ANALYZE, BUFFERS)` only with a safe representative query in staging; `ANALYZE` executes the query. Review RLS and ownership checks separately from performance, and keep point-in-time recovery/backups enabled on production.

## Client-side error monitoring status

This repository currently has no configured crash-reporting SDK or production error-report destination. Flutter cubits may report errors locally, but that does not provide a searchable fleet-wide error dashboard. Adding `firebase_crashlytics ^5.2.5` currently fails dependency resolution because the package requires `firebase_core ^4.12.0`, while the app uses `firebase_core ^5.0.0`; do not force a downgrade without aligning and validating Firebase Messaging too. Before release, align compatible FlutterFire versions or choose a crash reporter and add its project configuration. Verify that tokens, assistant message content, payment data, and personal data are redacted. Supabase Dashboard monitoring covers the backend and does not replace Flutter crash reporting.

## Million-user capacity

“Registered users” and “concurrent users” are not equivalent. This public-read script is a first smoke/load baseline only and cannot certify a million-user launch. Set explicit targets for daily active users, peak requests per second, concurrent app sessions, Realtime connections, and order bursts; use a production-like, isolated staging project and a representative dataset before sizing compute or making capacity claims.
