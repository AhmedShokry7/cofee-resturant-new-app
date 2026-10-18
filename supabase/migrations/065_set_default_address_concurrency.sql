-- 065_set_default_address_concurrency.sql
-- Serialize default-address selection per customer.
--
-- WHY: identity.set_default_address (060) clears the other rows and then flags
-- the target in two separate statements, with nothing keeping a second call for
-- the same customer out of the middle. Two concurrent calls (double tap, or a
-- retry that overlaps the first response) can both run the clear and then both
-- run the set; the loser trips the partial unique index
-- uq_addresses_one_default and fails with a raw unique_violation (23505) even
-- though the request was legitimate. Migration 058 already fixed exactly this
-- class of race for the cart with pg_advisory_xact_lock; this applies the same
-- idiom to the address book.
--
-- WHAT THIS DOES NOT CHANGE (authorization is deliberately untouched):
--   * the owner is still auth.uid() and never an argument from the client;
--   * a missing session still raises 42501;
--   * an address the caller does not own, or an archived one, still raises
--     P0002 before any row is touched;
--   * SECURITY DEFINER, set search_path = '', and the EXECUTE grants are
--     identical to 060 - no privilege is widened;
--   * the at-most-one-default invariant is still enforced by the existing
--     partial unique index; the lock only stops two correct calls from
--     colliding on it.

create or replace function identity.set_default_address(p_address_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_address_id is null then
    raise exception 'address required' using errcode = '22023';
  end if;

  -- One customer at a time: the clear-then-set pair below must never interleave
  -- with another call for the same account, or both calls would clear first and
  -- then both would set, and the second set would lose to uq_addresses_one_default.
  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':default-address', 0)
  );

  if not exists (
    select 1
      from identity.customer_addresses ca
     where ca.id = p_address_id
       and ca.user_id = v_uid
       and ca.archived_at is null
  ) then
    raise exception 'address not found' using errcode = 'P0002';
  end if;

  update identity.customer_addresses
     set is_default = false
   where user_id = v_uid
     and archived_at is null
     and id <> p_address_id;

  update identity.customer_addresses
     set is_default = true
   where id = p_address_id
     and user_id = v_uid;
end;
$fn$;

revoke all on function identity.set_default_address(uuid) from public, anon;
grant execute on function identity.set_default_address(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';