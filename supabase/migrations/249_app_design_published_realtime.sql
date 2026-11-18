-- A published design must reach a customer app that is already open.
--
-- 226 writes the document to `core.app_settings`; clients read it through the
-- public bridge view. Realtime does not publish view changes, so the running
-- app cannot hear a publish until the underlying table joins the publication.
-- The existing RLS policy (`settings_public_read`) already limits anon and
-- authenticated listeners to `is_public` rows, so no new grant is needed here.
--
-- Idempotent: safe to re-apply on an environment that already has the table.
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname    = 'supabase_realtime'
       and schemaname = 'core'
       and tablename  = 'app_settings'
  ) then
    alter publication supabase_realtime add table core.app_settings;
  end if;
end;
$$;
