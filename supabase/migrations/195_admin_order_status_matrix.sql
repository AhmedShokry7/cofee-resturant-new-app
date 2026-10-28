-- 195_admin_order_status_matrix.sql
--
-- Companion to 193 for the orders directory.
--
-- admin_order_status_options(p_order_id) answers "what can I move THIS order
-- to?", which is what the detail page needs. The directory shows dozens of
-- orders at once, each with a quick status menu, so asking the database one
-- question per card would turn a single page load into dozens of round trips.
--
-- This returns the whole allowed matrix in one read, plus the one caller fact
-- that changes what the matrix means on screen: whether this staff member may
-- cancel at all. The matrix itself is global reference data — orders.status_
-- transitions is already SELECT-granted to authenticated (023) and RLS-read
-- policy (021) — so nothing here is branch scoped. The write path is: an admin
-- who attempts a transition this matrix permits can still be refused by
-- orders.update_order_status for branch or payment reasons, and the app shows
-- that message.
--
-- Shape:
--   {"can_cancel": true,
--    "matrix": {"pending": ["cancelled", "confirmed"], ...}}
-- A status with no outgoing edge is simply absent, which is what a closed order
-- looks like to the UI.

create or replace function public.admin_order_status_matrix()
 returns jsonb
 language plpgsql
 security definer
 set search_path = ''
as $fn$
declare
  v_matrix jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select coalesce(
           jsonb_object_agg(src.from_status, src.to_statuses),
           '{}'::jsonb
         )
    into v_matrix
    from (
      select st.from_status,
             jsonb_agg(st.to_status order by st.to_status) as to_statuses
        from orders.status_transitions st
       where st.is_allowed
         and st.to_status <> st.from_status
       group by st.from_status
    ) src;

  return jsonb_build_object(
    'can_cancel', identity.has_permission('orders.cancel'),
    'matrix',     v_matrix
  );
end;
$fn$;

comment on function public.admin_order_status_matrix() is
  'The allowed order status matrix for the signed-in staff member, from orders.status_transitions.';

revoke all on function public.admin_order_status_matrix() from public, anon;
grant execute on function public.admin_order_status_matrix() to authenticated;

notify pgrst, 'reload schema';
