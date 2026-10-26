-- 184_admin_catalog_delete.sql
--
-- Deleting a category or a bundle from the dashboard.
--
-- Neither worked before this file:
--
--   * The category page called public.admin_delete_category(), and no
--     migration ever defined it, so the call failed before reaching the
--     database.
--   * The bundle page deleted through public.bundles, which is the read-only
--     routing view over catalog.bundles. A bundle that a live cart or a
--     loyalty reward still pointed at was refused by the foreign key, and the
--     admin saw a database error instead of a reason.
--
-- Both functions are SECURITY DEFINER, like every other admin write, because
-- the API only exposes public and anon has no write grants at all.
--
-- A category that still holds active products is refused with
-- 'category_in_use': the products would otherwise disappear from every
-- listing with no category to explain them. Products that were already
-- archived are detached, so their history survives the category.
--
-- A bundle targeted by a loyalty reward is refused with 'bundle_in_use': the
-- reward would break the moment the bundle is gone. Cart lines are not
-- orders, so they are removed with the bundle.

create or replace function public.admin_delete_category(p_category_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active   integer;
  v_archived integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.category.write') then
    raise exception 'missing permission: catalog.category.write' using errcode = '42501';
  end if;

  if not exists (select 1 from catalog.categories c where c.id = p_category_id) then
    raise exception 'category_not_found' using errcode = 'P0002';
  end if;

  select count(*) filter (where p.archived_at is null),
         count(*) filter (where p.archived_at is not null)
    into v_active, v_archived
    from catalog.products p
   where p.category_id = p_category_id;

  if v_active > 0 then
    raise exception 'category_in_use'
      using errcode = 'P0001',
            detail = format('%s products still use this category', v_active);
  end if;

  -- Archived products keep their row, but they no longer need a category
  -- that is being removed.
  if v_archived > 0 then
    update catalog.products p
       set category_id = null,
           updated_at = now()
     where p.category_id = p_category_id;
  end if;

  delete from catalog.categories c where c.id = p_category_id;
  return found;
end;
$$;

comment on function public.admin_delete_category(uuid) is
  'Deletes an empty category and detaches its archived products. Refuses while products still use it.';

create or replace function public.admin_delete_bundle(p_bundle_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.product.write') then
    raise exception 'missing permission: catalog.product.write' using errcode = '42501';
  end if;

  if not exists (select 1 from catalog.bundles b where b.id = p_bundle_id) then
    raise exception 'bundle_not_found' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from loyalty.loyalty_rewards r where r.bundle_id = p_bundle_id
  ) then
    raise exception 'bundle_in_use'
      using errcode = 'P0001',
            detail = 'a loyalty reward still targets this bundle';
  end if;

  -- A cart is not an order; a retired bundle must not keep a customer's cart
  -- from being emptied.
  delete from orders.cart_items ci where ci.bundle_id = p_bundle_id;

  delete from catalog.bundles b where b.id = p_bundle_id;
  return found;
end;
$$;

comment on function public.admin_delete_bundle(uuid) is
  'Deletes a bundle and its components. Refuses while a loyalty reward targets it.';

revoke all on function public.admin_delete_category(uuid) from public, anon;
grant execute on function public.admin_delete_category(uuid) to authenticated;

revoke all on function public.admin_delete_bundle(uuid) from public, anon;
grant execute on function public.admin_delete_bundle(uuid) to authenticated;

notify pgrst, 'reload schema';
