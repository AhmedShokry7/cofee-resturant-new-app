-- Phase 1.3 test-only payment adapter. This has no effect until a dedicated
-- test customer is allowlisted and the phase13-test-payment function is called.
-- The Edge Function separately refuses to run outside project webzzasosevzymftgszn.

create table if not exists payments.phase13_test_customers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  run_id uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at)
);

alter table payments.phase13_test_customers enable row level security;
revoke all on payments.phase13_test_customers from public, anon, authenticated;
grant select, insert, update, delete on payments.phase13_test_customers to service_role;

comment on table payments.phase13_test_customers is
  'Allowlist for dedicated Phase 1.3 test customers only; never populated in production.';

create table if not exists payments.phase13_test_identities (
  user_id uuid primary key references auth.users(id) on delete cascade,
  run_id uuid not null,
  identity_kind text not null check (identity_kind in (
    'customer', 'customer_denied', 'staff_reader', 'staff_denied'
  )),
  branch_id uuid references core.branches(id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at)
);
alter table payments.phase13_test_identities enable row level security;
revoke all on payments.phase13_test_identities from public, anon, authenticated;
grant select, insert, update, delete on payments.phase13_test_identities to service_role;

create or replace function payments.register_phase13_test_identity(
  p_user_id uuid,
  p_run_id uuid,
  p_identity_kind text,
  p_expires_at timestamptz,
  p_branch_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_email text;
  v_role_id uuid;
  v_role_code text;
  v_staff_id uuid;
  v_orders_read uuid;
begin
  if p_user_id is null or p_run_id is null
     or p_identity_kind not in ('customer','customer_denied','staff_reader','staff_denied')
     or p_expires_at <= now() or p_expires_at > now() + interval '48 hours' then
    raise exception 'invalid Phase 1.3 test identity registration' using errcode = '22023';
  end if;
  select u.email into v_email from auth.users u where u.id=p_user_id;
  if not found or v_email is null or lower(v_email) not like '%@example.invalid' then
    raise exception 'only newly provisioned .invalid test accounts can be registered' using errcode = '42501';
  end if;
  if exists (select 1 from identity.staff_members sm where sm.user_id=p_user_id)
     or exists (select 1 from payments.phase13_test_identities ti where ti.user_id=p_user_id) then
    raise exception 'identity is already in use; no existing account may be repurposed' using errcode = '23505';
  end if;

  if p_identity_kind='staff_reader' then
    if p_branch_id is null or not exists (
      select 1 from core.branches b
       where b.id=p_branch_id
         and b.settings->>'phase13_test_run_id'=p_run_id::text
         and b.is_active
    ) then
      raise exception 'a dedicated active Phase 1.3 test branch is required' using errcode = '22023';
    end if;
  elsif p_branch_id is not null then
    raise exception 'branch scope is only valid for the dedicated test reader' using errcode = '22023';
  end if;

  insert into payments.phase13_test_identities(user_id,run_id,identity_kind,branch_id,expires_at)
  values (p_user_id,p_run_id,p_identity_kind,p_branch_id,p_expires_at);

  if p_identity_kind='customer' then
    insert into payments.phase13_test_customers(user_id,run_id,expires_at)
    values (p_user_id,p_run_id,p_expires_at);
  elsif p_identity_kind in ('staff_reader','staff_denied') then
    insert into identity.staff_members(user_id,status,full_name,email,accepted_at)
    values (p_user_id,'active','Phase 1.3 Test Staff',v_email,now())
    returning id into v_staff_id;
    if p_identity_kind='staff_reader' then
      v_role_code := 'phase13_invoice_reader_' || replace(p_run_id::text,'-','');
      insert into identity.roles(code,name_ar,name_en,description,is_system)
      values (v_role_code,'قارئ فواتير الاختبار','Phase 1.3 invoice test reader',
        'Temporary test-only role limited to orders.read on one dedicated test branch.',false)
      returning id into v_role_id;
      select p.id into v_orders_read from identity.permissions p where p.code='orders.read';
      if v_orders_read is null then raise exception 'orders.read permission is unavailable'; end if;
      insert into identity.role_permissions(role_id,permission_id) values (v_role_id,v_orders_read);
      insert into identity.staff_roles(staff_id,role_id,branch_id)
      values (v_staff_id,v_role_id,p_branch_id);
    end if;
  end if;
end;
$fn$;
revoke all on function payments.register_phase13_test_identity(uuid,uuid,text,timestamptz,uuid) from public, anon, authenticated;
grant execute on function payments.register_phase13_test_identity(uuid,uuid,text,timestamptz,uuid) to service_role;

create or replace function payments.complete_phase13_test_payment(
  p_order_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
  v_payment payments.payment_transactions%rowtype;
  v_ref text;
begin
  if p_order_id is null or p_actor_user_id is null then
    raise exception 'order and authenticated test customer are required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from payments.phase13_test_customers t
     where t.user_id = p_actor_user_id and t.expires_at > now()
  ) then
    raise exception 'test payment harness is not enabled for this identity' using errcode = '42501';
  end if;

  select * into v_order
    from orders.orders o
   where o.id = p_order_id and o.user_id = p_actor_user_id
   for update;
  if not found then
    raise exception 'test order not found for authenticated customer' using errcode = 'P0002';
  end if;

  v_ref := 'phase13-test:' || p_order_id::text;
  select * into v_payment
    from payments.payment_transactions pt
   where pt.provider = 'codex_phase13_test'
     and pt.order_id = p_order_id
   order by pt.created_at desc
   limit 1
   for update;
  if found then
    if v_payment.status <> 'captured' or not v_payment.verified_by_server then
      raise exception 'test payment transaction is in an unexpected state' using errcode = '55000';
    end if;
    return jsonb_build_object(
      'order_id', p_order_id,
      'payment_transaction_id', v_payment.id,
      'provider', 'codex_phase13_test',
      'provider_reference', v_payment.provider_reference,
      'status', v_payment.status,
      'verified_by_server', v_payment.verified_by_server,
      'simulated_test_payment', true,
      'idempotent_replay', true
    );
  end if;

  if v_order.status = 'cancelled'
     or v_order.grand_total <= 0
     or v_order.payment_status not in ('unpaid', 'pending')
     or v_order.tax_registration_status_snapshot <> 'registered'
     or v_order.seller_snapshot is null
     or coalesce(v_order.seller_snapshot->>'legal_name', '') = ''
     or coalesce(v_order.seller_snapshot->>'vat_number', '') !~ '^[0-9]{15}$' then
    raise exception 'order is not eligible for Phase 1.3 simplified invoice test' using errcode = '22023';
  end if;
  if not exists (select 1 from orders.order_items oi where oi.order_id = p_order_id) then
    raise exception 'test order must contain at least one line' using errcode = '22023';
  end if;

  insert into payments.payment_transactions (
    order_id, provider, provider_reference, amount, currency_code,
    status, paid_at, verified_by_server
  ) values (
    p_order_id, 'codex_phase13_test', v_ref, v_order.grand_total,
    coalesce(v_order.currency_code, 'SAR'), 'pending', null, false
  ) returning * into v_payment;

  -- Simulated capture is performed only by this server-side test adapter.
  -- It does not assert or imitate a Tap signature or real provider payment.
  update payments.payment_transactions
     set status = 'captured', verified_by_server = true,
         paid_at = now(), updated_at = now()
   where id = v_payment.id
   returning * into v_payment;

  update orders.orders
     set payment_status = 'paid'
   where id = p_order_id and user_id = p_actor_user_id;

  insert into payments.payment_events (provider, event_id, charge_id, payload)
  values (
    'codex_phase13_test', v_ref || ':captured', v_ref,
    jsonb_build_object(
      'provider', 'codex_phase13_test',
      'test_only', true,
      'simulated_capture', true,
      'payment_transaction_id', v_payment.id,
      'order_id', p_order_id,
      'amount', v_payment.amount,
      'currency_code', v_payment.currency_code
    )
  ) on conflict (provider, event_id) do nothing;

  return jsonb_build_object(
    'order_id', p_order_id,
    'payment_transaction_id', v_payment.id,
    'provider', 'codex_phase13_test',
    'provider_reference', v_payment.provider_reference,
    'status', v_payment.status,
    'verified_by_server', v_payment.verified_by_server,
    'simulated_test_payment', true,
    'idempotent_replay', v_reused
  );
end;
$fn$;

revoke all on function payments.complete_phase13_test_payment(uuid, uuid) from public, anon, authenticated;
grant execute on function payments.complete_phase13_test_payment(uuid, uuid) to service_role;

comment on function payments.complete_phase13_test_payment(uuid, uuid) is
  'Test-only simulated capture for allowlisted dedicated test customers. Service-role only; caller must independently enforce the exact authorized test project and a real GoTrue session.';
