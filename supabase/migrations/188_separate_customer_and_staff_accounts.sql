-- 188_separate_customer_and_staff_accounts.sql
--
-- Two populations, two tables, no overlap.
--
--   identity.profiles      — customers of the user app (app at the repo root)
--   identity.staff_members — staff of the admin app (app/admin_app)
--
-- WHAT WAS WRONG
--   003_identity_01_profiles.sql:92 puts a trigger on auth.users that creates
--   an identity.profiles row for EVERY new auth user, whatever the account is
--   for. So an account provisioned as staff by 080's identity.provision_staff
--   also has a customer row: it is listed on the admin Customers page, it can
--   sign in to the customer app and order food under its own staff id, and the
--   two apps cannot tell each population apart. Verified on the live project
--   (2026-10-27): 2 auth users, 1 staff row, 2 profile rows, 1 of them the
--   staff account itself.
--   identity.admins (legacy, marked so by 123_unify_admin_identity.sql:256)
--   holds 0 rows and no app reads it, so it is not part of this problem.
--
-- THE RULE, ENFORCED IN THE DATABASE
--   An auth uid may have a row in one of the two tables, never both.
--   * a staff row appearing removes the customer row written by the signup
--     trigger (identity.remove_customer_profile_on_staff). Removing, rather
--     than refusing, is what makes the existing path work: the admin creates
--     the login on the dashboard, the trigger adds the profile, provision_staff
--     adds the staff row — the profile has to go, and it goes.
--   * a customer row for a uid that is already staff is refused at the statement
--     that writes it (identity.reject_customer_profile_for_staff).
--   The two together mean the rule holds for hand-written SQL too, not only for
--   the RPCs.
--
-- WHY THE STAFF SIDE CAN FAIL, AND WHY THAT IS THE RIGHT ANSWER
--   orders.orders.user_id references identity.profiles with ON DELETE RESTRICT
--   (it is the only RESTRICT edge into the table; every other reference
--   cascades or nulls out). So an account that really ordered food cannot be
--   detached from the customer table without destroying order history. That
--   attempt raises a named error instead of silently deleting or silently
--   keeping the row: the operator has to use a separate login for staff. Live
--   data has no such account today (0 orders for the staff uid), so this does
--   not block anything that exists now.
--
-- DATA
--   One delete, exactly the overlap rows that carry no orders. On the live
--   project that is the single profile row of admin@test.local. It holds no
--   orders, no cart, no addresses, no loyalty account.
--
-- NOT CHANGED
--   No column, no policy, no grant to a wider audience, no RLS change, nothing
--   in auth.users, and identity.handle_new_user() keeps its behaviour for every
--   customer signup. Nothing here weakens a permission check: identity.is_staff
--   (018) reads staff_members and is untouched, so a customer account still has
--   no staff powers, and a staff account now also has no customer identity to
--   exercise them with.
--
-- ROLLBACK: drop the two triggers and the two functions, and re-create 003's
--   signup behaviour is unchanged. The purged profile row can be re-created
--   with the same id as auth.users, but it should not: that is the defect.

-- ---------------------------------------------------------------------------
-- 1. The customer table refuses to hold a staff uid.
--    Immediate, not deferred: the only path that has both rows in one
--    transaction is provisioning, and there the profile row is removed by
--    section 2's trigger rather than written, so nothing needs to be re-checked
--    at commit.
-- ---------------------------------------------------------------------------
create or replace function identity.reject_customer_profile_for_staff()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if exists (
    select 1
      from identity.profiles p
     where p.id = new.id
  ) and exists (
    select 1
      from identity.staff_members s
     where s.user_id = new.id
  ) then
    raise exception 'a staff account cannot also be a customer'
      using errcode = '23514';
  end if;
  return null;
end;
$fn$;

comment on function identity.reject_customer_profile_for_staff() is
  'Constraint trigger on identity.profiles: a uid that has an identity.staff_members '
  'row may not keep a customer profile row.';

drop trigger if exists trg_profile_not_staff on identity.profiles;
create trigger trg_profile_not_staff
  after insert or update on identity.profiles
  for each row execute function identity.reject_customer_profile_for_staff();

-- ---------------------------------------------------------------------------
-- 2. The staff table takes its members out of the customer table.
--    Not a constraint trigger: it has to run before the check above is
--    evaluated at commit, and it is the only place that knows the profile row
--    is a side effect of the signup trigger rather than a real customer.
-- ---------------------------------------------------------------------------
create or replace function identity.remove_customer_profile_on_staff()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not exists (
    select 1 from identity.profiles p where p.id = new.user_id
  ) then
    return new;
  end if;
  delete from identity.profiles where id = new.user_id;
  return new;
exception
  when foreign_key_violation then
    raise exception
      'this account has customer orders, so it cannot become a staff account'
      using errcode = '23514';
end;
$fn$;

comment on function identity.remove_customer_profile_on_staff() is
  'Trigger on identity.staff_members: removes the customer profile that the '
  'auth.users signup trigger wrote for the same uid.';

drop trigger if exists trg_staff_drop_customer_profile on identity.staff_members;
create trigger trg_staff_drop_customer_profile
  after insert on identity.staff_members
  for each row execute function identity.remove_customer_profile_on_staff();

-- ---------------------------------------------------------------------------
-- 3. Purge the overlap that already exists. Rows whose account has orders stay
--    (RESTRICT would refuse them anyway) and are reported instead of hidden.
-- ---------------------------------------------------------------------------
delete from identity.profiles p
 using identity.staff_members s
 where s.user_id = p.id
   and not exists (select 1 from orders.orders o where o.user_id = p.id);

do $$
declare
  v_left integer;
begin
  select count(*)
    into v_left
    from identity.profiles p
    join identity.staff_members s on s.user_id = p.id;
  if v_left > 0 then
    raise notice
      'identity.profiles still holds % staff uid(s) with order history; '
      'they must use a separate login', v_left;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. The contract, written where the next reader will see it.
-- ---------------------------------------------------------------------------
comment on table identity.profiles is
  'Customer accounts of the user app, one row per auth user. A uid that is in '
  'identity.staff_members must not appear here (trg_profile_not_staff).';

comment on table identity.staff_members is
  'Staff accounts of the admin app, one row per auth user. Joining this table '
  'removes the customer profile of the same uid (trg_staff_drop_customer_profile).';

-- The signup trigger needs no change: it still writes a profile for every new
-- auth user, and a staff account stops being one the moment it is provisioned.

grant execute on function identity.reject_customer_profile_for_staff()
  to authenticated, supabase_auth_admin;
grant execute on function identity.remove_customer_profile_on_staff()
  to authenticated, supabase_auth_admin;

notify pgrst, 'reload schema';
