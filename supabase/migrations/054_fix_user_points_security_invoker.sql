-- 054_fix_user_points_security_invoker.sql
--
-- Security fix (F1): identity.user_points was a plain (owner-rights) view that
-- joined ALL profiles with loyalty_accounts, bypassing RLS on both tables.
-- The public.user_points bridge view was security_invoker, but the inner view
-- still executed with postgres privileges, so any authenticated user could read
-- every user's name and loyalty balance.
--
-- Fix: recreate identity.user_points WITH (security_invoker = true) so that the
-- caller's RLS policies on identity.profiles and loyalty.loyalty_accounts are
-- enforced. public.user_points already delegates to it and is unchanged.

-- The bridge view depends on the base view, so it must be dropped first.
-- Its SELECT grant is re-issued at the end of this migration.
drop view if exists public.user_points;

-- Recreate the base view as security_invoker. Column names and types are
-- unchanged so loyalty_repository.dart keeps working.
create or replace view identity.user_points
with (security_invoker = true)
as
select p.id                            as user_id,
       p.full_name,
       coalesce(l.points_balance, 0)   as points_balance,
       coalesce(l.lifetime_points, 0)  as lifetime_points,
       coalesce(l.tier, 'bronze')      as tier
from identity.profiles p
left join loyalty.loyalty_accounts l on l.user_id = p.id;

comment on view identity.user_points is
  'Profile + loyalty balance in one row. Read-only. Source of truth = loyalty.loyalty_accounts (D9). security_invoker so RLS on profiles/loyalty_accounts applies to the caller.';

-- Recreate the public bridge view (unchanged), still routing to the base view.
create or replace view public.user_points
with (security_invoker = true)
as
select * from identity.user_points;

comment on view public.user_points is
  'Routing view over identity.user_points. Loyalty balance single source of truth (D9).';

-- Restore grants dropped with the view. Only signed-in users may read points;
-- anon must never see them. RLS on the underlying tables now enforces row-level
-- isolation because the inner view is security_invoker.
grant select on public.user_points to authenticated;
revoke all on public.user_points from anon;

notify pgrst, 'reload schema';