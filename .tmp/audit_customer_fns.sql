select jsonb_build_object(
  'customer_details', pg_get_functiondef('public.admin_customer_details(uuid)'::regprocedure),
  'update_customer', pg_get_functiondef('public.admin_update_customer(uuid,text,text,boolean,text,jsonb)'::regprocedure),
  'customer_has_guard', (select pg_get_functiondef('public.admin_customer_details(uuid)'::regprocedure) like '%not a customer account%'),
  'customer_has_staff_source', (select pg_get_functiondef('public.admin_customer_details(uuid)'::regprocedure) like '%identity.staff_members%')
) as audit;