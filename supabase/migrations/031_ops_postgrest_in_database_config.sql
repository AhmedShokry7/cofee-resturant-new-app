-- 031_ops_postgrest_in_database_config.sql
--
-- Exposing the application schemas to PostgREST.
--
-- ⚠️ STATUS ON THIS PROJECT: INERT. Kept because it documents the attempt and
--    because it becomes the right mechanism on a self-hosted instance, but on
--    Supabase Cloud it does NOT take effect. Do not rely on it here.
--
-- UPDATE 2026-11-04 - the schemas listed below ARE exposed now, but not by this
--    file. Measured on the live gateway:
--      * GET /rest/v1/categories with Accept-Profile: catalog   -> 200 rows
--      * GET /rest/v1/profiles   with Accept-Profile: identity  -> 200, the
--        caller's own row only (RLS), and 401/42501 for anon
--      * GET /rest/v1/product_knowledge with Accept-Profile: ai -> 406 PGRST106
--        "Only the following schemas are exposed: public, graphql_public,
--        identity, core, catalog, orders, ..." - `ai` is absent, as intended.
--    The role setting now also reads back
--    authenticator: pgrst.db_schemas=public,graphql_public,identity,core,
--    catalog,orders,inventory,payments,loyalty,marketing,engagement. Nothing
--    below ran, and which switch produced the exposure (the dashboard tick this
--    file asked a human to make, or the platform itself) is not visible from
--    SQL - only the serving behaviour above is.
--
-- What was verified on webzzasosevzymftgszn (2026-10-15):
--   * this function is never invoked. Instrumenting it with an INSERT and
--     issuing a request produced zero invocations, which means in-database
--     configuration is disabled on the platform, so db-schemas cannot be set
--     from SQL at all.
--   * ALTER ROLE authenticator SET pgrst.db_schemas   -> stored, never read
--   * NOTIFY pgrst, 'reload config' / 'reload schema'   -> no effect
--   * PATCH /v1/projects/{ref}/postgrest {db_schema}   -> HTTP 200, value
--     reads back correctly through the API, but the running PostgREST keeps
--     serving only `public`
--   * restart of postgrest alone, then a full project restart -> still only
--     `public` in the schema cache
--
-- CONCLUSION: the value the Dashboard writes is not reproducible through the
-- public Management API on this project. Someone must tick it once in the
-- dashboard:
--   Dashboard -> Settings -> API -> Exposed schemas
-- Until then the database is complete and correct, and the Flutter client can
-- authenticate, but PostgREST serves no application table.
--
-- The schema list below is the intended configuration, and `ai` is deliberately
-- absent: it must stay unreachable from anon/authenticated and be read only
-- through an Edge Function (spec section 4).

create schema if not exists postgrest;

create table if not exists postgrest.config (
  id      integer primary key default 1,
  schemas text   not null,
  constraint config_singleton check (id = 1)
);

comment on table postgrest.config is
  'Intended PostgREST schema list. Applied by postgrest.pre_config() on '
  'self-hosted only; inert on Supabase Cloud. See header.';

insert into postgrest.config (id, schemas) values
  (1, 'public,graphql_public,identity,core,catalog,orders,inventory,payments,loyalty,marketing,engagement')
on conflict (id) do update
  set schemas = excluded.schemas;

create or replace function postgrest.pre_config()
returns void
language sql
as $fn$
  select set_config('pgrst.db_schemas', schemas, true)
  from postgrest.config;
$fn$;

comment on function postgrest.pre_config() is
  'Applies postgrest.config.schemas as db-schemas. Not invoked on Supabase Cloud.';

-- This table is infrastructure, not application data.
revoke all on schema postgrest from anon, authenticated;
revoke all on all tables in schema postgrest from anon, authenticated;