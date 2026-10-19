-- 079_fix_update_order_status_authorization.sql
--
-- Remediation for the P0 reported in the Supabase audit:
-- orders.update_order_status was a SECURITY DEFINER function with no
-- authorization check, and EXECUTE was granted to PUBLIC, allowing any
-- caller (including anon/authenticated customers) to change order status.
--
-- After this migration the function requires an authenticated staff
-- session with orders.status.update permission and branch scope, validates
-- the transition, writes status history, and records an audit row. Customer
-- cancellation remains available only through orders.cancel_order.

create or replace function orders.update_order_status(
  p_order_id uuid,
  p_to_status text,
  p_note text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
  v_uid   uuid := auth.uid();
  v_ok    boolean;
begin
  -- Trusted caller identity comes from the JWT, never from parameters.
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not identity.is_staff() or not identity.has_permission('orders.status.update') then
    raise exception 'orders.status.update permission required' using errcode = '42501';
  end if;

  select * into v_order
    from orders.orders
   where id = p_order_id
   for update;

  if not found then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;

  if not identity.can_manage_branch(v_order.branch_id) then
    raise exception 'you do not manage this branch' using errcode = '42501';
  end if;

  -- Cancellation must go through orders.cancel_order so stock and loyalty
  -- points are restored exactly once. This RPC only performs status transitions
  -- that do not require side effects.
  if p_to_status = 'cancelled' then
    raise exception 'use orders.cancel_order to cancel an order' using errcode = '23514';
  end if;

  select st.is_allowed into v_ok
    from orders.status_transitions st
   where st.from_status = v_order.status
     and st.to_status = p_to_status;

  if v_ok is null then
    raise exception 'unknown transition % -> %', v_order.status, p_to_status
      using errcode = '23514';
  end if;
  if not v_ok then
    raise exception 'transition % -> % is not allowed', v_order.status, p_to_status
      using errcode = '23514';
  end if;

  update orders.orders
     set status = p_to_status,
         completed_at = case when p_to_status = 'completed' then now() else completed_at end,
         cancelled_at = case when p_to_status = 'cancelled' then now() else cancelled_at end
   where id = p_order_id;

  insert into orders.order_status_history (order_id, from_status, to_status, changed_by, note)
  values (p_order_id, v_order.status, p_to_status, v_uid, p_note);

  perform identity.audit(
    'order.status.update',
    'order',
    p_order_id,
    jsonb_build_object('status', v_order.status),
    jsonb_build_object('status', p_to_status),
    v_order.branch_id
  );

  return true;
end;
$fn$;

comment on function orders.update_order_status(uuid, text, text) is
  'Authorized order status transition. Staff only, permission + branch scoped.';

-- Least privilege: remove the default PUBLIC grant and anon access.
revoke all on function orders.update_order_status(uuid, text, text) from public;
revoke execute on function orders.update_order_status(uuid, text, text) from anon;

-- Signed-in callers may attempt the RPC; the function enforces staff authorization.
grant execute on function orders.update_order_status(uuid, text, text) to authenticated;

-- Keep the public bridge wrapper consistent with the other signed-in-only RPCs.
revoke all on function public.update_order_status(uuid, text, text) from public;
revoke execute on function public.update_order_status(uuid, text, text) from anon;
grant execute on function public.update_order_status(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';
