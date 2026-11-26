select version, name from supabase_migrations.schema_migrations
where version like '20261124174706%' or name like '%push_permission%' or version='270'
order by version;
