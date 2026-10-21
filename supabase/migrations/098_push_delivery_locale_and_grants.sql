-- 098_push_delivery_locale_and_grants.sql
--
-- Small follow-up to 097.
--
-- 1. device_tokens gains a locale column.
--
--    The notifications are bilingual (Arabic and English) and the FCM
--    notification that Android shows in the tray is written by the server, so
--    the server has to know which language the phone reads. The app knows it,
--    the server does not, so the device stores it with the token and the
--    Edge Function picks the matching title and body.
--
-- 2. The Edge Function needs write access.
--
--    The delivery log is written by the Edge Function and stale tokens are
--    deleted by it, so service_role needs more than the read-only grant it
--    inherited from migration 018.

alter table engagement.device_tokens
  add column if not exists locale text;

comment on column engagement.device_tokens.locale is
  'The language of the device, used to pick the Arabic or the English text of a push.';

grant insert, update, delete on table engagement.push_deliveries to service_role;

grant insert, update, delete on table engagement.device_tokens to service_role;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
