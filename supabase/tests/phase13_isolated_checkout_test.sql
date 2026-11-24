-- Read-only security and fixture checks. Authenticated order creation/payment
-- requires genuine owner-provisioned GoTrue sessions and is deliberately not
-- simulated here.
select case when has_function_privilege('authenticated','public.phase13_test_checkout(uuid,uuid)','EXECUTE')
  and not has_function_privilege('anon','public.phase13_test_checkout(uuid,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','payments.phase13_test_checkout_context()','EXECUTE')
  and not has_function_privilege('anon','payments.phase13_test_checkout_context()','EXECUTE')
  then 'PASS' else 'FAIL: checkout or test-context RPC grants are too broad' end as rpc_grants;

select case when not b.is_active and b.settings->>'phase13_test_run_id'='b105bd82-18df-4e6a-9b10-306d5ed5e1bc'
  and not c.is_active and not p.is_active and p.archived_at is null
  and p.category_id=c.id and coalesce(bp.is_available,true)
  then 'PASS' else 'FAIL: isolated fixtures are active, mismatched, or unavailable' end as fixture_isolation
from core.branches b
join catalog.categories c on c.id='c4333e36-5ac9-446d-9394-eb043fc24d03'
join catalog.products p on p.id='8d98c73d-43e9-484f-9dab-9a10d0513e70'
left join catalog.branch_product_pricing bp on bp.branch_id=b.id and bp.product_id=p.id
where b.id='10dbfb03-ed35-4a79-9116-c44c7bb0ec66';

select case when exists(select 1 from pg_constraint where conrelid='core.branches'::regclass
    and conname='phase13_branch_must_stay_inactive')
  and exists(select 1 from pg_constraint where conrelid='catalog.categories'::regclass
    and conname='phase13_category_must_stay_inactive')
  and exists(select 1 from pg_constraint where conrelid='catalog.products'::regclass
    and conname='phase13_product_must_stay_inactive')
  then 'PASS' else 'FAIL: fixture activation guard constraints missing' end as fixture_activation_guards;

select case when has_function_privilege('service_role','payments.register_phase13_test_identity(uuid,uuid,text,timestamp with time zone,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','payments.register_phase13_test_identity(uuid,uuid,text,timestamp with time zone,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','payments.complete_phase13_test_payment(uuid,uuid)','EXECUTE')
  and not has_function_privilege('anon','payments.complete_phase13_test_payment(uuid,uuid)','EXECUTE')
  then 'PASS' else 'FAIL: identity registration or test payment grants are too broad' end as provisioning_payment_grants;

select case when pg_get_functiondef('public.phase13_test_checkout(uuid,uuid)'::regprocedure)
  ilike '%auth.uid()%' and pg_get_functiondef('public.phase13_test_checkout(uuid,uuid)'::regprocedure)
  ilike '%phase13_test_customers%' and pg_get_functiondef('public.phase13_test_checkout(uuid,uuid)'::regprocedure)
  ilike '%p.expires_at>now()%' and pg_get_functiondef('public.phase13_test_checkout(uuid,uuid)'::regprocedure)
  ilike '%orders.place_order_with_lines%' and pg_get_functiondef('public.phase13_test_checkout(uuid,uuid)'::regprocedure)
  ilike '%set_config(''app.phase13_test_run_id''%'
  then 'PASS' else 'FAIL: checkout identity, expiry, normal order writer, or run context missing' end as checkout_contract;

select case when pg_get_functiondef('public.quote_checkout(uuid,jsonb,text,uuid,text,uuid)'::regprocedure)
  ilike '%payments.phase13_test_checkout_context()%' and pg_get_functiondef('public.quote_checkout(uuid,jsonb,text,uuid,text,uuid)'::regprocedure)
  ilike '%core.brands%' and pg_get_functiondef('catalog.resolve_product_base_price(uuid,uuid)'::regprocedure)
  ilike '%payments.phase13_test_checkout_context()%' and pg_get_functiondef('catalog.resolve_product_base_price(uuid,uuid)'::regprocedure)
  ilike '%8d98c73d-43e9-484f-9dab-9a10d0513e70%'
  then 'PASS' else 'FAIL: test-only pricing path is not run/product scoped' end as pricing_scope;

select case when exists(select 1 from pg_trigger where tgname='tr_orders_snapshot_tax' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgname='tr_orders_guard_phase13_test_markers' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgname='tr_mark_phase13_test_invoice' and not tgisinternal)
  then 'PASS' else 'FAIL: test snapshot or immutable marker triggers missing' end as snapshot_guards;

select case when not exists(select 1 from payments.phase13_test_customers)
  and not exists(select 1 from payments.phase13_test_identities)
  and not exists(select 1 from orders.orders where test_run_id='b105bd82-18df-4e6a-9b10-306d5ed5e1bc')
  then 'PASS' else 'BLOCKED: existing test records are present; do not treat as this run’s fixtures' end as no_e2e_fixtures_created;

select case when has_function_privilege('authenticated','public.admin_invoice_history(timestamptz,timestamptz,uuid,text)','EXECUTE')
  and not has_function_privilege('anon','public.admin_invoice_history(timestamptz,timestamptz,uuid,text)','EXECUTE')
  and not has_function_privilege('authenticated','public.admin_invoice_history_all_internal(timestamptz,timestamptz,uuid,text)','EXECUTE')
  and pg_get_functiondef('public.admin_invoice_history(timestamptz,timestamptz,uuid,text)'::regprocedure)
    ilike '%test_only%<>%true%'
  then 'PASS' else 'FAIL: ordinary Admin invoice listing can expose test invoices' end as ordinary_invoice_list_isolation;

select case when has_function_privilege('authenticated','public.admin_phase13_test_invoice_history(uuid,timestamptz,timestamptz)','EXECUTE')
  and not has_function_privilege('anon','public.admin_phase13_test_invoice_history(uuid,timestamptz,timestamptz)','EXECUTE')
  and pg_get_functiondef('public.admin_phase13_test_invoice_history(uuid,timestamptz,timestamptz)'::regprocedure)
    ilike '%orders.read%' and pg_get_functiondef('public.admin_phase13_test_invoice_history(uuid,timestamptz,timestamptz)'::regprocedure)
    ilike '%identity.can_manage_branch%' and pg_get_functiondef('public.admin_phase13_test_invoice_history(uuid,timestamptz,timestamptz)'::regprocedure)
    ilike '%b105bd82-18df-4e6a-9b10-306d5ed5e1bc%'
  then 'PASS' else 'FAIL: run-scoped test invoice audit path is not correctly scoped' end as test_invoice_audit_scope;
