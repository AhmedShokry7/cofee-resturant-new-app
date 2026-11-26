-- Short-lived, user-bound previews for assistant status changes and
-- cancellations. All mutations delegate to the existing order lifecycle RPCs.
create table if not exists orders.admin_assistant_order_action_previews (
  token_hash text primary key,
  actor_user_id uuid not null,
  auth_session_id text not null default '',
  order_id uuid not null references orders.orders(id) on delete cascade,
  branch_id uuid not null references core.branches(id),
  action text not null check (action in ('status', 'cancel')),
  payload jsonb not null default '{}'::jsonb,
  expected_status text not null,
  expected_payment_status text not null,
  expected_updated_at timestamptz not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  result jsonb,
  created_at timestamptz not null default now()
);

alter table orders.admin_assistant_order_action_previews enable row level security;
revoke all on orders.admin_assistant_order_action_previews from public, anon, authenticated;

create or replace function public.admin_assistant_order_action_preview(
  p_order_number text,
  p_action text,
  p_target_status text default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_session_id text := coalesce(auth.jwt()->>'session_id', '');
  v_order orders.orders%rowtype;
  v_branch core.branches%rowtype;
  v_token text;
  v_target text := nullif(btrim(p_target_status), '');
  v_reason text := left(btrim(coalesce(p_reason, '')), 500);
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'active staff session required' using errcode = '42501';
  end if;
  if p_action is null or p_action not in ('status', 'cancel') then
    raise exception 'unsupported assistant order action' using errcode = '22023';
  end if;

  if (p_action = 'status' and not identity.has_permission('orders.status.update'))
     or (p_action = 'cancel' and not identity.has_permission('orders.cancel')) then
    raise exception 'missing permission for requested order action' using errcode = '42501';
  end if;
  if p_action = 'status' and (v_target is null or v_target not in (
    'pending','confirmed','preparing','ready','out_for_delivery','completed'
  )) then
    raise exception 'invalid target status' using errcode = '22023';
  end if;
  if p_action = 'cancel' and char_length(v_reason) < 3 then
    raise exception 'a cancellation reason is required' using errcode = '22023';
  end if;

  select * into v_order
    from orders.orders o
   where o.order_number = left(btrim(coalesce(p_order_number, '')), 80)
     and coalesce(o.test_only, false) = false
   for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_order.branch_id) then
    raise exception 'order branch out of scope' using errcode = '42501';
  end if;
  select * into v_branch from core.branches b where b.id = v_order.branch_id;

  if p_action = 'status' then
    if not exists (
      select 1 from orders.status_transitions st
       where st.from_status = v_order.status
         and st.to_status = v_target
         and st.is_allowed
    ) then
      raise exception 'transition % -> % is not allowed', v_order.status, v_target
        using errcode = '23514';
    end if;
  else
    if not identity.has_permission('orders.cancel') then
      raise exception 'missing permission: orders.cancel' using errcode = '42501';
    end if;
    if v_order.payment_status in ('paid', 'authorized') then
      raise exception 'paid orders must be refunded before cancellation' using errcode = '23514';
    end if;
    if not exists (
      select 1 from orders.status_transitions st
       where st.from_status = v_order.status
         and st.to_status = 'cancelled'
         and st.is_allowed
    ) then
      raise exception 'order cannot be cancelled from status %', v_order.status using errcode = '23514';
    end if;
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  delete from orders.admin_assistant_order_action_previews
   where created_at < now() - interval '7 days';
  insert into orders.admin_assistant_order_action_previews (
    token_hash, actor_user_id, auth_session_id, order_id, branch_id, action, payload,
    expected_status, expected_payment_status, expected_updated_at, expires_at
  ) values (
    encode(extensions.digest(convert_to(v_token, 'UTF8'), 'sha256'), 'hex'),
    v_uid, v_session_id, v_order.id, v_order.branch_id, p_action,
    case when p_action = 'cancel'
      then jsonb_build_object('reason', v_reason)
      else jsonb_build_object('target_status', v_target) end,
    v_order.status, v_order.payment_status, v_order.updated_at,
    now() + interval '5 minutes'
  );

  return jsonb_build_object(
    'approval_token', v_token,
    'expires_at', now() + interval '5 minutes',
    'action', p_action,
    'order_number', v_order.order_number,
    'branch_id', v_order.branch_id,
    'branch_name_ar', v_branch.name_ar,
    'branch_name_en', v_branch.name_en,
    'old_status', v_order.status,
    'new_status', case when p_action = 'cancel' then 'cancelled' else v_target end,
    'payment_status', v_order.payment_status,
    'grand_total', v_order.grand_total,
    'currency_code', v_order.currency_code,
    'reason', case when p_action = 'cancel' then v_reason else null end
  );
end;
$$;

create or replace function public.admin_assistant_order_action_execute(p_approval_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_session_id text := coalesce(auth.jwt()->>'session_id', '');
  v_hash text;
  v_preview orders.admin_assistant_order_action_previews%rowtype;
  v_order orders.orders%rowtype;
  v_result jsonb;
  v_target text;
  v_reason text;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'active staff session required' using errcode = '42501';
  end if;
  if p_approval_token is null or char_length(p_approval_token) <> 64 then
    raise exception 'invalid approval token' using errcode = '42501';
  end if;
  v_hash := encode(extensions.digest(convert_to(p_approval_token, 'UTF8'), 'sha256'), 'hex');

  select * into v_preview
    from orders.admin_assistant_order_action_previews p
   where p.token_hash = v_hash
   for update;
  if not found or v_preview.actor_user_id <> v_uid
     or v_preview.auth_session_id <> v_session_id then
    raise exception 'approval does not belong to this user' using errcode = '42501';
  end if;
  if v_preview.consumed_at is not null then
    return coalesce(v_preview.result, jsonb_build_object('ok', true, 'reused', true));
  end if;
  if v_preview.expires_at <= now() then
    raise exception 'approval expired; prepare a fresh preview' using errcode = '40001';
  end if;

  select * into v_order from orders.orders o where o.id = v_preview.order_id for update;
  if not found or v_order.branch_id <> v_preview.branch_id
     or not identity.can_manage_branch(v_preview.branch_id) then
    raise exception 'order branch out of scope or order missing' using errcode = '42501';
  end if;
  if v_order.status <> v_preview.expected_status
     or v_order.payment_status <> v_preview.expected_payment_status
     or v_order.updated_at is distinct from v_preview.expected_updated_at then
    raise exception 'order changed after preview; prepare a fresh preview' using errcode = '40001';
  end if;

  if v_preview.action = 'status' then
    if not identity.has_permission('orders.status.update') then
      raise exception 'missing permission: orders.status.update' using errcode = '42501';
    end if;
    v_target := v_preview.payload->>'target_status';
    perform orders.update_order_status(v_order.id, v_target, 'assistant-confirmed status change');
    insert into orders.order_events (order_id, event_type, payload)
    values (v_order.id, 'assistant.order.status', jsonb_build_object(
      'actor_user_id', v_uid, 'from_status', v_preview.expected_status,
      'to_status', v_target, 'approval', v_hash
    ));
    v_result := jsonb_build_object('ok', true, 'order_number', v_order.order_number,
      'old_status', v_preview.expected_status, 'new_status', v_target, 'reused', false);
  else
    if not identity.has_permission('orders.cancel') then
      raise exception 'missing permission: orders.cancel' using errcode = '42501';
    end if;
    v_reason := v_preview.payload->>'reason';
    perform orders.cancel_order(v_order.id, v_reason);
    insert into orders.order_events (order_id, event_type, payload)
    values (v_order.id, 'assistant.order.cancel', jsonb_build_object(
      'actor_user_id', v_uid, 'from_status', v_preview.expected_status,
      'reason', v_reason, 'approval', v_hash
    ));
    perform identity.audit(
      'assistant.order.cancel', 'order', v_order.id,
      jsonb_build_object('status', v_preview.expected_status),
      jsonb_build_object('status', 'cancelled', 'reason', v_reason, 'approval', v_hash),
      v_order.branch_id
    );
    v_result := jsonb_build_object('ok', true, 'order_number', v_order.order_number,
      'old_status', v_preview.expected_status, 'new_status', 'cancelled', 'reused', false);
  end if;

  update orders.admin_assistant_order_action_previews
     set consumed_at = now(), result = v_result
   where token_hash = v_hash;
  return v_result;
end;
$$;

revoke all on function public.admin_assistant_order_action_preview(text, text, text, text) from public, anon;
revoke all on function public.admin_assistant_order_action_execute(text) from public, anon;
grant execute on function public.admin_assistant_order_action_preview(text, text, text, text) to authenticated;
grant execute on function public.admin_assistant_order_action_execute(text) to authenticated;
