select version, name, created_by, idempotency_key,
 array_length(statements,1) as nstmts,
 statements[1] as first_stmt
from supabase_migrations.schema_migrations where version in ('267','268') order by version;