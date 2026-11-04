-- Last-mile push test, written against the state measured on 2026-11-04.
--
-- The user below (534c5b4d) is a real customer account of this project, and as
-- of that date it has an engagement.notification_preferences row with
-- push_enabled = true and NO row in engagement.device_tokens - the handset that
-- registered it was uninstalled or refreshed. So running this script today
-- answers `skipped / no_device_token`, which proves the queue -> function hop
-- and nothing about FCM. A push does reach a phone only when that user opens
-- the app on a device that has granted the notification permission, because
-- that is what registers a token.
--
-- The @test.local customers this script was written for are gone from the
-- project (no row in auth.users), which is also why `node tools/check_push.mjs`
-- cannot sign in. Recreate them with `node supabase/tests/make_test_users.js`
-- before using either script.
--
-- What the delivery table already proves, read-only and without writing:
--
--   select status, coalesce(error,'-') as error, count(*), max(created_at)
--     from engagement.push_deliveries group by 1,2 order by 3 desc;
--
-- The read-only answer on 2026-11-04 was 16 `sent` (newest 2026-10-31 18:37),
-- 2 `skipped/push_disabled`, 2 `skipped/no_device_token` and 1 `failed` with a
-- Google-side "Invalid JWT Signature" (2026-10-31 10:34, before the current
-- service account was set). `sent` rows carry a provider_message_id, so the
-- credential works and the whole hop is proven.
--
-- `push_disabled` for a customer who has a token but never chose is closed on
-- both sides now. The app writes the switch when the phone already granted the
-- permission (PushService.adoptGrantedPush), and send-push version 11, deployed
-- 2026-11-04 15:32, treats a missing preferences row as opted-in whenever the
-- customer has a registered device - a device only exists after the operating
-- system allowed notifications. Measured on the account that had the symptom
-- (4b37c64d, one token, no preferences row): the next notification came back
-- `sent` with provider_message_id
-- projects/new-coffee-4d196/messages/0:1793806472770404%73d27bdc73d27bdc.
--
-- This script writes into a real customer's list. To undo what it leaves
-- behind, run after reading the answer:
--
--   delete from engagement.notifications where payload ->> 'test' = 'true';
--   delete from engagement.push_deliveries where created_at > now() - interval '10 minutes';

begin;

insert into engagement.notification_preferences as prefs (
  user_id, order_status, promo, loyalty, system, push_enabled
) values (
  '534c5b4d-cd2a-4234-b0a0-404000bf0ff4', true, true, true, true, true
)
on conflict (user_id) do update set
  order_status = true,
  promo = true,
  loyalty = true,
  system = true,
  push_enabled = true,
  updated_at = now()
returning prefs.user_id, prefs.push_enabled, prefs.updated_at;

insert into engagement.notifications (
  user_id, type, title_ar, title_en, body_ar, body_en, payload, is_read
) values (
  '534c5b4d-cd2a-4234-b0a0-404000bf0ff4',
  'promo',
  'إشعار اختباري',
  'Test notification',
  'هذا إشعار اختباري للتحقق من وصول الإشعارات الفورية إلى الهاتف.',
  'Push pipeline test notification.',
  '{"test": true}'::jsonb,
  false
)
returning id, type, created_at;

commit;
