-- 120_admin_create_category_descriptions.sql
-- Extends admin_create_category so the dashboard can store the optional
-- Arabic and English descriptions of a category it creates.

create or replace function public.admin_create_category(
  p_name_ar text default null,
  p_name_en text default null,
  p_description_ar text default null,
  p_description_en text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_slug text;
  v_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.category.write') then
    raise exception 'missing permission: catalog.category.write' using errcode = '42501';
  end if;

  if btrim(coalesce(p_name_ar, '')) = '' then
    raise exception 'the category needs an Arabic name' using errcode = '22023';
  end if;

  if btrim(coalesce(p_name_en, '')) = '' then
    raise exception 'the category needs an English name' using errcode = '22023';
  end if;

  v_slug := coalesce(
    nullif(core.slugify(p_name_en), ''),
    nullif(core.slugify(p_name_ar), '')
  );
  if v_slug is null then
    v_slug := 'category-' || substr(md5(random()::text), 1, 8);
  end if;

  v_slug := v_slug || case
    when exists (select 1 from catalog.categories c where c.slug = v_slug)
      then '-' || substr(md5(random()::text), 1, 6)
    else ''
  end;

  insert into catalog.categories (name_ar, name_en, slug, is_active, description_ar, description_en)
  values (
    btrim(p_name_ar),
    btrim(p_name_en),
    v_slug,
    true,
    nullif(btrim(coalesce(p_description_ar, '')), ''),
    nullif(btrim(coalesce(p_description_en, '')), '')
  )
  returning id into v_id;

  return to_jsonb(c)
    from catalog.categories c
   where c.id = v_id;
end;
$$;

comment on function public.admin_create_category(text, text, text, text) is
  'Creates a category for the admin dashboard. Requires catalog.category.write.';

revoke all on function public.admin_create_category(text, text, text, text) from public;
revoke execute on function public.admin_create_category(text, text, text, text) from anon;
grant execute on function public.admin_create_category(text, text, text, text) to authenticated;

notify pgrst, 'reload schema';
