-- 216-PROPOSED: 188's two trigger functions are still PUBLIC-executable.
--
-- NOTHING HERE HAS BEEN EXECUTED AS A CHANGE. This file is a proposal kept in
-- supabase/proposals/. It is not applied to the live project and it is not part
-- of the migration chain until the owner copies it out with its own number and
-- repairs it into the ledger (`supabase migration repair`, never `db push`).
-- Applying it is an owner action in the SQL Editor. Its behaviour test
-- (supabase/tests/trigger_function_grants_test.sql) WAS run against the live
-- project on 2026-10-31 inside one transaction that ran the four REVOKEs below
-- and then rolled them back. The report row read
--   verdict=reached the end: no assertion failed
--   anon_before_216=both executable by anon
--   grants_after_216=anon=false service_role=false authenticated=true auth_admin=true owner=true
--   identity_anon_executable_now=0
--   drop_trigger=fired, reject_trigger_as_authenticated=23514, customer_profile_update=ok,
--   order_history_guard=23514
-- and a fresh session afterwards found both ACLs back to `=X/postgres,
-- postgres=X/postgres, authenticated=X/postgres, supabase_auth_admin=X/postgres`,
-- anon_can_execute true again, the two COMMENTs back to 188's text, and no
-- fixture row anywhere.
--
-- ONE TOPIC, ONE DECISION
--   Four REVOKE statements and two COMMENT statements, on the two functions 188
--   created. No table, no column, no constraint, no index, no policy, no new
--   grant, no function body, no trigger. It deletes nothing and adds nothing to
--   the schema; it only narrows who the catalogue says may call two functions
--   that exist to be called by a trigger.
--
-- WHY 216 IS A PROPOSAL NUMBER AND NOT A CLAIM
--   The chain runs to 212 and 213, 214 and 215 are already taken by the other
--   proposals in this folder, so 216 is the next free number locally — the only
--   thing assertable without touching the database. Verify live state first:
--     select p.proname, p.prosecdef,
--            coalesce(array_to_string(p.proacl, ','), 'NULL(default=public)') as acl,
--            has_function_privilege('anon', p.oid, 'execute') as anon_can_execute
--       from pg_proc p
--      where p.oid in ('identity.reject_customer_profile_for_staff()'::regprocedure,
--                      'identity.remove_customer_profile_on_staff()'::regprocedure);
--   If anon_can_execute is already false for both, this file is done and should
--   be retired rather than applied.
--
-- THE DEFECT, MEASURED ON 2026-10-31 AGAINST webzzasosevzymftgszn
--   188:173-176 ends with two GRANTs and no REVOKE:
--     grant execute on function identity.reject_customer_profile_for_staff()
--       to authenticated, supabase_auth_admin;
--     grant execute on function identity.remove_customer_profile_on_staff()
--       to authenticated, supabase_auth_admin;
--   A function created without a REVOKE starts with the default grant to PUBLIC,
--   so the live ACLs read
--     {=X/postgres, postgres=X/postgres, authenticated=X/postgres, supabase_auth_admin=X/postgres}
--   for both, and `has_function_privilege('anon', …, 'execute')` returns true for
--   both. The `=X/postgres` entry IS the PUBLIC grant; that is the line 081 would
--   have removed.
--
--   081_harden_function_and_view_grants.sql:14-15 is the blanket that this hole
--   sits inside:
--     revoke execute on all functions in schema identity from public;
--     revoke execute on all functions in schema identity from anon;
--   It runs at 081. 188 runs at 188 and creates two brand-new functions in the
--   same schema, which arrive with PUBLIC attached again. This is not a new kind
--   of bug: 105_grants_hardening.sql:5-15 documents exactly this sequence for
--   marketing.coupon_eligible_lines and marketing.allocate_coupon_discount —
--   "migration 081 … runs BEFORE 093, so it never saw them. The final state was
--   therefore EXECUTE TO PUBLIC" — and closes it the same way, one REVOKE per
--   function. 216 is that repair, for the pair 188 added.
--
--   Scope of the hole, measured rather than assumed. Across the application
--   schemas, 29 functions are currently executable by anon — almost all of them
--   the legitimate public-read RPCs (catalog.get_featured, core.active_branches
--   and their siblings), which are anon-executable on purpose. Of those 29,
--   exactly TWO are trigger functions, and they are precisely this pair:
--     identity.reject_customer_profile_for_staff, identity.remove_customer_profile_on_staff
--   So 216 is not a sweep and not a policy change; it closes the two entries of
--   a class that has no business being callable at all.
--
-- WHAT THIS IS NOT — STATED SO THE DECISION IS MADE ON THE RIGHT FACTS
--   It is a contract and catalogue fix, not a closed exploit. Three independent
--   layers already refuse an outside caller, and all three were measured:
--     * a direct call by the client role, measured in the rehearsal while the
--       PUBLIC entry was still there, fails with
--       `0A000: trigger functions can only be called as triggers`, and the row
--       count of identity.profiles was unchanged before and after. With 216
--       applied the same call answers `42501` instead — PostgreSQL reads the
--       function ACL before it complains about trigger context. Both arms refuse;
--       what changes is who the catalogue says is allowed to try.
--     * PostgREST does not expose the `identity` schema at all. With the anon
--       key, `POST /rest/v1/rpc/reject_customer_profile_for_staff` answers
--       `404 Could not find the function public.reject_customer_profile_for_staff
--       without parameters in the schema cache` — the same 404 shape as a name
--       that does not exist, while a function that IS exposed answers on its
--       own terms (`/rest/v1/rpc/admin_orders` returns `401 permission denied
--       for function admin_orders` for the same anon key);
--     * neither trigger has anything to do for anon or service_role, because
--       neither role can write either table it fires on.
--   What is left is the artifact itself: `pg_proc.proacl` advertises EXECUTE to
--   PUBLIC on two SECURITY DEFINER functions that modify identity.profiles, in a
--   schema whose hardening migration said no function in it should read that way.
--   A future reviewer running `select … from pg_proc where proacl && …` gets a
--   false positive, and a future function — an RPC, a view, a scheduled job —
--   that calls this by name inherits a wider audience than its author intended.
--
-- WHO IS AFFECTED — AND WHY THE ANSWER IS "NOBODY", MEASURED
--   The roles that fire these two triggers are the roles that can write the two
--   tables. Measured on the live database:
--     * anon: no INSERT or UPDATE on identity.profiles, no INSERT on
--       identity.staff_members. It cannot reach either trigger, so losing
--       EXECUTE removes a privilege with no path behind it.
--     * service_role: the same — no INSERT on either table (it has BYPASSRLS, but
--       BYPASSRLS does not create a missing table privilege). It relies on the
--       PUBLIC entry today and loses it, and fires nothing.
--     * authenticated: holds INSERT and UPDATE on identity.profiles, so it DOES
--       fire trg_profile_not_staff on the customer app's own profile writes
--       (profiles_insert_own, profiles_update_own). 216 leaves its grant exactly
--       where 188 put it.
--     * postgres: owns both functions, so it needs no grant. Every provisioning
--       path — 080's identity.provision_staff, 210's invitation accept, the 003
--       signup trigger — runs inside a SECURITY DEFINER function owned by it, so
--       trg_staff_drop_customer_profile fires as the owner, never as PUBLIC.
--   Whether PostgreSQL re-checks the invoker's EXECUTE when a trigger fires
--   (the documented requirement is for the role CREATING the trigger) is
--   therefore a question this file never has to answer: the only non-owner role
--   with a reachable write is authenticated, and its grant is untouched. That is
--   also why 216 does not additionally revoke from authenticated, even though
--   nothing in 188 explains why authenticated needs EXECUTE on a function it can
--   only ever reach through a trigger. Narrowing that further is a separate
--   decision with a real blast radius, and it belongs in its own file.
--
-- WHAT BREAKS IF THIS IS WRONG
--   A trigger firing needs its own function to be executable by someone, and the
--   someone is the owner. The worst outcome of being wrong is that a staff
--   provisioning or a profile write fails with `42501 permission denied for
--   function` — loudly, on the first attempt, in the rehearsal, not in
--   production. supabase/tests/trigger_function_grants_test.sql drives both
--   triggers through both write paths with the REVOKEs applied in the same
--   transaction, so this file cannot be merged on the strength of this section
--   alone.
--   Rollback: re-running 188:173-176 restores the grants, or
--     grant execute on function identity.reject_customer_profile_for_staff() to public;
--     grant execute on function identity.remove_customer_profile_on_staff() to public;
--
-- COMPANIONS
--   supabase/tests/trigger_function_grants_test.sql — the behaviour test, run
--   against the live project inside one rolled-back transaction on 2026-10-31.
--   supabase/tests/harden_grants_test.sql — 081's own static privilege test. It
--   asserts anon cannot execute identity.audit; it was written long before 188
--   and so cannot see this pair. 216's test asserts the whole-schema invariant
--   instead of two names, so it catches the next 188-shaped regression too.
--   No Dart change: nothing in either app references these function names —
--   searched across the repository, the only hits are 188 itself.

-- -----------------------------------------------------------------------------
-- 1. The repair: the two entries 081 would have cleared, cleared.
--    `from public` removes the default grant that 188's CREATE left attached;
--    `from anon` is the belt-and-braces line 081 and 105 both write, so the
--    client role is named rather than reached through PUBLIC.
--    188:173-176's explicit grants to authenticated and supabase_auth_admin are
--    left exactly as they are.
-- -----------------------------------------------------------------------------
revoke execute on function identity.reject_customer_profile_for_staff() from public;
revoke execute on function identity.reject_customer_profile_for_staff() from anon;

revoke execute on function identity.remove_customer_profile_on_staff() from public;
revoke execute on function identity.remove_customer_profile_on_staff() from anon;

-- -----------------------------------------------------------------------------
-- 2. The invariant, written on the objects themselves so the next reader of
--    \df or the dashboard sees that these are not client-callable.
-- -----------------------------------------------------------------------------
comment on function identity.reject_customer_profile_for_staff() is
  'AFTER trigger on identity.profiles (188 section 1): a uid that has an '
  'identity.staff_members row may not keep a customer profile row. Trigger-only — '
  'not client-callable (a direct call raises 0A000), EXECUTE revoked from PUBLIC '
  'and anon by 216, and held only by the grants 188 wrote.';

comment on function identity.remove_customer_profile_on_staff() is
  'AFTER trigger on identity.staff_members (188 section 2): removes the customer '
  'profile the signup trigger wrote for the same uid, and refuses the insert when '
  'that customer has order history. Trigger-only — not client-callable (a direct '
  'call raises 0A000), EXECUTE revoked from PUBLIC and anon by 216, and held only '
  'by the grants 188 wrote.';

notify pgrst, 'reload schema';

-- -----------------------------------------------------------------------------
-- READ-ONLY PRE-FLIGHT, run this in the SQL Editor BEFORE pasting anything above
-- -----------------------------------------------------------------------------
-- 1) The ACL of both functions, and whether anon is inside it.
-- select p.proname, coalesce(array_to_string(p.proacl, ','), 'NULL(default=public)') as acl,
--        has_function_privilege('anon', p.oid, 'execute') as anon_can_execute,
--        has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_execute
--   from pg_proc p
--  where p.oid in ('identity.reject_customer_profile_for_staff()'::regprocedure,
--                  'identity.remove_customer_profile_on_staff()'::regprocedure);
--
-- 2) Is any function of the identity schema still anon-executable? This is the
--    line 081:14-15 made true and 188 undid. Zero rows means the invariant holds
--    and this proposal is already paid for.
-- select p.proname
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'identity'
--    and has_function_privilege('anon', p.oid, 'execute');
--
-- 3) The claim that no role reaching these triggers depends on PUBLIC: every
--    role with a write on either table, and whether it is named in the ACL.
-- select grantee, table_name, privilege_type
--   from information_schema.role_table_grants
--  where table_schema = 'identity'
--    and table_name in ('profiles', 'staff_members')
--    and privilege_type in ('INSERT', 'UPDATE')
--  order by table_name, grantee, privilege_type;
--
-- 4) Rehearsal in a transaction that can never commit, the same discipline as
--    supabase/tests/*.sql. The behaviour test is the rehearsal; running it and
--    reading its report row is enough.
