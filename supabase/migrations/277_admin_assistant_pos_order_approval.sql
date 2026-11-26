-- Bind assistant-created POS orders to a short-lived, exact, authenticated
-- preview. The old direct assistant RPC is disabled after this migration.
create table if not exists orders.admin_assistant_pos_order_previews (
  token_hash text primary key check (char_length(token_hash) = 64),
  actor_user_id uuid not null,
  auth_session_id text not null default '',
  branch_id uuid not null references core.branches(id),
  table_id uuid not null references floor.tables(id),
  customer_id uuid not null,
  payment_method_id uuid not null references payments.payment_methods(id),
  lines jsonb not null check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) > 0),
  expected_total numeric not null check (expected_total >= 0),
  idempotency_key text not null check (char_length(idempotency_key) between 1 and 120),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  result jsonb
);

alter table orders.admin_assistant_pos_order_previews enable row level security;
revoke all on orders.admin_assistant_pos_order_previews from public, anon, authenticated;

create or replace function public.admin_assistant_pos_order_preview(
  p_branch_id uuid,
  p_lines jsonb,
  p_payment_method_id uuid,
  p_idempotency_key text,
  p_table_id uuid,
  p_customer_id uuid,
  p_expected_total numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_token text;
  v_session text := coalesce(auth.jwt()->>'session_id', '');
  v_expires timestamptz := now() + interval '5 minutes';
begin
  if auth.uid() is null or not identity.is_staff()
     or not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if p_branch_id is null or not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0
     or p_table_id is null or p_customer_id is null
     or p_payment_method_id is null
     or p_expected_total is null or p_expected_total < 0
     or nullif(btrim(p_idempotency_key), '') is null
     or char_length(p_idempotency_key) > 120 then
    raise exception 'incomplete order preview' using errcode = '22023';
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  delete from orders.admin_assistant_pos_order_previews
   where created_at < now() - interval '7 days';
  insert into orders.admin_assistant_pos_order_previews (
    token_hash, actor_user_id, auth_session_id, branch_id, table_id,
    customer_id, payment_method_id, lines, expected_total, idempotency_key,
    expires_at
  ) values (
    encode(extensions.digest(convert_to(v_token, 'UTF8'), 'sha256'), 'hex'),
    auth.uid(), v_session, p_branch_id, p_table_id, p_customer_id,
    p_payment_method_id, p_lines, p_expected_total, btrim(p_idempotency_key),
    v_expires
  );
  return jsonb_build_object(
    'approval_token', v_token,
    'expected_total', p_expected_total,
    'expires_at', v_expires
  );
end;
$fn$;

create or replace function public.admin_assistant_pos_order_execute(p_approval_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_session text := coalesce(auth.jwt()->>'session_id', '');
  v_hash text;
  v_preview orders.admin_assistant_pos_order_previews%rowtype;
  v_result jsonb;
  v_actual numeric;
begin
  if v_uid is null or not identity.is_staff()
     or not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if p_approval_token is null or char_length(p_approval_token) <> 64 then
    raise exception 'invalid approval token' using errcode = '42501';
  end if;
  v_hash := encode(extensions.digest(convert_to(p_approval_token, 'UTF8'), 'sha256'), 'hex');
  select * into v_preview
    from orders.admin_assistant_pos_order_previews p
   where p.token_hash = v_hash
   for update;
  if not found or v_preview.actor_user_id <> v_uid
     or v_preview.auth_session_id <> v_session then
    raise exception 'approval does not belong to this user/session' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(v_preview.branch_id) then
    raise exception 'order branch out of scope' using errcode = '42501';
  end if;
  if v_preview.consumed_at is not null then
    return coalesce(v_preview.result, jsonb_build_object('ok', true, 'replayed', true));
  end if;
  if v_preview.expires_at <= now() then
    raise exception 'order preview expired; prepare a fresh preview' using errcode = '40001';
  end if;

  v_result := public.admin_pos_place_table_order(
    v_preview.branch_id,
    v_preview.lines,
    'dine_in',
    v_preview.payment_method_id,
    v_preview.idempotency_key,
    v_preview.table_id,
    null,
    v_preview.customer_id,
    null
  );
  v_actual := nullif(v_result->>'grand_total', '')::numeric;
  if v_actual is null or abs(v_actual - v_preview.expected_total) >= 0.01 then
    raise exception 'order price changed after preview; prepare a fresh preview'
      using errcode = '40001';
  end if;

  update orders.admin_assistant_pos_order_previews
     set consumed_at = now(), result = v_result
   where token_hash = v_hash;
  return v_result;
end;
$fn$;

comment on function public.admin_assistant_pos_order_preview(uuid, jsonb, uuid, text, uuid, uuid, numeric) is
  'Creates a five-minute, session-bound approval for the exact assistant POS order payload.';
comment on function public.admin_assistant_pos_order_execute(text) is
  'Executes an exact approved POS order once and rejects stale prices atomically.';

revoke all on function public.admin_assistant_pos_order_preview(uuid, jsonb, uuid, text, uuid, uuid, numeric) from public, anon;
revoke all on function public.admin_assistant_pos_order_execute(text) from public, anon;
grant execute on function public.admin_assistant_pos_order_preview(uuid, jsonb, uuid, text, uuid, uuid, numeric) to authenticated;
grant execute on function public.admin_assistant_pos_order_execute(text) to authenticated;

-- Close the direct authenticated write path from migration 274.
revoke all on function public.admin_assistant_pos_order_create(uuid, jsonb, uuid, text, uuid, uuid, numeric) from public, anon, authenticated;
notify pgrst, 'reload schema';
