-- 003_identity_01_profiles.sql
-- Customer profile + address book. Decision D2: customer data lives in
-- identity.profiles and is always linked to an auth.users row by uuid.

create table if not exists identity.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text,
  email        text,
  phone        text,
  avatar_url   text,
  branch_id    uuid,                              -- FK added in 005 (core.branches)
  language     text not null default 'ar' check (language in ('ar','en')),
  last_seen_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table identity.profiles is
  'Customer profile. One row per auth.users. No role column (D2: staff live in staff_members).';

create index if not exists ix_profiles_email on identity.profiles (email);
create index if not exists ix_profiles_branch on identity.profiles (branch_id);

create trigger tr_profiles_updated_at
  before update on identity.profiles
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Address book. Replaces the hard-coded getAddressesList() and gives the
-- currently-in-memory addresses a real home.
-- ---------------------------------------------------------------------------
create table if not exists identity.customer_addresses (
  id          uuid primary key default extensions.gen_random_uuid(),
  user_id     uuid not null references identity.profiles(id) on delete cascade,
  label       text not null,
  details     text not null,
  latitude    numeric(9,6) check (latitude between -90 and 90),
  longitude   numeric(9,6) check (longitude between -180 and 180),
  is_default  boolean not null default false,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint ck_addresses_label check (length(btrim(label)) between 1 and 40)
);

comment on table identity.customer_addresses is
  'Customer saved addresses. Soft-deleted via archived_at, never hard-deleted.';

create index if not exists ix_addresses_user
  on identity.customer_addresses (user_id)
  where archived_at is null;

-- At most one default address per customer.
create unique index if not exists uq_addresses_one_default
  on identity.customer_addresses (user_id)
  where is_default and archived_at is null;

create trigger tr_addresses_updated_at
  before update on identity.customer_addresses
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Auto-create a profile the moment Supabase Auth creates the user.
-- SECURITY DEFINER because auth.users is not readable/writable by the
-- authenticated role, and this trigger fires inside the Auth service.
-- ---------------------------------------------------------------------------
create or replace function identity.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  insert into identity.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, ''), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$fn$;

comment on function identity.handle_new_user() is
  'Trigger on auth.users: creates identity.profiles row on signup.';

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function identity.handle_new_user();