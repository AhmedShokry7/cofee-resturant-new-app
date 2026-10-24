-- 101_cart_active_per_branch.sql
--
-- One active cart per customer per branch.
--
-- 011 created `uq_carts_one_active` on `(user_id) WHERE status = 'active'`,
-- while `orders.get_or_create_cart` looks a cart up by
-- `(user_id, branch_id, status = 'active')`.  A customer with an active cart
-- in branch A therefore hit a 23505 unique violation on the first write in
-- branch B, and `public.replace_cart` (which checkout also uses) failed the
-- same way at checkout.
--
-- The read side already supported several carts: `orders.carts` is keyed by
-- `(user_id, branch_id)` and the bridge view is filtered by RLS.  Only the
-- uniqueness promise was wrong.
--
-- Behaviour after this migration:
--   * switching branches keeps the previous branch's cart untouched;
--   * `get_or_create_cart`/`replace_customer_cart` keep their user-scoped
--     advisory lock, which is what serialises create-or-reuse;
--   * `remove_all_cart_items` and `get_cart_summary` are already cart-scoped
--     by `p_cart_id` and need no change;
--   * no automatic expiry is introduced; `expires_at` keeps its current
--     (unenforced) meaning.
--
-- Rollback is at the bottom and is only safe while no customer has two active
-- carts.

begin;

do $$
declare
  v_dups int;
begin
  select count(*) into v_dups
    from (
      select 1
        from orders.carts
       where status = 'active'
       group by user_id, branch_id
      having count(*) > 1
    ) d;

  if v_dups > 0 then
    raise exception
      'precondition failed: % (user,branch) pairs already have more than one active cart',
      v_dups
      using errcode = '23505';
  end if;

  if exists (
    select 1 from orders.carts where status = 'active' and branch_id is null
  ) then
    raise exception 'precondition failed: an active cart has no branch'
      using errcode = '23514';
  end if;

  if exists (
    select 1
      from orders.carts c
     where c.status = 'active'
       and not exists (select 1 from core.branches b where b.id = c.branch_id)
  ) then
    raise exception 'precondition failed: an active cart references a missing branch'
      using errcode = '23503';
  end if;
end $$;

drop index if exists orders.uq_carts_one_active;

create unique index uq_carts_one_active_per_branch
  on orders.carts (user_id, branch_id)
  where status = 'active';

-- Covered by the unique index above.
drop index if exists orders.ix_carts_user_branch_active;

comment on index orders.uq_carts_one_active_per_branch is
  'One active cart per customer per branch. Replaces the user-wide index from 011.';

commit;

-- Verification
-- ------------
-- 1) Exactly one index, on (user_id, branch_id), partial on active:
--      select indexdef from pg_indexes
--       where schemaname = 'orders'
--         and indexname = 'uq_carts_one_active_per_branch';
--    Expected: CREATE UNIQUE INDEX ... (user_id, branch_id) WHERE (status = 'active'::text)
-- 2) The old index is gone:
--      select 1 from pg_class where relname = 'uq_carts_one_active';
--    Expected: 0 rows.
-- 3) No customer has two active carts in the same branch:
--      select user_id, branch_id, count(*)
--        from orders.carts where status = 'active'
--       group by 1, 2 having count(*) > 1;
--    Expected: 0 rows.
--
-- Rollback
-- --------
-- Only while no customer holds two active carts.  Demote every extra cart to
-- `abandoned` first, keeping the most recently updated one.
--
-- begin;
-- update orders.carts
--    set status = 'abandoned', updated_at = now()
--  where id in (
--    select id from (
--      select id,
--             row_number() over (
--               partition by user_id order by updated_at desc, id
--             ) rn
--        from orders.carts
--       where status = 'active'
--    ) ranked
--    where rn > 1
--  );
-- drop index if exists orders.uq_carts_one_active_per_branch;
-- create unique index uq_carts_one_active
--   on orders.carts (user_id) where status = 'active';
-- create index ix_carts_user_branch_active
--   on orders.carts (user_id, branch_id) where status = 'active';
-- commit;
-- ---------------------------------------------------------------------------
