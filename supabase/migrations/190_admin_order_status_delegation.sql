-- 190_admin_order_status_delegation.sql
--
-- Records the state that is ALREADY deployed in project webzzasosevzymftgszn.
-- The 2026-10-27 orders audit shipped topic A of
-- supabase/proposals/186_admin_orders_branch_scope_and_totals.PROPOSED.sql
-- straight into the live database through the SQL Editor, without ever
-- creating a numbered migration, so 145_admin_order_status_update.sql still
-- holds the pre-audit direct "update orders.orders" version. A database
-- rebuilt from this chain would therefore lose the delegation that the
-- dashboard is written against.
--
-- What this function does now: "cancelled" routes through orders.cancel_order
-- (which demands orders.cancel and restocks/claws back loyalty), every other
-- status routes through orders.update_order_status (which enforces
-- orders.status_transitions and writes order_status_history + audit).
--
-- This file is a no-op against the live project: it replays the deployed
-- definition verbatim. Do not edit its body without running a live diff.

create or replace function public.admin_update_order_status(p_order_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;
  if p_status not in ('pending','confirmed','preparing','ready','out_for_delivery','completed','cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  if p_status = 'cancelled' then
    -- Needs orders.cancel as well; see the header.
    perform orders.cancel_order(
      p_order_id,
      'cancelled from the admin orders page'
    );
  else
    perform orders.update_order_status(p_order_id, p_status, null);
  end if;
end;
$fn$;

revoke all on function public.admin_update_order_status(uuid, text) from public, anon;
grant execute on function public.admin_update_order_status(uuid, text) to authenticated;
