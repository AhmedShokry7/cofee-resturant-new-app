-- 122_admin_catalog_pagination.sql
--
-- The catalogue page loads the products in pages.
--
-- The dashboard used to ask for the whole catalogue in one call and to build
-- a card for every row at once. admin_catalog_snapshot() now takes the size
-- of the page, the offset and a search term, and it hands back the number of
-- products that match, so the page knows when there is more to load.
--
-- The permissions, the branch scope and the shape of the rows stay the same:
-- only the number of rows the call returns changes.

drop function if exists public.admin_catalog_snapshot(uuid);

create or replace function public.admin_catalog_snapshot(
  p_branch_id uuid default null,
  p_limit integer default null,
  p_offset integer default null,
  p_search text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
  v_products jsonb;
  v_categories jsonb;
  v_total integer;
  v_search text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.product.write') then
    raise exception 'missing permission: catalog.product.write' using errcode = '42501';
  end if;

  if p_branch_id is null then
    select sr.branch_id into v_branch
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and sr.branch_id is not null
     order by sr.branch_id
     limit 1;

    if v_branch is null then
      select b.id into v_branch
        from core.branches b
       where b.is_active
       order by b.code
       limit 1;
    end if;
  else
    v_branch := p_branch_id;
    if not identity.can_manage_branch(v_branch) then
      raise exception 'branch not managed by the caller' using errcode = '42501';
    end if;
  end if;

  v_search := nullif(btrim(coalesce(p_search, '')), '');

  -- How many products match, before the page is cut out of them.
  select count(*)
    into v_total
    from catalog.products p
   where p.archived_at is null
     and (
       v_search is null
       or position(lower(v_search) in lower(p.name_ar)) > 0
       or position(lower(v_search) in lower(p.name_en)) > 0
       or position(lower(v_search) in lower(p.sku)) > 0
     );

  -- The page of products: the rows are cut out first, then they are
  -- gathered, so the limit and the offset belong to the rows and not to
  -- the aggregate.
  select coalesce(
           jsonb_agg(
             to_jsonb(page) order by page.sort_order, page.name_en
           ),
           '[]'::jsonb
         )
    into v_products
    from (
      select p.*,
             c.name_ar as category_name_ar,
             c.name_en as category_name_en,
             coalesce(s.quantity_on_hand, 0) as stock_quantity
        from catalog.products p
        join catalog.categories c on c.id = p.category_id
        left join lateral (
          select bs.quantity_on_hand
            from inventory.branch_stock bs
           where bs.product_id = p.id
             and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
             and (v_branch is null or bs.branch_id = v_branch)
           limit 1
        ) s on true
       where p.archived_at is null
         and (
           v_search is null
           or position(lower(v_search) in lower(p.name_ar)) > 0
           or position(lower(v_search) in lower(p.name_en)) > 0
           or position(lower(v_search) in lower(p.sku)) > 0
         )
       order by p.sort_order, p.name_en
       limit case when p_limit is null or p_limit <= 0 then null else p_limit end
       offset greatest(coalesce(p_offset, 0), 0)
    ) page;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order, c.name_en), '[]'::jsonb)
    into v_categories
    from catalog.categories c;

  return jsonb_build_object(
    'branch_id', v_branch,
    'products', v_products,
    'categories', v_categories,
    'total', v_total
  );
end;
$$;

comment on function public.admin_catalog_snapshot(uuid, integer, integer, text) is
  'A page of the products of the branch with their categories. Requires catalog.product.write.';

revoke all on function public.admin_catalog_snapshot(uuid, integer, integer, text) from public;
revoke execute on function public.admin_catalog_snapshot(uuid, integer, integer, text) from anon;
grant execute on function public.admin_catalog_snapshot(uuid, integer, integer, text) to authenticated;

notify pgrst, 'reload schema';
