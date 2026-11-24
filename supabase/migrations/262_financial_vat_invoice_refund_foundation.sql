-- 262_financial_vat_invoice_refund_foundation.sql
-- Phase 1 financial records. This migration is local preparation only; it is
-- not applied to any linked or production database by this task.

begin;

-- ---------------------------------------------------------------------------
-- Tax configuration and immutable configuration history.
-- ---------------------------------------------------------------------------
alter table core.brands
  add column if not exists tax_registration_status text not null default 'unconfigured'
    check (tax_registration_status in ('unconfigured','unregistered','registered')),
  add column if not exists delivery_fee_taxable boolean not null default false,
  add column if not exists tax_configuration_version integer not null default 1
    check (tax_configuration_version > 0),
  add column if not exists tax_effective_at timestamptz;

create table if not exists core.tax_configuration_history (
  id uuid primary key default extensions.gen_random_uuid(),
  brand_id uuid not null references core.brands(id) on delete restrict,
  version integer not null check (version > 0),
  registration_status text not null
    check (registration_status in ('unconfigured','unregistered','registered')),
  tax_rate numeric(5,2) not null check (tax_rate >= 0),
  tax_included boolean not null,
  delivery_fee_taxable boolean not null,
  effective_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  changed_by uuid references auth.users(id) on delete set null,
  unique (brand_id, version)
);

alter table core.tax_configuration_history enable row level security;
revoke all on core.tax_configuration_history from public, anon, authenticated;
grant select on core.tax_configuration_history to authenticated;
create policy tax_configuration_history_staff_read
  on core.tax_configuration_history for select to authenticated
  using (identity.has_permission('settings.write'));

create or replace function core.version_tax_configuration()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if old.tax_registration_status is distinct from new.tax_registration_status
     or old.tax_rate is distinct from new.tax_rate
     or old.tax_included is distinct from new.tax_included
     or old.delivery_fee_taxable is distinct from new.delivery_fee_taxable
     or old.tax_effective_at is distinct from new.tax_effective_at then
    new.tax_configuration_version := old.tax_configuration_version + 1;
    if new.tax_effective_at is not distinct from old.tax_effective_at then
      new.tax_effective_at := now();
    end if;
  end if;
  return new;
end;
$fn$;

create or replace function core.record_tax_configuration()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  insert into core.tax_configuration_history (
    brand_id, version, registration_status, tax_rate, tax_included,
    delivery_fee_taxable, effective_at, changed_by
  ) values (
    new.id, new.tax_configuration_version, new.tax_registration_status,
    new.tax_rate, new.tax_included, new.delivery_fee_taxable,
    coalesce(new.tax_effective_at, new.updated_at, now()), auth.uid()
  ) on conflict (brand_id, version) do nothing;
  return new;
end;
$fn$;

drop trigger if exists tr_brands_tax_version on core.brands;
create trigger tr_brands_tax_version
  before update on core.brands
  for each row execute function core.version_tax_configuration();
drop trigger if exists tr_brands_tax_history on core.brands;
create trigger tr_brands_tax_history
  after insert or update on core.brands
  for each row execute function core.record_tax_configuration();

insert into core.tax_configuration_history (
  brand_id, version, registration_status, tax_rate, tax_included,
  delivery_fee_taxable, effective_at
)
select id, tax_configuration_version, tax_registration_status, tax_rate,
       tax_included, delivery_fee_taxable, coalesce(tax_effective_at, now())
  from core.brands
on conflict (brand_id, version) do nothing;

-- ---------------------------------------------------------------------------
-- Financial snapshots on orders. Existing rows stay NULL: current tax settings
-- cannot be used to invent historical tax treatment.
-- ---------------------------------------------------------------------------
alter table orders.orders
  add column if not exists taxable_base numeric(12,2) check (taxable_base is null or taxable_base >= 0),
  add column if not exists vat_amount numeric(12,2) check (vat_amount is null or vat_amount >= 0),
  add column if not exists tax_rate_snapshot numeric(5,2) check (tax_rate_snapshot is null or tax_rate_snapshot >= 0),
  add column if not exists tax_included_snapshot boolean,
  add column if not exists tax_registration_status_snapshot text
    check (tax_registration_status_snapshot is null or tax_registration_status_snapshot in ('unconfigured','unregistered','registered')),
  add column if not exists tax_treatment_snapshot text
    check (tax_treatment_snapshot is null or tax_treatment_snapshot in ('configuration_unverified','not_registered','standard')),
  add column if not exists tax_configuration_version_snapshot integer,
  add column if not exists delivery_fee_taxable_snapshot boolean,
  add column if not exists seller_snapshot jsonb,
  add column if not exists tax_calculated_at timestamptz,
  add column if not exists refund_status text not null default 'none'
    check (refund_status in ('none','pending','partially_refunded','refunded','failed','unknown'));

-- The quote response and persisted order snapshot call the same calculation.
create or replace function orders.calculate_vat_amounts(
  p_subtotal numeric,
  p_discount numeric,
  p_delivery_fee numeric,
  p_rate numeric,
  p_tax_included boolean,
  p_delivery_fee_taxable boolean
)
returns table (taxable_base numeric, vat_amount numeric, tax_total numeric, grand_total numeric)
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_subtotal numeric(12,2) := round(coalesce(p_subtotal, 0), 2);
  v_discount numeric(12,2) := round(coalesce(p_discount, 0), 2);
  v_fee numeric(12,2) := round(coalesce(p_delivery_fee, 0), 2);
  v_rate numeric(5,2) := coalesce(p_rate, 0);
  v_base numeric(12,2);
  v_vat numeric(12,2);
  v_tax numeric(12,2);
begin
  if v_subtotal < 0 or v_discount < 0 or v_fee < 0 or v_rate < 0 or v_rate > 100 then
    raise exception 'invalid VAT calculation input' using errcode = '22023';
  end if;
  v_base := round(greatest(v_subtotal - v_discount, 0)
    + case when coalesce(p_delivery_fee_taxable, false) then v_fee else 0 end, 2);
  if v_rate = 0 then
    v_vat := 0;
    v_tax := 0;
  elsif coalesce(p_tax_included, false) then
    v_vat := round(v_base * v_rate / (100 + v_rate), 2);
    v_base := round(v_base - v_vat, 2);
    v_tax := 0;
  else
    v_vat := round(v_base * v_rate / 100, 2);
    v_tax := v_vat;
  end if;
  return query select v_base, v_vat, v_tax,
    round(greatest(v_subtotal - v_discount, 0) + v_fee + v_tax, 2);
end;
$fn$;
revoke all on function orders.calculate_vat_amounts(numeric,numeric,numeric,numeric,boolean,boolean)
  from public, anon, authenticated;
grant execute on function orders.calculate_vat_amounts(numeric,numeric,numeric,numeric,boolean,boolean)
  to service_role;

create or replace function orders.snapshot_order_tax()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_brand core.brands%rowtype;
  v_branch core.branches%rowtype;
  v_rate numeric(5,2);
  v_amounts record;
begin
  select * into v_brand from core.brands order by created_at limit 1;
  if not found then
    raise exception 'tax configuration is unavailable' using errcode = '55000';
  end if;
  select * into v_branch from core.branches where id = new.branch_id;
  if not found then
    raise exception 'order branch is unavailable' using errcode = '23503';
  end if;
  new.seller_snapshot := jsonb_build_object(
    'legal_name', nullif(btrim(v_branch.legal_name), ''),
    'name_ar', v_branch.name_ar, 'name_en', v_branch.name_en,
    'vat_number', nullif(btrim(v_branch.vat_number), ''),
    'branch_code', v_branch.code,
    'address', v_branch.address,
    'address_ar', v_branch.address_ar, 'address_en', v_branch.address_en,
    'phone', v_branch.phone
  );

  if v_brand.tax_registration_status = 'unregistered' and v_brand.tax_rate <> 0 then
    raise exception 'unregistered business must configure a zero tax rate'
      using errcode = '23514';
  end if;
  if v_brand.tax_registration_status = 'registered' and v_brand.tax_rate <= 0 then
    raise exception 'registered business must configure its applicable positive VAT rate'
      using errcode = '23514';
  end if;

  v_rate := v_brand.tax_rate;
  new.tax_rate_snapshot := v_rate;
  new.tax_included_snapshot := v_brand.tax_included;
  new.tax_registration_status_snapshot := v_brand.tax_registration_status;
  new.tax_treatment_snapshot := case v_brand.tax_registration_status
    when 'registered' then 'standard'
    when 'unregistered' then 'not_registered'
    else 'configuration_unverified' end;
  new.tax_configuration_version_snapshot := v_brand.tax_configuration_version;
  new.delivery_fee_taxable_snapshot := v_brand.delivery_fee_taxable;
  new.tax_calculated_at := now();

  select * into v_amounts from orders.calculate_vat_amounts(
    new.subtotal, new.discount_total, new.delivery_fee, v_rate,
    v_brand.tax_included, v_brand.delivery_fee_taxable
  );
  new.taxable_base := v_amounts.taxable_base;
  new.vat_amount := v_amounts.vat_amount;
  -- Inclusive VAT is recorded separately and is not added to the total twice.
  new.tax_total := v_amounts.tax_total;
  new.grand_total := v_amounts.grand_total;
  return new;
end;
$fn$;

-- POS receipt summary uses the tax and seller snapshots captured on the order,
-- not today's mutable brand/branch settings.
create or replace function payments.pos_invoice_summary(p_order_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
  v_branch core.branches%rowtype;
  v_tax_rate numeric := 0;
  v_vat numeric := 0;
  v_taxable numeric := 0;
  v_before numeric := 0;
  v_seller jsonb;
  v_invoice_number text;
begin
  select * into v_order from orders.orders where id = p_order_id;
  if not found then return '{}'::jsonb; end if;
  -- New paid POS sales synchronously enter the same durable invoice path that
  -- the deferred order trigger uses for online checkout. Legacy rows lack a
  -- tax/seller snapshot and are not retroactively issued here.
  if v_order.payment_status = 'paid' and v_order.seller_snapshot is not null then
    perform orders.issue_invoice_for_order(p_order_id);
    select i.invoice_number into v_invoice_number
      from orders.invoices i where i.order_id = p_order_id;
  end if;
  select * into v_branch from core.branches where id = v_order.branch_id;
  select coalesce(v_order.seller_snapshot, '{}'::jsonb) into v_seller;

  if v_order.vat_amount is not null then
    v_vat := v_order.vat_amount;
    v_taxable := coalesce(v_order.taxable_base, 0);
    v_tax_rate := coalesce(v_order.tax_rate_snapshot, 0);
  else
    -- Historical compatibility only: the original order never retained its
    -- old tax configuration, so this fallback is not used for archived tax
    -- invoices and must not be treated as a verified historical VAT amount.
    select coalesce(b.tax_rate, 0) into v_tax_rate
      from core.brands b order by b.created_at limit 1;
    if coalesce((select tax_included from core.brands order by created_at limit 1), true)
       and v_tax_rate > 0 then
      v_vat := round(v_order.grand_total * v_tax_rate / (100 + v_tax_rate), 2);
      v_taxable := round(v_order.grand_total - v_vat, 2);
    else
      v_vat := coalesce(v_order.tax_total, 0);
      v_taxable := round(v_order.subtotal - v_order.discount_total, 2);
    end if;
  end if;
  v_before := round(coalesce(v_order.subtotal, 0)
    + coalesce(v_order.product_discount_total, 0)
    + coalesce(v_order.discount_total, 0), 2);
  return jsonb_build_object(
    'product_discount_total', coalesce(v_order.product_discount_total, 0),
    'invoice_number', v_invoice_number,
    'invoice_issued_at', (select i.issued_at from orders.invoices i where i.order_id = p_order_id),
    'invoice_issued', v_invoice_number is not null,
    'invoice_type', (select i.invoice_type from orders.invoices i where i.order_id = p_order_id),
    'tax_registration_status', v_order.tax_registration_status_snapshot,
    'discount_total', coalesce(v_order.discount_total, 0),
    'before_discount_total', v_before,
    'taxable_total', v_taxable, 'vat_total', v_vat,
    'tax_rate', v_tax_rate, 'tax_included', coalesce(v_order.tax_included_snapshot, true),
    'seller_name_ar', case when v_order.seller_snapshot is not null
      then v_seller->>'name_ar' else v_branch.name_ar end,
    'seller_name_en', case when v_order.seller_snapshot is not null
      then v_seller->>'name_en' else v_branch.name_en end,
    'seller_legal_name', case when v_order.seller_snapshot is not null
      then v_seller->>'legal_name'
      else coalesce(v_branch.legal_name, v_branch.name_ar) end,
    'seller_vat_number', case when v_order.seller_snapshot is not null
      then v_seller->>'vat_number' else v_branch.vat_number end,
    'seller_address_ar', case when v_order.seller_snapshot is not null
      then v_seller->>'address_ar'
      else coalesce(v_branch.address_ar, v_branch.address) end,
    'seller_address_en', case when v_order.seller_snapshot is not null
      then v_seller->>'address_en'
      else coalesce(v_branch.address_en, v_branch.address) end,
    'seller_phone', case when v_order.seller_snapshot is not null
      then v_seller->>'phone' else v_branch.phone end
  );
end;
$fn$;
revoke all on function payments.pos_invoice_summary(uuid) from public, anon, authenticated;

drop trigger if exists tr_orders_snapshot_tax on orders.orders;
create trigger tr_orders_snapshot_tax
  before insert on orders.orders
  for each row execute function orders.snapshot_order_tax();

-- The existing quote RPC remains the source for repricing/coupon/zone checks.
-- Wrap it so the delivery-fee tax configuration is applied consistently, and
-- return VAT separately even when it is already included in the price.
alter function public.quote_checkout(uuid,jsonb,text,uuid,text,uuid)
  rename to quote_checkout_legacy;
revoke all on function public.quote_checkout_legacy(uuid,jsonb,text,uuid,text,uuid)
  from public, anon, authenticated, service_role;
create or replace function public.quote_checkout(
  p_branch_id uuid,
  p_lines jsonb,
  p_fulfillment_type text,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_address_id uuid default null
)
returns table (
  subtotal numeric, discount_total numeric, delivery_fee numeric,
  tax_total numeric, grand_total numeric, currency_code text,
  product_discount_total numeric
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_quote record;
  v_rate numeric(5,2);
  v_included boolean;
  v_registered text;
  v_fee_taxable boolean;
  v_amounts record;
begin
  select * into v_quote from public.quote_checkout_legacy(
    p_branch_id, p_lines, p_fulfillment_type,
    p_delivery_zone_id, p_coupon_code, p_address_id
  );
  select b.tax_rate, b.tax_included, b.tax_registration_status,
         b.delivery_fee_taxable
    into v_rate, v_included, v_registered, v_fee_taxable
    from core.brands b order by b.created_at limit 1;
  if v_registered = 'unregistered' and v_rate <> 0 then
    raise exception 'unregistered business must configure a zero tax rate'
      using errcode = '23514';
  end if;
  if v_registered = 'registered' and v_rate <= 0 then
    raise exception 'registered business must configure its applicable positive VAT rate'
      using errcode = '23514';
  end if;
  select * into v_amounts from orders.calculate_vat_amounts(
    v_quote.subtotal, v_quote.discount_total, v_quote.delivery_fee,
    coalesce(v_rate, 0), v_included, v_fee_taxable
  );
  return query select v_quote.subtotal, v_quote.discount_total, v_quote.delivery_fee,
    v_amounts.vat_amount, v_amounts.grand_total,
    v_quote.currency_code, v_quote.product_discount_total;
end;
$fn$;
revoke all on function public.quote_checkout(uuid,jsonb,text,uuid,text,uuid) from public, anon;
grant execute on function public.quote_checkout(uuid,jsonb,text,uuid,text,uuid) to authenticated, service_role;

-- The serialized order wrapper reloads the inserted row so any configured fee
-- tax treatment and tax snapshot are the exact values the client receives.
create or replace function orders.place_order_with_lines(
  p_branch_id uuid,
  p_lines jsonb,
  p_idempotency_key text,
  p_fulfillment_type text,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_note text default null,
  p_address_id uuid default null
)
returns table (
  order_id uuid, order_number text, subtotal numeric, discount_total numeric,
  delivery_fee numeric, tax_total numeric, grand_total numeric,
  points_earned integer, reused_existing_order boolean
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_existing orders.orders%rowtype;
  v_cart uuid;
  v_result record;
  v_saved orders.orders%rowtype;
begin
  if v_uid is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if nullif(btrim(coalesce(p_idempotency_key, '')), '') is null then
    raise exception 'idempotency key required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':order:' || p_idempotency_key, 0)
  );
  select * into v_existing from orders.orders
   where user_id = v_uid and idempotency_key = p_idempotency_key;
  if found then
    return query select v_existing.id, v_existing.order_number, v_existing.subtotal,
      v_existing.discount_total, v_existing.delivery_fee, v_existing.tax_total,
      v_existing.grand_total, v_existing.loyalty_points_earned, true;
    return;
  end if;
  v_cart := orders.replace_customer_cart(p_branch_id, p_lines);
  select * into v_result from orders.place_order_impl(
    v_cart,
    p_idempotency_key, p_fulfillment_type, p_delivery_zone_id,
    p_coupon_code, p_note, p_address_id
  );
  select * into v_saved from orders.orders where id = v_result.order_id;
  return query select v_saved.id, v_saved.order_number, v_saved.subtotal,
    v_saved.discount_total, v_saved.delivery_fee, v_saved.tax_total,
    v_saved.grand_total, v_saved.loyalty_points_earned, v_result.reused_existing_order;
end;
$fn$;
revoke all on function orders.place_order_with_lines(uuid,jsonb,text,text,uuid,text,text,uuid) from public, anon;
grant execute on function orders.place_order_with_lines(uuid,jsonb,text,text,uuid,text,text,uuid) to authenticated, service_role;

create or replace function public.place_order_with_quote(
  p_branch_id uuid,
  p_lines jsonb,
  p_idempotency_key text,
  p_fulfillment_type text,
  p_expected_total numeric,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_note text default null,
  p_address_id uuid default null
)
returns table (
  order_id uuid, order_number text, subtotal numeric, discount_total numeric,
  delivery_fee numeric, tax_total numeric, grand_total numeric,
  points_earned integer, reused_existing_order boolean,
  product_discount_total numeric
)
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  v_order record;
  v_saved orders.orders%rowtype;
begin
  if p_expected_total is null then
    raise exception 'checkout quote required' using errcode = '22023';
  end if;
  select * into v_order from public.place_order_with_lines(
    p_branch_id, p_lines, p_idempotency_key, p_fulfillment_type,
    p_delivery_zone_id, p_coupon_code, p_note, p_address_id
  );
  select * into v_saved from orders.orders where id = v_order.order_id;
  if abs(v_saved.grand_total - p_expected_total) > 0.005 then
    raise exception 'checkout total changed; refresh quote' using errcode = '40001';
  end if;
  return query select v_saved.id, v_saved.order_number, v_saved.subtotal,
    v_saved.discount_total, v_saved.delivery_fee, v_saved.tax_total,
    v_saved.grand_total, v_saved.loyalty_points_earned,
    v_order.reused_existing_order, coalesce(v_saved.product_discount_total, 0);
end;
$fn$;
revoke all on function public.place_order_with_quote(uuid,jsonb,text,text,numeric,uuid,text,text,uuid) from public, anon;
grant execute on function public.place_order_with_quote(uuid,jsonb,text,text,numeric,uuid,text,text,uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Append-only refund ledger; pending/unknown refunds reserve capacity.
-- ---------------------------------------------------------------------------
create table if not exists payments.payment_refunds (
  id uuid primary key default extensions.gen_random_uuid(),
  payment_transaction_id uuid not null references payments.payment_transactions(id) on delete restrict,
  order_id uuid not null references orders.orders(id) on delete restrict,
  provider text not null default 'tap',
  provider_refund_id text,
  idempotency_key text not null,
  requested_amount numeric(12,2) not null check (requested_amount > 0),
  confirmed_amount numeric(12,2) check (confirmed_amount is null or confirmed_amount > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  reason text not null,
  status text not null check (status in ('pending','succeeded','failed','unknown')),
  requested_by uuid references auth.users(id) on delete set null,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  provider_metadata jsonb not null default '{}'::jsonb,
  unique (payment_transaction_id, idempotency_key),
  check (status <> 'succeeded' or confirmed_amount is not null)
);

create unique index if not exists uq_payment_refunds_provider_id
  on payments.payment_refunds (provider, provider_refund_id)
  where provider_refund_id is not null;
create index if not exists ix_payment_refunds_order_time
  on payments.payment_refunds (order_id, requested_at desc);
create index if not exists ix_payment_refunds_transaction_status
  on payments.payment_refunds (payment_transaction_id, status);

create or replace view public.payment_refunds with (security_invoker = true) as
select id, payment_transaction_id, order_id, provider, provider_refund_id,
       idempotency_key, requested_amount, confirmed_amount, currency_code,
       reason, status, requested_by, requested_at, completed_at, provider_metadata
  from payments.payment_refunds;
revoke all on public.payment_refunds from public, anon, authenticated;
grant select on public.payment_refunds to service_role;

alter table payments.payment_refunds enable row level security;
revoke all on payments.payment_refunds from public, anon, authenticated;
grant select on payments.payment_refunds to authenticated;
grant all on payments.payment_refunds to service_role;
create policy payment_refunds_select_own on payments.payment_refunds
  for select to authenticated using (
    exists (select 1 from orders.orders o
             where o.id = payment_refunds.order_id and o.user_id = auth.uid())
  );
create policy payment_refunds_select_staff on payments.payment_refunds
  for select to authenticated using (
    identity.has_permission('payments.read')
    and exists (select 1 from orders.orders o
                 where o.id = payment_refunds.order_id
                   and identity.can_manage_branch(o.branch_id))
  );

alter table payments.payment_transactions
  add column if not exists refund_status text not null default 'none'
    check (refund_status in ('none','pending','partially_refunded','refunded','failed','unknown'));

create or replace function public.claim_payment_refund(
  p_transaction_id uuid,
  p_amount numeric,
  p_reason text,
  p_idempotency_key text,
  p_staff_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_tx payments.payment_transactions%rowtype;
  v_existing payments.payment_refunds%rowtype;
  v_order orders.orders%rowtype;
  v_reserved numeric(12,2);
  v_id uuid;
begin
  if p_transaction_id is null or p_amount is null or p_amount <= 0
     or p_amount <> round(p_amount, 2)
     or nullif(btrim(coalesce(p_reason, '')), '') is null
     or nullif(btrim(coalesce(p_idempotency_key, '')), '') is null
     or p_staff_user_id is null then
    raise exception 'invalid refund request' using errcode = '22023';
  end if;

  select * into v_tx from payments.payment_transactions
   where id = p_transaction_id for update;
  if not found or v_tx.order_id is null then
    raise exception 'payment transaction not found' using errcode = 'P0002';
  end if;
  select * into v_order from orders.orders where id = v_tx.order_id;

  select * into v_existing from payments.payment_refunds
   where payment_transaction_id = v_tx.id
     and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'ok', true, 'reused', true, 'refund_id', v_existing.id,
      'amount', v_existing.requested_amount, 'currency_code', v_existing.currency_code,
      'charge_id', v_tx.provider_reference, 'order_id', v_order.id,
      'branch_id', v_order.branch_id, 'status', v_existing.status
    );
  end if;

  if v_tx.status <> 'captured' then
    raise exception 'only captured transactions may be refunded' using errcode = '23514';
  end if;

  select coalesce(sum(case when status = 'succeeded'
                            then confirmed_amount
                            else requested_amount end), 0)
    into v_reserved
    from payments.payment_refunds
   where payment_transaction_id = v_tx.id
     and status in ('pending','unknown','succeeded');
  if v_reserved + p_amount > v_tx.amount then
    raise exception 'refund exceeds remaining captured amount' using errcode = '23514';
  end if;

  insert into payments.payment_refunds (
    payment_transaction_id, order_id, idempotency_key, requested_amount,
    currency_code, reason, status, requested_by
  ) values (
    v_tx.id, v_order.id, p_idempotency_key, p_amount,
    v_tx.currency_code, left(btrim(p_reason), 500), 'pending', p_staff_user_id
  ) returning id into v_id;

  update payments.payment_transactions set refund_status = 'pending'
   where id = v_tx.id;
  update orders.orders set refund_status = 'pending'
   where id = v_order.id and refund_status <> 'refunded';

  return jsonb_build_object(
    'ok', true, 'reused', false, 'refund_id', v_id,
    'amount', p_amount, 'currency_code', v_tx.currency_code,
    'charge_id', v_tx.provider_reference, 'order_id', v_order.id,
    'branch_id', v_order.branch_id, 'status', 'pending'
  );
end;
$fn$;

create or replace function public.complete_payment_refund(
  p_refund_id uuid,
  p_status text,
  p_confirmed_amount numeric,
  p_provider_refund_id text,
  p_provider_metadata jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_refund payments.payment_refunds%rowtype;
  v_tx payments.payment_transactions%rowtype;
  v_total numeric(12,2);
  v_pending boolean;
  v_unknown boolean;
begin
  if p_status not in ('pending','succeeded','failed','unknown') then
    raise exception 'invalid refund status' using errcode = '22023';
  end if;
  select * into v_refund from payments.payment_refunds
   where id = p_refund_id for update;
  if not found then raise exception 'refund not found' using errcode = 'P0002'; end if;
  select * into v_tx from payments.payment_transactions
   where id = v_refund.payment_transaction_id for update;

  if p_status = 'succeeded' and
     (p_confirmed_amount is null or p_confirmed_amount <> v_refund.requested_amount) then
    raise exception 'confirmed refund amount does not match request' using errcode = '23514';
  end if;

  if v_refund.status = 'succeeded' then
    if p_status <> 'succeeded' or p_confirmed_amount <> v_refund.confirmed_amount then
      raise exception 'a completed refund cannot be changed' using errcode = '23514';
    end if;
  else
    update payments.payment_refunds
       set status = p_status,
           confirmed_amount = case when p_status = 'succeeded' then p_confirmed_amount else null end,
           provider_refund_id = coalesce(nullif(p_provider_refund_id, ''), provider_refund_id),
           provider_metadata = coalesce(p_provider_metadata, '{}'::jsonb),
           completed_at = case when p_status in ('succeeded','failed') then now() else null end
     where id = v_refund.id;
  end if;

  select coalesce(sum(confirmed_amount), 0) into v_total
    from payments.payment_refunds
   where payment_transaction_id = v_tx.id and status = 'succeeded';
  if v_total > v_tx.amount then
    raise exception 'successful refunds exceed captured payment' using errcode = '23514';
  end if;
  select exists (select 1 from payments.payment_refunds
                  where payment_transaction_id = v_tx.id and status = 'pending'),
         exists (select 1 from payments.payment_refunds
                  where payment_transaction_id = v_tx.id and status = 'unknown')
    into v_pending, v_unknown;

  update payments.payment_transactions
     set refund_status = case
       when v_total = v_tx.amount then 'refunded'
       when v_unknown then 'unknown'
       when v_pending then 'pending'
       when v_total > 0 then 'partially_refunded'
       when p_status = 'failed' then 'failed'
       else 'none' end,
         status = case when v_total = v_tx.amount then 'refunded' else 'captured' end,
         refunded_at = case when v_total = v_tx.amount then coalesce(refunded_at, now()) else null end
   where id = v_tx.id;

  update orders.orders
     set refund_status = case
       when v_total = v_tx.amount then 'refunded'
       when v_unknown then 'unknown'
       when v_pending then 'pending'
       when v_total > 0 then 'partially_refunded'
       when p_status = 'failed' then 'failed'
       else 'none' end,
         payment_status = case when v_total = v_tx.amount then 'refunded' else payment_status end
   where id = v_refund.order_id;

  return jsonb_build_object(
    'refund_id', v_refund.id, 'status', p_status,
    'successful_refunds_total', v_total, 'payment_amount', v_tx.amount,
    'fully_refunded', v_total = v_tx.amount
  );
end;
$fn$;

revoke all on function public.claim_payment_refund(uuid,numeric,text,text,uuid) from public, anon, authenticated;
revoke all on function public.complete_payment_refund(uuid,text,numeric,text,jsonb) from public, anon, authenticated;
grant execute on function public.claim_payment_refund(uuid,numeric,text,text,uuid) to service_role;
grant execute on function public.complete_payment_refund(uuid,text,numeric,text,jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- Immutable invoice and adjustment records.
-- ---------------------------------------------------------------------------
create sequence if not exists orders.invoice_number_seq;
create sequence if not exists orders.adjustment_number_seq;

create table if not exists orders.invoices (
  id uuid primary key default extensions.gen_random_uuid(),
  invoice_number text not null unique,
  order_id uuid not null unique references orders.orders(id) on delete restrict,
  branch_id uuid not null references core.branches(id) on delete restrict,
  invoice_type text not null check (invoice_type in ('receipt','simplified','standard')),
  status text not null default 'issued' check (status = 'issued'),
  zatca_status text not null default 'not_submitted'
    check (zatca_status in ('not_submitted','submitted','reported','cleared','rejected')),
  issued_at timestamptz not null,
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  snapshot_sha256 text not null check (snapshot_sha256 ~ '^[0-9a-f]{64}$'),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists ix_invoices_branch_issue
  on orders.invoices (branch_id, issued_at desc);

create table if not exists orders.invoice_adjustments (
  id uuid primary key default extensions.gen_random_uuid(),
  adjustment_number text not null unique,
  invoice_id uuid not null references orders.invoices(id) on delete restrict,
  payment_refund_id uuid unique references payments.payment_refunds(id) on delete restrict,
  adjustment_type text not null check (adjustment_type in ('credit_note','debit_note')),
  status text not null default 'issued' check (status = 'issued'),
  issued_at timestamptz not null default now(),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  amount numeric(12,2) not null check (amount > 0),
  vat_amount numeric(12,2) not null check (vat_amount >= 0),
  reason text not null,
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  snapshot_sha256 text not null check (snapshot_sha256 ~ '^[0-9a-f]{64}$'),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists ix_invoice_adjustments_invoice_time
  on orders.invoice_adjustments (invoice_id, issued_at desc);

alter table orders.invoices enable row level security;
alter table orders.invoice_adjustments enable row level security;
revoke all on orders.invoices, orders.invoice_adjustments from public, anon, authenticated;
grant select on orders.invoices, orders.invoice_adjustments to authenticated;
grant all on orders.invoices, orders.invoice_adjustments to service_role;
create policy invoices_select_owner_staff on orders.invoices
  for select to authenticated using (
    exists (select 1 from orders.orders o
             where o.id = invoices.order_id and
               (o.user_id = auth.uid() or
                (identity.has_permission('orders.read') and identity.can_manage_branch(o.branch_id))))
  );
create policy invoice_adjustments_select_owner_staff on orders.invoice_adjustments
  for select to authenticated using (
    exists (select 1 from orders.invoices i join orders.orders o on o.id = i.order_id
             where i.id = invoice_adjustments.invoice_id and
               (o.user_id = auth.uid() or
                (identity.has_permission('orders.read') and identity.can_manage_branch(o.branch_id))))
  );

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
  if v_order.tax_registration_status_snapshot = 'registered'
     and (nullif(btrim(v_order.seller_snapshot->>'legal_name'), '') is null
          or nullif(btrim(v_order.seller_snapshot->>'vat_number'), '') is null) then
    raise exception 'registered branch needs legal name and VAT registration number before invoice issuance'
      using errcode = '23514';
  end if;
  if v_order.user_id is not null then
    select * into v_profile from identity.profiles where id = v_order.user_id;
  end if;

  v_snapshot := jsonb_build_object(
    'invoice_type', case when v_order.tax_registration_status_snapshot = 'registered'
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
  v_invoice_number := 'INV-' || to_char(v_now, 'YYYY') || '-' ||
    lpad(nextval('orders.invoice_number_seq')::text, 8, '0');

  insert into orders.invoices (
    invoice_number, order_id, branch_id, invoice_type, issued_at,
    currency_code, snapshot, snapshot_sha256, created_by
  ) values (
    v_invoice_number, v_order.id, v_order.branch_id,
    case when v_order.tax_registration_status_snapshot = 'registered'
      then 'simplified' else 'receipt' end, v_now,
    v_order.currency_code, v_snapshot,
    encode(extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'), 'hex'),
    auth.uid()
  ) on conflict (order_id) do update set order_id = excluded.order_id
  returning id into v_invoice_id;

  return v_invoice_id;
end;
$fn$;

create or replace function orders.issue_eligible_invoice()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status <> 'cancelled'
     and new.payment_status = 'paid' then
    perform orders.issue_invoice_for_order(new.id);
  end if;
  return null;
end;
$fn$;

drop trigger if exists tr_orders_issue_eligible_invoice on orders.orders;
create constraint trigger tr_orders_issue_eligible_invoice
  after insert or update on orders.orders
  deferrable initially deferred
  for each row execute function orders.issue_eligible_invoice();

-- Preserve immutable invoice financial content. The ZATCA status alone may
-- advance through the controlled integration boundary.
create or replace function orders.guard_invoice_immutability()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  if tg_op = 'DELETE' then
    raise exception 'issued invoices and adjustments cannot be deleted' using errcode = '55000';
  end if;
  if tg_table_name = 'invoices' then
    if (to_jsonb(new) - 'zatca_status') is distinct from (to_jsonb(old) - 'zatca_status') then
      raise exception 'issued invoice content is immutable' using errcode = '55000';
    end if;
  elsif to_jsonb(new) is distinct from to_jsonb(old) then
    raise exception 'issued invoice adjustment is immutable' using errcode = '55000';
  end if;
  return new;
end;
$fn$;
drop trigger if exists tr_invoices_immutable on orders.invoices;
create trigger tr_invoices_immutable before update or delete on orders.invoices
  for each row execute function orders.guard_invoice_immutability();
drop trigger if exists tr_invoice_adjustments_immutable on orders.invoice_adjustments;
create trigger tr_invoice_adjustments_immutable before update or delete on orders.invoice_adjustments
  for each row execute function orders.guard_invoice_immutability();

create or replace function public.my_order_invoice(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  select jsonb_build_object(
    'invoice_id', i.id, 'invoice_number', i.invoice_number,
    'invoice_type', i.invoice_type, 'status', i.status,
    'issued_at', i.issued_at, 'currency_code', i.currency_code,
    'snapshot', i.snapshot, 'document_url', null
  ) into v_result
    from orders.invoices i join orders.orders o on o.id = i.order_id
   where o.id = p_order_id and o.user_id = auth.uid();
  return v_result;
end;
$fn$;
revoke all on function public.my_order_invoice(uuid) from public, anon;
grant execute on function public.my_order_invoice(uuid) to authenticated;

create or replace function public.admin_order_invoice(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'invoice_id', i.id, 'invoice_number', i.invoice_number,
    'invoice_type', i.invoice_type, 'status', i.status,
    'zatca_status', i.zatca_status, 'issued_at', i.issued_at,
    'currency_code', i.currency_code, 'snapshot', i.snapshot,
    'snapshot_sha256', i.snapshot_sha256, 'document_url', null
  ) into v_result from orders.invoices i
   where i.order_id = p_order_id and identity.can_manage_branch(i.branch_id);
  return v_result;
end;
$fn$;
revoke all on function public.admin_order_invoice(uuid) from public, anon;
grant execute on function public.admin_order_invoice(uuid) to authenticated;

create or replace function public.admin_invoice_history(
  p_from timestamptz default null,
  p_until timestamptz default null,
  p_branch_id uuid default null,
  p_search text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'invoice_id', i.id, 'invoice_number', i.invoice_number,
      'invoice_type', i.invoice_type, 'status', i.status,
      'zatca_status', i.zatca_status, 'issued_at', i.issued_at,
      'currency_code', i.currency_code, 'order_id', i.order_id,
      'branch_id', i.branch_id, 'snapshot', i.snapshot,
      'snapshot_sha256', i.snapshot_sha256
    ) order by i.issued_at desc), '[]'::jsonb)
    into v_result
    from orders.invoices i
    join orders.orders o on o.id = i.order_id
   where identity.can_manage_branch(i.branch_id)
     and (p_branch_id is null or i.branch_id = p_branch_id)
     and (p_from is null or i.issued_at >= p_from)
     and (p_until is null or i.issued_at < p_until)
     and (nullif(btrim(coalesce(p_search, '')), '') is null
          or i.invoice_number ilike '%' || btrim(p_search) || '%'
          or o.order_number ilike '%' || btrim(p_search) || '%');
  return v_result;
end;
$fn$;
revoke all on function public.admin_invoice_history(timestamptz,timestamptz,uuid,text) from public, anon;
grant execute on function public.admin_invoice_history(timestamptz,timestamptz,uuid,text) to authenticated;

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
    where i.issued_at >= p_from and i.issued_at < p_until
      and identity.can_manage_branch(i.branch_id)
      and (p_branch_id is null or i.branch_id = p_branch_id)
    group by i.branch_id
  ) rows;
  return v_result;
end;
$fn$;
revoke all on function public.admin_tax_report(timestamptz,timestamptz,uuid) from public, anon;
grant execute on function public.admin_tax_report(timestamptz,timestamptz,uuid) to authenticated;

-- A refund is not itself a credit note. This explicit staff action creates one
-- only for a successful refund tied to a registered-seller invoice and requires
-- the accountant-confirmed VAT adjustment amount; line allocation is unknown.
create or replace function public.admin_issue_refund_credit_note(
  p_refund_id uuid,
  p_vat_amount numeric,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_refund payments.payment_refunds%rowtype;
  v_invoice orders.invoices%rowtype;
  v_order orders.orders%rowtype;
  v_amount numeric(12,2);
  v_vat numeric(12,2);
  v_number text;
  v_snapshot jsonb;
  v_id uuid;
  v_prior_credit_amount numeric(12,2);
  v_prior_credit_vat numeric(12,2);
begin
  if not identity.is_staff() or not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'reason is required' using errcode = '22023';
  end if;
  select * into v_refund from payments.payment_refunds
   where id = p_refund_id for update;
  if not found or v_refund.status <> 'succeeded' then
    raise exception 'only a successful refund can be linked to a credit note' using errcode = '23514';
  end if;
  select * into v_invoice from orders.invoices where order_id = v_refund.order_id for update;
  if not found or v_invoice.invoice_type <> 'simplified'
     or v_invoice.snapshot->>'tax_registration_status' <> 'registered' then
    raise exception 'refund has no issued ZATCA tax invoice' using errcode = '23514';
  end if;
  select * into v_order from orders.orders where id = v_refund.order_id;
  if not identity.can_manage_branch(v_invoice.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  select id into v_id from orders.invoice_adjustments where payment_refund_id = p_refund_id;
  if found then
    select adjustment_number into v_number from orders.invoice_adjustments where id = v_id;
    return jsonb_build_object('id', v_id, 'adjustment_number', v_number, 'reused', true);
  end if;

  v_amount := v_refund.confirmed_amount;
  if p_vat_amount is null or p_vat_amount < 0 or p_vat_amount > v_amount
     or p_vat_amount <> round(p_vat_amount, 2) then
    raise exception 'accountant-confirmed VAT adjustment amount is required'
      using errcode = '22023';
  end if;
  v_vat := p_vat_amount;
  select coalesce(sum(amount), 0), coalesce(sum(vat_amount), 0)
    into v_prior_credit_amount, v_prior_credit_vat
    from orders.invoice_adjustments
   where invoice_id = v_invoice.id and adjustment_type = 'credit_note';
  if v_prior_credit_amount + v_amount > (v_invoice.snapshot->>'grand_total')::numeric
     or v_prior_credit_vat + v_vat > coalesce((v_invoice.snapshot->>'vat_amount')::numeric, 0) then
    raise exception 'credit notes would exceed the original invoice totals'
      using errcode = '23514';
  end if;
  v_number := 'CN-' || to_char(now(), 'YYYY') || '-' ||
    lpad(nextval('orders.adjustment_number_seq')::text, 8, '0');
  v_snapshot := jsonb_build_object(
    'adjustment_type', 'credit_note', 'issued_at', now(),
    'original_invoice_id', v_invoice.id,
    'original_invoice_number', v_invoice.invoice_number,
    'refund_id', v_refund.id,
    'order_id', v_order.id, 'order_number', v_order.order_number,
    'amount', v_amount, 'vat_amount', v_vat,
    'currency_code', v_refund.currency_code,
    'reason', left(btrim(p_reason), 500)
  );
  insert into orders.invoice_adjustments (
    adjustment_number, invoice_id, payment_refund_id, adjustment_type,
    currency_code, amount, vat_amount, reason, snapshot, snapshot_sha256, created_by
  ) values (
    v_number, v_invoice.id, p_refund_id, 'credit_note', v_refund.currency_code,
    v_amount, v_vat, left(btrim(p_reason), 500), v_snapshot,
    encode(extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'), 'hex'),
    auth.uid()
  ) returning id into v_id;
  perform identity.audit('orders.invoice.credit_note.issue', 'invoice_adjustment', v_id,
    null, v_snapshot, v_invoice.branch_id);
  return jsonb_build_object('id', v_id, 'adjustment_number', v_number, 'reused', false);
end;
$fn$;
revoke all on function public.admin_issue_refund_credit_note(uuid,numeric,text) from public, anon;
grant execute on function public.admin_issue_refund_credit_note(uuid,numeric,text) to authenticated;

create or replace function public.admin_tax_configuration()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'registration_status', tax_registration_status,
    'tax_rate', tax_rate, 'tax_included', tax_included,
    'delivery_fee_taxable', delivery_fee_taxable,
    'version', tax_configuration_version, 'effective_at', tax_effective_at
  ) into v_result from core.brands order by created_at limit 1;
  return coalesce(v_result, '{}'::jsonb);
end;
$fn$;

create or replace function public.admin_save_tax_configuration(
  p_registration_status text,
  p_tax_rate numeric,
  p_tax_included boolean,
  p_delivery_fee_taxable boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_old jsonb; v_new jsonb; v_brand_id uuid;
begin
  if not identity.is_staff() or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_registration_status not in ('unconfigured','unregistered','registered')
     or p_tax_rate is null or p_tax_rate < 0 or p_tax_rate > 100
     or p_tax_rate <> round(p_tax_rate, 2)
     or p_tax_included is null or p_delivery_fee_taxable is null then
    raise exception 'invalid tax configuration' using errcode = '22023';
  end if;
  if p_registration_status = 'unregistered' and p_tax_rate <> 0 then
    raise exception 'an unregistered business must use a zero rate' using errcode = '23514';
  end if;
  if p_registration_status = 'registered' and p_tax_rate <= 0 then
    raise exception 'a registered business needs its configured VAT rate' using errcode = '23514';
  end if;
  select id into v_brand_id from core.brands order by created_at limit 1 for update;
  if v_brand_id is null then raise exception 'brand not configured' using errcode = 'P0002'; end if;
  select jsonb_build_object('registration_status', tax_registration_status,
      'tax_rate', tax_rate, 'tax_included', tax_included,
      'delivery_fee_taxable', delivery_fee_taxable)
    into v_old from core.brands where id = v_brand_id;
  update core.brands set tax_registration_status = p_registration_status,
      tax_rate = p_tax_rate, tax_included = p_tax_included,
      delivery_fee_taxable = p_delivery_fee_taxable,
      tax_effective_at = now(), updated_at = now()
   where id = v_brand_id;
  select jsonb_build_object('registration_status', tax_registration_status,
      'tax_rate', tax_rate, 'tax_included', tax_included,
      'delivery_fee_taxable', delivery_fee_taxable,
      'version', tax_configuration_version, 'effective_at', tax_effective_at)
    into v_new from core.brands where id = v_brand_id;
  perform identity.audit('core.tax_configuration.update', 'brand', v_brand_id, v_old, v_new);
  return v_new;
end;
$fn$;

revoke all on function public.admin_tax_configuration() from public, anon;
revoke all on function public.admin_save_tax_configuration(text,numeric,boolean,boolean) from public, anon;
grant execute on function public.admin_tax_configuration() to authenticated;
grant execute on function public.admin_save_tax_configuration(text,numeric,boolean,boolean) to authenticated;

notify pgrst, 'reload schema';
commit;
