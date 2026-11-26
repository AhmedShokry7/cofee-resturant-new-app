select pg_get_functiondef('public.admin_customer_details(uuid)'::regprocedure) as def,
 (select pg_get_functiondef('public.admin_customer_details(uuid)'::regprocedure) like '%not a customer account%') as has_guard,
 (select pg_get_functiondef('public.admin_customer_details(uuid)'::regprocedure) like '%identity.staff_members%') as has_staff_source,
 (select jsonb_agg(jsonb_build_object('name', p.proname, 'args', pg_get_function_identity_arguments(p.oid)))
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='admin_update_customer') as update_sigs;