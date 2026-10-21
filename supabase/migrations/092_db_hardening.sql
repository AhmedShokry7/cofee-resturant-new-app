-- 092_db_hardening.sql
--
-- Hardening and reliability fixes verified against the live database.
-- No destructive operations. Every statement is idempotent where practical.
--
-- Evidence for each change is recorded in the section comments.

-- ---------------------------------------------------------------------------
-- 1. Rate limiting — correct fixed-window semantics.
--
-- Verified defect in public.increment_rate_limit():
--   * expires_at was always set to now() + window, so the stored window slid
--     forward on every request instead of resetting after a fixed period.
--   * window_start was only reset when older than 1 hour, which never aligned
--     with the freshly written expires_at, so a rejected request kept
--     extending the block.
--   * p_limit / p_cost / p_window_seconds were never validated.
--
-- Fix: reset count/window only when the stored window has actually expired,
-- validate the arguments, and keep the same function signature so the
-- rate-limit Edge Function and its callers are unaffected.
-- ---------------------------------------------------------------------------
create or replace function public.increment_rate_limit(
  p_user_id uuid,
  p_endpoint text,
  p_limit bigint,
  p_cost bigint default 1,
  p_window_seconds bigint default 3600
)
returns table (
  allowed boolean,
  remaining bigint,
  reset_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_now    timestamptz := now();
  v_current bigint;
  v_reset   timestamptz;
begin
  if p_user_id is null or p_endpoint is null or btrim(p_endpoint) = '' then
    raise exception 'user_id and endpoint are required' using errcode = '22023';
  end if;
  if p_limit is null or p_limit <= 0 then
    raise exception 'limit must be positive' using errcode = '22023';
  end if;
  if p_cost is null or p_cost <= 0 then
    raise exception 'cost must be positive' using errcode = '22023';
  end if;
  if p_window_seconds is null or p_window_seconds <= 0 then
    raise exception 'window_seconds must be positive' using errcode = '22023';
  end if;

  insert into public.rate_limit_counters (user_id, endpoint, count, window_start, expires_at)
  values (p_user_id, p_endpoint, p_cost, v_now, v_now + (p_window_seconds * interval '1 second'))
  on conflict (user_id, endpoint)
  do update set
    count = case
              when public.rate_limit_counters.expires_at <= v_now
              then p_cost
              else public.rate_limit_counters.count + p_cost
            end,
    window_start = case
                     when public.rate_limit_counters.expires_at <= v_now
                     then v_now
                     else public.rate_limit_counters.window_start
                   end,
    expires_at = case
                   when public.rate_limit_counters.expires_at <= v_now
                   then v_now + (p_window_seconds * interval '1 second')
                   else public.rate_limit_counters.expires_at
                 end
  returning count, expires_at into v_current, v_reset;

  if v_current is null then
    select count, expires_at into v_current, v_reset
      from public.rate_limit_counters
     where user_id = p_user_id and endpoint = p_endpoint;
  end if;

  if v_current > p_limit then
    return query select false, 0::bigint, v_reset;
    return;
  end if;

  return query select true, (p_limit - v_current)::bigint, v_reset;
end;
$fn$;

comment on function public.increment_rate_limit(uuid, text, bigint, bigint, bigint) is
  'Fixed-window rate limit. Resets only when the stored window expires; validates cost/limit/window.';

-- ---------------------------------------------------------------------------
-- 2. Materialized views — reliable refresh on first population and later.
--
-- Verified defect in public.refresh_materialized_caches():
--   REFRESH ... CONCURRENTLY fails with SQLSTATE 0A000 when a view has never
--   been populated ("CONCURRENTLY cannot be used when the materialized view is
--   not populated"). All four views were created WITH NO DATA.
--
-- Fix: populate with a non-concurrent refresh when the view is empty, then use
-- CONCURRENTLY for subsequent refreshes. The required unique indexes already
-- exist (ix_popular_products_cache_id, ix_active_categories_cache_id,
-- ix_published_banners_cache_id, ix_active_coupons_cache_code).
-- ---------------------------------------------------------------------------
create or replace function public.refresh_materialized_caches()
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if (select m.ispopulated from pg_matviews m
       where m.schemaname = 'catalog' and m.matviewname = 'popular_products_cache') then
    refresh materialized view concurrently catalog.popular_products_cache;
  else
    refresh materialized view catalog.popular_products_cache;
  end if;

  if (select m.ispopulated from pg_matviews m
       where m.schemaname = 'catalog' and m.matviewname = 'active_categories_cache') then
    refresh materialized view concurrently catalog.active_categories_cache;
  else
    refresh materialized view catalog.active_categories_cache;
  end if;

  if (select m.ispopulated from pg_matviews m
       where m.schemaname = 'marketing' and m.matviewname = 'published_banners_cache') then
    refresh materialized view concurrently marketing.published_banners_cache;
  else
    refresh materialized view marketing.published_banners_cache;
  end if;

  if (select m.ispopulated from pg_matviews m
       where m.schemaname = 'marketing' and m.matviewname = 'active_coupons_cache') then
    refresh materialized view concurrently marketing.active_coupons_cache;
  else
    refresh materialized view marketing.active_coupons_cache;
  end if;
end;
$fn$;

comment on function public.refresh_materialized_caches() is
  'Refreshes catalog caches; populates empty views first, then refreshes concurrently.';

-- ---------------------------------------------------------------------------
-- 3. Expired rate-limit counter cleanup.
--
-- The Edge Function currently issues a DELETE of expired counters on every
-- request. Move cleanup into a single, index-backed function that can be run
-- by a scheduled job (ix_rate_limit_expires exists on expires_at).
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_expired_rate_limits()
returns integer
language sql
security definer
set search_path = ''
as $fn$
  with deleted as (
    delete from public.rate_limit_counters
     where expires_at <= now()
    returning 1
  )
  select count(*)::int from deleted;
$fn$;

comment on function public.cleanup_expired_rate_limits() is
  'Deletes expired rate-limit counters and returns the number removed.';

-- ---------------------------------------------------------------------------
-- 4. Privileges.
--
-- Verified: public.rate_limit_counters had SELECT/INSERT/UPDATE/DELETE granted
-- to anon and authenticated (the RLS policy denies all rows, but table
-- privileges were unnecessarily broad). The rate-limit Edge Function uses
-- service_role, so client roles do not need direct table access.
-- ---------------------------------------------------------------------------
revoke all on table public.rate_limit_counters from anon, authenticated;
grant select, insert, update, delete on table public.rate_limit_counters to service_role;

revoke all on function public.increment_rate_limit(uuid, text, bigint, bigint, bigint)
  from public, authenticated;
grant execute on function public.increment_rate_limit(uuid, text, bigint, bigint, bigint)
  to service_role;

revoke all on function public.refresh_materialized_caches()
  from public, authenticated;
grant execute on function public.refresh_materialized_caches()
  to service_role;

revoke all on function public.cleanup_expired_rate_limits()
  from public, anon, authenticated;
grant execute on function public.cleanup_expired_rate_limits()
  to service_role;

-- ---------------------------------------------------------------------------
-- 4b. ai schema access.
--
-- Verified: service_role held table privileges on ai.product_knowledge and
-- ai.knowledge_articles but NOT USAGE on the schema itself, so server-side
-- code could not actually read them. anon and authenticated correctly have
-- neither table privileges nor schema usage, and stay that way.
-- ---------------------------------------------------------------------------
grant usage on schema ai to service_role;

-- ---------------------------------------------------------------------------
-- 5. Scheduled cleanup of expired rate-limit counters.
--
-- No cleanup job existed; the only refresh job is
-- 'refresh-materialized-caches'. Add a single daily cleanup to reclaim rows.
-- ---------------------------------------------------------------------------
do $do$
begin
  perform cron.unschedule('cleanup-expired-rate-limits');
exception when others then
  null;
end
$do$;

select cron.schedule(
  'cleanup-expired-rate-limits',
  '17 3 * * *',
  $$select public.cleanup_expired_rate_limits();$$
);

-- ---------------------------------------------------------------------------
-- 6. identity.admins — enable RLS.
--
-- Verified: identity.admins is a legacy duplicate of identity.staff_members.
-- No client role has table privileges (only postgres), so it is not reachable
-- through PostgREST. Every function that reads it (identity.is_staff,
-- identity.has_permission, identity.can_manage_branch,
-- identity.manages_all_branches, identity.provision_staff,
-- public.admin_get_my_admin_record) is SECURITY DEFINER owned by the table
-- owner, so enabling RLS does not change their behaviour.
-- ---------------------------------------------------------------------------
alter table identity.admins enable row level security;

notify pgrst, 'reload schema';
