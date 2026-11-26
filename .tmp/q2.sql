select substring(prosrc from 6330 for 1200) as top_products
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'admin_dashboard_metrics';
