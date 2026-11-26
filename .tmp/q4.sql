select position('test_only' in prosrc) as t1,
       position('invoice_adjustments' in prosrc) as ia,
       prosrc like '%create or replace%' as selfref
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='admin_dashboard_metrics';
