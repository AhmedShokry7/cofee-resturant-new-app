select version, name from supabase_migrations.schema_migrations order by version desc limit 5;
select p.oid::regprocedure, length(pg_get_functiondef(p.oid)) as bytes, md5(pg_get_functiondef(p.oid)) as hash
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('admin_dashboard_metrics','admin_catalog_snapshot');
