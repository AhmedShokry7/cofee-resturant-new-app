select jsonb_build_object(
 'update_customer_guard', (select pg_get_functiondef('public.admin_update_customer(uuid,boolean,boolean,text)'::regprocedure) like '%not a customer account%'),
 'update_customer_write_perm', (select pg_get_functiondef('public.admin_update_customer(uuid,boolean,boolean,text)'::regprocedure) like '%customers.write%'),
 'payments_coalesce', (select pg_get_functiondef('public.admin_payments()'::regprocedure) like '%coalesce(p.full_name, pc.full_name)%'),
 'payments_branch_scope', (select pg_get_functiondef('public.admin_payments()'::regprocedure) like '%identity.can_manage_branch(o.branch_id)%'),
 'carts_branch_scope', (select pg_get_functiondef('public.admin_abandoned_carts()'::regprocedure) like '%identity.can_manage_branch(c.branch_id)%'),
 'customer_acl', (select p.proacl::text from pg_proc p where p.oid='public.admin_customer_details(uuid)'::regprocedure),
 'customer_owner', (select p.proowner::regrole::text from pg_proc p where p.oid='public.admin_customer_details(uuid)'::regprocedure),
 'customer_secdef', (select p.prosecdef from pg_proc p where p.oid='public.admin_customer_details(uuid)'::regprocedure),
 'customer_config', (select p.proconfig::text from pg_proc p where p.oid='public.admin_customer_details(uuid)'::regprocedure),
 'history', (select jsonb_build_object('created_by', created_by, 'name', name, 'nstmts', array_length(statements,1)) from supabase_migrations.schema_migrations where version='211')
) as audit;