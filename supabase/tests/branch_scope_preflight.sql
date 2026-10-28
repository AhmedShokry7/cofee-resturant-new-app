-- Pre-flight checks that must run BEFORE applying
-- supabase/migrations/186_admin_orders_payments_branch_scope.sql
--
-- Run against the real (linked) database, read-only, in the Supabase SQL Editor
-- or with:  supabase db query --linked -f supabase/tests/branch_scope_preflight.sql
--
-- Nothing here writes. Both statements only inspect the deployed catalog and
-- the role assignments, and their output decides whether migration 186 is safe
-- to apply as written.

-- 1. Are the deployed admin_orders()/admin_payments() the definitions 186
--    copies its body from (176 and 178), and do they already filter by branch?
--    * already_scoped  = true  -> 186 would be a no-op for that function; the
--      leak is already closed there and a newer definition exists. STOP.
--    * is_176_or_later = false -> the deployed function predates 176/178, so
--      186's body would roll back fields the deployed version has (for example
--      pos_customer_id). STOP and reconcile the chain first.
--    * def_hash        -> compare the two hashes with the same md5 computed on
--      the local 176/178 bodies to prove the file matches what is deployed.
select p.proname,
       md5(pg_get_functiondef(p.oid)) as def_hash,
       position('can_manage_branch' in pg_get_functiondef(p.oid)) > 0 as already_scoped,
       position('pos_customer_id' in pg_get_functiondef(p.oid)) > 0 as is_176_or_later
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('admin_orders', 'admin_payments')
 order by p.proname;

-- 2. Does every owner/manager row actually carry a NULL branch?
--    can_manage_branch() has no owner short-circuit, so a global owner or
--    manager whose staff_roles.branch_id is NOT NULL loses every order and
--    payment the moment 186 is applied. Any row here with branch_id NOT NULL
--    for a role that is meant to be global must be fixed (or the role rows
--    reviewed) before applying.
select r.code,
       sr.branch_id,
       count(*) as staff_count
  from identity.staff_roles sr
  join identity.staff_members sm on sm.id = sr.staff_id
  join identity.roles r on r.id = sr.role_id
 where r.code in ('owner', 'manager')
 group by r.code, sr.branch_id
 order by r.code, sr.branch_id nulls first;

-- 3. Which migrations does the database believe it has already applied?
--    The ledger versions are 14-digit timestamps (e.g. 20261025121013), NOT the
--    161..186 sequence used by the local file names, so this lists the tail of
--    what is deployed and any non-timestamp version in between.
--    Lexicographic order is correct for equal-length timestamps; the length
--    term keeps the shorter local-style names (004b, 176) grouped readably.
--    (supabase_migrations.schema_migrations has no timestamp column: version,
--     name, statements, created_by, idempotency_key, rollback.)
select version, name, created_by
  from supabase_migrations.schema_migrations
 order by length(version) desc, version desc
 limit 30;

-- 3b. How many rows total, and does anything already claim the 186 slot?
select count(*) as applied_total,
       count(*) filter (where version like '186%' or name like '186%') as owns_186
  from supabase_migrations.schema_migrations;
