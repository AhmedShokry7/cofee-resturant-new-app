-- 013_payments_01.sql
-- Payment methods, attempts and transactions.
--
-- Hard rule: there is no PAN column and no CVV column anywhere in this
-- schema, by design. Only a provider reference, the brand and last four
-- digits may ever be stored.
--
-- The Flutter app stored id/brand/last4/holder/expiry as plaintext JSON in
-- SharedPreferences ('saved_cards_v1'). That moves here, still without a PAN.

create table if not exists payments.payment_methods (
  id                  uuid primary key default extensions.gen_random_uuid(),
  code                text not null unique check (code ~ '^[a-z_]+$'),
  name_ar             text not null,
  name_en             text not null,
  is_active           boolean not null default true,
  is_online           boolean not null default false,
  sort_order          integer not null default 0,
  requires_saved_card boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on table payments.payment_methods is
  'Available payment methods. is_online is informational; no real gateway in v1.';

create index if not exists ix_payment_methods_active
  on payments.payment_methods (sort_order) where is_active;

-- orders.payment_method_id FK, wired now that payment_methods exists.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_payment_method_fkey'
      and conrelid = 'orders.orders'::regclass
  ) then
    alter table orders.orders
      add constraint orders_payment_method_fkey
      foreign key (payment_method_id) references payments.payment_methods(id) on delete set null;
  end if;
end $$;

-- ---------------------------------------------------------------------------
create table if not exists payments.payment_attempts (
  id                uuid primary key default extensions.gen_random_uuid(),
  order_id          uuid not null references orders.orders(id) on delete cascade,
  method_id         uuid not null references payments.payment_methods(id) on delete restrict,
  status            text not null check (status in
                      ('initiated','requires_action','processing','succeeded','failed','cancelled')),
  failure_code      text,
  failure_message   text,
  client_initiated  boolean not null default true,
  started_at        timestamptz not null default now(),
  finished_at       timestamptz
);

comment on table payments.payment_attempts is
  'One row per payment try. client_initiated is recorded so the server can tell a real confirmation from a forged one.';

create index if not exists ix_payment_attempts_order
  on payments.payment_attempts (order_id, started_at desc);

-- ---------------------------------------------------------------------------
create table if not exists payments.payment_transactions (
  id                 uuid primary key default extensions.gen_random_uuid(),
  order_id           uuid not null references orders.orders(id) on delete cascade,
  attempt_id         uuid references payments.payment_attempts(id) on delete set null,
  provider           text,
  provider_reference text,
  amount             numeric(12,2) not null check (amount > 0),
  currency_code      text not null default 'SAR',
  status             text not null check (status in
                       ('pending','authorized','captured','failed','refunded','voided')),
  paid_at            timestamptz,
  refunded_at        timestamptz,
  card_brand         text,
  card_last4         text check (card_last4 ~ '^[0-9]{4}$'),
  card_holder_name   text,
  -- stays false until a trusted server-side provider callback exists
  verified_by_server boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table payments.payment_transactions is
  'Transactions. No PAN, no CVV, ever. verified_by_server stays false in v1.';

create index if not exists ix_payment_tx_order
  on payments.payment_transactions (order_id, created_at desc);
create unique index if not exists uq_payment_tx_provider_ref
  on payments.payment_transactions (provider, provider_reference)
  where provider_reference is not null;

create trigger tr_payment_tx_updated_at
  before update on payments.payment_transactions
  for each row execute function core.set_updated_at();

-- Guard: a transaction may only be marked paid if the server verified it.
create or replace function payments.guard_payment_status()
returns trigger
language plpgsql
as $fn$
begin
  if new.status in ('captured','authorized') and not new.verified_by_server then
    raise exception
      'payment cannot be marked % without server verification', new.status
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;

create trigger tr_payment_tx_verified
  before update on payments.payment_transactions
  for each row execute function payments.guard_payment_status();

comment on function payments.guard_payment_status() is
  'Blocks marking a payment captured/authorized without verified_by_server (acceptance test 25).';