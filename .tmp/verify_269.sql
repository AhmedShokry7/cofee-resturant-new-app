select jsonb_build_object(
 'history', (select jsonb_build_object('version',version,'name',name,'nstmts',array_length(statements,1),
    'has_guard', exists(select 1 from unnest(statements) s where s like '%not a customer account%'),
    'has_staff_source', exists(select 1 from unnest(statements) s where s like '%identity.staff_members%'))
   from supabase_migrations.schema_migrations where version='269'),
 'live', (select jsonb_build_object(
    'has_guard', pg_get_functiondef(p.oid) like '%not a customer account%',
    'has_staff_guard', pg_get_functiondef(p.oid) like '%sm.user_id = p_customer_id%',
    'has_identity_staff', pg_get_functiondef(p.oid) like '%identity.staff_members%',
    'owner', p.proowner::regrole::text, 'secdef', p.prosecdef,
    'config', p.proconfig, 'acl', p.proacl::text,
    'anon', has_function_privilege('anon', p.oid, 'execute'),
    'authenticated', has_function_privilege('authenticated', p.oid, 'execute'),
    'public_grant', exists(select 1 from aclexplode(p.proacl) a where a.grantee = 0),
    'n_overloads', (select count(*) from pg_proc q where q.proname='admin_customer_details' and q.pronamespace='public'::regnamespace))
   from pg_proc p where p.oid='public.admin_customer_details(uuid)'::regprocedure)
) as result;