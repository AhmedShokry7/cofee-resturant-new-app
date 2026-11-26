select version, name from supabase_migrations.schema_migrations
where version in ('270','271','20261124203348','20261124204111','20261124204223','20261124205316','20261124211129','20261125063912','20261125064626')
order by version;
