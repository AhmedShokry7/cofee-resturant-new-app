-- 074_subscriptions_01.sql
-- Coffee subscription plans, customer subscriptions, usage, QR tokens and RPCs.

create schema if not exists subscriptions;

-- ---------------------------------------------------------------------------
-- Plans (admin-managed).
-- ---------------------------------------------------------------------------
create table if not exists subscriptions.plans (
  id                    uuid primary key default extensions.gen_random_uuid(),
  code                  text not null unique,
  name_ar               text not null,
  name_en               text not null,
  description_ar        text,
  description_en        text,
  price                 numeric(12,2) not null check (price >= 0),
  currency_code         text not null default 'SAR',
  duration_days         integer not null default 30 check (duration_days > 0),
  cups_per_cycle        integer not null default 0 check (cups_per_cycle >= 0),
  bonus_type            text not null default 'none'
                          check (bonus_type in ('none','percent','fixed','points')),
  bonus_value           numeric(12,2) not null default 0 check (bonus_value >= 0),
  bonus_expires_with_cycle boolean not null default true,
  rollover_cap_cups     integer not null default 0 check (rollover_cap_cups >= 0),
  renewal_policy        text not null default 'manual'
                          check (renewal_policy in ('manual','auto')),
  auto_renew_supported  boolean not null default false,
  all_branches          boolean not null default true,
  product_scope         text not null default 'all'
                          check (product_scope in ('all','selected')),
  is_active             boolean not null default true,
  is_for_sale           boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger tr_subscription_plans_updated_at
  before update on subscriptions.plans
  for each row execute function core.set_updated_at();

create table if not exists subscriptions.plan_branches (
  plan_id   uuid not null references subscriptions.plans(id) on delete cascade,
  branch_id uuid not null references core.branches(id) on delete cascade,
  primary key (plan_id, branch_id)
);

create table if not exists subscriptions.plan_products (
  plan_id    uuid not null references subscriptions.plans(id) on delete cascade,
  product_id uuid not null references catalog.products(id) on delete cascade,
  primary key (plan_id, product_id)
);

-- ---------------------------------------------------------------------------
-- Customer subscriptions.
-- ---------------------------------------------------------------------------
create table if not exists subscriptions.subscriptions (
  id                   uuid primary key default extensions.gen_random_uuid(),
  user_id              uuid not null references identity.profiles(id) on delete cascade,
  plan_id              uuid not null references subscriptions.plans(id) on delete restrict,
  status               text not null default 'active'
                         check (status in ('active','expired','cancelled','pending_payment')),
  starts_at            timestamptz not null default now(),
  ends_at              timestamptz not null,
  cups_entitled        integer not null default 0 check (cups_entitled >= 0),
  cups_used            integer not null default 0 check (cups_used >= 0),
  cups_carried_over    integer not null default 0 check (cups_carried_over >= 0),
  bonus_balance        numeric(12,2) not null default 0 check (bonus_balance >= 0),
  bonus_expires_at     timestamptz,
  auto_renew           boolean not null default false,
  payment_reference    text,
  idempotency_key      text not null,
  rollover_applied     boolean not null default false,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (idempotency_key)
);

create index if not exists ix_subscriptions_user on subscriptions.subscriptions (user_id, created_at desc);
create index if not exists ix_subscriptions_active on subscriptions.subscriptions (user_id, status) where status = 'active';

create trigger tr_subscriptions_updated_at
  before update on subscriptions.subscriptions
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Usage log (idempotent by key).
-- ---------------------------------------------------------------------------
create table if not exists subscriptions.subscription_usage (
  id                uuid primary key default extensions.gen_random_uuid(),
  subscription_id   uuid not null references subscriptions.subscriptions(id) on delete cascade,
  branch_id         uuid not null references core.branches(id) on delete restrict,
  product_id        uuid references catalog.products(id) on delete set null,
  order_id          uuid references orders.orders(id) on delete set null,
  quantity          integer not null default 1 check (quantity > 0),
  method            text not null check (method in ('qr','app_order','manual')),
  idempotency_key   text not null,
  performed_by      uuid references auth.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  unique (idempotency_key)
);

create index if not exists ix_subscription_usage_sub on subscriptions.subscription_usage (subscription_id, created_at desc);

-- ---------------------------------------------------------------------------
-- QR tokens.
-- ---------------------------------------------------------------------------
create table if not exists subscriptions.qr_tokens (
  token            text primary key,
  user_id          uuid not null references identity.profiles(id) on delete cascade,
  subscription_id  uuid not null references subscriptions.subscriptions(id) on delete cascade,
  expires_at       timestamptz not null,
  created_at       timestamptz not null default now()
);

create index if not exists ix_qr_tokens_sub on subscriptions.qr_tokens (subscription_id, expires_at desc);

-- ---------------------------------------------------------------------------
-- Events / audit.
-- ---------------------------------------------------------------------------
create table if not exists subscriptions.subscription_events (
  id              bigserial primary key,
  subscription_id uuid references subscriptions.subscriptions(id) on delete cascade,
  user_id         uuid references identity.profiles(id) on delete set null,
  event_type      text not null,
  payload         jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RLS.
-- ---------------------------------------------------------------------------
alter table subscriptions.plans enable row level security;
alter table subscriptions.plan_branches enable row level security;
alter table subscriptions.plan_products enable row level security;
alter table subscriptions.subscriptions enable row level security;
alter table subscriptions.subscription_usage enable row level security;
alter table subscriptions.qr_tokens enable row level security;
alter table subscriptions.subscription_events enable row level security;

-- Plans: public read of active plans; writes by permission.
create policy plans_read on subscriptions.plans
  for select using (is_active and is_for_sale);
create policy plans_write on subscriptions.plans
  for all using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

create policy plan_branches_read on subscriptions.plan_branches
  for select using (true);
create policy plan_branches_write on subscriptions.plan_branches
  for all using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

create policy plan_products_read on subscriptions.plan_products
  for select using (true);
create policy plan_products_write on subscriptions.plan_products
  for all using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

-- Subscriptions: owner or staff with permission.
create policy subscriptions_read on subscriptions.subscriptions
  for select using (
    user_id = auth.uid() or identity.has_permission('subscriptions.consume') or identity.has_permission('subscriptions.manage')
  );
create policy subscriptions_write on subscriptions.subscriptions
  for all using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

-- Usage: owner or staff.
create policy usage_read on subscriptions.subscription_usage
  for select using (
    exists (select 1 from subscriptions.subscriptions s where s.id = subscription_id and s.user_id = auth.uid())
    or identity.has_permission('subscriptions.consume')
    or identity.has_permission('subscriptions.manage')
  );

-- QR tokens: owner only.
create policy qr_tokens_read on subscriptions.qr_tokens
  for select using (user_id = auth.uid());
create policy qr_tokens_write on subscriptions.qr_tokens
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Events: owner or staff.
create policy events_read on subscriptions.subscription_events
  for select using (
    user_id = auth.uid() or identity.has_permission('subscriptions.consume') or identity.has_permission('subscriptions.manage')
  );

-- ---------------------------------------------------------------------------
-- Permission seed.
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('subscriptions.manage',  'إدارة الاشتراكات', 'Manage subscriptions', null),
  ('subscriptions.consume', 'استهلاك الاشتراك', 'Consume subscription', null)
on conflict (code) do nothing;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r join identity.permissions p
  on p.code in ('subscriptions.manage','subscriptions.consume')
 where r.code = 'manager'
on conflict do nothing;
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r join identity.permissions p
  on p.code in ('subscriptions.manage','subscriptions.consume')
 where r.code = 'branch_manager'
on conflict do nothing;
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r join identity.permissions p
  on p.code = 'subscriptions.consume'
 where r.code = 'cashier'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Functions.
-- ---------------------------------------------------------------------------
create or replace function subscriptions.list_plans(p_branch_id uuid default null)
returns table (
  id uuid, code text, name_ar text, name_en text, description_ar text, description_en text,
  price numeric, currency_code text, duration_days integer, cups_per_cycle integer,
  bonus_type text, bonus_value numeric, bonus_expires_with_cycle boolean,
  rollover_cap_cups integer, renewal_policy text, auto_renew_supported boolean,
  all_branches boolean, product_scope text, is_active boolean, is_for_sale boolean
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select p.id, p.code, p.name_ar, p.name_en, p.description_ar, p.description_en,
         p.price, p.currency_code, p.duration_days, p.cups_per_cycle,
         p.bonus_type, p.bonus_value, p.bonus_expires_with_cycle,
         p.rollover_cap_cups, p.renewal_policy, p.auto_renew_supported,
         p.all_branches, p.product_scope, p.is_active, p.is_for_sale
    from subscriptions.plans p
   where p.is_active and p.is_for_sale
     and (p.all_branches or p_branch_id is null or exists (
           select 1 from subscriptions.plan_branches pb
            where pb.plan_id = p.id and pb.branch_id = p_branch_id))
   order by p.price;
$fn$;

create or replace function subscriptions.subscribe(
  p_plan_id uuid,
  p_payment_reference text,
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
  v_prev subscriptions.subscriptions%rowtype;
  v_existing uuid;
  v_carry integer := 0;
  v_unused integer;
  v_start timestamptz := now();
  v_end timestamptz;
  v_new uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if coalesce(btrim(p_payment_reference), '') = '' then
    raise exception 'payment reference required' using errcode = '23514';
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

  -- carryover from the most recent subscription, once.
  select * into v_prev
    from subscriptions.subscriptions
   where user_id = v_uid
     and rollover_applied = false
   order by ends_at desc
   limit 1
   for update;

  if found then
    v_unused := greatest(v_prev.cups_entitled + v_prev.cups_carried_over - v_prev.cups_used, 0);
    v_carry := least(v_unused, v_plan.rollover_cap_cups);
    update subscriptions.subscriptions
       set status = 'expired', rollover_applied = true
     where id = v_prev.id;
  end if;

  v_end := v_start + (v_plan.duration_days || ' days')::interval;

  insert into subscriptions.subscriptions
    (user_id, plan_id, status, starts_at, ends_at, cups_entitled, cups_used,
     cups_carried_over, bonus_balance, bonus_expires_at, auto_renew,
     payment_reference, idempotency_key)
  values
    (v_uid, v_plan.id, 'active', v_start, v_end, v_plan.cups_per_cycle, 0,
     v_carry,
     case when v_plan.bonus_type = 'none' then 0 else v_plan.bonus_value end,
     case when v_plan.bonus_expires_with_cycle then v_end else null end,
     v_plan.renewal_policy = 'auto' and v_plan.auto_renew_supported,
     p_payment_reference, p_idempotency_key)
  returning id into v_new;

  insert into subscriptions.subscription_events (subscription_id, user_id, event_type, payload)
  values (v_new, v_uid, 'subscribed', jsonb_build_object('plan', v_plan.id, 'carry', v_carry));

  return v_new;
end;
$fn$;

create or replace function subscriptions.renew(
  p_subscription_id uuid,
  p_payment_reference text,
  p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_old subscriptions.subscriptions%rowtype;
  v_plan subscriptions.plans%rowtype;
  v_existing uuid;
  v_carry integer := 0;
  v_unused integer;
  v_start timestamptz := now();
  v_end timestamptz;
  v_new uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if coalesce(btrim(p_payment_reference), '') = '' then
    raise exception 'payment reference required' using errcode = '23514';
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

  select * into v_old from subscriptions.subscriptions
   where id = p_subscription_id and user_id = v_uid for update;
  if not found then
    raise exception 'subscription not found' using errcode = 'P0002';
  end if;

  select * into v_plan from subscriptions.plans where id = v_old.plan_id and is_active and is_for_sale for update;
  if not found then
    raise exception 'plan not available' using errcode = 'P0002';
  end if;

  if v_old.rollover_applied = false then
    v_unused := greatest(v_old.cups_entitled + v_old.cups_carried_over - v_old.cups_used, 0);
    v_carry := least(v_unused, v_plan.rollover_cap_cups);
    update subscriptions.subscriptions
       set status = 'expired', rollover_applied = true
     where id = v_old.id;
  else
    update subscriptions.subscriptions set status = 'expired' where id = v_old.id;
  end if;

  v_end := v_start + (v_plan.duration_days || ' days')::interval;

  insert into subscriptions.subscriptions
    (user_id, plan_id, status, starts_at, ends_at, cups_entitled, cups_used,
     cups_carried_over, bonus_balance, bonus_expires_at, auto_renew,
     payment_reference, idempotency_key)
  values
    (v_uid, v_plan.id, 'active', v_start, v_end, v_plan.cups_per_cycle, 0,
     v_carry,
     case when v_plan.bonus_type = 'none' then 0 else v_plan.bonus_value end,
     case when v_plan.bonus_expires_with_cycle then v_end else null end,
     v_old.auto_renew and v_plan.auto_renew_supported,
     p_payment_reference, p_idempotency_key)
  returning id into v_new;

  insert into subscriptions.subscription_events (subscription_id, user_id, event_type, payload)
  values (v_new, v_uid, 'renewed', jsonb_build_object('previous', v_old.id, 'carry', v_carry));

  return v_new;
end;
$fn$;

create or replace function subscriptions.set_auto_renew(p_subscription_id uuid, p_enabled boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  update subscriptions.subscriptions
     set auto_renew = p_enabled
   where id = p_subscription_id and user_id = v_uid and status = 'active';
  if not found then raise exception 'subscription not found' using errcode='P0002'; end if;
  return true;
end;
$fn$;

create or replace function subscriptions.cancel_subscription(p_subscription_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  update subscriptions.subscriptions
     set status = 'cancelled', auto_renew = false, ends_at = least(ends_at, now())
   where id = p_subscription_id and user_id = v_uid and status = 'active';
  if not found then raise exception 'subscription not found' using errcode='P0002'; end if;
  return true;
end;
$fn$;

create or replace function subscriptions.generate_qr_token(p_subscription_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_sub subscriptions.subscriptions%rowtype;
  v_token text;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  select * into v_sub from subscriptions.subscriptions
   where id = p_subscription_id and user_id = v_uid and status = 'active' and ends_at > now();
  if not found then raise exception 'active subscription required' using errcode='P0002'; end if;

  v_token := encode(extensions.gen_random_bytes(16), 'hex');
  insert into subscriptions.qr_tokens (token, user_id, subscription_id, expires_at)
  values (v_token, v_uid, v_sub.id, now() + interval '5 minutes');
  return v_token;
end;
$fn$;

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
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  if identity.has_permission('subscriptions.consume') is not true then
    raise exception 'subscription.consume permission required' using errcode='42501';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'invalid quantity' using errcode='23514';
  end if;
  if coalesce(btrim(p_idempotency_key), '') = '' then
    raise exception 'idempotency key required' using errcode='23514';
  end if;

  -- idempotent retry
  select (s.cups_entitled + s.cups_carried_over - s.cups_used)
    into v_existing
    from subscriptions.subscription_usage u
    join subscriptions.subscriptions s on s.id = u.subscription_id
   where u.idempotency_key = p_idempotency_key;
  if found then
    return v_existing;
  end if;

  select * into v_token from subscriptions.qr_tokens
   where token = p_token and expires_at > now()
   for update;
  if not found then
    raise exception 'invalid or expired token' using errcode='P0002';
  end if;

  select * into v_sub from subscriptions.subscriptions
   where id = v_token.subscription_id and status = 'active' and ends_at > now()
   for update;
  if not found then
    raise exception 'subscription not active' using errcode='P0002';
  end if;

  select * into v_plan from subscriptions.plans where id = v_sub.plan_id;
  if not found then raise exception 'plan not found' using errcode='P0002'; end if;

  if not v_plan.all_branches and not exists (
        select 1 from subscriptions.plan_branches pb
         where pb.plan_id = v_plan.id and pb.branch_id = p_branch_id) then
    raise exception 'branch not allowed' using errcode='42501';
  end if;

  if v_plan.product_scope = 'selected' and not exists (
        select 1 from subscriptions.plan_products pp
         where pp.plan_id = v_plan.id and pp.product_id = p_product_id) then
    raise exception 'product not included' using errcode='42501';
  end if;

  v_available := v_sub.cups_entitled + v_sub.cups_carried_over - v_sub.cups_used;
  if v_available < p_quantity then
    raise exception 'not enough cups' using errcode='23514';
  end if;

  insert into subscriptions.subscription_usage
    (subscription_id, branch_id, product_id, quantity, method, idempotency_key, performed_by)
  values
    (v_sub.id, p_branch_id, p_product_id, p_quantity, 'qr', p_idempotency_key, v_uid);

  update subscriptions.subscriptions
     set cups_used = cups_used + p_quantity
   where id = v_sub.id;

  v_remaining := v_available - p_quantity;

  insert into subscriptions.subscription_events (subscription_id, user_id, event_type, payload)
  values (v_sub.id, v_token.user_id, 'consumed_qr',
          jsonb_build_object('branch', p_branch_id, 'product', p_product_id, 'qty', p_quantity));

  return v_remaining;
end;
$fn$;

create or replace function subscriptions.my_subscription()
returns table (
  id uuid, plan_id uuid, plan_name_ar text, plan_name_en text, status text,
  starts_at timestamptz, ends_at timestamptz, cups_entitled integer,
  cups_used integer, cups_carried_over integer, bonus_balance numeric,
  bonus_expires_at timestamptz, auto_renew boolean, created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select s.id, s.plan_id, p.name_ar, p.name_en, s.status, s.starts_at, s.ends_at,
         s.cups_entitled, s.cups_used, s.cups_carried_over, s.bonus_balance,
         s.bonus_expires_at, s.auto_renew, s.created_at
    from subscriptions.subscriptions s
    join subscriptions.plans p on p.id = s.plan_id
   where s.user_id = auth.uid()
   order by s.created_at desc
   limit 1;
$fn$;

create or replace function subscriptions.usage_history(p_subscription_id uuid default null)
returns table (
  id uuid, subscription_id uuid, branch_id uuid, product_id uuid, quantity integer,
  method text, created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select u.id, u.subscription_id, u.branch_id, u.product_id, u.quantity, u.method, u.created_at
    from subscriptions.subscription_usage u
    join subscriptions.subscriptions s on s.id = u.subscription_id
   where s.user_id = auth.uid()
     and (p_subscription_id is null or u.subscription_id = p_subscription_id)
   order by u.created_at desc
   limit 100;
$fn$;

-- ---------------------------------------------------------------------------
-- Public bridge wrappers.
-- ---------------------------------------------------------------------------
create or replace function public.list_subscription_plans(p_branch_id uuid default null)
returns table (
  id uuid, code text, name_ar text, name_en text, description_ar text, description_en text,
  price numeric, currency_code text, duration_days integer, cups_per_cycle integer,
  bonus_type text, bonus_value numeric, bonus_expires_with_cycle boolean,
  rollover_cap_cups integer, renewal_policy text, auto_renew_supported boolean,
  all_branches boolean, product_scope text, is_active boolean, is_for_sale boolean
)
language sql stable security invoker set search_path = ''
as $fn$ select * from subscriptions.list_plans(p_branch_id); $fn$;

create or replace function public.subscribe_to_plan(p_plan_id uuid, p_payment_reference text, p_idempotency_key text)
returns uuid
language sql security invoker set search_path = ''
as $fn$ select subscriptions.subscribe(p_plan_id, p_payment_reference, p_idempotency_key); $fn$;

create or replace function public.renew_subscription(p_subscription_id uuid, p_payment_reference text, p_idempotency_key text)
returns uuid
language sql security invoker set search_path = ''
as $fn$ select subscriptions.renew(p_subscription_id, p_payment_reference, p_idempotency_key); $fn$;

create or replace function public.set_subscription_auto_renew(p_subscription_id uuid, p_enabled boolean)
returns boolean
language sql security invoker set search_path = ''
as $fn$ select subscriptions.set_auto_renew(p_subscription_id, p_enabled); $fn$;

create or replace function public.cancel_subscription(p_subscription_id uuid)
returns boolean
language sql security invoker set search_path = ''
as $fn$ select subscriptions.cancel_subscription(p_subscription_id); $fn$;

create or replace function public.generate_subscription_qr(p_subscription_id uuid)
returns text
language sql security invoker set search_path = ''
as $fn$ select subscriptions.generate_qr_token(p_subscription_id); $fn$;

create or replace function public.consume_subscription_qr(
  p_token text, p_branch_id uuid, p_product_id uuid, p_quantity integer default 1, p_idempotency_key text default null
)
returns integer
language sql security invoker set search_path = ''
as $fn$ select subscriptions.consume_qr(p_token, p_branch_id, p_product_id, p_quantity, p_idempotency_key); $fn$;

create or replace function public.my_subscription()
returns table (
  id uuid, plan_id uuid, plan_name_ar text, plan_name_en text, status text,
  starts_at timestamptz, ends_at timestamptz, cups_entitled integer,
  cups_used integer, cups_carried_over integer, bonus_balance numeric,
  bonus_expires_at timestamptz, auto_renew boolean, created_at timestamptz
)
language sql stable security invoker set search_path = ''
as $fn$ select * from subscriptions.my_subscription(); $fn$;

create or replace function public.subscription_usage_history(p_subscription_id uuid default null)
returns table (
  id uuid, subscription_id uuid, branch_id uuid, product_id uuid, quantity integer,
  method text, created_at timestamptz
)
language sql stable security invoker set search_path = ''
as $fn$ select * from subscriptions.usage_history(p_subscription_id); $fn$;

-- Grants.
grant usage on schema subscriptions to anon, authenticated;
grant select on subscriptions.plans, subscriptions.plan_branches, subscriptions.plan_products to anon, authenticated;

grant execute on function
  public.list_subscription_plans(uuid),
  public.my_subscription(),
  public.subscription_usage_history(uuid)
  to anon, authenticated;

grant execute on function
  public.subscribe_to_plan(uuid, text, text),
  public.renew_subscription(uuid, text, text),
  public.set_subscription_auto_renew(uuid, boolean),
  public.cancel_subscription(uuid),
  public.generate_subscription_qr(uuid)
  to authenticated;

grant execute on function
  public.consume_subscription_qr(text, uuid, uuid, integer, text)
  to authenticated;

revoke execute on function
  public.subscribe_to_plan(uuid, text, text),
  public.renew_subscription(uuid, text, text),
  public.set_subscription_auto_renew(uuid, boolean),
  public.cancel_subscription(uuid),
  public.generate_subscription_qr(uuid),
  public.consume_subscription_qr(text, uuid, uuid, integer, text)
  from anon;
