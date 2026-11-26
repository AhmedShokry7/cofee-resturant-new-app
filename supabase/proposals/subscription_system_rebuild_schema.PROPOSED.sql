-- REVIEW ONLY. Additive schema draft for an isolated development database.
-- Do not apply to production. Posting, invoicing and refunds remain blocked
-- until the accounting/VAT decisions in the companion audit are approved.
-- This file deliberately contains no data migration or customer cancellation.

begin;

-- A sold offer version is immutable. The existing subscriptions.plans rows
-- remain the legacy package catalog and historical foreign-key targets.
create table subscriptions.offer_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  legacy_plan_id uuid references subscriptions.plans(id) on delete restrict,
  offer_kind text not null check (offer_kind in ('package_pool','product_specific')),
  version integer not null check (version > 0),
  state text not null check (state in ('draft','published','retired')),
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  price numeric(12,2) not null check (price >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  duration_days integer not null check (duration_days > 0),
  pool_units integer check (pool_units > 0),
  daily_limit integer check (daily_limit > 0),
  rollover_cap integer not null default 0 check (rollover_cap >= 0),
  all_branches boolean not null default false,
  terms_snapshot jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (legacy_plan_id, version),
  check (
    (offer_kind = 'package_pool' and pool_units is not null)
    or (offer_kind = 'product_specific' and pool_units is null)
  ),
  check (state <> 'published' or published_at is not null)
);

create table subscriptions.offer_version_products (
  offer_version_id uuid not null references subscriptions.offer_versions(id) on delete restrict,
  product_id uuid not null references catalog.products(id) on delete restrict,
  product_units integer,
  pool_unit_cost integer not null default 1 check (pool_unit_cost > 0),
  primary key (offer_version_id, product_id),
  check (product_units is null or product_units > 0)
);

create table subscriptions.offer_version_branches (
  offer_version_id uuid not null references subscriptions.offer_versions(id) on delete restrict,
  branch_id uuid not null references core.branches(id) on delete restrict,
  primary key (offer_version_id, branch_id)
);

-- A purchase is a financial intent, never a balance. The amount and terms are
-- captured from the server-published offer, never from client totals.
create table subscriptions.purchases (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references identity.profiles(id) on delete restrict,
  offer_version_id uuid not null references subscriptions.offer_versions(id) on delete restrict,
  funding_source text not null check (funding_source in ('paid','free','reward','counter_grant')),
  status text not null check (status in (
    'pending_payment','payment_processing','paid','payment_failed',
    'refund_pending','partially_refunded','refunded','cancelled'
  )),
  amount numeric(12,2) not null check (amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  idempotency_key text not null,
  terms_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  unique (user_id, idempotency_key),
  check (funding_source = 'paid' or amount = 0)
);

-- Keep existing payments.payment_transactions as the real gateway record.
-- Never synthesize a transaction for free/reward grants or covered orders.
create table subscriptions.purchase_payment_links (
  purchase_id uuid not null references subscriptions.purchases(id) on delete restrict,
  payment_transaction_id uuid not null references payments.payment_transactions(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (purchase_id, payment_transaction_id),
  unique (payment_transaction_id)
);

-- The account identifies pooled versus per-product spendability. A purchase
-- may create one package pool or one account per purchased product.
create table subscriptions.entitlement_accounts (
  id uuid primary key default extensions.gen_random_uuid(),
  purchase_id uuid not null references subscriptions.purchases(id) on delete restrict,
  user_id uuid not null references identity.profiles(id) on delete restrict,
  account_kind text not null check (account_kind in ('package_pool','product_specific')),
  product_id uuid references catalog.products(id) on delete restrict,
  state text not null check (state in ('active','expired','cancelled')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check ((account_kind = 'package_pool') = (product_id is null)),
  unique (purchase_id, account_kind, product_id)
);
create unique index entitlement_one_pool_per_purchase
  on subscriptions.entitlement_accounts (purchase_id)
  where account_kind = 'package_pool';

-- Append-only movement record. A DB RPC must lock the account and validate
-- the transition before inserting an event. The unique key prevents replay.
-- Available and reserved totals are derived from this ledger or a locked
-- projection updated in the same transaction; neither is client-writable.
create table subscriptions.entitlement_events (
  id uuid primary key default extensions.gen_random_uuid(),
  account_id uuid not null references subscriptions.entitlement_accounts(id) on delete restrict,
  user_id uuid not null references identity.profiles(id) on delete restrict,
  product_id uuid references catalog.products(id) on delete restrict,
  order_id uuid references orders.orders(id) on delete restrict,
  event_type text not null check (event_type in (
    'grant','reserve','consume','release','expire','revoke','refund_adjustment'
  )),
  units integer not null check (units > 0),
  reason text not null,
  actor_id uuid references auth.users(id) on delete set null,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  check (event_type not in ('reserve','consume','release') or order_id is not null)
);
create index entitlement_events_account_time
  on subscriptions.entitlement_events (account_id, created_at, id);
create index entitlement_events_order
  on subscriptions.entitlement_events (order_id)
  where order_id is not null;

-- An order allocation binds exact order lines to entitlement units and cash
-- coverage. The amount is derived by the server from sold pricing rules.
create table subscriptions.order_allocations (
  id uuid primary key default extensions.gen_random_uuid(),
  order_id uuid not null references orders.orders(id) on delete restrict,
  account_id uuid not null references subscriptions.entitlement_accounts(id) on delete restrict,
  product_id uuid not null references catalog.products(id) on delete restrict,
  units integer not null check (units > 0),
  coverage_amount numeric(12,2) not null check (coverage_amount >= 0),
  state text not null check (state in ('reserved','consumed','released')),
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  unique (order_id, account_id, product_id)
);

-- Customer reads are scoped to their own rows or published offers. All writes
-- use reviewed, narrowly scoped SECURITY DEFINER RPCs; no app table writes.
alter table subscriptions.offer_versions enable row level security;
alter table subscriptions.offer_version_products enable row level security;
alter table subscriptions.offer_version_branches enable row level security;
alter table subscriptions.purchases enable row level security;
alter table subscriptions.purchase_payment_links enable row level security;
alter table subscriptions.entitlement_accounts enable row level security;
alter table subscriptions.entitlement_events enable row level security;
alter table subscriptions.order_allocations enable row level security;

create policy published_offer_read on subscriptions.offer_versions
  for select to authenticated using (state = 'published');
create policy published_offer_products_read on subscriptions.offer_version_products
  for select to authenticated using (exists (
    select 1 from subscriptions.offer_versions v
     where v.id = offer_version_id and v.state = 'published'
  ));
create policy published_offer_branches_read on subscriptions.offer_version_branches
  for select to authenticated using (exists (
    select 1 from subscriptions.offer_versions v
     where v.id = offer_version_id and v.state = 'published'
  ));
create policy own_purchase_read on subscriptions.purchases
  for select to authenticated using (user_id = auth.uid());
create policy own_purchase_payment_link_read on subscriptions.purchase_payment_links
  for select to authenticated using (exists (
    select 1 from subscriptions.purchases p
     where p.id = purchase_id and p.user_id = auth.uid()
  ));
create policy own_account_read on subscriptions.entitlement_accounts
  for select to authenticated using (user_id = auth.uid());
create policy own_entitlement_event_read on subscriptions.entitlement_events
  for select to authenticated using (user_id = auth.uid());
create policy own_allocation_read on subscriptions.order_allocations
  for select to authenticated using (exists (
    select 1 from subscriptions.entitlement_accounts a
     where a.id = account_id and a.user_id = auth.uid()
  ));

revoke all on subscriptions.offer_versions,
  subscriptions.offer_version_products, subscriptions.offer_version_branches,
  subscriptions.purchases, subscriptions.purchase_payment_links,
  subscriptions.entitlement_accounts, subscriptions.entitlement_events,
  subscriptions.order_allocations from anon, authenticated;
grant select on subscriptions.offer_versions,
  subscriptions.offer_version_products, subscriptions.offer_version_branches,
  subscriptions.purchases, subscriptions.purchase_payment_links,
  subscriptions.entitlement_accounts, subscriptions.entitlement_events,
  subscriptions.order_allocations to authenticated;

-- Staff reads require dedicated RPCs with current permission and branch checks.
-- Service-role writes must be limited to those RPCs in the application layer.
-- This draft is intentionally rolled back even if executed by mistake.
rollback;
