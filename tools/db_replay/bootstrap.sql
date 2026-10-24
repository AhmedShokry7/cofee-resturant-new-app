-- tools/db_replay/bootstrap.sql
--
-- The platform objects the migrations expect, for an isolated replay on a
-- vanilla PostgreSQL.  This file is NOT a migration: it is never applied to
-- production and it is not part of the migration chain.
--
-- It provides the roles, schemas and helper functions that Supabase creates
-- for a project, so the application migrations can be replayed and asserted
-- without touching a live database:
--
--   roles        anon, authenticated, service_role, authenticator,
--                supabase_admin, supabase_auth_admin, supabase_storage_admin
--   schemas      auth, storage, cron, net, vault, extensions, identity
--   auth.uid()   the caller's id, read from the request claim
--   storage      the avatar bucket and objects
--   cron/net     stand-ins for the extensions that cannot be installed here
--   vault        the secret store the push trigger reads
--
-- Two objects are created here although no migration creates them, because
-- production has them and the migrations assume them:
--   identity.admins            (migration 092 enables RLS on it)
--   supabase_realtime          (the publication migration 097 adds a table to)

\set ON_ERROR_STOP on

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    create role supabase_admin nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    create role supabase_auth_admin nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_storage_admin') then
    create role supabase_storage_admin nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'dashboard_user') then
    create role dashboard_user nologin;
  end if;
end $$;

-- Supabase serves the `extensions` schema through the search path, so the
-- unqualified operator classes of the migrations resolve.
alter role postgres set search_path = "$user", public, extensions;
alter database postgres set search_path = "$user", public, extensions;

create schema if not exists extensions;
grant usage on schema extensions to public;

create schema if not exists auth;
create schema if not exists storage;
create schema if not exists cron;
create schema if not exists net;
create schema if not exists vault;
create schema if not exists identity;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- Legacy table that migration 092 assumes already exists.  No migration in the
-- repository creates it; production has it out-of-band.  It is created after
-- auth.users below, because it carries a foreign key to it.

-- The ledger the Supabase CLI keeps.  It is created here so the replay can
-- record the version of every file it applies: a version that is used twice
-- is rejected by the primary key, which is exactly the defect the repository
-- had with the two files of version 097.
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text not null primary key,
  name text,
  statements text[]
);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb default '{}'::jsonb,
  raw_app_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Legacy table that migration 092 assumes already exists.  No migration in the
-- repository creates it; production has it out-of-band.  The shape below is
-- the one the live database has.
create table if not exists identity.admins (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid,
  status        text not null default 'active',
  full_name     text not null,
  email         text not null,
  invited_by    uuid,
  invited_at    timestamptz,
  accepted_at   timestamptz,
  suspended_at  timestamptz,
  created_at    timestamptz default now(),
  constraint admins_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade
);

-- The identity of the caller.  PostgREST sets `request.jwt.claims` (the whole
-- token) and, since version 9, `request.jwt.claim.<name>` for every claim.
-- Both are read here, so a test can set either one.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    coalesce(
      nullif(current_setting('request.jwt.claim.sub', true), ''),
      nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    ), '')::uuid
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz default now()
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text,
  name text not null,
  owner uuid,
  metadata jsonb,
  created_at timestamptz default now()
);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to anon, authenticated, service_role;
grant select on storage.buckets to anon, authenticated, service_role;

create or replace function storage.foldername(p_name text)
returns text[]
language sql
immutable
as $$
  select (string_to_array(p_name, '/'))[1:array_length(string_to_array(p_name, '/'), 1) - 1]
$$;

-- pg_cron / pg_net are not installable here; the scheduling calls of the
-- migrations are captured by these stand-ins so the rest of each file runs.
create table if not exists cron.job (
  jobid bigserial primary key,
  schedule text,
  command text,
  jobname text unique,
  active boolean default true
);

create or replace function cron.schedule(
  p_jobname text, p_schedule text, p_command text
) returns bigint
language plpgsql
as $$
declare
  v_id bigint;
begin
  insert into cron.job (jobname, schedule, command)
  values (p_jobname, p_schedule, p_command)
  on conflict (jobname) do update
    set schedule = excluded.schedule, command = excluded.command
  returning jobid into v_id;
  return v_id;
end;
$$;

create or replace function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint
language sql
as $$
  select 1::bigint
$$;

create table if not exists vault.secrets (
  id uuid primary key default gen_random_uuid(),
  name text unique,
  decrypted_secret text,
  created_at timestamptz default now()
);

create or replace view vault.decrypted_secrets with (security_invoker = true) as
  select id, name, decrypted_secret from vault.secrets;
