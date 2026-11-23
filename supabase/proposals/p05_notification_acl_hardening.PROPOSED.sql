-- SUPERSEDED: official migration is supabase/migrations/*.sql (P0.7, applied). This proposal is now a historical reference only.
-- P0.5 LOCAL PROPOSAL ONLY. Do NOT apply without separate approval.
-- File: p05_notification_acl_hardening.PROPOSED.sql
-- Purpose: narrow authenticated direct notification writes to RPC paths.
-- Dependencies: 016_engagement_01, 022_rls_04_loyalty_marketing_engagement,
--   023_grants_01, 032_public_bridge_views, 170_admin_notifications,
--   235_notification_delete_rpc, 236_secure_notification_delete,
--   237_mark_all_customer_notifications_read.
-- Scope: engagement.notifications and public.notifications only.
-- Not in scope: RLS policies, triggers, legacy admin_send_notification behavior.
-- Rollback proposal: re-grant only the exact privilege needed after a proven
-- RPC regression; do not restore broad table UPDATE as a silent rollback.
-- Tests: supabase/tests/marketing_hub_acl_test.sql

begin;

-- Remove direct table-wide write privileges from authenticated.
revoke insert, update, delete on engagement.notifications from authenticated;
revoke insert, update, delete on public.notifications from authenticated;

-- Remove all column-level UPDATE privileges except is_read/read_at on the base table.
revoke update (
  id, user_id, type,
  title_ar, title_en, body_ar, body_en,
  payload, related_entity_type, related_entity_id,
  dedupe_key, created_at, campaign_id, created_by
) on engagement.notifications from authenticated;

-- public.notifications exposes the 032 select * view and does NOT expose
-- campaign_id / created_by (added by 170 after the view was created).
revoke update (
  id, user_id, type,
  title_ar, title_en, body_ar, body_en,
  payload, related_entity_type, related_entity_id,
  dedupe_key, created_at
) on public.notifications from authenticated;

-- Customer-safe direct update columns only, on both the base table and the
-- security_invoker view (invoker needs privileges on both paths).
grant update (is_read, read_at) on engagement.notifications to authenticated;
grant update (is_read, read_at) on public.notifications to authenticated;

-- Exact current client RPCs, extracted from migration sources.
-- 237: engagement.mark_notifications_read(p_ids uuid[] default null)
--      public.mark_notifications_read(p_ids uuid[] default null)
-- 235/236: engagement.delete_notifications(p_ids uuid[])
--          public.delete_notifications(p_ids uuid[] default null)
-- 170: public.admin_send_notification(text, text, text, text, text, text, uuid, jsonb)
--      public.admin_resend_notification(uuid)
--      public.admin_set_notification_read(uuid, boolean)
--      public.admin_delete_notification(uuid)
revoke all on function public.mark_notifications_read(uuid[]) from public, anon;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;

revoke all on function public.delete_notifications(uuid[]) from public, anon;
grant execute on function public.delete_notifications(uuid[]) to authenticated;

revoke all on function public.admin_send_notification(text, text, text, text, text, text, uuid, jsonb)
  from public, anon;
grant execute on function public.admin_send_notification(text, text, text, text, text, text, uuid, jsonb)
  to authenticated;

revoke all on function public.admin_resend_notification(uuid) from public, anon;
grant execute on function public.admin_resend_notification(uuid) to authenticated;

revoke all on function public.admin_set_notification_read(uuid, boolean) from public, anon;
grant execute on function public.admin_set_notification_read(uuid, boolean) to authenticated;

revoke all on function public.admin_delete_notification(uuid) from public, anon;
grant execute on function public.admin_delete_notification(uuid) to authenticated;

comment on table engagement.notifications is
  'In-app notification log. Written server-side only. authenticated may directly update only is_read/read_at; all other writes use RPCs.';
comment on view public.notifications is
  'Security-invoker bridge to engagement.notifications. authenticated may directly update only is_read/read_at; insert/delete/send paths are RPC-only.';

notify pgrst, 'reload schema';

commit;
