-- admin_set_category_image_test.sql
-- Behaviour test for migration 205: public.admin_set_category_image(uuid, text)
-- records or clears the picture URL of a category for the admin dashboard, and
-- it does so without giving the client EXECUTE on the search rebuild functions
-- that 081 took away.
--
-- STATUS: EXECUTED ON 2026-10-28 against webzzasosevzymftgszn, ALL NINE CASES
-- PASSED, EVERY FIXTURE ROLLED BACK.
--
-- Plain SQL for the Supabase SQL Editor, `supabase db query --linked -f`, or
-- psql: one transaction, every fixture rolled back at the end, and every call
-- made as a real role with real JWT claims so the guard arms are executed rather
-- than asserted about.
--
-- WHY THIS NEEDS A TEST AT ALL. The bug this migration closes was invisible to
-- every earlier gate: `update public.categories set image_url = …` passed RLS and
-- then died inside `tr_categories_search`, whose SECURITY INVOKER function calls
-- `catalog.rebuild_category_search(uuid)` — a function whose live ACL after 081
-- is `{postgres=X/postgres, service_role=X/postgres}`. So the test has to prove
-- two things at once: the picture write now succeeds as `authenticated`, and the
-- client still cannot execute the rebuild function directly. A closure that only
-- re-granted 083 would pass case 1 and fail case 9.
--
-- WHAT THE FIXTURES SET UP
--   CAT   one category, no picture yet, slug supplied because the column is not
--         null (the trap that failed an earlier fixture in this genre).
--   ALIAS one Arabic alias of CAT, so case 1 can show the search row was really
--         rebuilt by the trigger and not merely left alone.
--   WR    active staff whose role row is manager → holds catalog.category.write.
--   CAS   active staff whose role row is cashier → holds no catalog permission.
--   CUS   a signed-in customer: auth.users row only, no staff row.
--
-- PREREQUISITES: 004/005/007 (identity, RBAC), 009 (categories, aliases,
-- category_search and their triggers), 081/083 (the grant history), 116 (audit
-- log), 194 (the guard shape this function mirrors), 205.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into catalog.categories (id, name_ar, name_en, slug, sort_order, is_active)
values ('ac500000-0000-4000-8000-000000000001',
        'مشروبات اختبار', 'ACB Drinks', 'acb-drinks', 1, true);

insert into catalog.category_aliases (id, category_id, alias, locale)
values ('ac510000-0000-4000-8000-000000000001',
        'ac500000-0000-4000-8000-000000000001', 'عصائر اختبار', 'ar');

insert into auth.users (id, email)
values
  ('ac520000-0000-4000-8000-000000000001', 'acb-writer@test.local'),
  ('ac520000-0000-4000-8000-000000000002', 'acb-cashier@test.local'),
  ('ac520000-0000-4000-8000-000000000003', 'acb-customer@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('ac530000-0000-4000-8000-000000000001', 'ac520000-0000-4000-8000-000000000001', 'active', 'ACB Writer', 'acb-writer@test.local'),
  ('ac530000-0000-4000-8000-000000000002', 'ac520000-0000-4000-8000-000000000002', 'active', 'ACB Cashier', 'acb-cashier@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ac530000-0000-4000-8000-000000000001', r.id, null
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ac530000-0000-4000-8000-000000000002', r.id, null
from identity.roles r where r.code = 'cashier';

-- ---------------------------------------------------------------------------
-- The calls, all made as the roles the app really uses. Only the last
-- row-returning statement of the run comes back through the CLI, so every
-- answer is parked in a transaction-local setting and read in the cases below.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ac520000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- 1: a manager records a picture URL.
do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac500000-0000-4000-8000-000000000001'::uuid,
    'https://cdn.example.test/category/acb-drinks.png') into v;
  perform set_config('test.acb_write', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_write', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 2: the same manager clears it again by passing an empty string.
do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac500000-0000-4000-8000-000000000001'::uuid, '') into v;
  perform set_config('test.acb_clear', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_clear', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- Put a picture back on the row so case 3 has something it must not overwrite.
-- Through the function, not with a bare update: as this very role the bare
-- update is the bug 205 closes, and it answers 42501 inside the trigger.
do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac500000-0000-4000-8000-000000000001'::uuid,
    'https://cdn.example.test/category/keep-me.png') into v;
  perform set_config('test.acb_reseed', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_reseed', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 3: a URL that is not http(s) is refused without touching the row.
do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac500000-0000-4000-8000-000000000001'::uuid, 'ftp://cdn.example/test.png') into v;
  perform set_config('test.acb_badurl', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_badurl', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 4: a category id nobody knows.
do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac599999-0000-4000-8000-000000000009'::uuid, 'https://cdn.example.test/x.png') into v;
  perform set_config('test.acb_unknown', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_unknown', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 5: a cashier — active staff, but no catalog.category.write.
select set_config('request.jwt.claims',
  '{"sub":"ac520000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac500000-0000-4000-8000-000000000001'::uuid, 'https://cdn.example/test.png') into v;
  perform set_config('test.acb_cashier', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_cashier', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 6: a signed-in customer, not staff at all.
select set_config('request.jwt.claims',
  '{"sub":"ac520000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac500000-0000-4000-8000-000000000001'::uuid, 'https://cdn.example/test.png') into v;
  perform set_config('test.acb_customer', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_customer', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

reset role;

-- 7: anon has no claims and no EXECUTE.
set local role anon;

do $$
declare v jsonb;
begin
  select public.admin_set_category_image(
    'ac500000-0000-4000-8000-000000000001'::uuid, 'https://cdn.example/test.png') into v;
  perform set_config('test.acb_anon', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.acb_anon', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 1. The manager's write answered ok, the row carries the URL, the trigger
--    really rebuilt the search row (the alias is in it), and the audit kept both
--    URLs. This is the case that reproduced as 42501 before 205.
-- ---------------------------------------------------------------------------
do $$
declare
  answer jsonb := current_setting('test.acb_write')::jsonb;
  v_search text;
  v_found int;
begin
  if left(current_setting('test.acb_write'), 6) = 'RAISED' then
    raise exception 'FAIL 1: the manager''s write raised: %', current_setting('test.acb_write');
  end if;
  if answer ->> 'ok' <> 'true' then
    raise exception 'FAIL 1: the write answered %', answer;
  end if;

  -- The row is not read here: every call in the run has already finished, so the
  -- live value is the reseed case 3 needs. This write's own effect is proven by
  -- the search row below (only the trigger can put the alias there) and by its
  -- audit pair.
  -- The body is stored normalised (أ → ا), so the alias is compared through the
  -- same normaliser the rebuild uses rather than as the literal that was typed.
  select body_norm into v_search from catalog.category_search
   where category_id = 'ac500000-0000-4000-8000-000000000001';
  if v_search is null or v_search not like '%' || core.normalize_ar('عصائر اختبار') || '%' then
    raise exception 'FAIL 1: the search row does not carry the alias, so the trigger did not run: %', v_search;
  end if;

  -- The audit rows all carry the transaction timestamp, so they are matched by
  -- their payload rather than by their order.
  select count(*) into v_found from identity.audit_log a
   where a.action = 'catalog.category.image'
     and a.entity_id = 'ac500000-0000-4000-8000-000000000001'
     and a.new_values ->> 'image_url' = 'https://cdn.example.test/category/acb-drinks.png'
     and (a.old_values ->> 'image_url') is null;
  if v_found <> 1 then
    raise exception 'FAIL 1: the write was audited % times from an empty previous URL, expected 1', v_found;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Clearing works and is audited as a loss, not as a string. The row itself is
--    read in case 3, because the reseed that case needs has already run by now.
-- ---------------------------------------------------------------------------
do $$
declare
  answer jsonb := current_setting('test.acb_clear')::jsonb;
  reseed jsonb := current_setting('test.acb_reseed')::jsonb;
  v_found int;
begin
  if left(current_setting('test.acb_clear'), 6) = 'RAISED' then
    raise exception 'FAIL 2: the clear raised: %', current_setting('test.acb_clear');
  end if;
  if answer ->> 'ok' <> 'true' then
    raise exception 'FAIL 2: the clear answered %', answer;
  end if;

  if left(current_setting('test.acb_reseed'), 6) = 'RAISED' then
    raise exception 'FAIL 2: the reseed raised: %', current_setting('test.acb_reseed');
  end if;
  if reseed ->> 'ok' <> 'true' then
    raise exception 'FAIL 2: the reseed answered %', reseed;
  end if;

  select count(*) into v_found from identity.audit_log a
   where a.action = 'catalog.category.image'
     and a.entity_id = 'ac500000-0000-4000-8000-000000000001'
     and a.new_values ->> 'image_url' is null
     and a.old_values ->> 'image_url' = 'https://cdn.example.test/category/acb-drinks.png';
  if v_found <> 1 then
    raise exception 'FAIL 2: the clear was audited % times as a loss of the URL it replaced, expected 1', v_found;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. A non-http URL is refused, and the row keeps the picture it had.
-- ---------------------------------------------------------------------------
do $$
declare
  answer jsonb := current_setting('test.acb_badurl')::jsonb;
  v_url text;
begin
  if left(current_setting('test.acb_badurl'), 6) = 'RAISED' then
    raise exception 'FAIL 3: a bad URL raised instead of answering: %', current_setting('test.acb_badurl');
  end if;
  if answer ->> 'ok' <> 'false' or answer ->> 'reason' <> 'invalid_url' then
    raise exception 'FAIL 3: a bad URL answered %', answer;
  end if;

  select image_url into v_url from catalog.categories
   where id = 'ac500000-0000-4000-8000-000000000001';
  if v_url <> 'https://cdn.example.test/category/keep-me.png' then
    raise exception 'FAIL 3: the refused write still changed the row to %', v_url;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. An unknown category id raises 22023 rather than silently writing nothing.
-- ---------------------------------------------------------------------------
do $$
begin
  if current_setting('test.acb_unknown') <> 'RAISED:22023:unknown category' then
    raise exception 'FAIL 4: the unknown category answered %', current_setting('test.acb_unknown');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5/6/7. The refusals: staff without the permission, a customer, and anon.
-- ---------------------------------------------------------------------------
do $$
begin
  if current_setting('test.acb_cashier') <> 'RAISED:42501:missing permission: catalog.category.write' then
    raise exception 'FAIL 5: the cashier answered %', current_setting('test.acb_cashier');
  end if;
  if current_setting('test.acb_customer') <> 'RAISED:42501:not authenticated' then
    raise exception 'FAIL 6: the customer answered %', current_setting('test.acb_customer');
  end if;
  if left(current_setting('test.acb_anon'), 6) <> 'RAISED' then
    raise exception 'FAIL 7: anon was allowed to call the function: %', current_setting('test.acb_anon');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Nothing outside the fixture moved: every audit row this run wrote belongs
--    to the fixture category and carries the picture action. Scoped to the
--    fixture because the live database may hold other rows already.
-- ---------------------------------------------------------------------------
do $$
declare v_count int;
begin
  select count(*) into v_count from identity.audit_log a
   where a.actor_user_id in ('ac520000-0000-4000-8000-000000000001'::uuid,
                             'ac520000-0000-4000-8000-000000000002'::uuid,
                             'ac520000-0000-4000-8000-000000000003'::uuid)
     and a.action <> 'catalog.category.image';
  if v_count <> 0 then
    raise exception 'FAIL 8: the fixture actors wrote % audit rows of another action', v_count;
  end if;

  select count(*) into v_count from identity.audit_log a
   where a.action = 'catalog.category.image'
     and a.entity_id is distinct from 'ac500000-0000-4000-8000-000000000001'::uuid;
  if v_count <> 0 then
    raise exception 'FAIL 8: % picture audit rows belong to another category', v_count;
  end if;

  select count(*) into v_count from identity.audit_log a
   where a.action = 'catalog.category.image'
     and a.entity_id = 'ac500000-0000-4000-8000-000000000001';
  if v_count <> 3 then
    raise exception 'FAIL 8: the picture write, the clear and the reseed left % audit rows, expected 3', v_count;
  end if;

  if exists (select 1 from catalog.category_search s
              where s.category_id = 'ac599999-0000-4000-8000-000000000009') then
    raise exception 'FAIL 8: the unknown category id produced a search row';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. The hardening 081 introduced stays in place. This is what separates the
--    definer entry point from the shortcut of granting the rebuild functions
--    back to every signed-in customer.
-- ---------------------------------------------------------------------------
do $$
begin
  if pg_catalog.has_function_privilege('authenticated', 'catalog.rebuild_category_search(uuid)', 'EXECUTE') then
    raise exception 'FAIL 9: authenticated can execute catalog.rebuild_category_search again';
  end if;
  if pg_catalog.has_function_privilege('authenticated', 'catalog.rebuild_product_search(uuid)', 'EXECUTE') then
    raise exception 'FAIL 9: authenticated can execute catalog.rebuild_product_search again';
  end if;
  if not pg_catalog.has_function_privilege('authenticated', 'public.admin_set_category_image(uuid, text)', 'EXECUTE') then
    raise exception 'FAIL 9: authenticated cannot execute the new entry point';
  end if;
  if pg_catalog.has_function_privilege('anon', 'public.admin_set_category_image(uuid, text)', 'EXECUTE') then
    raise exception 'FAIL 9: anon can execute the new entry point';
  end if;
end $$;

select 'all nine cases passed' as result;

rollback;
