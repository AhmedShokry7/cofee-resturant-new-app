with fns as (
  select p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args,
         pg_get_functiondef(p.oid) as def, p.prosecdef, p.proconfig,
         p.proowner::regrole::text as owner
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where (n.nspname = 'public' and p.proname in
          ('admin_customer_details','admin_update_customer','admin_payments',
           'admin_update_payment_status','admin_abandoned_carts'))
      or (n.nspname = 'identity' and p.proname in
          ('is_staff','has_permission','can_manage_branch'))
), hist as (
  select version, name, statements
    from supabase_migrations.schema_migrations
   where version = '211'
)
select 'functions' as kind, jsonb_agg(jsonb_build_object(
  'schema', nspname, 'name', proname, 'args', args, 'owner', owner,
  'secdef', prosecdef, 'config', proconfig,
  'anon', has_function_privilege('anon', oid, 'execute'),
  'authenticated', has_function_privilege('authenticated', oid, 'execute'),
  'def', def) order by nspname, proname) as payload
from fns
union all
select 'history_211', jsonb_build_object(
  'name', name,
  'nstmts', array_length(statements, 1),
  'has_guard', exists (select 1 from unnest(statements) s where s like '%not a customer account%'),
  'has_staff_members', exists (select 1 from unnest(statements) s where s like '%identity.staff_members%'))
from hist
union all
select 'overlap', jsonb_build_object(
  'staff_rows', (select count(*) from identity.staff_members),
  'profiles_for_staff', (select count(*) from identity.profiles p join identity.staff_members sm on sm.user_id = p.id),
  'profiles', (select count(*) from identity.profiles),
  'customer_read_roles', (select jsonb_agg(r.code order by r.code)
     from identity.roles r join identity.role_permissions rp on rp.role_id = r.id
     join identity.permissions p on p.id = rp.permission_id where p.code = 'customers.read'))
union all
select 'triggers', jsonb_build_object(
  'profile_triggers', (select jsonb_agg(tgname order by tgname) from pg_trigger
     where tgrelid = 'identity.profiles'::regclass and not tgisinternal),
  'staff_triggers', (select jsonb_agg(tgname order by tgname) from pg_trigger
     where tgrelid = 'identity.staff_members'::regclass and not tgisinternal));
