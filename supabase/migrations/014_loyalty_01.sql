-- 014_loyalty_01.sql
--
-- Decision D9: single source of truth for the loyalty balance.
-- profiles has NO loyalty_points column. This table and its ledger are the
-- only place a balance is stored. identity.user_points is the cheap read view.
--
-- loyalty_transactions is a real ledger, which is what prevents two
-- concurrent redemptions from spending the same balance twice.

create table if not exists loyalty.loyalty_rules (
  id                      uuid primary key default extensions.gen_random_uuid(),
  code                    text not null unique check (code ~ '^[a-z_]+$'),
  name_ar                 text not null,
  name_en                 text not null,
  points_per_currency_unit numeric(12,4) not null default 1 check (points_per_currency_unit >= 0),
  point_value             numeric(12,2) not null default 0.05 check (point_value >= 0),
  is_active               boolean not null default true,
  valid_from              timestamptz not null default now(),
  valid_to                timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  constraint ck_loyalty_rules_window check (valid_to is null or valid_to > valid_from)
);

comment on table loyalty.loyalty_rules is
  'How many points an order earns and what a point is worth.';

create table if not exists loyalty.loyalty_accounts (
  user_id         uuid primary key references identity.profiles(id) on delete cascade,
  points_balance  integer not null default 0 check (points_balance >= 0),
  lifetime_points integer not null default 0 check (lifetime_points >= 0),
  tier            text not null default 'bronze'
                   check (tier in ('bronze','silver','gold','platinum')),
  updated_at      timestamptz not null default now()
);

comment on table loyalty.loyalty_accounts is
  'THE source of truth for a points balance (D9). Never duplicated elsewhere.';

create trigger tr_loyalty_accounts_updated_at
  before update on loyalty.loyalty_accounts
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- The ledger. Every balance change goes through a row here.
-- ---------------------------------------------------------------------------
create table if not exists loyalty.loyalty_transactions (
  id             uuid primary key default extensions.gen_random_uuid(),
  user_id        uuid not null references identity.profiles(id) on delete cascade,
  points         integer not null check (points <> 0),
  balance_after  integer not null check (balance_after >= 0),
  reason         text not null check (reason in
                   ('earn_order','redeem_reward','expire','adjustment','refund')),
  reference_type text check (reference_type in ('order')),
  reference_id   uuid,
  note           text,
  created_at     timestamptz not null default now(),
  constraint ck_loyalty_tx_earning check (
    reason <> 'earn_order' or points > 0
  )
);

comment on table loyalty.loyalty_transactions is
  'Append-only points ledger. Balance never changes without a row here.';

create index if not exists ix_loyalty_tx_user
  on loyalty.loyalty_transactions (user_id, created_at desc);
create index if not exists ix_loyalty_tx_reference
  on loyalty.loyalty_transactions (reference_type, reference_id);

-- One earning per order. Stops a retry from paying points twice.
create unique index if not exists uq_loyalty_tx_earn_once
  on loyalty.loyalty_transactions (user_id, reference_id, reason)
  where reason = 'earn_order' and reference_id is not null;

-- ---------------------------------------------------------------------------
create table if not exists loyalty.loyalty_rewards (
  id              uuid primary key default extensions.gen_random_uuid(),
  product_id      uuid not null references catalog.products(id) on delete restrict,
  points_cost     integer not null check (points_cost > 0),
  stock_available integer check (stock_available >= 0),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (product_id)
);

comment on table loyalty.loyalty_rewards is
  'Redeemable rewards with their point cost (was a frozen Map in loyalty_rules.dart:19-26).';

create index if not exists ix_loyalty_rewards_active
  on loyalty.loyalty_rewards (points_cost) where is_active;

create trigger tr_loyalty_rewards_updated_at
  before update on loyalty.loyalty_rewards
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- D9 read view. Created here because loyalty_accounts does not exist before
-- this migration.
-- ---------------------------------------------------------------------------
create or replace view identity.user_points as
  select p.id                     as user_id,
         p.full_name,
         coalesce(l.points_balance, 0)  as points_balance,
         coalesce(l.lifetime_points, 0) as lifetime_points,
         coalesce(l.tier, 'bronze')      as tier
  from identity.profiles p
  left join loyalty.loyalty_accounts l on l.user_id = p.id;

comment on view identity.user_points is
  'Profile + loyalty balance in one row. Read-only. Source of truth = loyalty.loyalty_accounts (D9).';

-- ---------------------------------------------------------------------------
-- Balance mutation, always inside a caller's transaction, always locked.
-- This is the only function that changes a balance.
-- ---------------------------------------------------------------------------
create or replace function loyalty.apply_points(
  p_user_id uuid,
  p_points integer,
  p_reason text,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_note text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_balance integer;
begin
  -- serialise concurrent changes for this user
  insert into loyalty.loyalty_accounts (user_id, points_balance, lifetime_points)
  values (p_user_id, greatest(p_points, 0), greatest(p_points, 0))
  on conflict (user_id) do nothing;

  select points_balance into v_balance
    from loyalty.loyalty_accounts
   where user_id = p_user_id
     for update;

  v_balance := v_balance + p_points;
  if v_balance < 0 then
    raise exception 'insufficient loyalty points: have %, need %', v_balance, -p_points
      using errcode = '23514';
  end if;

  update loyalty.loyalty_accounts
     set points_balance  = v_balance,
         lifetime_points = lifetime_points + greatest(p_points, 0)
   where user_id = p_user_id;

  insert into loyalty.loyalty_transactions
    (user_id, points, balance_after, reason, reference_type, reference_id, note)
  values (p_user_id, p_points, v_balance, p_reason, p_reference_type, p_reference_id, p_note);

  return v_balance;
end;
$fn$;

comment on function loyalty.apply_points is
  'The only writer of a loyalty balance. Locks the account row, appends a ledger row, never goes negative.';