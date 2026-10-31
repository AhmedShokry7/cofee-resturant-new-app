-- trigger_function_grants_test.sql
-- Behaviour test for supabase/proposals/216_trigger_function_grants.PROPOSED.sql:
-- the two trigger functions 188 created are executable by PUBLIC, and 216 takes
-- that away without touching the grants 188 wrote or the triggers that fire them.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-31 against webzzasosevzymftgszn
--
--   Run whole, exactly as written, inside one transaction that ended in
--   `rollback;`. The report row it returned:
--     verdict                         reached the end: no assertion failed
--     anon_before_216                 both executable by anon
--     acl_before                      =X/postgres,postgres=X/postgres,authenticated=X/postgres,supabase_auth_admin=X/postgres
--     acl_after                       postgres=X/postgres,authenticated=X/postgres,supabase_auth_admin=X/postgres  (both functions)
--     grants_after_216                anon=false service_role=false authenticated=true auth_admin=true owner=true
--     identity_anon_executable_now    0
--     anon_direct_call_before         0A000
--     anon_direct_call_after          42501
--     signup_path                     3 profiles from 3 signups
--     drop_trigger                    fired: profile of the staff uid removed
--     reject_trigger_as_authenticated 23514
--     customer_profile_update         ok
--     order_history_guard             23514
--     uids_in_both_tables             0    customers_kept 2    staff_kept 1    order_kept 1
--
--   A fresh session afterwards read the database back as it was before the run:
--     acl_reject_now / acl_remove_now  =X/postgres,postgres=X/postgres,authenticated=X/postgres,supabase_auth_admin=X/postgres
--     anon_execute_now                 true
--     service_role_execute_now         true
--     identity_anon_executable_now     2
--     comments_rewritten_now           0
--     branch / auth.users / profiles / staff_members / orders fixture residue: 0 each
--
--   THREE THINGS THE RUN MEASURED THAT THE PROPOSAL HEADER SHOULD SAY:
--     * anon and service_role lost EXECUTE as intended; authenticated and
--       supabase_auth_admin kept the grants 188 wrote, byte for byte.
--     * PostgreSQL checks the function ACL BEFORE it complains about trigger
--       context: the same direct call by anon answered 0A000 while PUBLIC held
--       the grant and 42501 once it was gone. Both are refusals — this file was
--       never about a reachable exploit — but the answer a caller sees does
--       change, so the proposal says that rather than claiming it does not.
--     * The path 216 could in principle break is section 5c, an authenticated
--       INSERT into identity.profiles firing trg_profile_not_staff. It answered
--       23514 — the trigger's own refusal, not a privilege error — with the
--       REVOKEs already applied in the same transaction. Section 5d is its
--       mirror: an ordinary customer's own profile edit still goes through.
--       Whether PostgreSQL would have raised 42501 for an invoker that held no
--       grant at all is a question this file cannot answer, because no role with
--       a write on either table depends on the PUBLIC entry (anon and
--       service_role have none; measured in the proposal).
--
-- HOW TO RUN
--   Plain SQL for the Supabase SQL Editor or psql, as the owner role. Everything
--   sits inside one transaction that is rolled back at the end, so the four
--   REVOKEs, the two COMMENTs and every fixture row disappear with it. Section 1
--   measures the live state and section 2 changes it, so one run prints the
--   before/after pair; if the owner has already applied 216, section 1 reports
--   `already revoked out of band` and the run still passes — that is deliberate,
--   the assertions are all on the end state this file itself creates.
--
-- WHAT EACH SECTION PROVES
--   1  the state 216 starts from, measured in this transaction: the ACL text, and
--      whether anon is inside it. Also what a direct call by anon answers with
--      while the PUBLIC entry is still there.
--   2  216's own body, verbatim: four REVOKEs, two COMMENTs, one notify.
--   3  the grants it claims to keep are exactly kept: authenticated (the only
--      non-owner role with a write on identity.profiles, so the only role that
--      fires trg_profile_not_staff on its own) and supabase_auth_admin both hold
--      EXECUTE, postgres holds it as owner, and PUBLIC is gone from the ACL text.
--   4  the invariant 081:14-15 established for the identity schema is true again
--      for EVERY function in it, not only for these two names, and the class 216
--      belongs to — anon-executable trigger functions — is empty across the
--      application schemas.
--   5  the two triggers still fire, on every write path the product has, with
--      216 applied: the signup path creates its profile, provisioning drops it,
--      a staff uid writing its own customer profile is refused with 23514 and
--      not with 42501, a plain customer still edits its own profile, and an
--      account with order history is still refused rather than silently deleted.
--   6  what a direct call by anon answers with once the PUBLIC entry is gone.
--      Both arms must refuse; the point of printing both is that 216 changes who
--      the catalogue says may call, and this section records whether that is also
--      a different answer.
--   7  188's own end state survived: no uid sits in both tables.
--
-- WHY THE JOURNAL IS A GUC AND NOT A TABLE
--   Every scenario has to run AS a different role, and the answer has to outlive
--   the subtransaction the scenario aborts in. An ordinary journal table would
--   need a grant, and the project runs an `ensure_rls` event trigger on
--   ddl_command_end that turns RLS on for any table a script creates, so the
--   table would need turning back off first. Transaction-local settings
--   (`set_config(..., true)`) need neither: they are visible to every role,
--   including anon, and the rollback takes them with the transaction.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: one branch (section 5 needs a real order), three accounts.
--   …001 starts life as a customer and is provisioned as staff — the path that
--      must drop its profile.
--   …002 is a plain customer and stays one.
--   …003 is a customer WITH an order, so provisioning it must be refused.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values ('9c0b0000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000001', 'TFG-B1', 'فرع الصلاحيات', 'Grants Branch 1',
        'addr', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('9c100000-0000-4000-8000-000000000001', 'tfg-flip@test.local'),
  ('9c100000-0000-4000-8000-000000000002', 'tfg-customer@test.local'),
  ('9c100000-0000-4000-8000-000000000003', 'tfg-buyer@test.local');

-- ---------------------------------------------------------------------------
-- 1. The state 216 starts from, taken before anything in this file changes it.
-- ---------------------------------------------------------------------------
do $$
declare
  v_acl text;
  v_state text;
begin
  select coalesce(array_to_string(p.proacl, ','), 'NULL(default=public)')
    into v_acl
    from pg_proc p
   where p.oid = 'identity.reject_customer_profile_for_staff()'::regprocedure;
  perform set_config('test.tfg_acl_reject_before', v_acl, true);

  if has_function_privilege('anon', 'identity.reject_customer_profile_for_staff()', 'execute')
     and has_function_privilege('anon', 'identity.remove_customer_profile_on_staff()', 'execute') then
    perform set_config('test.tfg_anon_before', 'both executable by anon', true);
  else
    perform set_config('test.tfg_anon_before', 'already revoked out of band', true);
  end if;

  -- A direct call by the client role, while the PUBLIC entry is still there.
  -- Whatever it answers, it must not answer by running.
  execute 'set local role anon';
  begin
    perform identity.reject_customer_profile_for_staff();
    v_state := 'RAN - returned a value';
  exception when others then
    v_state := sqlstate;
  end;
  execute 'reset role';
  perform set_config('test.tfg_direct_before', v_state, true);
end $$;

-- ---------------------------------------------------------------------------
-- 2. THE PROPOSAL. Everything between here and section 3 is
--    216_trigger_function_grants.PROPOSED.sql, statement for statement.
-- ---------------------------------------------------------------------------
revoke execute on function identity.reject_customer_profile_for_staff() from public;
revoke execute on function identity.reject_customer_profile_for_staff() from anon;

revoke execute on function identity.remove_customer_profile_on_staff() from public;
revoke execute on function identity.remove_customer_profile_on_staff() from anon;

comment on function identity.reject_customer_profile_for_staff() is
  'AFTER trigger on identity.profiles (188 section 1): a uid that has an '
  'identity.staff_members row may not keep a customer profile row. Trigger-only — '
  'not client-callable (a direct call raises 0A000), EXECUTE revoked from PUBLIC '
  'and anon by 216, and held only by the grants 188 wrote.';

comment on function identity.remove_customer_profile_on_staff() is
  'AFTER trigger on identity.staff_members (188 section 2): removes the customer '
  'profile the signup trigger wrote for the same uid, and refuses the insert when '
  'that customer has order history. Trigger-only — not client-callable (a direct '
  'call raises 0A000), EXECUTE revoked from PUBLIC and anon by 216, and held only '
  'by the grants 188 wrote.';

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- 3. The grants 216 says it keeps are kept, and the one it removes is gone.
--    188:173-176 granted authenticated and supabase_auth_admin; 216 names neither.
-- ---------------------------------------------------------------------------
do $$
declare
  v_acl text;
begin
  if has_function_privilege('anon', 'identity.reject_customer_profile_for_staff()', 'execute') then
    raise exception 'FAIL 3: anon still executes reject_customer_profile_for_staff after the revoke';
  end if;
  if has_function_privilege('anon', 'identity.remove_customer_profile_on_staff()', 'execute') then
    raise exception 'FAIL 3: anon still executes remove_customer_profile_on_staff after the revoke';
  end if;

  -- service_role reached both functions only through PUBLIC, so 216 takes it away
  -- from this role too. That is the intended effect, and it is safe only because
  -- service_role holds no INSERT on either table — measured in the proposal, and
  -- the reason its provisioning writes go through the SECURITY DEFINER functions
  -- owned by postgres.
  if has_function_privilege('service_role', 'identity.reject_customer_profile_for_staff()', 'execute') then
    raise exception 'FAIL 3: service_role still reaches the function through an entry 216 removed';
  end if;

  if not has_function_privilege('authenticated', 'identity.reject_customer_profile_for_staff()', 'execute') then
    raise exception 'FAIL 3: authenticated lost the grant 188 wrote — the customer app profile path is the one role that really fires this trigger';
  end if;
  if not has_function_privilege('authenticated', 'identity.remove_customer_profile_on_staff()', 'execute') then
    raise exception 'FAIL 3: authenticated lost the grant 188 wrote on the second function';
  end if;
  if not has_function_privilege('supabase_auth_admin', 'identity.reject_customer_profile_for_staff()', 'execute') then
    raise exception 'FAIL 3: supabase_auth_admin lost the grant 188 wrote';
  end if;
  if not has_function_privilege('postgres', 'identity.reject_customer_profile_for_staff()', 'execute') then
    raise exception 'FAIL 3: the owner lost EXECUTE on its own function';
  end if;

  -- PUBLIC is an ACL entry, not a role membership check: read the text. A
  -- function still carrying it serialises as `=X/<owner>` first.
  select coalesce(array_to_string(p.proacl, ','), 'NULL(default=public)')
    into v_acl
    from pg_proc p
   where p.oid = 'identity.reject_customer_profile_for_staff()'::regprocedure;
  if v_acl like '=X/%' then
    raise exception 'FAIL 3: a PUBLIC entry is still in the ACL: %', v_acl;
  end if;
  if v_acl not like '%authenticated=X%' then
    raise exception 'FAIL 3: 188''s explicit grant to authenticated is gone from the ACL: %', v_acl;
  end if;
end $$;

-- The ACL text after the change, for the report row.
do $$
declare
  v_acl text;
begin
  select string_agg(coalesce(array_to_string(p.proacl, ','), 'NULL(default=public)'), ' || ')
    into v_acl
    from pg_proc p
   where p.oid in ('identity.reject_customer_profile_for_staff()'::regprocedure,
                   'identity.remove_customer_profile_on_staff()'::regprocedure);
  perform set_config('test.tfg_acl_after', coalesce(v_acl, 'none'), true);
end $$;

-- ---------------------------------------------------------------------------
-- 4. The invariant 081 wrote, measured over the whole schema rather than over
--    two names, so the next migration that creates an identity function without
--    a REVOKE fails here too.
-- ---------------------------------------------------------------------------
do $$
declare
  v_left text;
  v_class text;
begin
  select coalesce(string_agg(p.proname, ', ' order by p.proname), 'none')
    into v_left
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'identity'
     and has_function_privilege('anon', p.oid, 'execute');
  if v_left <> 'none' then
    raise exception 'FAIL 4: identity still holds anon-executable functions: %', v_left;
  end if;

  -- The class 216 belongs to: trigger functions a client role could call.
  select coalesce(string_agg(n.nspname || '.' || p.proname, ', ' order by n.nspname || '.' || p.proname), 'none')
    into v_class
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public','identity','core','catalog','orders','cart','payments',
                       'marketing','loyalty','hr','pos','delivery','support','notifications')
     and p.prorettype = 'trigger'::regtype
     and has_function_privilege('anon', p.oid, 'execute');
  if v_class <> 'none' then
    raise exception 'FAIL 4: anon-executable trigger functions remain: %', v_class;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Both triggers still fire, with 216 applied, on every write path the product
--    has. Each scenario writes the answer into a transaction-local setting so
--    the report row shows what actually happened, not what was expected.
-- ---------------------------------------------------------------------------

-- 5a. The signup path (003's trigger, unchanged by 188 or 216): a new auth user
--     gets a profile, so the AFTER trigger on identity.profiles ran and passed.
do $$
begin
  if (select count(*) from identity.profiles
       where id in ('9c100000-0000-4000-8000-000000000001',
                    '9c100000-0000-4000-8000-000000000002',
                    '9c100000-0000-4000-8000-000000000003')) <> 3 then
    raise exception 'FAIL 5a: the signup path stopped writing identity.profiles — % rows for three accounts',
      (select count(*) from identity.profiles
        where id in ('9c100000-0000-4000-8000-000000000001',
                     '9c100000-0000-4000-8000-000000000002',
                     '9c100000-0000-4000-8000-000000000003'));
  end if;
  perform set_config('test.tfg_signup', '3 profiles from 3 signups', true);
end $$;

-- 5b. Provisioning, as the owner. This is the role every real provisioning path
--     runs in: 080's identity.provision_staff and 210's invitation accept are
--     SECURITY DEFINER owned by postgres, so the insert into identity.staff_members
--     — and the trigger it fires — happen as the owner, never as PUBLIC.
do $$
begin
  insert into identity.staff_members (id, user_id, status, full_name, email)
  values ('9c200000-0000-4000-8000-000000000001',
          '9c100000-0000-4000-8000-000000000001', 'active', 'TFG Flip', 'tfg-flip@test.local');
  if exists (select 1 from identity.profiles where id = '9c100000-0000-4000-8000-000000000001') then
    raise exception 'FAIL 5b: trg_staff_drop_customer_profile did not fire — the staff account kept its customer row';
  end if;
  perform set_config('test.tfg_drop_trigger', 'fired: profile of the staff uid removed', true);
end $$;

-- 5c. The authenticated path on identity.profiles. `authenticated` holds INSERT
--     and UPDATE there (profiles_insert_own, profiles_update_own), so it is the
--     one non-owner role that really fires trg_profile_not_staff. It must still
--     be refused by the trigger with 23514 — a 42501 here would mean the revoke
--     took away an EXECUTE the trigger path needed, which is the one failure
--     mode of 216 worth catching before it is applied.
do $$
declare
  v_state text;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"9c100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
  execute 'set local role authenticated';
  begin
    insert into identity.profiles (id, email, full_name)
    values ('9c100000-0000-4000-8000-000000000001', 'tfg-flip@test.local', 'TFG Flip');
    v_state := 'RAN - a staff uid was accepted into identity.profiles';
  exception when others then
    v_state := sqlstate;
  end;
  execute 'reset role';
  perform set_config('test.tfg_reject_trigger', v_state, true);

  if v_state <> '23514' then
    raise exception 'FAIL 5c: a staff uid writing its own profile answered % instead of 23514 — '
      '42501 would mean the revoked EXECUTE was needed at trigger time', v_state;
  end if;
  if exists (select 1 from identity.profiles where id = '9c100000-0000-4000-8000-000000000001') then
    raise exception 'FAIL 5c: the refused profile row was kept';
  end if;
end $$;

-- 5d. The same role on a write it is allowed to make: a plain customer edits its
--     own profile, the trigger runs, finds no staff row, and lets it through.
do $$
declare
  v_state text;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"9c100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
  execute 'set local role authenticated';
  begin
    update identity.profiles set full_name = 'TFG Customer Edited'
     where id = '9c100000-0000-4000-8000-000000000002';
    v_state := 'ok';
  exception when others then
    v_state := sqlstate;
  end;
  execute 'reset role';
  perform set_config('test.tfg_customer_update', v_state, true);

  if v_state <> 'ok' then
    raise exception 'FAIL 5d: a plain customer lost its own profile edit (%) — 216 must change nothing on this path', v_state;
  end if;
  if (select full_name from identity.profiles
       where id = '9c100000-0000-4000-8000-000000000002') <> 'TFG Customer Edited' then
    raise exception 'FAIL 5d: the update answered ok but wrote nothing';
  end if;
end $$;

-- 5e. The refusal that protects an order history still refuses, with the same
--     message, through the same exception handler inside the function.
do $$
declare
  v_state text;
begin
  insert into orders.orders (
    id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
    subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
    customer_note, placed_at, loyalty_points_earned, idempotency_key, order_source
  )
  values (
    '9c300000-0000-4000-8000-000000000001', 'TEST-TFG-1',
    '9c100000-0000-4000-8000-000000000003', '9c0b0000-0000-4000-8000-000000000001',
    'dine_in', 'confirmed', 'paid', 40.00, 0.00, 0.00, 0.00, 40.00, 'SAR', 'tfg',
    '2026-01-01T10:00:00Z', 0, 'tfg-test-key-1', 'online'
  );

  begin
    insert into identity.staff_members (id, user_id, status, full_name, email)
    values ('9c200000-0000-4000-8000-000000000003',
            '9c100000-0000-4000-8000-000000000003', 'invited',
            'TFG Buyer As Staff', 'tfg-buyer@test.local');
    v_state := 'RAN - an account with orders was turned into staff';
  exception when others then
    v_state := sqlstate;
  end;
  perform set_config('test.tfg_order_guard', v_state, true);

  if v_state <> '23514' then
    raise exception 'FAIL 5e: provisioning a buyer answered % instead of 23514', v_state;
  end if;
  if not exists (select 1 from identity.profiles where id = '9c100000-0000-4000-8000-000000000003') then
    raise exception 'FAIL 5e: the refused provisioning deleted the customer row';
  end if;
  if exists (select 1 from identity.staff_members where user_id = '9c100000-0000-4000-8000-000000000003') then
    raise exception 'FAIL 5e: the refused provisioning kept the staff row';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. The same direct call as section 1, now that PUBLIC is gone. Both arms
--    refuse; the two codes are printed side by side so the reader can see what
--    the revoke actually changed for a caller.
-- ---------------------------------------------------------------------------
do $$
declare
  v_state text;
begin
  execute 'set local role anon';
  begin
    perform identity.reject_customer_profile_for_staff();
    v_state := 'RAN - returned a value';
  exception when others then
    v_state := sqlstate;
  end;
  execute 'reset role';
  perform set_config('test.tfg_direct_after', v_state, true);

  if v_state = 'RAN - returned a value' then
    raise exception 'FAIL 6: a direct call by anon ran the trigger function after the revoke';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. 188's contract survived 216 untouched: the two populations share no uid.
-- ---------------------------------------------------------------------------
do $$
declare
  v_both integer;
begin
  select count(*) into v_both
    from identity.profiles p
    join identity.staff_members s on s.user_id = p.id;
  if v_both > 0 then
    raise exception 'FAIL 7: % uid(s) sit in both identity.profiles and identity.staff_members', v_both;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Report. One row, everything the run observed.
-- ---------------------------------------------------------------------------
select
  'reached the end: no assertion failed'                                as verdict,
  current_setting('test.tfg_anon_before')                                as anon_before_216,
  current_setting('test.tfg_acl_reject_before')                          as acl_before,
  current_setting('test.tfg_acl_after')                                  as acl_after,
  'anon=' || has_function_privilege('anon', 'identity.reject_customer_profile_for_staff()', 'execute')
    || ' service_role=' || has_function_privilege('service_role', 'identity.reject_customer_profile_for_staff()', 'execute')
    || ' authenticated=' || has_function_privilege('authenticated', 'identity.reject_customer_profile_for_staff()', 'execute')
    || ' auth_admin=' || has_function_privilege('supabase_auth_admin', 'identity.reject_customer_profile_for_staff()', 'execute')
    || ' owner=' || has_function_privilege('postgres', 'identity.reject_customer_profile_for_staff()', 'execute')
                                                                        as grants_after_216,
  (select count(*) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'identity'
      and has_function_privilege('anon', p.oid, 'execute'))              as identity_anon_executable_now,
  current_setting('test.tfg_direct_before')                              as anon_direct_call_before,
  current_setting('test.tfg_direct_after')                               as anon_direct_call_after,
  current_setting('test.tfg_signup')                                     as signup_path,
  current_setting('test.tfg_drop_trigger')                               as drop_trigger,
  current_setting('test.tfg_reject_trigger')                             as reject_trigger_as_authenticated,
  current_setting('test.tfg_customer_update')                            as customer_profile_update,
  current_setting('test.tfg_order_guard')                                as order_history_guard,
  (select count(*) from identity.profiles p
     join identity.staff_members s on s.user_id = p.id)                  as uids_in_both_tables,
  (select count(*) from identity.profiles
     where id in ('9c100000-0000-4000-8000-000000000002',
                  '9c100000-0000-4000-8000-000000000003'))               as customers_kept,
  (select count(*) from identity.staff_members
     where id = '9c200000-0000-4000-8000-000000000001')                  as staff_kept,
  (select count(*) from orders.orders where order_number = 'TEST-TFG-1') as order_kept;

rollback;
