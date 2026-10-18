-- set_default_address_test.sql
-- Behaviour tests for identity.set_default_address (migration 065).
--
-- RUN THIS ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE.
--
-- Every access-control assertion runs as the real `authenticated` role with
-- real JWT claims, the same way supabase/tests/acceptance.js does. Nothing here
-- asserts access control while connected as postgres or service_role, because
-- those roles bypass RLS and would prove nothing. The privilege checks at the
-- end are pure metadata introspection (has_function_privilege), so they run as
-- the connecting role - that is what actually reports another role's rights.
--
-- Usage (local Supabase stack):
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f set_default_address_test.sql
--
-- The script leaves the database unchanged: all fixtures live in one
-- transaction that is rolled back at the end.
--
-- The three fixture ids are handed to the assertions through transaction-local
-- custom GUCs rather than a temp table, so reading them needs no grant and
-- works identically under any SET ROLE.
--
-- NOTE ON FIXTURES: identity.profiles.id references auth.users(id), so the two
-- test customers need an auth.users row. Only (id, email) are written; on a
-- Supabase version that adds further NOT NULL columns to auth.users, extend
-- this insert rather than dropping the test.

\set ON_ERROR_STOP on
\timing off

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two customers. A owns two addresses (one already default), B owns
-- one.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'sd-a@test.local'),
  ('22222222-2222-4222-8222-222222222222', 'sd-b@test.local');

insert into identity.profiles (id, email, full_name)
values
  ('11111111-1111-4111-8111-111111111111', 'sd-a@test.local', 'SD A'),
  ('22222222-2222-4222-8222-222222222222', 'sd-b@test.local', 'SD B');

insert into identity.customer_addresses (user_id, label, details, is_default)
values
  ('11111111-1111-4111-8111-111111111111', 'A home', 'A street 1', true),
  ('11111111-1111-4111-8111-111111111111', 'A work', 'A street 2', false),
  ('22222222-2222-4222-8222-222222222222', 'B home', 'B street 1', false);

select set_config('sd.a_home',
  (select id::text from identity.customer_addresses
    where user_id = '11111111-1111-4111-8111-111111111111' and label = 'A home'), true);
select set_config('sd.a_work',
  (select id::text from identity.customer_addresses
    where user_id = '11111111-1111-4111-8111-111111111111' and label = 'A work'), true);
select set_config('sd.b_home',
  (select id::text from identity.customer_addresses
    where user_id = '22222222-2222-4222-8222-222222222222' and label = 'B home'), true);

-- From here on every data assertion runs as the real customer.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","aud":"authenticated"}', true);

\echo '--- 1. the owner sets their own address as default (expect success) ---'
do $$
declare v_id uuid;
begin
  v_id := current_setting('sd.a_work')::uuid;
  perform identity.set_default_address(v_id);

  if (select count(*) from identity.customer_addresses
       where user_id = '11111111-1111-4111-8111-111111111111'
         and archived_at is null and is_default) <> 1 then
    raise exception 'FAIL: expected exactly one default for A';
  end if;
  if not exists (select 1 from identity.customer_addresses where id = v_id and is_default) then
    raise exception 'FAIL: A work is not the default';
  end if;
  raise notice 'PASS: A set their own address as default';
end $$;

\echo '--- 2. switching the default keeps the at-most-one invariant ---'
do $$
declare v_id uuid;
begin
  v_id := current_setting('sd.a_home')::uuid;
  perform identity.set_default_address(v_id);

  if exists (select 1 from identity.customer_addresses
              where user_id = '11111111-1111-4111-8111-111111111111'
                and archived_at is null and is_default
                and label <> 'A home') then
    raise exception 'FAIL: two defaults after switching';
  end if;
  raise notice 'PASS: switching the default keeps exactly one default';
end $$;

\echo '--- 3. another customer address cannot be claimed (expect P0002) ---'
do $$
declare
  v_id uuid;
  v_failed boolean := false;
begin
  v_id := current_setting('sd.b_home')::uuid;

  begin
    perform identity.set_default_address(v_id);
  exception when others then
    v_failed := true;
    if sqlerrm not like '%address not found%' then
      raise exception 'FAIL: expected address-not-found, got: %', sqlerrm;
    end if;
  end;

  if not v_failed then
    raise exception 'FAIL: A was allowed to claim the address of B';
  end if;
  raise notice 'PASS: cross-customer assignment refused';
end $$;

\echo '--- 4. an unknown address is refused (expect P0002) ---'
do $$
declare v_failed boolean := false;
begin
  begin
    perform identity.set_default_address('99999999-9999-4999-8999-999999999999');
  exception when others then
    v_failed := true;
    if sqlerrm not like '%address not found%' then
      raise exception 'FAIL: expected address-not-found, got: %', sqlerrm;
    end if;
  end;
  if not v_failed then
    raise exception 'FAIL: unknown address accepted';
  end if;
  raise notice 'PASS: unknown address refused';
end $$;

\echo '--- 5. an archived address cannot become the default ---'
do $$
declare
  v_id uuid;
  v_failed boolean := false;
begin
  v_id := current_setting('sd.a_work')::uuid;
  update identity.customer_addresses set archived_at = now() where id = v_id;

  begin
    perform identity.set_default_address(v_id);
  exception when others then
    v_failed := true;
  end;

  if not v_failed then
    raise exception 'FAIL: archived address accepted as default';
  end if;
  raise notice 'PASS: archived address refused';
end $$;

\echo '--- 6. a NULL address id is rejected (expect 22023) ---'
do $$
declare v_failed boolean := false;
begin
  begin
    perform identity.set_default_address(null);
  exception when others then
    v_failed := true;
    if sqlerrm not like '%address required%' then
      raise exception 'FAIL: expected address required, got: %', sqlerrm;
    end if;
  end;
  if not v_failed then
    raise exception 'FAIL: NULL address id accepted';
  end if;
  raise notice 'PASS: NULL address id rejected';
end $$;

reset role;

\echo '--- 7. a call with no session at all is refused (expect 42501) ---'
-- The claims set above are transaction-local, so they must be cleared first,
-- otherwise auth.uid() still returns A and the auth guard is never reached.
select set_config('request.jwt.claims', '{}', true);
set local role authenticated;
do $$
declare
  v_id uuid;
  v_failed boolean := false;
begin
  v_id := current_setting('sd.a_home')::uuid;

  begin
    perform identity.set_default_address(v_id);
  exception when others then
    v_failed := true;
    if sqlerrm not like '%authentication required%' then
      raise exception 'FAIL: expected authentication required, got: %', sqlerrm;
    end if;
  end;
  if not v_failed then
    raise exception 'FAIL: anonymous call accepted';
  end if;
  raise notice 'PASS: anonymous call refused';
end $$;

reset role;

\echo '--- 8. EXECUTE grants: anon must not have it, authenticated must ---'
do $$
begin
  if has_function_privilege('anon', 'identity.set_default_address(uuid)', 'execute') then
    raise exception 'FAIL: anon may execute set_default_address';
  end if;
  if not has_function_privilege('authenticated', 'identity.set_default_address(uuid)', 'execute') then
    raise exception 'FAIL: authenticated lost EXCECUTE';
  end if;
  raise notice 'PASS: EXECUTE granted to authenticated only';
end $$;

\echo '--- 9. the function is SECURITY DEFINER (security setting intact) ---'
do $$
declare v_def boolean;
begin
  select prosecdef into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'identity' and p.proname = 'set_default_address';
  if not v_def then
    raise exception 'FAIL: function is no longer SECURITY DEFINER';
  end if;
  raise notice 'PASS: SECURITY DEFINER retained';
end $$;

-- ---------------------------------------------------------------------------
-- Concurrency needs two independent sessions and cannot live in this single
-- transaction. Run it on the isolated database with the fixed definition in
-- place, as A, against two of A's addresses, finishing both calls at the same
-- time (paste each block into its own psql session):
--
--   begin;
--   set local role authenticated;
--   select set_config('request.jwt.claims',
--     '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
--   select identity.set_default_address('<A home id>');
--   commit;
--
-- Expected WITH migration 065: both calls succeed, exactly one row is flagged.
-- Expected WITHOUT the advisory lock: one succeeds, the other fails with
-- unique_violation 23505. Verify with:
--
--   select label, is_default from identity.customer_addresses
--    where user_id = '11111111-1111-4111-8111-111111111111' and archived_at is null;
-- ---------------------------------------------------------------------------

rollback;
\echo 'All set_default_address checks finished; fixtures rolled back.'