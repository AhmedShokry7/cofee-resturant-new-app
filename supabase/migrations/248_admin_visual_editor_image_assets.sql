-- Read the complete customer-facing image library for staff members who can
-- manage each owning feature. The visual editor never writes catalogue rows
-- itself; replacement/removal still use their feature-specific repositories.

create or replace function public.admin_image_assets_catalog()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(asset order by asset->>'asset_kind', asset->>'name_en')
      from (
        select jsonb_build_object(
          'asset_kind', 'product', 'id', p.id,
          'name_ar', p.name_ar, 'name_en', p.name_en, 'image_url', p.image_url
        ) as asset
          from catalog.products p
         where identity.has_permission('catalog.product.write')
        union all
        select jsonb_build_object(
          'asset_kind', 'category', 'id', c.id,
          'name_ar', c.name_ar, 'name_en', c.name_en, 'image_url', c.image_url
        ) as asset
          from catalog.categories c
         where identity.has_permission('catalog.category.write')
      ) assets
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_catalog() from public, anon;
grant execute on function public.admin_image_assets_catalog() to authenticated;

create or replace function public.admin_image_assets_product_images()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('catalog.product.write') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', pi.id, 'product_id', pi.product_id, 'image_url', pi.image_url,
      'alt_ar', pi.alt_ar, 'alt_en', pi.alt_en, 'sort_order', pi.sort_order,
      'is_primary', pi.is_primary
    ) order by pi.product_id, pi.sort_order)
      from catalog.product_images pi
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_product_images() from public, anon;
grant execute on function public.admin_image_assets_product_images() to authenticated;

create or replace function public.admin_image_assets_banners()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'title_ar', b.title_ar, 'title_en', b.title_en,
      'image_url', b.image_url
    ) order by b.sort_order)
      from marketing.banners b
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_banners() from public, anon;
grant execute on function public.admin_image_assets_banners() to authenticated;

create or replace function public.admin_image_assets_bundles()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('catalog.product.write') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name_ar', b.name_ar, 'name_en', b.name_en,
      'image_url', b.image_url
    ) order by b.sort_order)
      from catalog.bundles b
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_bundles() from public, anon;
grant execute on function public.admin_image_assets_bundles() to authenticated;
