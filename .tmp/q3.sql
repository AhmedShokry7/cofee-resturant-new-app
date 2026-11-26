select left(prosrc, 700) as head, right(prosrc, 300) as tail,
       position('v_month_baseline' in prosrc) as mb,
       position('month_baseline' in prosrc) as mb2
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'admin_dashboard_metrics';
