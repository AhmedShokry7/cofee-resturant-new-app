-- Last-mile push test for the one real Android session in this project
-- (user 534c5b4d, token registered 2026-10-28).
--
-- The pg_net log already proves the queue -> send-push hop works and returns
-- 200 {"skipped":true,"reason":"push_disabled"} because this customer has no
-- engagement.notification_preferences row. This script supplies that row and
-- writes one notification, so the AFTER INSERT trigger performs a real
-- dispatch and engagement.push_deliveries records what FCM answers.
--
-- The notification is labelled as a test so the customer list stays honest.

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
