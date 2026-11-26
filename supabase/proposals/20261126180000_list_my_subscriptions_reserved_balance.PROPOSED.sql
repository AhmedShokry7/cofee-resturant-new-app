-- Reviewable proposal only. NOT A MIGRATION. DO NOT EXECUTE before owner approval.
--
-- Fixes the customer subscription page's missing public RPC and returns the
-- reserved balance already required by CustomerSubscription.fromDatabase.
-- Target intended for review: Supabase TEST/DEVELOPMENT project
-- webzzasosevzymftgszn, confirmed against .env URL and supabase/config.toml.
-- This file has not been applied to any database.

begin;

-- The current pending local definition has the same zero-argument signature
-- but a different RETURNS TABLE shape. PostgreSQL cannot change that OUT-row
-- shape with CREATE OR REPLACE, so replace only this exact RPC; never CASCADE.
drop function if exists public.list_my_subscriptions();

create function public.list_my_subscriptions()
returns table (
  id uuid,
  plan_id uuid,
  plan_name_ar text,
  plan_name_en text,
  status text,
  starts_at timestamptz,
  ends_at timestamptz,
  cups_entitled integer,
  cups_used integer,
  cups_reserved integer,
  cups_carried_over integer,
  bonus_balance numeric,
  bonus_expires_at timestamptz,
  auto_renew boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select s.id,
         s.plan_id,
         p.name_ar,
         p.name_en,
         s.status,
         s.starts_at,
         s.ends_at,
         s.cups_entitled,
         s.cups_used,
         s.cups_reserved,
         s.cups_carried_over,
         s.bonus_balance,
         s.bonus_expires_at,
         s.auto_renew,
         s.created_at
    from subscriptions.subscriptions as s
    join subscriptions.plans as p on p.id = s.plan_id
   where auth.uid() is not null
     and s.user_id = auth.uid()
   order by s.created_at desc, s.id desc;
$fn$;

revoke all on function public.list_my_subscriptions() from public, anon;
grant execute on function public.list_my_subscriptions() to authenticated;

notify pgrst, 'reload schema';
commit;

-- ROLLBACK (review-only; run only after a reviewed client rollback):
-- begin;
-- drop function if exists public.list_my_subscriptions();
-- create function public.list_my_subscriptions()
-- returns table (
--   id uuid, plan_id uuid, plan_name_ar text, plan_name_en text, status text,
--   starts_at timestamptz, ends_at timestamptz, cups_entitled integer,
--   cups_used integer, cups_carried_over integer, bonus_balance numeric,
--   bonus_expires_at timestamptz, auto_renew boolean, created_at timestamptz
-- ) language sql stable security definer set search_path = '' as $fn$
--   select s.id, s.plan_id, p.name_ar, p.name_en, s.status, s.starts_at,
--          s.ends_at, s.cups_entitled, s.cups_used, s.cups_carried_over,
--          s.bonus_balance, s.bonus_expires_at, s.auto_renew, s.created_at
--     from subscriptions.subscriptions as s
--     join subscriptions.plans as p on p.id = s.plan_id
--    where auth.uid() is not null and s.user_id = auth.uid()
--    order by s.created_at desc, s.id desc;
-- $fn$;
-- revoke all on function public.list_my_subscriptions() from public, anon;
-- grant execute on function public.list_my_subscriptions() to authenticated;
-- notify pgrst, 'reload schema';
-- commit;
