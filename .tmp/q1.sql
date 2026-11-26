select position('top_products as (' in prosrc) as tp_pos,
       position('product_id' in prosrc) as pid_pos
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'admin_dashboard_metrics';
