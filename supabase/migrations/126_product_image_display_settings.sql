-- 126_product_image_display_settings.sql
--
-- Every picture of a product gets its own display settings.
--
-- The cropping of a picture is baked into the file itself (the editor writes
-- a new file), so what the database still needs is how the picture is shown:
-- the way it fills its space (`fit`) and where it sits in it (`alignment`).
--
-- The settings belong to the row of the picture, so two pictures of the same
-- product can be shown differently, and a change of one of them never touches
-- the others.
--
-- The pictures that exist today have no settings: they keep the safe default
-- (`cover`, centred), so nothing changes for them.
--
-- Idempotent: safe to re-run. NOT APPLIED YET: applying it needs the
-- approval of the owner, because it changes the shape of the catalogue.

-- ---------------------------------------------------------------------------
-- A. The settings of a picture.
-- ---------------------------------------------------------------------------
alter table catalog.product_images
  add column if not exists fit text not null default 'cover',
  add column if not exists alignment text not null default 'center';

comment on column catalog.product_images.fit is
  'How the picture fills its space: cover, contain, fill, fitWidth, fitHeight, scaleDown or none.';

comment on column catalog.product_images.alignment is
  'Where the picture sits in its space: center, topLeft, topCenter, topRight, centerLeft, centerRight, bottomLeft, bottomCenter or bottomRight.';

-- Only the values the dashboard knows are accepted.
alter table catalog.product_images
  drop constraint if exists product_images_fit_check;
alter table catalog.product_images
  add constraint product_images_fit_check
  check (fit in ('cover', 'contain', 'fill', 'fitWidth', 'fitHeight', 'scaleDown', 'none'));

alter table catalog.product_images
  drop constraint if exists product_images_alignment_check;
alter table catalog.product_images
  add constraint product_images_alignment_check
  check (alignment in (
    'center',
    'topLeft', 'topCenter', 'topRight',
    'centerLeft', 'centerRight',
    'bottomLeft', 'bottomCenter', 'bottomRight'
  ));

-- ---------------------------------------------------------------------------
-- B. The public view of the pictures carries the settings too.
--
-- PostgREST exposes the catalogue through the views of the public schema,
-- and a view keeps the columns it was created with. Without this the
-- dashboard would ask for a column the view does not have, and the write
-- would be refused with PGRST204.
-- ---------------------------------------------------------------------------
create or replace view public.product_images
  with (security_invoker = true)
as
  select id,
         product_id,
         image_url,
         alt_ar,
         alt_en,
         sort_order,
         is_primary,
         created_at,
         fit,
         alignment
    from catalog.product_images;

comment on view public.product_images is
  'The pictures of the products with their display settings.';

-- ---------------------------------------------------------------------------
-- C. The snapshot of the catalogue hands the settings of the primary picture
--    to the dashboard, so the card of a product shows it the same way the
--    gallery does.
-- ---------------------------------------------------------------------------
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
             coalesce(s.quantity_on_hand, 0) as stock_quantity,
             coalesce(pi.fit, 'cover') as image_fit,
             coalesce(pi.alignment, 'center') as image_alignment
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
        left join lateral (
          select img.fit, img.alignment
            from catalog.product_images img
           where img.product_id = p.id
             and img.is_primary
           order by img.sort_order
           limit 1
        ) pi on true
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
