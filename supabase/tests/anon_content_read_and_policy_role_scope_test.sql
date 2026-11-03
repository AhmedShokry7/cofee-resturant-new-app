-- anon_content_read_and_policy_role_scope_test.sql
--
-- Static privilege assertions for migration 223. Run as a privileged role;
-- `has_table_privilege` reports another role's rights, and `pg_policies` is
-- readable by anyone.
--
-- ONE statement, eight rows: it runs unchanged in `psql -f`, in CI, and in the
-- Supabase dashboard SQL editor - the editor only returns the last result set,
-- so separate `select case ...` statements showed one row each and hid the
-- rest. Every row is `PASS` or a `FAIL:` sentence naming what is wrong.
--
-- Both halves guard a 42501 measured against the live project through PostgREST
-- as an anon client on 2026-11-03, not a hypothesis:
--
--   GET /rest/v1/legal_documents -> permission denied for table legal_documents
--   GET /rest/v1/loyalty_rewards -> permission denied for function has_permission
--
-- Each check is run before and after 223 on a database that has NOT had it
-- applied, so t1/t4/t6/t7 must read FAIL first. A file that passes on the broken
-- database proves nothing.

with
  -- The editorial family the bridge views sit on. A `security_invoker` view
  -- (032) runs as the calling role, so every table behind one needs its own
  -- anon grant; 033 fixed three of these and missed legal_documents.
  editorial(oid) as (
    values ('core.faq_items'::regclass),
           ('core.onboarding_slides'::regclass),
           ('core.app_settings'::regclass),
           ('core.legal_documents'::regclass)
  ),
  -- A `create policy` with no TO clause is `TO PUBLIC`, and anon is a member of
  -- PUBLIC, so such a policy is evaluated for guests. `identity.has_permission`
  -- is granted to authenticated only, so evaluating it as anon raises 42501 and
  -- kills the whole read instead of filtering it.
  public_permission_policies as (
    select string_agg(
             schemaname || '.' || tablename || '/' || policyname,
             ', ' order by schemaname, tablename, policyname
           ) as offenders
      from pg_policies
     where schemaname in ('core','catalog','orders','marketing','loyalty',
                          'payments','subscriptions','engagement','identity',
                          'inventory')
       and roles::text[] = array['public']::text[]
       and (qual like '%has_permission%' or with_check like '%has_permission%')
  ),
  subscription_policies as (
    select policyname, roles
      from pg_policies
     where schemaname = 'subscriptions'
  ),
  staff_policies as (
    select bool_and('authenticated' = any (roles)) as covered
      from subscription_policies
     where policyname in ('plans_write','plan_branches_write','plan_products_write',
                          'subscriptions_read','subscriptions_write','usage_read',
                          'events_read','sub_consumptions_read')
  )
select 't1 anon reads core.legal_documents (the base table 033 missed)' as check,
       case when has_table_privilege('anon', 'core.legal_documents', 'SELECT')
            then 'PASS'
            else 'FAIL: anon cannot select core.legal_documents, so 223 is not applied'
       end as result
union all
select 't2 anon reads the public.legal_documents view',
       case when has_table_privilege('anon', 'public.legal_documents', 'SELECT')
            then 'PASS'
            else 'FAIL: anon cannot select the public.legal_documents view'
       end
union all
select 't3 the whole editorial family is granted to anon',
       case when (select bool_and(has_table_privilege('anon', oid, 'SELECT'))
                   from editorial)
            then 'PASS'
            else 'FAIL: a core editorial table is missing its anon grant'
       end
union all
select 't4 no policy falls through to PUBLIC while calling a staff helper',
       case when (select offenders from public_permission_policies) is null
            then 'PASS'
            else 'FAIL: applies to PUBLIC and calls identity.has_permission: '
                 || (select offenders from public_permission_policies)
       end
union all
select 't5 all eleven 074/075 subscription policies still exist after 223',
       case when (select count(*) from subscription_policies
                   where policyname in ('plans_read','plan_branches_read',
                                        'plan_products_read','plans_write',
                                        'plan_branches_write','plan_products_write',
                                        'subscriptions_read','subscriptions_write',
                                        'usage_read','events_read',
                                        'sub_consumptions_read')) = 11
            then 'PASS'
            else 'FAIL: a 074/075 subscription policy is missing after 223'
       end
union all
select 't6 staff and owners still cover authenticated',
       case when (select covered from staff_policies)
            then 'PASS'
            else 'FAIL: a staff/owner subscription policy no longer covers authenticated'
       end
union all
select 't7 the public plan catalogue is still readable by anon',
       case when (select bool_and('anon' = any (roles)) from subscription_policies
                   where policyname in ('plans_read','plan_branches_read','plan_products_read'))
            then 'PASS'
            else 'FAIL: the public plan catalogue is no longer readable by anon'
       end
union all
select 't8 anon reads the reward catalogue (022 public read policy)',
       case when has_table_privilege('anon', 'public.loyalty_rewards', 'SELECT')
            then 'PASS'
            else 'FAIL: anon cannot select public.loyalty_rewards'
       end;
