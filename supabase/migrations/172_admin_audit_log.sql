-- 172_admin_audit_log.sql
-- A readable audit trail for the admin dashboard.
--
-- What this migration adds:
--
--   1. a display view that resolves the actor from identity.staff_members
--      (the canonical staff table) with identity.profiles as a fallback, and
--      aggregates the Arabic and English role names from staff_roles/roles;
--   2. a directory function with server-side search, domain and critical
--      filters and paging, so the page never downloads the whole log;
--   3. headline metrics for the page cards;
--   4. an index for the newest-first reads and the domain filter.
--
-- 149 joined identity.profiles directly, which is the customers table. Staff
-- actors therefore showed an empty name in the dashboard, so this migration
-- replaces that function and keeps its old jsonb-array response for callers
-- that still use it.
--
-- The table is append-only and written by SECURITY DEFINER functions only, so
-- this file adds no INSERT/UPDATE/DELETE grants. Every function keeps the
-- audit.read guard.

-- ---------------------------------------------------------------------------
-- 1. Critical classification and the readable view
-- ---------------------------------------------------------------------------
create or replace function identity.audit_is_critical(p_action text)
returns boolean
language sql
immutable
set search_path = ''
as $fn$
  select p_action like '%.delete'
      or split_part(p_action, '.', 1) in ('permission', 'role')
      or p_action in (
        'staff.provision',
        'stock.adjust',
        'core.branch.deactivate'
      );
$fn$;

comment on function identity.audit_is_critical(text) is
  'True for destructive, access-related and stock-changing audit actions.';

revoke all on function identity.audit_is_critical(text) from public;

-- The view is read only by the SECURITY DEFINER functions below. It is not
-- granted to anon or authenticated, and the identity schema is not exposed
-- through PostgREST.
create or replace view identity.audit_log_display as
select
  a.id,
  a.actor_user_id,
  coalesce(sm.full_name, p.full_name) as actor_name,
  coalesce(sm.email, p.email) as actor_email,
  a.actor_role,
  coalesce(roles.names_ar, array[]::text[]) as actor_roles_ar,
  coalesce(roles.names_en, array[]::text[]) as actor_roles_en,
  a.action,
  split_part(a.action, '.', 1) as domain,
  identity.audit_is_critical(a.action) as is_critical,
  a.entity_type,
  a.entity_id,
  a.branch_id,
  b.name_ar as branch_name_ar,
  b.name_en as branch_name_en,
  a.old_values,
  a.new_values,
  a.created_at
from identity.audit_log a
left join identity.staff_members sm on sm.user_id = a.actor_user_id
left join identity.profiles p on p.id = a.actor_user_id
left join core.branches b on b.id = a.branch_id
left join lateral (
  select
    array_agg(distinct r.name_ar) as names_ar,
    array_agg(distinct r.name_en) as names_en
  from identity.staff_roles sr
  join identity.roles r on r.id = sr.role_id
  where sr.staff_id = sm.id
) roles on true;

comment on view identity.audit_log_display is
  'Audit rows enriched with the staff actor, role names, branch names and the critical flag.';

revoke all on identity.audit_log_display from public, anon, authenticated;

-- Newest-first scans, and the domain filter of the directory.
create index if not exists ix_audit_created_at
  on identity.audit_log (created_at desc);
create index if not exists ix_audit_domain_created
  on identity.audit_log ((split_part(action, '.', 1)), created_at desc);

-- ---------------------------------------------------------------------------
-- 2. Guard shared by every read function
-- ---------------------------------------------------------------------------
create or replace function identity.require_audit_reader()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('audit.read') then
    raise exception 'missing permission: audit.read' using errcode = '42501';
  end if;
end;
$fn$;

revoke all on function identity.require_audit_reader() from public;

-- ---------------------------------------------------------------------------
-- 3. Directory with search, filters and paging
-- ---------------------------------------------------------------------------
create or replace function public.admin_audit_directory(
  p_search text default null,
  p_domain text default null,
  p_critical_only boolean default false,
  p_limit int default 20,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_term text := nullif(btrim(left(coalesce(p_search, ''), 120)), '');
  v_domain text := nullif(btrim(p_domain), '');
  v_limit int := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  perform identity.require_audit_reader();

  return (
    select jsonb_build_object(
      'rows', coalesce(
        jsonb_agg(to_jsonb(page_row) - 'total_count' order by page_row.created_at desc, page_row.id desc),
        '[]'::jsonb
      ),
      'total', coalesce(max(page_row.total_count), 0)
    )
    from (
      select
        d.id,
        d.actor_user_id,
        d.actor_name,
        d.actor_email,
        d.actor_role,
        d.actor_roles_ar,
        d.actor_roles_en,
        d.action,
        d.domain,
        d.is_critical,
        d.entity_type,
        d.entity_id,
        d.branch_id,
        d.branch_name_ar,
        d.branch_name_en,
        d.old_values,
        d.new_values,
        d.created_at,
        count(*) over() as total_count
      from identity.audit_log_display d
      where
        (v_term is null or (
          coalesce(d.actor_name, '') ilike '%' || v_term || '%'
          or coalesce(d.actor_email, '') ilike '%' || v_term || '%'
          or d.action ilike '%' || v_term || '%'
          or d.entity_type ilike '%' || v_term || '%'
          or coalesce(d.entity_id::text, '') ilike '%' || v_term || '%'
          or coalesce(d.branch_name_ar, '') ilike '%' || v_term || '%'
          or coalesce(d.branch_name_en, '') ilike '%' || v_term || '%'
          or array_to_string(d.actor_roles_ar, ' ') ilike '%' || v_term || '%'
          or array_to_string(d.actor_roles_en, ' ') ilike '%' || v_term || '%'
          or coalesce(d.new_values::text, '') ilike '%' || v_term || '%'
          or coalesce(d.old_values::text, '') ilike '%' || v_term || '%'
        ))
        and (not coalesce(p_critical_only, false) or d.is_critical)
        and (
          v_domain is null
          or (v_domain = 'other' and d.domain not in (
            'core', 'marketing', 'loyalty', 'engagement', 'order', 'stock',
            'staff', 'subscription', 'catalog', 'inventory', 'payment',
            'identity', 'permission', 'role'
          ))
          or d.domain = v_domain
        )
      order by d.created_at desc, d.id desc
      limit v_limit
      offset v_offset
    ) page_row
  );
end;
$fn$;

comment on function public.admin_audit_directory(text, text, boolean, int, int) is
  'Readable audit rows with server-side search, domain and critical filters and paging.';

revoke all on function public.admin_audit_directory(text, text, boolean, int, int) from public, anon;
grant execute on function public.admin_audit_directory(text, text, boolean, int, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Metrics for the page cards
-- ---------------------------------------------------------------------------
create or replace function public.admin_audit_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform identity.require_audit_reader();

  return (
    select jsonb_build_object(
      'total', count(*),
      'today', count(*) filter (where d.created_at >= date_trunc('day', now())),
      'week', count(*) filter (where d.created_at >= now() - interval '7 days'),
      'critical', count(*) filter (where d.is_critical),
      'critical_week', count(*) filter (
        where d.is_critical and d.created_at >= now() - interval '7 days'
      ),
      'actors', count(distinct d.actor_user_id),
      'actors_week', count(distinct d.actor_user_id) filter (
        where d.created_at >= now() - interval '7 days'
      ),
      'branches', count(distinct d.branch_id),
      'latest_at', max(d.created_at)
    )
    from identity.audit_log_display d
  );
end;
$fn$;

comment on function public.admin_audit_metrics() is
  'Headline audit metrics: totals, today, week, critical events and active actors.';

revoke all on function public.admin_audit_metrics() from public, anon;
grant execute on function public.admin_audit_metrics() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Keep the 149 function, now with real staff actors
-- ---------------------------------------------------------------------------
create or replace function public.admin_audit_log(p_limit int default 200)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform identity.require_audit_reader();

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'actor_user_id', d.actor_user_id,
        'actor_name', d.actor_name,
        'actor_email', d.actor_email,
        'actor_role', d.actor_role,
        'actor_roles_ar', d.actor_roles_ar,
        'actor_roles_en', d.actor_roles_en,
        'action', d.action,
        'domain', d.domain,
        'is_critical', d.is_critical,
        'entity_type', d.entity_type,
        'entity_id', d.entity_id,
        'branch_id', d.branch_id,
        'branch_name_ar', d.branch_name_ar,
        'branch_name_en', d.branch_name_en,
        'old_values', d.old_values,
        'new_values', d.new_values,
        'created_at', d.created_at
      )
      order by d.created_at desc, d.id desc
    )
    from (
      select *
      from identity.audit_log_display
      order by created_at desc, id desc
      limit greatest(1, least(coalesce(p_limit, 200), 500))
    ) d
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_audit_log(int) from public, anon;
grant execute on function public.admin_audit_log(int) to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
