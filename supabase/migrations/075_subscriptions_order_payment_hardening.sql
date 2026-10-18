-- 075_subscriptions_order_payment_hardening.sql
-- Order lifecycle integration, payment-linked activation, single-use QR tokens.

-- ---------------------------------------------------------------------------
-- Payment transactions can now reference a subscription purchase.
-- ---------------------------------------------------------------------------
alter table payments.payment_transactions
  add column if not exists subscription_id uuid references subscriptions.subscriptions(id) on delete set null;

alter table payments.payment_transactions
  alter column order_id drop not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'payment_transactions_one_target'
      and conrelid = 'payments.payment_transactions'::regclass
  ) then
    alter table payments.payment_transactions
      add constraint payment_transactions_one_target
      check ((order_id is null) <> (subscription_id is null));
  end if;
end $$;

create index if not exists ix_payment_tx_subscription
  on payments.payment_transactions (subscription_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Subscription state additions.
-- ---------------------------------------------------------------------------
alter table subscriptions.subscriptions
  add column if not exists cups_reserved integer not null default 0 check (cups_reserved >= 0);

alter table subscriptions.subscriptions
  alter column starts_at drop not null,
  alter column ends_at drop not null;

alter table subscriptions.qr_tokens
  add column if not exists consumed_at timestamptz;

-- ---------------------------------------------------------------------------
-- Consumptions tied to orders.
-- ---------------------------------------------------------------------------
create table if not exists subscriptions.subscription_consumptions (
  id                uuid primary key default extensions.gen_random_uuid(),
  subscription_id   uuid not null references subscriptions.subscriptions(id) on delete cascade,
  order_id          uuid not null references orders.orders(id) on delete cascade,
  order_item_id     uuid references orders.order_items(id) on delete set null,
  branch_id         uuid not null references core.branches(id) on delete restrict,
  product_id        uuid references catalog.products(id) on delete set null,
  quantity          integer not null check (quantity > 0),
  status            text not null default 'reserved'
                      check (status in ('reserved','finalized','released')),
  idempotency_key   text not null unique,
  reservation_key   text not null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists ix_sub_consumptions_order
  on subscriptions.subscription_consumptions (order_id, status);
create index if not exists ix_sub_consumptions_sub
  on subscriptions.subscription_consumptions (subscription_id, status);
create index if not exists ix_sub_consumptions_reservation
  on subscriptions.subscription_consumptions (reservation_key);

create trigger tr_sub_consumptions_updated_at
  before update on subscriptions.subscription_consumptions
  for each row execute function core.set_updated_at();

alter table subscriptions.subscription_consumptions enable row level security;

create policy sub_consumptions_read on subscriptions.subscription_consumptions
  for select using (
    exists (select 1 from subscriptions.subscriptions s where s.id = subscription_id and s.user_id = auth.uid())
    or identity.has_permission('subscriptions.consume')
    or identity.has_permission('subscriptions.manage')
  );

-- ---------------------------------------------------------------------------
-- Pending subscription creation (no payment yet).
-- ---------------------------------------------------------------------------
create or replace function subscriptions.create_pending_subscription(
  p_plan_id uuid,
  p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_plan subscriptions.plans%rowtype;
  v_existing uuid;
  v_new uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if coalesce(btrim(p_idempotency_key), '') = '' then
    raise exception 'idempotency key required' using errcode = '23514';
  end if;

  select id into v_existing
    from subscriptions.subscriptions
   where idempotency_key = p_idempotency_key;
  if found then
    return v_existing;
  end if;

  select * into v_plan from subscriptions.plans where id = p_plan_id and is_active and is_for_sale for update;
  if not found then
    raise exception 'plan not available' using errcode = 'P0002';
  end if;

  insert into subscriptions.subscriptions
    (user_id, plan_id, status, starts_at, ends_at, cups_entitled, cups_used,
     cups_carried_over, bonus_balance, auto_renew, idempotency_key)
  values
    (v_uid, v_plan.id, 'pending_payment', null, null, 0, 0, 0, 0, false, p_idempotency_key)
  returning id into v_new;

  insert into subscriptions.subscription_events (subscription_id, user_id, event_type, payload)
  values (v_new, v_uid, 'pending_payment', jsonb_build_object('plan', v_plan.id));

  return v_new;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Activation after trusted server-side payment confirmation.
-- ---------------------------------------------------------------------------
create or replace function subscriptions.activate_subscription(
  p_subscription_id uuid,
  p_payment_reference text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_sub subscriptions.subscriptions%rowtype;
  v_plan subscriptions.plans%rowtype;
  v_prev subscriptions.subscriptions%rowtype;
  v_unused integer;
  v_carry integer := 0;
  v_start timestamptz := now();
  v_end timestamptz;
  v_tx payments.payment_transactions%rowtype;
begin
  if coalesce(btrim(p_payment_reference), '') = '' then
    raise exception 'payment reference required' using errcode = '23514';
  end if;

  select * into v_sub
    from subscriptions.subscriptions
   where id = p_subscription_id
   for update;
  if not found then
    raise exception 'subscription not found' using errcode = 'P0002';
  end if;

  -- Idempotent: already activated with the same payment reference.
  if v_sub.status = 'active' and v_sub.payment_reference = p_payment_reference then
    return v_sub.id;
  end if;
  if v_sub.status <> 'pending_payment' then
    raise exception 'subscription is not pending payment' using errcode = '23514';
  end if;

  select * into v_tx
    from payments.payment_transactions
   where subscription_id = v_sub.id
     and provider_reference = p_payment_reference
     and verified_by_server = true
     and status in ('captured','authorized')
   limit 1;
  if not found then
    raise exception 'verified payment not found' using errcode = '42501';
  end if;

  select * into v_plan from subscriptions.plans where id = v_sub.plan_id and is_active and is_for_sale for update;
  if not found then
    raise exception 'plan not available' using errcode = 'P0002';
  end if;

  -- Carryover from the most recent completed subscription, once.
  select * into v_prev
    from subscriptions.subscriptions
   where user_id = v_sub.user_id
     and id <> v_sub.id
     and rollover_applied = false
     and status in ('active','expired')
   order by ends_at desc nulls last
   limit 1
   for update;
  if found then
    v_unused := greatest(v_prev.cups_entitled + v_prev.cups_carried_over - v_prev.cups_used - v_prev.cups_reserved, 0);
    v_carry := least(v_unused, v_plan.rollover_cap_cups);
    update subscriptions.subscriptions
       set status = 'expired', rollover_applied = true
     where id = v_prev.id;
  end if;

  v_end := v_start + (v_plan.duration_days || ' days')::interval;

  update subscriptions.subscriptions
     set status = 'active',
         starts_at = v_start,
         ends_at = v_end,
         cups_entitled = v_plan.cups_per_cycle,
         cups_used = 0,
         cups_carried_over = v_carry,
         cups_reserved = 0,
         bonus_balance = case when v_plan.bonus_type = 'none' then 0 else v_plan.bonus_value end,
         bonus_expires_at = case when v_plan.bonus_expires_with_cycle then v_end else null end,
         auto_renew = v_plan.renewal_policy = 'auto' and v_plan.auto_renew_supported,
         payment_reference = p_payment_reference,
         rollover_applied = true
   where id = v_sub.id;

  insert into subscriptions.subscription_events (subscription_id, user_id, event_type, payload)
  values (v_sub.id, v_sub.user_id, 'activated', jsonb_build_object('payment', p_payment_reference, 'carry', v_carry));

  return v_sub.id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Reservation helpers for order lifecycle.
-- ---------------------------------------------------------------------------
create or replace function subscriptions.reserve_for_order(
  p_order_id uuid,
  p_subscription_id uuid,
  p_branch_id uuid,
  p_lines jsonb,
  p_idempotency_key text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_sub subscriptions.subscriptions%rowtype;
  v_plan subscriptions.plans%rowtype;
  v_existing integer;
  v_total integer := 0;
  v_line jsonb;
  v_product_id uuid;
  v_quantity integer;
  v_order_item_id uuid;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  if coalesce(btrim(p_idempotency_key), '') = '' then raise exception 'idempotency key required' using errcode='23514'; end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'subscription lines required' using errcode='23514';
  end if;

  -- Idempotent retry.
  select coalesce(sum(quantity), 0)::integer into v_existing
    from subscriptions.subscription_consumptions
   where reservation_key = p_idempotency_key;
  if exists (select 1 from subscriptions.subscription_consumptions where reservation_key = p_idempotency_key) then
    return v_existing;
  end if;

  select * into v_sub from subscriptions.subscriptions where id = p_subscription_id for update;
  if not found or v_sub.user_id <> v_uid or v_sub.status <> 'active' or v_sub.ends_at is null or v_sub.ends_at <= now() then
    raise exception 'active subscription required' using errcode='P0002';
  end if;

  select * into v_plan from subscriptions.plans where id = v_sub.plan_id;
  if not found or not v_plan.is_active then
    raise exception 'plan not available' using errcode='P0002';
  end if;

  if not v_plan.all_branches and not exists (
        select 1 from subscriptions.plan_branches pb where pb.plan_id = v_plan.id and pb.branch_id = p_branch_id) then
    raise exception 'branch not allowed' using errcode='42501';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_product_id := nullif(v_line->>'product_id', '')::uuid;
    v_quantity := coalesce((v_line->>'quantity')::integer, 0);
    v_order_item_id := nullif(v_line->>'order_item_id', '')::uuid;
    if v_product_id is null or v_quantity <= 0 then
      raise exception 'invalid subscription line' using errcode='23514';
    end if;
    if v_plan.product_scope = 'selected' and not exists (
          select 1 from subscriptions.plan_products pp where pp.plan_id = v_plan.id and pp.product_id = v_product_id) then
      raise exception 'product not included' using errcode='42501';
    end if;
    v_total := v_total + v_quantity;
  end loop;

  if (v_sub.cups_entitled + v_sub.cups_carried_over - v_sub.cups_used - v_sub.cups_reserved) < v_total then
    raise exception 'not enough subscription cups' using errcode='23514';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_product_id := (v_line->>'product_id')::uuid;
    v_quantity := (v_line->>'quantity')::integer;
    v_order_item_id := nullif(v_line->>'order_item_id', '')::uuid;
    insert into subscriptions.subscription_consumptions
      (subscription_id, order_id, order_item_id, branch_id, product_id, quantity, status, idempotency_key, reservation_key)
    values
      (v_sub.id, p_order_id, v_order_item_id, p_branch_id, v_product_id, v_quantity, 'reserved', p_idempotency_key || ':' || v_product_id::text, p_idempotency_key);
  end loop;

  update subscriptions.subscriptions
     set cups_reserved = cups_reserved + v_total
   where id = v_sub.id;

  return v_total;
end;
$fn$;

create or replace function subscriptions.finalize_order_consumption(p_order_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_row subscriptions.subscription_consumptions%rowtype;
  v_count integer := 0;
begin
  for v_row in
    select * from subscriptions.subscription_consumptions
     where order_id = p_order_id and status = 'reserved'
     for update
  loop
    update subscriptions.subscriptions
       set cups_reserved = greatest(cups_reserved - v_row.quantity, 0),
           cups_used = cups_used + v_row.quantity
     where id = v_row.subscription_id;

    update subscriptions.subscription_consumptions
       set status = 'finalized'
     where id = v_row.id;
    v_count := v_count + v_row.quantity;
  end loop;
  return v_count;
end;
$fn$;

create or replace function subscriptions.release_order_consumption(p_order_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_row subscriptions.subscription_consumptions%rowtype;
  v_count integer := 0;
begin
  for v_row in
    select * from subscriptions.subscription_consumptions
     where order_id = p_order_id and status = 'reserved'
     for update
  loop
    update subscriptions.subscriptions
       set cups_reserved = greatest(cups_reserved - v_row.quantity, 0)
     where id = v_row.subscription_id;

    update subscriptions.subscription_consumptions
       set status = 'released'
     where id = v_row.id;
    v_count := v_count + v_row.quantity;
  end loop;
  return v_count;
end;
$fn$;

-- Trigger: finalize on completion, release on cancellation.
create or replace function subscriptions.handle_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    perform subscriptions.finalize_order_consumption(new.id);
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    perform subscriptions.release_order_consumption(new.id);
  end if;
  return new;
end;
$fn$;

drop trigger if exists tr_orders_subscription_consumption on orders.orders;
create trigger tr_orders_subscription_consumption
  after update of status on orders.orders
  for each row
  execute function subscriptions.handle_order_status_change();

-- Single-use QR token update.
create or replace function subscriptions.consume_qr(
  p_token text,
  p_branch_id uuid,
  p_product_id uuid,
  p_quantity integer default 1,
  p_idempotency_key text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_token subscriptions.qr_tokens%rowtype;
  v_sub subscriptions.subscriptions%rowtype;
  v_plan subscriptions.plans%rowtype;
  v_existing integer;
  v_available integer;
  v_remaining integer;
begin
  if v_uid is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if identity.has_permission('subscriptions.consume') is not true then
    raise exception 'subscription.consume permission required' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch management required' using errcode = '42501';
  end if;
  if not exists (select 1 from core.branches b where b.id = p_branch_id and b.is_active) then
    raise exception 'branch not active' using errcode = '23514';
  end if;
  if not exists (select 1 from catalog.products pr where pr.id = p_product_id and pr.is_active) then
    raise exception 'product not available' using errcode = 'P0002';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'invalid quantity' using errcode = '23514';
  end if;
  if coalesce(btrim(p_idempotency_key), '') = '' then
    raise exception 'idempotency key required' using errcode = '23514';
  end if;

  -- idempotent retry
  select (s.cups_entitled + s.cups_carried_over - s.cups_used - s.cups_reserved)
    into v_existing
    from subscriptions.subscription_usage u
    join subscriptions.subscriptions s on s.id = u.subscription_id
   where u.idempotency_key = p_idempotency_key;
  if found then
    return v_existing;
  end if;

  select * into v_token from subscriptions.qr_tokens
   where token = p_token and expires_at > now() and consumed_at is null
   for update;
  if not found then
    raise exception 'invalid, expired or already used token' using errcode = 'P0002';
  end if;

  select * into v_sub from subscriptions.subscriptions
   where id = v_token.subscription_id and status = 'active' and ends_at > now()
   for update;
  if not found then
    raise exception 'subscription not active' using errcode = 'P0002';
  end if;

  select * into v_plan from subscriptions.plans where id = v_sub.plan_id;
  if not found then raise exception 'plan not found' using errcode = 'P0002'; end if;

  if not v_plan.all_branches and not exists (
        select 1 from subscriptions.plan_branches pb
         where pb.plan_id = v_plan.id and pb.branch_id = p_branch_id) then
    raise exception 'branch not allowed' using errcode = '42501';
  end if;

  if v_plan.product_scope = 'selected' and not exists (
        select 1 from subscriptions.plan_products pp
         where pp.plan_id = v_plan.id and pp.product_id = p_product_id) then
    raise exception 'product not included' using errcode = '42501';
  end if;

  v_available := v_sub.cups_entitled + v_sub.cups_carried_over - v_sub.cups_used - v_sub.cups_reserved;
  if v_available < p_quantity then
    raise exception 'not enough cups' using errcode = '23514';
  end if;

  insert into subscriptions.subscription_usage
    (subscription_id, branch_id, product_id, quantity, method, idempotency_key, performed_by)
  values
    (v_sub.id, p_branch_id, p_product_id, p_quantity, 'qr', p_idempotency_key, v_uid);

  update subscriptions.subscriptions
     set cups_used = cups_used + p_quantity
   where id = v_sub.id;

  update subscriptions.qr_tokens
     set consumed_at = now()
   where token = p_token;

  v_remaining := v_available - p_quantity;

  insert into subscriptions.subscription_events (subscription_id, user_id, event_type, payload)
  values (v_sub.id, v_token.user_id, 'consumed_qr',
          jsonb_build_object('branch', p_branch_id, 'product', p_product_id, 'qty', p_quantity));

  return v_remaining;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Public bridge wrappers.
-- ---------------------------------------------------------------------------
create or replace function public.create_pending_subscription(p_plan_id uuid, p_idempotency_key text)
returns uuid
language sql security invoker set search_path = ''
as $fn$ select subscriptions.create_pending_subscription(p_plan_id, p_idempotency_key); $fn$;

create or replace function public.activate_subscription(p_subscription_id uuid, p_payment_reference text)
returns uuid
language sql security invoker set search_path = ''
as $fn$ select subscriptions.activate_subscription(p_subscription_id, p_payment_reference); $fn$;

create or replace function public.reserve_subscription_for_order(
  p_order_id uuid, p_subscription_id uuid, p_branch_id uuid, p_lines jsonb, p_idempotency_key text
)
returns integer
language sql security invoker set search_path = ''
as $fn$ select subscriptions.reserve_for_order(p_order_id, p_subscription_id, p_branch_id, p_lines, p_idempotency_key); $fn$;

-- Grants.
grant execute on function
  public.create_pending_subscription(uuid, text),
  public.activate_subscription(uuid, text),
  public.reserve_subscription_for_order(uuid, uuid, uuid, jsonb, text)
  to authenticated;

revoke execute on function
  public.create_pending_subscription(uuid, text),
  public.activate_subscription(uuid, text),
  public.reserve_subscription_for_order(uuid, uuid, uuid, jsonb, text)
  from anon;

-- Remove the previous unsafe direct-activation entry points.
drop function if exists public.subscribe_to_plan(uuid, text, text);
drop function if exists public.renew_subscription(uuid, text, text);
drop function if exists subscriptions.subscribe(uuid, text, text);
drop function if exists subscriptions.renew(uuid, text, text);
