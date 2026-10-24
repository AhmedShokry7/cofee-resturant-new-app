-- 119_admin_catalog_category_write.sql
--
-- Two changes to the admin catalogue write path.
--
-- 1. The names of a product are stored exactly as the admin typed them.
--    Before, an empty English name was filled with the Arabic one. An empty
--    name now stays empty and the save is refused with a clear message, so
--    nothing is ever written in the place of what the admin left out.
--
-- 2. The dashboard can create a category of its own, next to picking one of
--    the categories that already exist.

-- ---------------------------------------------------------------------------
-- A. The product names are stored as they are typed.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_product(
  p_product_id       uuid default null,
  p_name_ar          text default null,
  p_name_en          text default null,
  p_sku              text default null,
  p_slug             text default null,
  p_base_price       numeric default 0,
  p_compare_at_price numeric default null,
  p_category_id      uuid default null,
  p_image_url        text default null,
  p_is_featured      boolean default false,
  p_is_active        boolean default true,
  p_prep_minutes     integer default null,
  p_stock_quantity   integer default null,
  p_branch_id        uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product_id uuid;
  v_slug text;
  v_sku text;
  v_branch uuid;
  v_previous integer;
  v_saved jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.product.write') then
    raise exception 'missing permission: catalog.product.write' using errcode = '42501';
  end if;

  if btrim(coalesce(p_name_ar, '')) = '' then
    raise exception 'the product needs an Arabic name' using errcode = '22023';
  end if;

  if btrim(coalesce(p_name_en, '')) = '' then
    raise exception 'the product needs an English name' using errcode = '22023';
  end if;

  if p_category_id is null
     or not exists (select 1 from catalog.categories c where c.id = p_category_id) then
    raise exception 'unknown category' using errcode = '22023';
  end if;

  if p_compare_at_price is not null and p_compare_at_price <= p_base_price then
    raise exception 'the compare price must be above the price' using errcode = '22023';
  end if;

  if p_product_id is null then
    v_slug := coalesce(
      nullif(btrim(p_slug), ''),
      nullif(core.slugify(p_name_en), ''),
      nullif(core.slugify(p_name_ar), '')
    );
    if v_slug is null then
      v_slug := 'product-' || substr(md5(random()::text), 1, 8);
    end if;

    v_sku := coalesce(
      nullif(btrim(p_sku), ''),
      'SKU-' || upper(substr(md5(v_slug || random()::text), 1, 8))
    );

    insert into catalog.products (
      category_id, sku, slug, name_ar, name_en,
      base_price, compare_at_price, image_url,
      is_active, is_featured, prep_minutes
    )
    values (
      p_category_id, v_sku, v_slug,
      btrim(p_name_ar),
      btrim(p_name_en),
      p_base_price, p_compare_at_price, p_image_url,
      p_is_active, p_is_featured, p_prep_minutes
    )
    returning id into v_product_id;
  else
    v_product_id := p_product_id;

    if not exists (select 1 from catalog.products p where p.id = v_product_id) then
      raise exception 'unknown product' using errcode = '22023';
    end if;

    update catalog.products p
       set name_ar = btrim(p_name_ar),
           name_en = btrim(p_name_en),
           base_price = p_base_price,
           compare_at_price = p_compare_at_price,
           category_id = p_category_id,
           image_url = p_image_url,
           is_active = p_is_active,
           is_featured = p_is_featured,
           prep_minutes = p_prep_minutes,
           updated_at = now()
     where p.id = v_product_id;
  end if;

  -- The stock belongs to a branch, so it needs its own permission.
  if p_stock_quantity is not null then
    if not identity.has_permission('inventory.adjust') then
      raise exception 'missing permission: inventory.adjust' using errcode = '42501';
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
    end if;

    if v_branch is null then
      raise exception 'no branch holds the stock of this dashboard' using errcode = '22023';
    end if;

    if not identity.can_manage_branch(v_branch) then
      raise exception 'branch not managed by the caller' using errcode = '42501';
    end if;

    if p_stock_quantity < 0 then
      raise exception 'the stock cannot be negative' using errcode = '22023';
    end if;

    select bs.quantity_on_hand into v_previous
      from inventory.branch_stock bs
     where bs.branch_id = v_branch
       and bs.product_id = v_product_id
       and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

    insert into inventory.branch_stock (
      branch_id, product_id, variant_key, quantity_on_hand
    )
    values (
      v_branch, v_product_id,
      '00000000-0000-0000-0000-000000000000'::uuid,
      p_stock_quantity
    )
    on conflict (branch_id, product_id, variant_key)
    do update
      set quantity_on_hand = excluded.quantity_on_hand,
          updated_at = now();

    if coalesce(v_previous, 0) <> p_stock_quantity then
      insert into inventory.stock_movements (
        branch_id, product_id, variant_key, quantity_delta,
        reason, reference_type, actor_user_id, note
      )
      values (
        v_branch, v_product_id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        p_stock_quantity - coalesce(v_previous, 0),
        'adjustment', 'manual', auth.uid(), 'admin dashboard'
      );
    end if;
  end if;

  select to_jsonb(p) || jsonb_build_object(
           'category_name_ar', c.name_ar,
           'category_name_en', c.name_en,
           'stock_quantity', coalesce(s.quantity_on_hand, 0)
         )
    into v_saved
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
   where p.id = v_product_id;

  return v_saved;
end;
$$;

-- ---------------------------------------------------------------------------
-- B. The dashboard creates the categories it needs.
-- ---------------------------------------------------------------------------
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

  -- The slug is the public identifier of the category, so it has to stay
  -- unique. A name that repeats simply gets a suffix.
  v_slug := v_slug || case
    when exists (select 1 from catalog.categories c where c.slug = v_slug)
      then '-' || substr(md5(random()::text), 1, 6)
    else ''
  end;

  insert into catalog.categories (name_ar, name_en, slug, is_active, description_ar, description_en)
  values (btrim(p_name_ar), btrim(p_name_en), v_slug, true, nullif(btrim(coalesce(p_description_ar, '')), ''), nullif(btrim(coalesce(p_description_en, '')), ''))
  returning id into v_id;

  return to_jsonb(c)
    from catalog.categories c
   where c.id = v_id;
end;
$$;

comment on function public.admin_create_category(text, text) is
  'Creates a category for the admin dashboard. Requires catalog.category.write.';

-- ---------------------------------------------------------------------------
-- Grants.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_save_product(
  uuid, text, text, text, text, numeric, numeric, uuid, text, boolean, boolean, integer, integer, uuid
) from public;
revoke execute on function public.admin_save_product(
  uuid, text, text, text, text, numeric, numeric, uuid, text, boolean, boolean, integer, integer, uuid
) from anon;
grant execute on function public.admin_save_product(
  uuid, text, text, text, text, numeric, numeric, uuid, text, boolean, boolean, integer, integer, uuid
) to authenticated;

revoke all on function public.admin_create_category(text, text) from public;
revoke execute on function public.admin_create_category(text, text) from anon;
grant execute on function public.admin_create_category(text, text) to authenticated;

notify pgrst, 'reload schema';
