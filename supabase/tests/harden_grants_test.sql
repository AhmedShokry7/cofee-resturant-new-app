-- harden_grants_test.sql
-- Static privilege assertions for migration 081 (and 079/080 where relevant).
-- Run as a privileged role; has_function_privilege reports another role's rights.

\set ON_ERROR_STOP on

-- Sensitive internal helpers must not be callable by anon.
select
  case when has_function_privilege('anon', 'loyalty.apply_points(uuid,integer,text,text,uuid,text)', 'EXECUTE')
       then 'FAIL: anon can execute loyalty.apply_points' else 'PASS' end as t1;
select
  case when has_function_privilege('anon', 'identity.audit(text,text,uuid,jsonb,jsonb,uuid)', 'EXECUTE')
       then 'FAIL: anon can execute identity.audit' else 'PASS' end as t2;
select
  case when has_function_privilege('anon', 'orders.update_order_status(uuid,text,text)', 'EXECUTE')
       then 'FAIL: anon can execute orders.update_order_status' else 'PASS' end as t3;

-- Sensitive internal helpers must not be callable by authenticated clients.
select
  case when has_function_privilege('authenticated', 'loyalty.apply_points(uuid,integer,text,text,uuid,text)', 'EXECUTE')
       then 'FAIL: authenticated can execute loyalty.apply_points' else 'PASS' end as t4;
select
  case when has_function_privilege('authenticated', 'identity.audit(text,text,uuid,jsonb,jsonb,uuid)', 'EXECUTE')
       then 'FAIL: authenticated can execute identity.audit' else 'PASS' end as t5;

-- Admin-facing RPC remains callable by signed-in users.
select
  case when has_function_privilege('authenticated', 'identity.provision_staff(uuid,text,text,text,uuid)', 'EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute identity.provision_staff' end as t6;

-- Anonymous users must not have DML on public bridge tables/views.
select
  case when has_table_privilege('anon', 'public.products', 'INSERT')
       then 'FAIL: anon can insert public.products' else 'PASS' end as t7;
select
  case when has_table_privilege('anon', 'public.products', 'UPDATE')
       then 'FAIL: anon can update public.products' else 'PASS' end as t8;
select
  case when has_table_privilege('anon', 'public.products', 'DELETE')
       then 'FAIL: anon can delete public.products' else 'PASS' end as t9;
