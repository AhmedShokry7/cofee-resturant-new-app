-- app_design_test.sql
-- Behaviour test for migration 226: the app builder's design document — draft,
-- published, version history, rollback — and the two permission codes that
-- gate it.
--
-- STATUS: NOT EXECUTED. 226 has not been applied to the linked project, so
-- every case below would raise 42883 (function does not exist). Run this only
-- after 226 is applied, with `supabase db query --linked -f` or psql.
--
-- Plain SQL, one transaction, every fixture rolled back at the end, and every
-- call made as a real role with real JWT claims so the guard arms execute
-- rather than being asserted about (the shape 205's test established).
--
-- WHY THIS NEEDS A TEST AT ALL
-- The panel hides the publish button when the employee lacks the permission,
-- and the panel's own validator refuses a tree it cannot draw. Neither of those
-- is the protection: the RPCs are. So this file has to prove three separate
-- things — that a malformed document is refused by the database and leaves the
-- row it would have overwritten alone, that `design.edit` and `design.publish`
-- are really two gates and not one, and that a published document reaches the
-- customer through `public.app_settings` while a draft never does.
--
-- WHAT THE FIXTURES SET UP
--   EDS  active staff, role `manager` → holds design.edit AND design.publish
--        after 226. The edit-only case removes the publish row inside this
--        transaction, so the gate is shown separately without inventing a role.
--   CAS  active staff, role `cashier` → holds neither code.
--   CUS  a signed-in customer: auth.users row only, no staff row.
--   DOC  one valid document: home with a section inside the page root.
--   BAD  documents that break one rule each: unknown page key, a repeated node
--       id, a property whose value is an object, a subtree deeper than 12.
--
-- PREREQUISITES: 004/005 (identity, RBAC, app_settings), 018 (has_permission),
-- 020 (settings RLS), 032/033 (the public bridge views and their grants),
-- 116 (audit log), 226.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values
  ('ad600000-0000-4000-8000-000000000001', 'ad-editor@test.local'),
  ('ad600000-0000-4000-8000-000000000002', 'ad-cashier@test.local'),
  ('ad600000-0000-4000-8000-000000000003', 'ad-customer@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('ad610000-0000-4000-8000-000000000001', 'ad600000-0000-4000-8000-000000000001', 'active', 'AD Editor', 'ad-editor@test.local'),
  ('ad610000-0000-4000-8000-000000000002', 'ad600000-0000-4000-8000-000000000002', 'active', 'AD Cashier', 'ad-cashier@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ad610000-0000-4000-8000-000000000001', r.id, null
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ad610000-0000-4000-8000-000000000002', r.id, null
from identity.roles r where r.code = 'cashier';

-- ---------------------------------------------------------------------------
-- The calls, all as the roles the app really uses. Only the last row-returning
-- statement of the run comes back through the CLI, so every answer is parked in
-- a transaction-local setting and read in the cases below.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ad600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- 1: the editor saves a valid draft.
do $$
declare v jsonb;
begin
  select public.admin_save_app_design_draft(
    '{"schema_version":1,"pages":[{"page":"home","root":{"id":"page-home","type":"page","visible":true,"properties":{},"children":[{"id":"hero","type":"promo_banner","visible":true,"properties":{"bannerIndex":1},"children":[]}]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_draft_save', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_draft_save', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 2: a page key the phone cannot open is refused, and the draft from case 1 is
--    still the one stored.
do $$
declare v jsonb;
begin
  select public.admin_save_app_design_draft(
    '{"schema_version":1,"pages":[{"page":"checkout","root":{"id":"page-checkout","type":"page","visible":true,"properties":{},"children":[]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_bad_page', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_bad_page', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 3: two nodes with the same id — the panel names layers by id, so a repeat is
--    an unreferable tree.
do $$
declare v jsonb;
begin
  select public.admin_save_app_design_draft(
    '{"schema_version":1,"pages":[{"page":"home","root":{"id":"same","type":"page","visible":true,"properties":{},"children":[{"id":"same","type":"section","visible":true,"properties":{},"children":[]}]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_dup_id', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_dup_id', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 4: a property whose value is an object rather than a scalar.
do $$
declare v jsonb;
begin
  select public.admin_save_app_design_draft(
    '{"schema_version":1,"pages":[{"page":"home","root":{"id":"page-home","type":"page","visible":true,"properties":{"nested":{"a":1}},"children":[]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_prop_object', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_prop_object', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 5: a subtree 13 levels deep, past the depth the builder allows.
do $$
declare
  v_node jsonb := '{"id":"leaf","type":"section","visible":true,"properties":{},"children":[]}'::jsonb;
  v_document jsonb;
  v_answer jsonb;
begin
  for i in 1..12 loop
    v_node := jsonb_build_object(
      'id', 'level-' || i::text,
      'type', 'column',
      'visible', true,
      'properties', '{}'::jsonb,
      'children', jsonb_build_array(v_node));
  end loop;
  v_document := jsonb_build_object(
    'schema_version', 1,
    'pages', jsonb_build_array(jsonb_build_object('page', 'home', 'root', v_node)));
  select public.admin_save_app_design_draft(v_document) into v_answer;
  perform set_config('test.ad_depth', coalesce(v_answer::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_depth', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 6: the editor publishes. This is the write the customer app reads.
do $$
declare v jsonb;
begin
  select public.admin_publish_app_design(
    '{"schema_version":1,"pages":[{"page":"home","root":{"id":"page-home","type":"page","visible":true,"properties":{},"children":[{"id":"hero","type":"promo_banner","visible":true,"properties":{"bannerIndex":1},"children":[]}]}}]}'::jsonb,
    'افتتاحية الاختبار'
  ) into v;
  perform set_config('test.ad_publish', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_publish', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 7: the same editor, now without the publish row, publishes again. The row is
--    deleted inside this transaction only, so `design.publish` is shown to be a
--    gate of its own rather than a second name for `design.edit`.
delete from identity.role_permissions rp
 using identity.permissions p, identity.roles r
  where rp.role_id = r.id
    and r.code = 'manager'
    and p.code = 'design.publish';

do $$
declare v jsonb;
begin
  select public.admin_publish_app_design(
    '{"schema_version":1,"pages":[{"page":"home","root":{"id":"page-home","type":"page","visible":true,"properties":{},"children":[]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_publish_denied', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_publish_denied', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 7b: with that same row still missing, the draft save must still work — the
--     refusal above is about publishing, not about editing.
do $$
declare v jsonb;
begin
  select public.admin_save_app_design_draft(
    '{"schema_version":1,"pages":[{"page":"search","root":{"id":"page-search","type":"page","visible":true,"properties":{},"children":[]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_draft_after', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_draft_after', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 8: publish one more version, then roll the first back. Numbers must grow.
do $$
declare v jsonb;
begin
  select public.admin_publish_app_design(
    '{"schema_version":1,"pages":[{"page":"categories","root":{"id":"page-categories","type":"page","visible":true,"properties":{},"children":[]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_publish_2', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_publish_2', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

do $$
declare v jsonb;
begin
  select jsonb_build_object('id', x.id) into v
    from core.app_design_versions x
   where x.note = 'افتتاحية الاختبار';
  perform set_config('test.ad_first_id', v ->> 'id', true);
end $$;

do $$
declare v jsonb;
begin
  select public.admin_restore_app_design_version(
    current_setting('test.ad_first_id')::uuid
  ) into v;
  perform set_config('test.ad_restore', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_restore', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 9: restoring an id nobody has.
do $$
declare v jsonb;
begin
  select public.admin_restore_app_design_version(
    'ad699999-0000-4000-8000-000000000009'::uuid
  ) into v;
  perform set_config('test.ad_restore_missing', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_restore_missing', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 10: the version list — metadata only, newest first.
do $$
declare v jsonb;
begin
  select public.admin_list_app_design_versions(10) into v;
  perform set_config('test.ad_versions', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_versions', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 11: a cashier — active staff, neither code.
select set_config('request.jwt.claims',
  '{"sub":"ad600000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  select public.admin_get_app_design('draft') into v;
  perform set_config('test.ad_cashier_read', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_cashier_read', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 12: a signed-in customer, not staff at all.
select set_config('request.jwt.claims',
  '{"sub":"ad600000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  select public.admin_save_app_design_draft(
    '{"schema_version":1,"pages":[{"page":"home","root":{"id":"x","type":"page","visible":true,"properties":{},"children":[]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_customer_write', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_customer_write', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

reset role;

-- 13: anon has no claims and no EXECUTE.
set local role anon;

do $$
declare v jsonb;
begin
  select public.admin_publish_app_design(
    '{"schema_version":1,"pages":[{"page":"home","root":{"id":"x","type":"page","visible":true,"properties":{},"children":[]}}]}'::jsonb
  ) into v;
  perform set_config('test.ad_anon_publish', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.ad_anon_publish', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 14: what the customer app actually sees through the bridge view. Run as anon,
--     because that is the role it uses: the published row must be there and the
--     draft must not.
select set_config('test.ad_anon_public_rows', (
  select count(*)::text from public.app_settings s where s.key = 'app_design_published'
), true);

select set_config('test.ad_anon_draft_rows', (
  select count(*)::text from public.app_settings s where s.key = 'app_design_draft'
), true);

reset role;

-- ---------------------------------------------------------------------------
-- 1. The draft save answers with a timestamp, stores the document under a key
--    that is not public, and audits the write.
-- ---------------------------------------------------------------------------
do $$
declare
  answer jsonb;
  v_value jsonb;
  v_public boolean;
  v_found int;
begin
  if left(current_setting('test.ad_draft_save'), 6) = 'RAISED' then
    raise exception 'FAIL 1: the draft save raised: %', current_setting('test.ad_draft_save');
  end if;
  answer := current_setting('test.ad_draft_save')::jsonb;
  if answer -> 'saved_at' is null or answer ->> 'saved_at' = 'null' then
    raise exception 'FAIL 1: the draft save answered without a timestamp: %', answer;
  end if;

  -- The stored document is the one case 7b replaced; what proves case 1 is the
  -- audit row it wrote and the flag it set.
  select count(*) into v_found from identity.audit_log a
   where a.action = 'core.app_design.draft.save'
     and a.new_values ->> 'pages' = '1';
  if v_found < 1 then
    raise exception 'FAIL 1: the draft save wrote % audit rows, expected at least 1', v_found;
  end if;

  select s.is_public, s.value into v_public, v_value
    from core.app_settings s where s.key = 'app_design_draft';
  if v_public is null then
    raise exception 'FAIL 1: no app_design_draft row was written';
  end if;
  if v_public then
    raise exception 'FAIL 1: the draft is marked is_public, so the customer app would read an unpublished design';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2–5. Every malformed document is refused with 22023 and names the broken
--      part, and none of them replaced the draft that case 1 stored.
-- ---------------------------------------------------------------------------
do $$
declare answer text;
begin
  answer := current_setting('test.ad_bad_page');
  if left(answer, 6) <> 'RAISED' or answer not like '%22023%' then
    raise exception 'FAIL 2: an unknown page key answered %', answer;
  end if;
  if answer not like '%page_key%' then
    raise exception 'FAIL 2: the refusal did not name the broken part: %', answer;
  end if;

  answer := current_setting('test.ad_dup_id');
  if left(answer, 6) <> 'RAISED' or answer not like '%22023%' or answer not like '%node_duplicate%' then
    raise exception 'FAIL 3: a repeated node id answered %', answer;
  end if;

  answer := current_setting('test.ad_prop_object');
  if left(answer, 6) <> 'RAISED' or answer not like '%22023%' or answer not like '%property_value%' then
    raise exception 'FAIL 4: an object-valued property answered %', answer;
  end if;

  answer := current_setting('test.ad_depth');
  if left(answer, 6) <> 'RAISED' or answer not like '%22023%' or answer not like '%depth%' then
    raise exception 'FAIL 5: a 13-level subtree answered %', answer;
  end if;

  -- None of the four reached the row: the last draft that stored cleanly is the
  -- search page from case 7b, and no refusal wrote a checkout/categories/
  -- duplicated tree under the draft key.
  select value #>> '{pages,0,page}' into answer from core.app_settings
   where key = 'app_design_draft';
  if answer <> 'search' then
    raise exception 'FAIL 2–5: the draft row carries page % after four refusals, expected the last clean save', answer;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Publish writes one version row and one public settings row, and returns
--    both.
-- ---------------------------------------------------------------------------
do $$
declare
  answer jsonb;
  v_count int;
begin
  if left(current_setting('test.ad_publish'), 6) = 'RAISED' then
    raise exception 'FAIL 6: the publish raised: %', current_setting('test.ad_publish');
  end if;
  answer := current_setting('test.ad_publish')::jsonb;
  if answer ->> 'note' <> 'افتتاحية الاختبار' then
    raise exception 'FAIL 6: the publish lost its note: %', answer;
  end if;
  if answer ->> 'schema_version' <> '1' then
    raise exception 'FAIL 6: the publish answered schema_version %', answer ->> 'schema_version';
  end if;

  select count(*) into v_count from core.app_design_versions v
   where v.id = (answer ->> 'id')::uuid;
  if v_count <> 1 then
    raise exception 'FAIL 6: no version row % behind the publish answer', answer ->> 'id';
  end if;

  select count(*) into v_count from identity.audit_log a
   where a.action = 'core.app_design.publish'
     and a.entity_id = (answer ->> 'id')::uuid;
  if v_count <> 1 then
    raise exception 'FAIL 6: the publish was audited % times, expected 1', v_count;
  end if;

  perform set_config('test.ad_first_version_number',
    answer ->> 'version_number', true);
end $$;

-- ---------------------------------------------------------------------------
-- 7 / 7b. design.publish refused while design.edit still worked: two gates, and
--         the published row kept the document from case 6.
-- ---------------------------------------------------------------------------
do $$
declare
  answer text;
  v_page text;
begin
  answer := current_setting('test.ad_publish_denied');
  if left(answer, 6) <> 'RAISED' or answer not like '%42501%' then
    raise exception 'FAIL 7: publishing without design.publish answered %', answer;
  end if;
  if answer not like '%design.publish%' then
    raise exception 'FAIL 7: the refusal did not name the permission: %', answer;
  end if;

  if left(current_setting('test.ad_draft_after'), 6) = 'RAISED' then
    raise exception 'FAIL 7b: the draft save raised after the publish gate closed: %',
      current_setting('test.ad_draft_after');
  end if;

  -- The refused publish left the live design exactly where case 6 put it.
  select value #>> '{pages,0,page}' into v_page from core.app_settings
   where key = 'app_design_published';
  if v_page <> 'home' then
    raise exception 'FAIL 7: the published design is page % after a refused publish, expected home', v_page;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8 / 9. Rollback republishes the old document under a NEW number; the log keeps
--        both publishes and the roll. An unknown id is P0002, not a silent null.
-- ---------------------------------------------------------------------------
do $$
declare
  first_number int;
  second jsonb;
  restated jsonb;
  v_document jsonb;
  v_page text;
begin
  if left(current_setting('test.ad_publish_2'), 6) = 'RAISED' then
    raise exception 'FAIL 8: the second publish raised: %', current_setting('test.ad_publish_2');
  end if;
  if left(current_setting('test.ad_restore'), 6) = 'RAISED' then
    raise exception 'FAIL 8: the restore raised: %', current_setting('test.ad_restore');
  end if;

  first_number := current_setting('test.ad_first_version_number')::int;
  second := current_setting('test.ad_publish_2')::jsonb;
  restated := current_setting('test.ad_restore')::jsonb;

  if second ->> 'version_number' <> (first_number + 1)::text then
    raise exception 'FAIL 8: the second publish took number % after %', second ->> 'version_number', first_number;
  end if;
  if (restated ->> 'version_number')::int <= (second ->> 'version_number')::int then
    raise exception 'FAIL 8: the rollback reused a number instead of adding one: % after %',
      restated ->> 'version_number', second ->> 'version_number';
  end if;
  if restated -> 'note' is null or restated ->> 'note' not like 'restored from version%' then
    raise exception 'FAIL 8: the rollback did not say what it restored: %', restated;
  end if;

  -- The published row is the FIRST document again, with its section intact.
  select value #>> '{pages,0,page}' into v_page from core.app_settings
   where key = 'app_design_published';
  if v_page <> 'home' then
    raise exception 'FAIL 8: after the rollback the customer design is page %, expected home', v_page;
  end if;

  if left(current_setting('test.ad_restore_missing'), 6) <> 'RAISED'
     or current_setting('test.ad_restore_missing') not like '%P0002%' then
    raise exception 'FAIL 9: restoring an unknown version answered %',
      current_setting('test.ad_restore_missing');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 10. The list is metadata newest-first and carries no documents: the panel
--     renders numbers and dates, and fetching every stored tree to do it is the
--     slowest possible way to show one.
-- ---------------------------------------------------------------------------
do $$
declare answer jsonb;
begin
  if left(current_setting('test.ad_versions'), 6) = 'RAISED' then
    raise exception 'FAIL 10: the version list raised: %', current_setting('test.ad_versions');
  end if;
  answer := current_setting('test.ad_versions')::jsonb;
  if jsonb_typeof(answer) <> 'array' or jsonb_array_length(answer) <> 3 then
    raise exception 'FAIL 10: the list answered % rows, expected the three publishes', jsonb_array_length(answer);
  end if;
  if answer -> 0 ->> 'version_number' = '1' then
    raise exception 'FAIL 10: the list is oldest first: %', answer -> 0;
  end if;
  if answer -> 0 ? 'document' then
    raise exception 'FAIL 10: the list carries whole documents';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 11–14. Nobody else touches the design: a cashier without either code, a
--        customer who is not staff, and anon without EXECUTE all fail, while the
--        published row is readable by the customer role and the draft is not.
-- ---------------------------------------------------------------------------
do $$
declare
  answer text;
  v_public int;
  v_draft int;
begin
  answer := current_setting('test.ad_cashier_read');
  if left(answer, 6) <> 'RAISED' or answer not like '%42501%' then
    raise exception 'FAIL 11: a cashier read the draft and answered %', answer;
  end if;

  answer := current_setting('test.ad_customer_write');
  if left(answer, 6) <> 'RAISED' or answer not like '%42501%' then
    raise exception 'FAIL 12: a customer saved a draft and answered %', answer;
  end if;

  answer := current_setting('test.ad_anon_publish');
  if left(answer, 6) <> 'RAISED'
     or (answer not like '%42501%' and answer not like '%42882%') then
    raise exception 'FAIL 13: anon published and answered %', answer;
  end if;

  -- 14, read as anon: the published document reaches the customer app through
  -- the bridge view, the draft never does.
  v_public := current_setting('test.ad_anon_public_rows')::int;
  v_draft := current_setting('test.ad_anon_draft_rows')::int;
  if v_public <> 1 then
    raise exception 'FAIL 14: anon sees % published design rows, expected 1 — is_public was not set', v_public;
  end if;
  if v_draft <> 0 then
    raise exception 'FAIL 14: anon can read the draft through public.app_settings';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 15. Nothing is exposed to a client role: the version table answers no SELECT
--     or write to anon or authenticated, so only the definer RPCs reach it.
--     Measured with has_table_privilege, because 226's own REVOKE leaves an
--     explicit (and therefore non-null) relacl — an empty ACL is not the goal,
--     an unusable one is.
-- ---------------------------------------------------------------------------
do $$
declare
  v_role text;
  v_kind text;
begin
  foreach v_role in array array['anon','authenticated'] loop
    foreach v_kind in array array['select','insert','update','delete','references','trigger'] loop
      if has_table_privilege(v_role, 'core.app_design_versions', v_kind) then
        raise exception 'FAIL 15: % holds % on core.app_design_versions', v_role, v_kind;
      end if;
    end loop;
  end loop;
end $$;

rollback;
