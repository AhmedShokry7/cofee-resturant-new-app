-- 028_ops_migration_log.sql
--
-- Decision D10 says public stays empty. The migration bookkeeping table
-- created by the applier was sitting in public, which breaks that.
-- Move it into a dedicated _ops schema so public really is empty.

create schema if not exists _ops;

do $$
begin
  if to_regclass('public._migration_log') is not null
     and to_regclass('_ops.migration_log') is null then
    execute 'alter table public._migration_log set schema _ops';
  end if;
end $$;

revoke all on schema _ops from anon, authenticated;
revoke all on all tables in schema _ops from anon, authenticated;

comment on schema _ops is
  'Operational bookkeeping. Never exposed to clients. Not part of DATABASE_SPEC.md section 4.';