select
 (select count(*)=6 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('admin_get_reservation_cancellation_policy','admin_set_reservation_cancellation_policy','list_my_reservations','list_my_customer_event_requests','cancel_my_reservation','cancel_my_customer_event_request')) as functions_installed,
 position('reservation_cancel_cutoff_minutes' in pg_get_functiondef('public.cancel_my_reservation(uuid)'::regprocedure))>0 as cutoff_installed,
 not has_function_privilege('anon','public.admin_set_reservation_cancellation_policy(uuid,integer,integer)','EXECUTE') as anon_denied,
 (select count(*)=0 from core.branches where code='CANCEL-CUTOFF-TEST') as test_branch_removed,
 (select count(*)=0 from auth.users where id in ('bca00000-0000-4000-8000-000000000021','bca00000-0000-4000-8000-000000000023')) as test_accounts_removed;
