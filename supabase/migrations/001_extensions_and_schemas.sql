-- 001_extensions_and_schemas.sql
-- Extensions + the 10 application schemas from DATABASE_SPEC.md section 4.
-- Idempotent: safe to re-run.

-- --- Extensions ---------------------------------------------------------
-- pg_trgm  : Arabic + English fuzzy search          (decision D6)
-- pgcrypto : gen_random_uuid()                      (decision D7)
create extension if not exists pg_trgm with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- --- Application schemas ------------------------------------------------
-- public stays EMPTY by decision D10.
create schema if not exists identity;
create schema if not exists core;
create schema if not exists catalog;
create schema if not exists orders;
create schema if not exists inventory;
create schema if not exists payments;
create schema if not exists loyalty;
create schema if not exists marketing;
create schema if not exists engagement;
create schema if not exists ai;

-- --- Ownership ----------------------------------------------------------
alter schema identity  owner to postgres;
alter schema core      owner to postgres;
alter schema catalog   owner to postgres;
alter schema orders    owner to postgres;
alter schema inventory owner to postgres;
alter schema payments  owner to postgres;
alter schema loyalty   owner to postgres;
alter schema marketing owner to postgres;
alter schema engagement owner to postgres;
alter schema ai        owner to postgres;

-- Make the trigram operator class resolvable without schema-qualifying it
-- in every index. We keep search_path empty in SECURITY DEFINER functions and
-- always qualify names, so this is only a convenience for index definitions.
do $$
begin
  if current_setting('search_path') not like '%extensions%' then
    execute 'set search_path = public, extensions';
  end if;
end $$;

comment on schema identity  is 'Customer profiles, addresses, staff, RBAC, audit. D2 identity separation.';
comment on schema core      is 'Brand, branches, delivery zones, app settings, editorial content.';
comment on schema catalog   is 'Categories, products, options, bundles, per-branch pricing.';
comment on schema orders    is 'Carts, orders, order items with price snapshots, status history.';
comment on schema inventory is 'Per-branch stock and stock movement ledger.';
comment on schema payments  is 'Payment methods, attempts, transactions. No PAN, ever.';
comment on schema loyalty   is 'Loyalty ledger, rules, rewards. Single source of truth (D9).';
comment on schema marketing is 'Banners, coupons, coupon redemptions.';
comment on schema engagement is 'Reviews, notifications, preferences, device tokens.';
comment on schema ai        is 'Local assistant knowledge. NOT exposed to PostgREST.';