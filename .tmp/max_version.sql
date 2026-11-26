select max(version) as max_version,
 (select jsonb_agg(version order by version) from supabase_migrations.schema_migrations where version in ('267','268') or version like '2026%') as timestamp_versions
from supabase_migrations.schema_migrations;