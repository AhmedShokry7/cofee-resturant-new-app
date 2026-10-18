-- 061_payments_tap_01.sql
-- Tap Payments integration schema.
--
-- Adds Tap-specific persistence for customer mapping, saved cards, payment
-- idempotency and webhook deduplication. No PAN/CVV is ever stored; only
-- provider references, brand, last4 and expiry metadata.

create table if not exists payments.tap_customers (
  user_id         uuid primary key references identity.profiles(id) on delete cascade,
  tap_customer_id text not null unique,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger tr_tap_customers_updated_at
  before update on payments.tap_customers
  for each row execute function core.set_updated_at();

create table if not exists payments.saved_cards (
  id                    uuid primary key default extensions.gen_random_uuid(),
  user_id               uuid not null references identity.profiles(id) on delete cascade,
  tap_customer_id       text not null,
  tap_card_id           text not null,
  payment_agreement_id  text,
  brand                 text,
  last4                 text check (last4 ~ '^[0-9]{4}$'),
  expiry_month          text,
  expiry_year           text,
  holder_name           text,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (tap_customer_id, tap_card_id)
);

create index if not exists ix_saved_cards_user
  on payments.saved_cards (user_id) where is_active;

create trigger tr_saved_cards_updated_at
  before update on payments.saved_cards
  for each row execute function core.set_updated_at();

create table if not exists payments.payment_events (
  id           uuid primary key default extensions.gen_random_uuid(),
  provider     text not null default 'tap',
  event_id     text not null,
  charge_id    text,
  payload      jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now(),
  unique (provider, event_id)
);

-- Idempotency for payment attempts.
alter table payments.payment_attempts
  add column if not exists idempotency_key text;

create unique index if not exists uq_payment_attempts_idempotency
  on payments.payment_attempts (order_id, idempotency_key)
  where idempotency_key is not null;
