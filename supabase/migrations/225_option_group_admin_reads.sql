-- 225_option_group_admin_reads.sql
--
-- The two things the dashboard needs on top of 224, both measured live on
-- 2026-11-03 against pg_class.relacl and the policy list of 020.
--
-- 1. A deactivated group vanished from the dashboard for good.
--    `option_groups_public_read` and `option_values_public_read` (020) answer
--    SELECT with `using (is_active)`, and there was no staff-side read policy
--    beside them, so the moment the admin switched a size or an extra off, the
--    row stopped being readable and there was no screen left to switch it back
--    on. `catalog.products` faced the same wall and got `products_staff_read_all`
--    for it; the option tables are the two that never received the equivalent.
--
-- 2. The two views 224 created were wide open.
--    Supabase keeps default privileges in `public` that hand every new table or
--    view ALL to anon, authenticated and service_role, so
--    `public.option_group_categories` came back with anon INSERT, UPDATE and
--    DELETE, and `public.product_option_groups_effective` with the same. The
--    rows were still safe - RLS runs through the security-invoker view and the
--    base tables grant anon only SELECT - but 032 and 105 explicitly narrow
--    every other bridge view, and a future migration that widens an RLS policy
--    would turn this granted-by-accident surface into a real hole.

-- ---------------------------------------------------------------------------
-- 1. Staff read: the dashboard sees the whole catalogue, including what it
--    switched off. Permissive RLS ORs this with the public read, so a staff
--    account without catalog.product.write keeps exactly the customer answer.
-- ---------------------------------------------------------------------------
drop policy if exists option_groups_staff_read_all on catalog.option_groups;
create policy option_groups_staff_read_all on catalog.option_groups
  for select to authenticated
  using (identity.has_permission('catalog.product.write'));

drop policy if exists option_values_staff_read_all on catalog.option_values;
create policy option_values_staff_read_all on catalog.option_values
  for select to authenticated
  using (identity.has_permission('catalog.product.write'));

comment on policy option_groups_staff_read_all on catalog.option_groups is
  'The dashboard lists and re-activates inactive groups (225), like products_staff_read_all (020).';

comment on policy option_values_staff_read_all on catalog.option_values is
  'The dashboard lists and re-activates inactive values (225).';

-- ---------------------------------------------------------------------------
-- 2. Lock the 224 views to what the clients actually do: everyone reads the
--    mapping, staff writes it, and the resolved answer is read-only by shape -
--    it is built from a function, so no row of it can be written at all.
-- ---------------------------------------------------------------------------
revoke all on public.option_group_categories from anon;
revoke all on public.product_option_groups_effective from anon;
revoke all on public.option_group_categories from authenticated;
revoke all on public.product_option_groups_effective from authenticated;

grant select on public.option_group_categories to anon, authenticated;
grant select on public.product_option_groups_effective to anon, authenticated;

-- The base tables keep the grants 224 gave them; the view is a separate object
-- and needs its own (131 measured exactly this for branch_product_pricing).
grant insert, update, delete on public.option_group_categories to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
