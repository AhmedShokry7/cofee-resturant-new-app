-- Evaluate the JWT user ID once per statement instead of once per row.
-- The access rules stay the same; this reduces repeated auth function work
-- when customer bundle policies scan many rows.

drop policy customer_bundles_delete_own on public.customer_bundles;
create policy customer_bundles_delete_own on public.customer_bundles for delete to authenticated
using (((select auth.uid()) = user_id) or identity.is_staff());

drop policy customer_bundles_insert_own on public.customer_bundles;
create policy customer_bundles_insert_own on public.customer_bundles for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy customer_bundles_select_own on public.customer_bundles;
create policy customer_bundles_select_own on public.customer_bundles for select to authenticated
using (((select auth.uid()) = user_id) or identity.is_staff());

drop policy customer_bundles_update_own on public.customer_bundles;
create policy customer_bundles_update_own on public.customer_bundles for update to authenticated
using (((select auth.uid()) = user_id) or identity.is_staff())
with check (((select auth.uid()) = user_id) or identity.is_staff());

drop policy customer_bundle_items_delete_own on public.customer_bundle_items;
create policy customer_bundle_items_delete_own on public.customer_bundle_items for delete to authenticated
using (exists (
  select 1 from public.customer_bundles b
  where b.id = customer_bundle_items.bundle_id
    and (b.user_id = (select auth.uid()) or identity.is_staff())
));

drop policy customer_bundle_items_insert_own on public.customer_bundle_items;
create policy customer_bundle_items_insert_own on public.customer_bundle_items for insert to authenticated
with check (exists (
  select 1 from public.customer_bundles b
  where b.id = customer_bundle_items.bundle_id
    and b.user_id = (select auth.uid())
));

drop policy customer_bundle_items_select_own on public.customer_bundle_items;
create policy customer_bundle_items_select_own on public.customer_bundle_items for select to authenticated
using (exists (
  select 1 from public.customer_bundles b
  where b.id = customer_bundle_items.bundle_id
    and (b.user_id = (select auth.uid()) or identity.is_staff())
));

drop policy customer_bundle_items_update_own on public.customer_bundle_items;
create policy customer_bundle_items_update_own on public.customer_bundle_items for update to authenticated
using (exists (
  select 1 from public.customer_bundles b
  where b.id = customer_bundle_items.bundle_id
    and (b.user_id = (select auth.uid()) or identity.is_staff())
))
with check (exists (
  select 1 from public.customer_bundles b
  where b.id = customer_bundle_items.bundle_id
    and (b.user_id = (select auth.uid()) or identity.is_staff())
));
