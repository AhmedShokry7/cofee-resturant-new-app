-- Isolated seller/tax snapshots for one Phase 1.3 test run. This migration
-- never writes core.brands or core.tax_configuration_history.
begin;

create table payments.phase13_test_seller_profiles (
  run_id uuid primary key,
  branch_id uuid not null unique references core.branches(id) on delete restrict,
  seller_label text not null,
  address_label text not null,
  tax_rate numeric(5,2) not null check (tax_rate between 0 and 100),
  tax_included boolean not null default false,
  delivery_fee_taxable boolean not null default true,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (expires_at > created_at),
  check (seller_label like 'TEST ONLY%'),
  check (address_label like 'TEST ONLY%')
);
alter table payments.phase13_test_seller_profiles enable row level security;
revoke all on payments.phase13_test_seller_profiles from public, anon, authenticated;
grant select, insert, update, delete on payments.phase13_test_seller_profiles to service_role;

-- Explicitly synthetic calculation profile; it contains no legal seller or
-- VAT registration identifiers and expires automatically.
insert into payments.phase13_test_seller_profiles
  (run_id, branch_id, seller_label, address_label, tax_rate, expires_at)
values
  ('b105bd82-18df-4e6a-9b10-306d5ed5e1bc',
   '10dbfb03-ed35-4a79-9116-c44c7bb0ec66',
   'TEST ONLY — NOT A LEGAL SELLER',
   'TEST ONLY — NOT A REAL ADDRESS', 15.00, now() + interval '14 days');

alter table orders.orders add column test_only boolean not null default false;
alter table orders.orders add column test_run_id uuid
  references payments.phase13_test_seller_profiles(run_id) on delete restrict;
alter table orders.orders add constraint orders_test_run_marker_check
  check ((test_only and test_run_id is not null) or (not test_only and test_run_id is null));
alter table orders.invoices add column test_only boolean not null default false;
alter table orders.invoices add column test_run_id uuid
  references payments.phase13_test_seller_profiles(run_id) on delete restrict;
alter table orders.invoices add constraint invoices_test_run_marker_check
  check ((test_only and test_run_id is not null) or (not test_only and test_run_id is null));
alter table orders.invoices drop constraint invoices_invoice_type_check;
alter table orders.invoices add constraint invoices_invoice_type_check
  check (invoice_type in ('receipt','simplified','standard','test_simplified'));

-- Permit the isolated marker in the immutable order snapshot's status field.
do $block$
declare c record;
begin
  for c in select conname from pg_constraint
   where conrelid='orders.orders'::regclass and contype='c'
     and pg_get_constraintdef(oid) ilike '%tax_registration_status_snapshot%'
  loop execute format('alter table orders.orders drop constraint %I',c.conname); end loop;
end;
$block$;
alter table orders.orders add constraint orders_tax_registration_snapshot_check
  check (tax_registration_status_snapshot in ('unconfigured','unregistered','registered','test_only'));
do $block$
declare c record;
begin
  for c in select conname from pg_constraint
   where conrelid='orders.orders'::regclass and contype='c'
     and pg_get_constraintdef(oid) ilike '%tax_treatment_snapshot%'
  loop execute format('alter table orders.orders drop constraint %I',c.conname); end loop;
end;
$block$;
alter table orders.orders add constraint orders_tax_treatment_snapshot_check
  check (tax_treatment_snapshot in ('configuration_unverified','not_registered','standard','test_only'));

create sequence orders.phase13_test_invoice_number_seq;
revoke all on sequence orders.phase13_test_invoice_number_seq from public, anon, authenticated;
grant usage, select on sequence orders.phase13_test_invoice_number_seq to service_role;

-- A test-branch order is only possible for a currently allowlisted dedicated
-- test customer, and receives its isolated seller/tax snapshot at insertion.
create or replace function orders.snapshot_order_tax()
returns trigger language plpgsql security definer set search_path = '' as $fn$
declare
  v_brand core.brands%rowtype;
  v_branch core.branches%rowtype;
  v_profile payments.phase13_test_seller_profiles%rowtype;
  v_rate numeric(5,2);
  v_included boolean;
  v_delivery_taxable boolean;
  v_amounts record;
  v_run uuid;
begin
  select * into v_branch from core.branches where id=new.branch_id;
  if not found then raise exception 'order branch is unavailable' using errcode='23503'; end if;
  v_run := nullif(v_branch.settings->>'phase13_test_run_id','')::uuid;
  if v_run is not null then
    select * into v_profile from payments.phase13_test_seller_profiles p
     where p.run_id=v_run and p.branch_id=new.branch_id and p.expires_at>now();
    if not found or new.user_id is null or not exists (
      select 1 from payments.phase13_test_customers c
       where c.user_id=new.user_id and c.run_id=v_run and c.expires_at>now()
    ) or not exists (
      select 1 from payments.phase13_test_identities i
       where i.user_id=new.user_id and i.run_id=v_run
         and i.identity_kind='customer' and i.expires_at>now()
    ) then
      raise exception 'dedicated Phase 1.3 test identity or run is unavailable' using errcode='42501';
    end if;
    new.test_only := true;
    new.test_run_id := v_run;
    new.seller_snapshot := jsonb_build_object(
      'test_only',true,'test_run_id',v_run,'seller_label',v_profile.seller_label,
      'address_label',v_profile.address_label,'legal_name',null,'vat_number',null,
      'tax_identity_status','not_a_legal_registration');
    v_rate:=v_profile.tax_rate; v_included:=v_profile.tax_included;
    v_delivery_taxable:=v_profile.delivery_fee_taxable;
    new.tax_registration_status_snapshot:='test_only';
    new.tax_treatment_snapshot:='test_only';
    new.tax_configuration_version_snapshot:=0;
  else
    select * into v_brand from core.brands order by created_at limit 1;
    if not found then raise exception 'tax configuration is unavailable' using errcode='55000'; end if;
    new.seller_snapshot := jsonb_build_object(
      'legal_name', nullif(btrim(v_branch.legal_name), ''),
      'name_ar', v_branch.name_ar, 'name_en', v_branch.name_en,
      'vat_number', nullif(btrim(v_branch.vat_number), ''), 'branch_code', v_branch.code,
      'address', v_branch.address, 'address_ar', v_branch.address_ar,
      'address_en', v_branch.address_en, 'phone', v_branch.phone);
    if v_brand.tax_registration_status='unregistered' and v_brand.tax_rate<>0 then
      raise exception 'unregistered business must configure a zero tax rate' using errcode='23514';
    end if;
    if v_brand.tax_registration_status='registered' and v_brand.tax_rate<=0 then
      raise exception 'registered business must configure its applicable positive VAT rate' using errcode='23514';
    end if;
    v_rate:=v_brand.tax_rate; v_included:=v_brand.tax_included;
    v_delivery_taxable:=v_brand.delivery_fee_taxable;
    new.tax_registration_status_snapshot:=v_brand.tax_registration_status;
    new.tax_treatment_snapshot:=case v_brand.tax_registration_status
      when 'registered' then 'standard' when 'unregistered' then 'not_registered'
      else 'configuration_unverified' end;
    new.tax_configuration_version_snapshot:=v_brand.tax_configuration_version;
  end if;
  new.tax_rate_snapshot:=v_rate;
  new.tax_included_snapshot:=v_included;
  new.delivery_fee_taxable_snapshot:=v_delivery_taxable;
  new.tax_calculated_at:=now();
  select * into v_amounts from orders.calculate_vat_amounts(
    new.subtotal,new.discount_total,new.delivery_fee,v_rate,v_included,v_delivery_taxable);
  new.taxable_base:=v_amounts.taxable_base;
  new.vat_amount:=v_amounts.vat_amount;
  new.tax_total:=v_amounts.tax_total;
  new.grand_total:=v_amounts.grand_total;
  return new;
end;
$fn$;

-- Invoice insert interceptor makes test issuance visibly distinct and keeps
-- test numbers outside the official invoice sequence.
create or replace function orders.mark_phase13_test_invoice()
returns trigger language plpgsql security definer set search_path = '' as $fn$
declare v_order orders.orders%rowtype; v_profile payments.phase13_test_seller_profiles%rowtype;
begin
  select * into v_order from orders.orders where id=new.order_id;
  if not found or not v_order.test_only then return new; end if;
  select * into v_profile from payments.phase13_test_seller_profiles p
   where p.run_id=v_order.test_run_id and p.branch_id=v_order.branch_id and p.expires_at>now();
  if not found then raise exception 'Phase 1.3 test run is expired or unavailable' using errcode='55000'; end if;
  new.test_only:=true; new.test_run_id:=v_order.test_run_id;
  new.invoice_type:='test_simplified';
  if new.invoice_number not like 'TEST-P13-%' then
    new.invoice_number:='TEST-P13-'||substr(replace(v_order.test_run_id::text,'-',''),1,8)||'-'||
      lpad(nextval('orders.phase13_test_invoice_number_seq')::text,8,'0');
  end if;
  new.snapshot:=new.snapshot || jsonb_build_object(
    'test_only',true,'test_run_id',v_order.test_run_id,
    'invoice_type','test_simplified','document_watermark','TEST ONLY — NOT A TAX INVOICE',
    'tax_registration_status','test_only','tax_treatment','test_only',
    'test_qr_structure_only',true,
    'seller',jsonb_build_object('seller_label',v_profile.seller_label,
      'address_label',v_profile.address_label,'tax_identity_status','not_a_legal_registration'));
  new.snapshot_sha256:=encode(extensions.digest(convert_to(new.snapshot::text,'UTF8'),'sha256'),'hex');
  return new;
end;
$fn$;
revoke all on function orders.mark_phase13_test_invoice() from public, anon, authenticated;
drop trigger if exists tr_mark_phase13_test_invoice on orders.invoices;
create trigger tr_mark_phase13_test_invoice before insert on orders.invoices
for each row execute function orders.mark_phase13_test_invoice();

-- Server-role RPC is callable only through the project-pinned harness, after
-- it has verified an actual GoTrue bearer session. Run and identity expiry are
-- checked again in SQL. No provider is contacted and no Tap rows are created.
create or replace function payments.complete_phase13_test_payment(p_order_id uuid,p_actor_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_order orders.orders%rowtype; v_payment payments.payment_transactions%rowtype;
  v_profile payments.phase13_test_seller_profiles%rowtype; v_amounts record;
  v_ref text;
begin
  if p_order_id is null or p_actor_user_id is null then
    raise exception 'order and authenticated test customer are required' using errcode='22023';
  end if;
  select * into v_order from orders.orders where id=p_order_id and user_id=p_actor_user_id for update;
  if not found or not v_order.test_only or v_order.test_run_id is null then
    raise exception 'test order not found for authenticated customer' using errcode='P0002';
  end if;
  select * into v_profile from payments.phase13_test_seller_profiles p
   where p.run_id=v_order.test_run_id and p.branch_id=v_order.branch_id and p.expires_at>now();
  if not found or not exists (select 1 from payments.phase13_test_customers c
       where c.user_id=p_actor_user_id and c.run_id=v_order.test_run_id and c.expires_at>now())
     or not exists (select 1 from payments.phase13_test_identities i
       where i.user_id=p_actor_user_id and i.run_id=v_order.test_run_id
         and i.identity_kind='customer' and i.expires_at>now()) then
    raise exception 'Phase 1.3 test identity or run is expired or unauthorized' using errcode='42501';
  end if;
  v_ref:='phase13-test:'||p_order_id::text;
  select * into v_payment from payments.payment_transactions
   where provider='codex_phase13_test' and order_id=p_order_id
   order by created_at desc limit 1 for update;
  if found then
    if v_payment.status<>'captured' or not v_payment.verified_by_server then
      raise exception 'test payment transaction is in an unexpected state' using errcode='55000';
    end if;
    return jsonb_build_object('order_id',p_order_id,'payment_transaction_id',v_payment.id,
      'provider','codex_phase13_test','provider_reference',v_payment.provider_reference,
      'status',v_payment.status,'verified_by_server',true,'simulated_test_payment',true,
      'idempotent_replay',true);
  end if;
  if v_order.status='cancelled' or v_order.grand_total<=0
     or v_order.payment_status not in ('unpaid','pending')
     or not exists(select 1 from orders.order_items where order_id=p_order_id) then
    raise exception 'test order is not eligible for simulated capture' using errcode='22023';
  end if;
  select * into v_amounts from orders.calculate_vat_amounts(
    v_order.subtotal,v_order.discount_total,v_order.delivery_fee,v_profile.tax_rate,
    v_profile.tax_included,v_profile.delivery_fee_taxable);
  update orders.orders set
    seller_snapshot=jsonb_build_object('test_only',true,'test_run_id',v_order.test_run_id,
      'seller_label',v_profile.seller_label,'address_label',v_profile.address_label,
      'tax_identity_status','not_a_legal_registration'),
    tax_rate_snapshot=v_profile.tax_rate,tax_included_snapshot=v_profile.tax_included,
    tax_registration_status_snapshot='test_only',tax_treatment_snapshot='test_only',
    tax_configuration_version_snapshot=0,delivery_fee_taxable_snapshot=v_profile.delivery_fee_taxable,
    taxable_base=v_amounts.taxable_base,vat_amount=v_amounts.vat_amount,
    tax_total=v_amounts.tax_total,grand_total=v_amounts.grand_total,tax_calculated_at=now()
   where id=p_order_id returning * into v_order;
  insert into payments.payment_transactions(order_id,provider,provider_reference,amount,currency_code,status,paid_at,verified_by_server)
   values(p_order_id,'codex_phase13_test',v_ref,v_order.grand_total,coalesce(v_order.currency_code,'SAR'),'captured',now(),true)
   returning * into v_payment;
  update orders.orders set payment_status='paid' where id=p_order_id;
  insert into payments.payment_events(provider,event_id,charge_id,payload)
   values('codex_phase13_test',v_ref||':captured',v_ref,
    jsonb_build_object('provider','codex_phase13_test','test_only',true,'simulated_capture',true,
      'payment_transaction_id',v_payment.id,'order_id',p_order_id,'amount',v_payment.amount,
      'currency_code',v_payment.currency_code)) on conflict(provider,event_id) do nothing;
  return jsonb_build_object('order_id',p_order_id,'payment_transaction_id',v_payment.id,
    'provider','codex_phase13_test','provider_reference',v_payment.provider_reference,
    'status',v_payment.status,'verified_by_server',true,'simulated_test_payment',true,
    'idempotent_replay',false);
end;
$fn$;
revoke all on function payments.complete_phase13_test_payment(uuid,uuid) from public, anon, authenticated;
grant execute on function payments.complete_phase13_test_payment(uuid,uuid) to service_role;

comment on table payments.phase13_test_seller_profiles is
  'Run-scoped synthetic seller and tax calculation profile; never a legal registration or production tax configuration.';
comment on column orders.invoices.test_only is 'Excluded from real VAT and financial transaction reports.';

create or replace function payments.reject_tap_for_phase13_test_order()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  if new.order_id is not null and new.provider='tap' and exists (
    select 1 from orders.orders o where o.id=new.order_id and o.test_only
  ) then
    raise exception 'Phase 1.3 test orders cannot use Tap' using errcode='42501';
  end if;
  return new;
end;
$fn$;
revoke all on function payments.reject_tap_for_phase13_test_order() from public, anon, authenticated;
drop trigger if exists tr_reject_tap_for_phase13_test_order on payments.payment_transactions;
create trigger tr_reject_tap_for_phase13_test_order
before insert or update of order_id,provider on payments.payment_transactions
for each row execute function payments.reject_tap_for_phase13_test_order();


-- Keep all operational totals clear of Phase 1.3 records.
create or replace function orders.issue_invoice_for_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
  v_branch core.branches%rowtype;
  v_profile identity.profiles%rowtype;
  v_snapshot jsonb;
  v_invoice_id uuid;
  v_invoice_number text;
  v_now timestamptz := now();
begin
  select * into v_order from orders.orders where id = p_order_id for update;
  if not found or v_order.status = 'cancelled'
     or v_order.payment_status <> 'paid' then
    return null;
  end if;

  select id into v_invoice_id from orders.invoices where order_id = p_order_id;
  if found then return v_invoice_id; end if;

  select * into v_branch from core.branches where id = v_order.branch_id;
  if not v_order.test_only and v_order.tax_registration_status_snapshot = 'registered'
     and (nullif(btrim(v_order.seller_snapshot->>'legal_name'), '') is null
          or nullif(btrim(v_order.seller_snapshot->>'vat_number'), '') is null) then
    raise exception 'registered branch needs legal name and VAT registration number before invoice issuance'
      using errcode = '23514';
  end if;
  if v_order.user_id is not null then
    select * into v_profile from identity.profiles where id = v_order.user_id;
  end if;

  v_snapshot := jsonb_build_object(
    'invoice_type', case when v_order.test_only then 'test_simplified'
                         when v_order.tax_registration_status_snapshot = 'registered'
                         then 'simplified' else 'receipt' end,
    'issued_at', v_now,
    'source', jsonb_build_object('order_id', v_order.id, 'order_number', v_order.order_number,
      'payment_status', v_order.payment_status, 'order_source', v_order.order_source),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'payment_id', pt.id, 'provider', pt.provider,
        'provider_reference', pt.provider_reference, 'amount', pt.amount,
        'currency_code', pt.currency_code, 'status', pt.status
      ) order by pt.created_at, pt.id)
        from payments.payment_transactions pt where pt.order_id = v_order.id
    ), '[]'::jsonb),
    'seller', v_order.seller_snapshot,
    'branch', jsonb_build_object('id', v_branch.id,
      'code', v_order.seller_snapshot->>'branch_code',
      'name_ar', v_order.seller_snapshot->>'name_ar',
      'name_en', v_order.seller_snapshot->>'name_en',
      'address_ar', v_order.seller_snapshot->>'address_ar',
      'address_en', v_order.seller_snapshot->>'address_en'),
    'buyer', case when v_order.user_id is null then null else jsonb_build_object(
      'customer_id', v_profile.id, 'name', v_profile.full_name,
      'email', v_profile.email, 'phone', v_profile.phone) end,
    'currency_code', v_order.currency_code,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', oi.product_id, 'sku', oi.sku_snapshot,
        'name_ar', oi.product_name_ar, 'name_en', oi.product_name_en,
        'option_group_ar', oi.option_group_name_ar,
        'option_group_en', oi.option_group_name_en,
        'quantity', oi.quantity, 'unit_price', oi.unit_price,
        'line_total', oi.line_total, 'discount', oi.product_discount_total,
        'options', coalesce((select jsonb_agg(jsonb_build_object(
          'name_ar', oio.option_name_ar, 'name_en', oio.option_name_en,
          'price_delta', oio.price_delta) order by oio.id)
          from orders.order_item_options oio where oio.order_item_id = oi.id), '[]'::jsonb)
      ) order by oi.created_at, oi.id)
      from orders.order_items oi where oi.order_id = v_order.id
    ), '[]'::jsonb),
    'subtotal', v_order.subtotal, 'discount_total', v_order.discount_total,
    'delivery_fee', v_order.delivery_fee,
    'taxable_base', v_order.taxable_base, 'vat_amount', v_order.vat_amount,
    'tax_total', v_order.tax_total, 'tax_rate', v_order.tax_rate_snapshot,
    'tax_included', v_order.tax_included_snapshot,
    'tax_registration_status', v_order.tax_registration_status_snapshot,
    'tax_treatment', v_order.tax_treatment_snapshot,
    'tax_configuration_version', v_order.tax_configuration_version_snapshot,
    'grand_total', v_order.grand_total
  );
  v_invoice_number := case when v_order.test_only then
    'TEST-P13-'||substr(replace(v_order.test_run_id::text,'-',''),1,8)||'-'||
      lpad(nextval('orders.phase13_test_invoice_number_seq')::text,8,'0')
    else 'INV-' || to_char(v_now, 'YYYY') || '-' ||
      lpad(nextval('orders.invoice_number_seq')::text, 8, '0') end;

  insert into orders.invoices (
    invoice_number, order_id, branch_id, invoice_type, issued_at,
    currency_code, snapshot, snapshot_sha256, created_by
  ) values (
    v_invoice_number, v_order.id, v_order.branch_id,
    case when v_order.test_only then 'test_simplified'
      when v_order.tax_registration_status_snapshot = 'registered'
      then 'simplified' else 'receipt' end, v_now,
    v_order.currency_code, v_snapshot,
    encode(extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'), 'hex'),
    auth.uid()
  ) on conflict (order_id) do update set order_id = excluded.order_id
  returning id into v_invoice_id;

  return v_invoice_id;
end;
$fn$;
create or replace function public.admin_tax_report(
  p_from timestamptz,
  p_until timestamptz,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;
  if p_from is null or p_until is null or p_until <= p_from then
    raise exception 'valid reporting period required' using errcode = '22023';
  end if;
  select jsonb_build_object(
    'from', p_from, 'until', p_until,
    'branches', coalesce(jsonb_agg(jsonb_build_object(
      'branch_id', rows.branch_id,
      'invoice_count', rows.invoice_count,
      'gross_sales', rows.gross_sales,
      'taxable_base', rows.taxable_base,
      'vat_amount', rows.vat_amount,
      'adjustment_amount', rows.adjustment_amount,
      'adjustment_vat_amount', rows.adjustment_vat_amount,
      'successful_refunds', rows.successful_refunds,
      'net_after_adjustments', round(rows.gross_sales - rows.adjustment_amount, 2),
      'net_vat_after_adjustments', round(rows.vat_amount - rows.adjustment_vat_amount, 2)
    ) order by rows.branch_id), '[]'::jsonb)
  ) into v_result
  from (
    select i.branch_id,
      count(distinct i.id)::integer as invoice_count,
      coalesce(sum((i.snapshot->>'grand_total')::numeric),0)::numeric(12,2) as gross_sales,
      coalesce(sum(case when i.snapshot->>'tax_registration_status' = 'registered'
        then (i.snapshot->>'taxable_base')::numeric else 0 end),0)::numeric(12,2) as taxable_base,
      coalesce(sum(case when i.snapshot->>'tax_registration_status' = 'registered'
        then (i.snapshot->>'vat_amount')::numeric else 0 end),0)::numeric(12,2) as vat_amount,
      coalesce(sum(a.signed_amount),0)::numeric(12,2) as adjustment_amount,
      coalesce(sum(a.signed_vat),0)::numeric(12,2) as adjustment_vat_amount,
      coalesce(sum(r.refund_amount),0)::numeric(12,2) as successful_refunds
    from orders.invoices i
    join orders.orders o on o.id = i.order_id
    left join lateral (
      select sum(case when x.adjustment_type = 'credit_note' then x.amount else -x.amount end) as signed_amount,
             sum(case when x.adjustment_type = 'credit_note' then x.vat_amount else -x.vat_amount end) as signed_vat
        from orders.invoice_adjustments x
       where x.invoice_id = i.id and x.issued_at >= p_from and x.issued_at < p_until
    ) a on true
    left join lateral (
      select sum(x.confirmed_amount) as refund_amount
        from payments.payment_refunds x
       where x.order_id = o.id and x.status = 'succeeded'
         and x.completed_at >= p_from and x.completed_at < p_until
    ) r on true
    where i.test_only is not true and i.issued_at >= p_from and i.issued_at < p_until
      and identity.can_manage_branch(i.branch_id)
      and (p_branch_id is null or i.branch_id = p_branch_id)
    group by i.branch_id
  ) rows;
  return v_result;
end;
$fn$;
create or replace function public.admin_financial_reconciliation(
  p_from timestamptz, p_until timestamptz, p_branch_id uuid default null
)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;
  if p_from is null or p_until is null or p_until <= p_from then
    raise exception 'valid reporting period required' using errcode = '22023';
  end if;

  select jsonb_build_object(
    'from', p_from, 'until', p_until,
    'orders', jsonb_build_object(
      'paid_count', (select count(*) from orders.orders o
        where o.test_only is not true and o.payment_status in ('paid','refunded') and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)),
      'paid_total', coalesce((select sum(o.grand_total) from orders.orders o
        where o.test_only is not true and o.payment_status in ('paid','refunded') and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)),0),
      'missing_invoice_count', (select count(*) from orders.orders o
        where o.test_only is not true and o.payment_status in ('paid','refunded') and o.status <> 'cancelled'
          and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)
          and not exists (select 1 from orders.invoices i where i.order_id = o.id)),
      'missing_invoice_order_ids', coalesce((select jsonb_agg(o.id order by o.placed_at)
        from orders.orders o where o.test_only is not true and o.payment_status in ('paid','refunded') and o.status <> 'cancelled'
          and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)
          and not exists (select 1 from orders.invoices i where i.order_id = o.id)), '[]'::jsonb)
    ),
    'invoice_documents', jsonb_build_object(
      'not_ready_count', (select count(*) from orders.invoices i
        join orders.orders o on o.id=i.order_id left join orders.invoice_documents d on d.invoice_id=i.id
        where i.test_only is not true and i.issued_at>=p_from and i.issued_at<p_until and coalesce(d.status,'pending')<>'ready'
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),
      'failed_count', (select count(*) from orders.invoice_documents d join orders.invoices i on i.id=d.invoice_id
        where i.test_only is not true and d.status='failed' and i.issued_at>=p_from and i.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id))
    ),
    'duplicate_invoice_orders', coalesce((select jsonb_agg(q.order_id) from (
      select i.order_id from orders.invoices i where i.test_only is not true and i.issued_at>=p_from and i.issued_at<p_until
        and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)
      group by i.order_id having count(*)>1
    ) q),'[]'::jsonb),
    'payment_invoice_mismatches', coalesce((
      select jsonb_agg(jsonb_build_object('order_id',x.order_id,'invoice_total',x.invoice_total,
        'captured_total',x.captured_total,'difference',round(x.captured_total-x.invoice_total,2)) order by x.order_id)
      from (
        select i.order_id, (i.snapshot->>'grand_total')::numeric as invoice_total,
          coalesce(sum(pt.amount) filter (where o.test_only is not true and pt.status in ('captured','refunded')),0) as captured_total
        from orders.invoices i join orders.orders o on o.id=i.order_id
        left join payments.payment_transactions pt on pt.order_id=o.id
        where i.test_only is not true and i.issued_at >= p_from and i.issued_at < p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)
        group by i.order_id,i.snapshot
        having abs(coalesce(sum(pt.amount) filter (where o.test_only is not true and pt.status in ('captured','refunded')),0)
          - (i.snapshot->>'grand_total')::numeric) >= 0.01
      ) x
    ), '[]'::jsonb),
    'vat_by_treatment', coalesce((
      select jsonb_agg(jsonb_build_object('tax_treatment',x.tax_treatment,
        'invoice_count',x.invoice_count,'taxable_base',x.taxable_base,'vat_amount',x.vat_amount)
        order by x.tax_treatment)
      from (select coalesce(i.snapshot->>'tax_treatment','unknown') tax_treatment,
        count(*) invoice_count,
        coalesce(sum((i.snapshot->>'taxable_base')::numeric),0) taxable_base,
        coalesce(sum((i.snapshot->>'vat_amount')::numeric),0) vat_amount
        from orders.invoices i where i.test_only is not true and i.issued_at >= p_from and i.issued_at < p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)
        group by coalesce(i.snapshot->>'tax_treatment','unknown')) x
    ), '[]'::jsonb),
    'refunds', jsonb_build_object(
      'requested_amount', coalesce((select sum(r.requested_amount) from payments.payment_refunds r
        join orders.orders o on o.id=r.order_id where r.requested_at >= p_from and r.requested_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),0),
      'confirmed_amount', coalesce((select sum(r.confirmed_amount) from payments.payment_refunds r
        join orders.orders o on o.id=r.order_id where o.test_only is not true and r.status='succeeded' and r.completed_at >= p_from and r.completed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),0),
      'fully_refunded_payment_count', (select count(*) from payments.payment_transactions pt
        join orders.orders o on o.id=pt.order_id where o.test_only is not true and pt.status='refunded'
          and pt.paid_at>=p_from and pt.paid_at<p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'partially_refunded_payment_count', (select count(*) from payments.payment_transactions pt
        join orders.orders o on o.id=pt.order_id where o.test_only is not true and pt.status='captured'
          and pt.refund_status='partially_refunded' and pt.paid_at>=p_from and pt.paid_at<p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'pending_count', (select count(*) from payments.payment_refunds r join orders.orders o on o.id=r.order_id
        where o.test_only is not true and r.status in ('pending','unknown') and r.requested_at>=p_from and r.requested_at<p_until
          and identity.can_manage_branch(o.branch_id)
          and (p_branch_id is null or o.branch_id=p_branch_id)),
      'failed_count', (select count(*) from payments.payment_refunds r join orders.orders o on o.id=r.order_id
        where o.test_only is not true and r.status='failed' and r.completed_at >= p_from and r.completed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'over_reserved_count', (select count(*) from (
        select pt.id from payments.payment_transactions pt join orders.orders o on o.id=pt.order_id
        join payments.payment_refunds r on r.payment_transaction_id=pt.id
        where o.test_only is not true and pt.status in ('captured','refunded') and identity.can_manage_branch(o.branch_id)
          and (p_branch_id is null or o.branch_id=p_branch_id)
        group by pt.id,pt.amount having sum(case when r.status='succeeded' then r.confirmed_amount
          when r.status in ('pending','unknown') then r.requested_amount else 0 end)>pt.amount
      ) q),
      'remaining_refundable_balance', coalesce((select sum(greatest(pt.amount-coalesce(rsv.reserved,0),0))
        from payments.payment_transactions pt join orders.orders o on o.id=pt.order_id
        left join lateral (select sum(case when r.status='succeeded' then r.confirmed_amount
          when r.status in ('pending','unknown') then r.requested_amount else 0 end) reserved
          from payments.payment_refunds r where r.payment_transaction_id=pt.id) rsv on true
        where o.test_only is not true and pt.status in ('captured','refunded') and identity.can_manage_branch(o.branch_id)
          and (p_branch_id is null or o.branch_id=p_branch_id)),0)
    ),
    'adjustments', jsonb_build_object(
      'credit_note_amount', coalesce((select sum(a.amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where i.test_only is not true and a.adjustment_type='credit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0),
      'credit_note_vat', coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where i.test_only is not true and a.adjustment_type='credit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0),
      'debit_note_amount', coalesce((select sum(a.amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where i.test_only is not true and a.adjustment_type='debit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0),
      'debit_note_vat', coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where i.test_only is not true and a.adjustment_type='debit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0)
    ),
    'net_sales', (select jsonb_build_object(
      'invoice_gross', coalesce(sum((i.snapshot->>'grand_total')::numeric),0),
      'invoice_taxable_base', coalesce(sum((i.snapshot->>'taxable_base')::numeric),0),
      'invoice_vat', coalesce(sum((i.snapshot->>'vat_amount')::numeric),0),
      'net_taxable_sales', coalesce(sum((i.snapshot->>'taxable_base')::numeric),0)
        - coalesce((select sum(a.amount-a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='credit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
        + coalesce((select sum(a.amount-a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='debit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0),
      'net_vat', coalesce(sum((i.snapshot->>'vat_amount')::numeric),0)
        - coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='credit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
        + coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='debit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
    ) from orders.invoices i where i.test_only is not true and i.issued_at>=p_from and i.issued_at<p_until
      and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id))
  ) into v_result;
  return v_result;
end;
$fn$;
create or replace function public.admin_dashboard_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_day_start timestamptz := (
    date_trunc('day', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  );
  v_yesterday_start timestamptz := v_day_start - interval '1 day';
  v_week_start timestamptz := v_day_start - interval '6 days';
  v_prev_week_start timestamptz := v_day_start - interval '13 days';
  v_series_start timestamptz := v_day_start - interval '29 days';
  v_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  );
  -- مثل 160 حرفيًا: الشهر السابق يُحسب من منتصف ليل الرياض وليس من منتصف ليل UTC.
  v_prev_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  ) - interval '1 month';
  v_company_scope boolean := identity.manages_all_branches();
  v_can_read_customers boolean := identity.has_permission('customers.read');
  v_can_write_settings boolean := identity.has_permission('settings.write');
  v_can_write_catalog boolean := identity.has_permission('catalog.product.write');
  v_target numeric;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  if v_company_scope then
    select nullif(s.value #>> '{}', '')::numeric
      into v_target
      from core.app_settings s
     where s.key = 'monthly_revenue_target';
  end if;

  return (
    with scoped as materialized (
      select
        o.id,
        o.order_number,
        o.status,
        o.grand_total,
        o.placed_at,
        o.fulfillment_type,
        o.user_id,
        o.pos_customer_id
      from orders.orders o
      where o.test_only is not true and identity.can_manage_branch(o.branch_id)
    ),
    customer_profiles as materialized (
      select p.id, p.created_at
      from identity.profiles p
      where not exists (
        select 1 from identity.staff_members sm where sm.user_id = p.id
      )
    ),
    totals as (
      select
        count(*) filter (
          where s.placed_at >= v_day_start and s.status <> 'cancelled'
        )::int as today_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_day_start and s.status <> 'cancelled'
        ), 0)::numeric as today_revenue,
        count(*) filter (
          where s.placed_at >= v_yesterday_start
            and s.placed_at < v_day_start
            and s.status <> 'cancelled'
        )::int as yesterday_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_yesterday_start
            and s.placed_at < v_day_start
            and s.status <> 'cancelled'
        ), 0)::numeric as yesterday_revenue,
        count(*) filter (
          where s.placed_at >= v_week_start and s.status <> 'cancelled'
        )::int as week_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_week_start and s.status <> 'cancelled'
        ), 0)::numeric as week_revenue,
        count(*) filter (
          where s.placed_at >= v_prev_week_start
            and s.placed_at < v_week_start
            and s.status <> 'cancelled'
        )::int as prev_week_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_prev_week_start
            and s.placed_at < v_week_start
            and s.status <> 'cancelled'
        ), 0)::numeric as prev_week_revenue,
        count(*) filter (
          where s.placed_at >= v_month_start and s.status <> 'cancelled'
        )::int as month_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_month_start and s.status <> 'cancelled'
        ), 0)::numeric as month_revenue,
        count(*) filter (
          where s.placed_at >= v_prev_month_start
            and s.placed_at < v_month_start
            and s.status <> 'cancelled'
        )::int as prev_month_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_prev_month_start
            and s.placed_at < v_month_start
            and s.status <> 'cancelled'
        ), 0)::numeric as prev_month_revenue,
        count(*) filter (
          where s.status not in ('completed', 'cancelled')
        )::int as active_orders,
        count(*)::int as total_orders
      from scoped s
    ),
    -- عدّ واحد للبروفايلات بدل أربعة: الأربعة كانت تمشي على نفس الصفوف
      -- أربع مرات لتجيب نفس السؤال بأربع نوافذ زمنية.
    customer_counts as (
      select
        count(*)::int as total_customers,
        count(*) filter (where c.created_at < v_month_start)::int
          as customers_before_month,
        count(*) filter (where c.created_at >= v_month_start)::int
          as new_customers,
        count(*) filter (
          where c.created_at >= v_prev_month_start
            and c.created_at < v_month_start
        )::int as previous_new_customers
      from customer_profiles c
    ),
    sales_series as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'date', to_char(d.day at time zone 'Asia/Riyadh', 'YYYY-MM-DD'),
        'revenue', d.revenue,
        'orders', d.orders
      ) order by d.day), '[]'::jsonb) as items
      from (
        select
          g.day,
          coalesce(sum(o.grand_total) filter (
            where o.status <> 'cancelled'
          ), 0)::numeric as revenue,
          count(o.id) filter (
            where o.status <> 'cancelled'
          )::int as orders
        from generate_series(
          v_series_start, v_day_start, interval '1 day'
        ) as g(day)
        left join scoped o
          on o.placed_at >= g.day
         and o.placed_at < g.day + interval '1 day'
        group by g.day
      ) d
    ),
    channels as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'channel', c.fulfillment_type,
        'orders', c.orders,
        'revenue', c.revenue
      ) order by c.orders desc), '[]'::jsonb) as items
      from (
        select
          s.fulfillment_type,
          count(*)::int as orders,
          coalesce(sum(s.grand_total), 0)::numeric as revenue
        from scoped s
        where s.placed_at >= v_series_start
          and s.status <> 'cancelled'
        group by s.fulfillment_type
      ) c
    ),
    top_products as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'product_name_ar', p.product_name_ar,
        'product_name_en', p.product_name_en,
        'image_url', p.image_url,
        'quantity', p.quantity,
        'revenue', p.revenue
      ) order by p.quantity desc, p.revenue desc), '[]'::jsonb) as items
      from (
        select
          oi.product_name_ar,
          oi.product_name_en,
          -- max لا arbitrary: منتج باعه طلبان بصورة قديمة وواحد بصورة جديدة
          -- يجب أن يعطي نفس السطر نفس الصورة في كل مرة تُفتح فيها اللوحة.
          max(oi.image_snapshot) as image_url,
          sum(oi.quantity)::int as quantity,
          coalesce(sum(oi.line_total), 0)::numeric as revenue
        from orders.order_items oi
        join scoped o on o.id = oi.order_id
        where o.placed_at >= v_week_start
          and o.status <> 'cancelled'
        group by oi.product_name_ar, oi.product_name_en
        order by sum(oi.quantity) desc, coalesce(sum(oi.line_total), 0) desc
        limit 5
      ) p
    ),
    recent_orders as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'order_number', r.order_number,
        'customer_name', r.customer_name,
        'status', r.status,
        'fulfillment_type', r.fulfillment_type,
        'grand_total', r.grand_total,
        'items_count', r.items_count,
        'placed_at', r.placed_at
      ) order by r.placed_at desc), '[]'::jsonb) as items
      from (
        select
          s.id,
          s.order_number,
          s.status,
          s.fulfillment_type,
          s.grand_total,
          s.placed_at,
          coalesce(p.full_name, pc.full_name) as customer_name,
          (
            select count(*)::int
            from orders.order_items oi
            where oi.order_id = s.id
          ) as items_count
        from scoped s
        left join identity.profiles p on p.id = s.user_id
        left join orders.pos_customers pc on pc.id = s.pos_customer_id
        order by s.placed_at desc
        limit 6
      ) r
    ),
    -- خطوة لا تُعرض لمن لا يملك فعلها: لا يُقال لكاشير «ارفع صورة فرعك» وهو
    -- لا يستطيع كتابتها، وإلا صار العدّاد «٢/٤» كاذبًا بالنسبة له لا ناقصًا.
    setup_steps as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'key', s.key,
        'done', s.done
      ) order by s.step_order), '[]'::jsonb) as items
      from (
        select
          1 as step_order,
          'first_product' as key,
          exists (
            select 1 from catalog.products p
            where p.is_active and p.archived_at is null
          ) as done
        where v_can_write_catalog
        union all
        select
          2,
          'branch_image',
          exists (
            select 1 from core.branches b
            where identity.can_manage_branch(b.id)
              and nullif(btrim(coalesce(b.image_url, '')), '') is not null
          )
        where v_can_write_settings
        union all
        select 3, 'revenue_target', (v_target is not null)
        where v_can_write_settings and v_company_scope
        union all
        select
          4,
          'first_order',
          exists (
            select 1 from scoped o where o.status <> 'cancelled'
          )
      ) s
    )
    select jsonb_build_object(
      'today_orders', t.today_orders,
      'today_revenue', t.today_revenue,
      'yesterday_orders', t.yesterday_orders,
      'yesterday_revenue', t.yesterday_revenue,
      'average_order_value', case
        when t.today_orders = 0 then 0
        else round(t.today_revenue / t.today_orders, 2)
      end,
      'yesterday_average_order_value', case
        when t.yesterday_orders = 0 then 0
        else round(t.yesterday_revenue / t.yesterday_orders, 2)
      end,
      'active_orders', t.active_orders,
      'total_orders', t.total_orders,
      'week_orders', t.week_orders,
      'week_revenue', t.week_revenue,
      'prev_week_orders', t.prev_week_orders,
      'prev_week_revenue', t.prev_week_revenue,
      'month_orders', t.month_orders,
      'month_revenue', t.month_revenue,
      'prev_month_orders', t.prev_month_orders,
      'prev_month_revenue', t.prev_month_revenue,
      'monthly_revenue_target', v_target,
      'total_customers', case
        when v_can_read_customers and v_company_scope then cc.total_customers
      end,
      'customers_before_month', case
        when v_can_read_customers and v_company_scope
        then cc.customers_before_month
      end,
      'new_customers', case
        when v_can_read_customers and v_company_scope then cc.new_customers
      end,
      'previous_new_customers', case
        when v_can_read_customers and v_company_scope
        then cc.previous_new_customers
      end,
      'sales_series', ss.items,
      'channels', ch.items,
      'top_products', tp.items,
      'recent_orders', ro.items,
      'setup_steps', st.items
    )
    from totals t
    cross join customer_counts cc
    cross join sales_series ss
    cross join channels ch
    cross join top_products tp
    cross join recent_orders ro
    cross join setup_steps st
  );
end;
$fn$;
create or replace function public.admin_customer_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  );
  v_previous_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  ) - interval '1 month';
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  return (
    with customers as (
      select p.id, p.created_at
        from identity.profiles p
       where not exists (
         select 1 from identity.staff_members sm where sm.user_id = p.id
       )
    ),
    order_stats as (
      select
        o.user_id,
        count(*) filter (where o.placed_at >= v_month_start) as current_orders,
        count(*) filter (
          where o.placed_at >= v_previous_month_start
            and o.placed_at < v_month_start
        ) as previous_orders,
        coalesce(sum(o.grand_total) filter (
          where o.placed_at >= v_month_start
        ), 0) as current_spent,
        coalesce(sum(o.grand_total) filter (
          where o.placed_at >= v_previous_month_start
            and o.placed_at < v_month_start
        ), 0) as previous_spent
        from orders.orders o
        join customers c on c.id = o.user_id
       where o.test_only is not true
       group by o.user_id
    )
    select jsonb_build_object(
      'total_customers', (select count(*) from customers),
      'previous_total_customers', (
        select count(*) from customers where created_at < v_month_start
      ),
      'new_customers', (
        select count(*) from customers where created_at >= v_month_start
      ),
      'previous_new_customers', (
        select count(*)
          from customers
         where created_at >= v_previous_month_start
           and created_at < v_month_start
      ),
      'current_buyers', (
        select count(*) from order_stats where current_orders > 0
      ),
      'previous_buyers', (
        select count(*) from order_stats where previous_orders > 0
      ),
      'current_spent', (
        select coalesce(sum(current_spent), 0) from order_stats
      ),
      'previous_spent', (
        select coalesce(sum(previous_spent), 0) from order_stats
      ),
      'current_repeat_buyers', (
        select count(*) from order_stats where current_orders >= 2
      ),
      'previous_repeat_buyers', (
        select count(*) from order_stats where previous_orders >= 2
      )
    )
  );
end;
$fn$;
create or replace function payments.pos_shift_totals(p_shift_id uuid)
returns table (
  cash_sales     numeric,
  card_sales     numeric,
  sales_total    numeric,
  order_count    integer,
  cash_in_total  numeric,
  cash_out_total numeric
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select
    coalesce((
      select sum(t.amount)
        from orders.orders o
        join payments.payment_transactions t
          on t.order_id = o.id
         and t.provider = 'pos_counter'
         and t.status = 'captured'
        join payments.payment_methods m
          on m.id = coalesce(t.method_id, o.payment_method_id)
       where o.test_only is not true and o.pos_shift_id = p_shift_id
         and m.code = 'cash'
    ), 0)::numeric,
    coalesce((
      select sum(t.amount)
        from orders.orders o
        join payments.payment_transactions t
          on t.order_id = o.id
         and t.provider = 'pos_counter'
         and t.status = 'captured'
        join payments.payment_methods m
          on m.id = coalesce(t.method_id, o.payment_method_id)
       where o.test_only is not true and o.pos_shift_id = p_shift_id
         and m.code = 'card'
    ), 0)::numeric,
    coalesce((
      select sum(o.grand_total)
        from orders.orders o
       where o.test_only is not true and o.pos_shift_id = p_shift_id
    ), 0)::numeric,
    coalesce((
      select count(*)::integer
        from orders.orders o
       where o.test_only is not true and o.pos_shift_id = p_shift_id
    ), 0),
    coalesce((
      select sum(mv.amount)
        from payments.pos_shift_movements mv
       where mv.shift_id = p_shift_id
         and mv.kind = 'cash_in'
    ), 0)::numeric,
    coalesce((
      select sum(mv.amount)
        from payments.pos_shift_movements mv
       where mv.shift_id = p_shift_id
         and mv.kind = 'cash_out'
    ), 0)::numeric;
$fn$;
create or replace function public.admin_customers()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'email', p.email,
      'phone', p.phone,
      'avatar_url', p.avatar_url,
      'language', p.language,
      'last_seen_at', p.last_seen_at,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'orders_count', coalesce(o.cnt, 0),
      'total_spent', coalesce(o.spent, 0),
      'last_order_at', o.last_order_at,
      'is_vip', p.is_vip,
      'is_blacklisted', p.is_blacklisted,
      'admin_notes', p.admin_notes
    ) order by p.created_at desc)
    from identity.profiles p
    left join lateral (
      select
        count(*)::int as cnt,
        coalesce(sum(grand_total), 0)::numeric as spent,
        max(placed_at) as last_order_at
      from orders.orders
      where user_id = p.id and test_only is not true
    ) o on true
    where not exists (
      select 1 from identity.staff_members sm where sm.user_id = p.id
    )
  ), '[]'::jsonb);
end;
$fn$;
create or replace function public.admin_payments()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id,
      'order_id', t.order_id,
      'order_number', o.order_number,
      'customer_name', coalesce(p.full_name, pc.full_name),
      'provider', t.provider,
      'provider_reference', t.provider_reference,
      'method_id', t.method_id,
      'method_code', m.code,
      'method_name_ar', m.name_ar,
      'method_name_en', m.name_en,
      'amount', t.amount,
      'currency_code', t.currency_code,
      'status', t.status,
      'paid_at', t.paid_at,
      'refunded_at', t.refunded_at,
      'card_brand', t.card_brand,
      'card_last4', t.card_last4,
      'card_holder_name', t.card_holder_name,
      'verified_by_server', t.verified_by_server,
      'created_at', t.created_at
    ) order by t.created_at desc)
    from payments.payment_transactions t
    left join orders.orders o on o.id = t.order_id
    left join identity.profiles p on p.id = o.user_id
    left join orders.pos_customers pc on pc.id = o.pos_customer_id
    left join payments.payment_methods m on m.id = t.method_id
    where o.test_only is not true and identity.can_manage_branch(o.branch_id)
  ), '[]'::jsonb);
end;
$fn$;
create or replace function public.my_order_invoice(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  select jsonb_build_object(
    'invoice_id', i.id, 'invoice_number', i.invoice_number,
    'invoice_type', i.invoice_type, 'status', i.status,
    'test_only', i.test_only, 'test_run_id', i.test_run_id,
    'issued_at', i.issued_at, 'currency_code', i.currency_code,
    'snapshot', i.snapshot, 'document_status', coalesce(d.status,'pending'),
    'document_url', null
  ) into v_result
    from orders.invoices i join orders.orders o on o.id=i.order_id
    left join orders.invoice_documents d on d.invoice_id=i.id
   where o.id=p_order_id and o.user_id=auth.uid();
  return v_result;
end;
$fn$;
create or replace function public.admin_order_invoice(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'invoice_id',i.id,'invoice_number',i.invoice_number,'invoice_type',i.invoice_type,'test_only',i.test_only,'test_run_id',i.test_run_id,
    'status',i.status,'zatca_status',i.zatca_status,'issued_at',i.issued_at,
    'currency_code',i.currency_code,'snapshot',i.snapshot,'snapshot_sha256',i.snapshot_sha256,
    'document_status',coalesce(d.status,'pending')
  ) into v_result from orders.invoices i
    left join orders.invoice_documents d on d.invoice_id=i.id
   where i.order_id=p_order_id and identity.can_manage_branch(i.branch_id);
  return v_result;
end;
$fn$;
create or replace function public.admin_invoice_history(
  p_from timestamptz default null, p_until timestamptz default null,
  p_branch_id uuid default null, p_search text default null
)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',i.id,'invoice_number',i.invoice_number,'invoice_type',i.invoice_type,'test_only',i.test_only,'test_run_id',i.test_run_id,
    'status',i.status,'document_status',coalesce(d.status,'pending'),
    'issued_at',i.issued_at,'currency_code',i.currency_code,'order_id',i.order_id,
    'branch_id',i.branch_id,'snapshot',i.snapshot,'snapshot_sha256',i.snapshot_sha256
  ) order by i.issued_at desc),'[]'::jsonb) into v_result
  from orders.invoices i join orders.orders o on o.id=i.order_id
  left join orders.invoice_documents d on d.invoice_id=i.id
  where identity.can_manage_branch(i.branch_id)
    and (p_branch_id is null or i.branch_id=p_branch_id)
    and (p_from is null or i.issued_at>=p_from)
    and (p_until is null or i.issued_at<p_until)
    and (nullif(btrim(coalesce(p_search,'')),'') is null
      or i.invoice_number ilike '%'||btrim(p_search)||'%'
      or o.order_number ilike '%'||btrim(p_search)||'%');
  return v_result;
end;
$fn$;
create or replace function public.invoice_document_access(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  select jsonb_build_object(
    'invoice_id', i.id, 'invoice_number', i.invoice_number,
    'invoice_type', i.invoice_type, 'status', i.status,
    'test_only', i.test_only, 'test_run_id', i.test_run_id,
    'issued_at', i.issued_at, 'currency_code', i.currency_code,
    'snapshot', i.snapshot, 'snapshot_sha256', i.snapshot_sha256,
    'document_status', coalesce(d.status, 'pending')
  ) into v_result
  from orders.invoices i
  join orders.orders o on o.id = i.order_id
  left join orders.invoice_documents d on d.invoice_id = i.id
  where i.id = p_invoice_id
    and i.status = 'issued'
    and (o.user_id = auth.uid() or (
      identity.is_staff() and identity.has_permission('orders.read')
      and identity.can_manage_branch(i.branch_id)
    ));
  if v_result is null then raise exception 'invoice not found' using errcode = 'P0002'; end if;
  return v_result;
end;
$fn$;
notify pgrst,'reload schema';
commit;
