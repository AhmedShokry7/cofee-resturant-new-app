-- 168_admin_coupons.sql
-- Admin-side coupon management on top of the existing marketing schema.
--
-- The customer app already validates and redeems coupons; there was no admin
-- surface to create them. This migration adds:
--   * a directory with real redemption performance per coupon;
--   * headline metrics that follow the same status rules the UI shows;
--   * the category/product catalogue a coupon can be scoped to;
--   * transactional create/update with scope replacement;
--   * pause/activate and delete (delete refuses a coupon with redemptions).
--
-- Status precedence used by the UI and by admin_coupon_metrics():
--   paused > expired > scheduled > exhausted > active
-- Read and write both require settings.write, matching the coupon RLS policy.

-- ---------------------------------------------------------------------------
-- 1. Coupon directory with performance.
-- ---------------------------------------------------------------------------
create or replace function public.admin_coupons()
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
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id,
      'code', c.code,
      'title_ar', c.title_ar,
      'title_en', c.title_en,
      'description_ar', c.description_ar,
      'description_en', c.description_en,
      'discount_type', c.discount_type,
      'discount_value', c.discount_value,
      'max_discount', c.max_discount,
      'min_order_amount', c.min_order_amount,
      'applies_to', c.applies_to,
      'usage_limit', c.usage_limit,
      'per_user_limit', c.per_user_limit,
      'starts_at', c.starts_at,
      'ends_at', c.ends_at,
      'is_active', c.is_active,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'redemptions_count', coalesce(stats.redemptions_count, 0),
      'unique_customers', coalesce(stats.unique_customers, 0),
      'discount_given', coalesce(stats.discount_given, 0),
      'last_redeemed_at', stats.last_redeemed_at,
      'categories', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', cat.id,
          'name_ar', cat.name_ar,
          'name_en', cat.name_en
        ) order by cat.name_ar)
        from marketing.coupons_categories cc
        join catalog.categories cat on cat.id = cc.category_id
        where cc.coupon_id = c.id
      ), '[]'::jsonb),
      'products', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', p.id,
          'name_ar', p.name_ar,
          'name_en', p.name_en,
          'image_url', p.image_url
        ) order by p.name_ar)
        from marketing.coupons_products cp
        join catalog.products p on p.id = cp.product_id
        where cp.coupon_id = c.id
      ), '[]'::jsonb)
    ) order by c.is_active desc, c.created_at desc)
    from marketing.coupons c
    left join lateral (
      select count(*)::integer as redemptions_count,
             count(distinct r.user_id)::integer as unique_customers,
             coalesce(sum(r.amount), 0) as discount_given,
             max(r.created_at) as last_redeemed_at
        from marketing.coupon_redemptions r
       where r.coupon_id = c.id
    ) stats on true
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_coupons is
  'Every coupon with its scope and real redemption performance for the admin directory.';

revoke all on function public.admin_coupons() from public, anon;
grant execute on function public.admin_coupons() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Headline metrics.
-- ---------------------------------------------------------------------------
create or replace function public.admin_coupon_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_now timestamptz := now();
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'active', count(*) filter (
        where c.is_active
          and (c.starts_at is null or c.starts_at <= v_now)
          and (c.ends_at is null or c.ends_at > v_now + interval '7 days')
          and (c.usage_limit is null or coalesce(used.total_used, 0) < c.usage_limit)
      ),
      'expiring_soon', count(*) filter (
        where c.is_active
          and (c.starts_at is null or c.starts_at <= v_now)
          and c.ends_at is not null
          and c.ends_at > v_now
          and c.ends_at <= v_now + interval '7 days'
          and (c.usage_limit is null or coalesce(used.total_used, 0) < c.usage_limit)
      ),
      'scheduled', count(*) filter (
        where c.is_active and c.starts_at is not null and c.starts_at > v_now
      ),
      'paused', count(*) filter (where not c.is_active),
      'expired', count(*) filter (
        where c.ends_at is not null and c.ends_at <= v_now
      ),
      'exhausted', count(*) filter (
        where c.usage_limit is not null and coalesce(used.total_used, 0) >= c.usage_limit
      ),
      'total', count(*),
      'redemptions', coalesce(sum(used.total_used), 0),
      'unique_customers', (
        select count(distinct r.user_id)::integer
          from marketing.coupon_redemptions r
      ),
      'discount_given', (
        select coalesce(sum(r.amount), 0)
          from marketing.coupon_redemptions r
      )
    )
    from marketing.coupons c
    left join lateral (
      select count(*)::integer as total_used
        from marketing.coupon_redemptions rr
       where rr.coupon_id = c.id
    ) used on true
  );
end;
$fn$;

comment on function public.admin_coupon_metrics is
  'Coupon headline metrics using the same status precedence as the admin directory.';

revoke all on function public.admin_coupon_metrics() from public, anon;
grant execute on function public.admin_coupon_metrics() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Catalogue the admin can scope a coupon to.
-- ---------------------------------------------------------------------------
create or replace function public.admin_coupon_targets()
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
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name_ar', c.name_ar,
        'name_en', c.name_en,
        'image_url', c.image_url,
        'is_active', c.is_active,
        'products_count', (
          select count(*)::integer
            from catalog.products p
           where p.category_id = c.id
             and p.archived_at is null
        )
      ) order by c.sort_order, c.name_ar)
      from catalog.categories c
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name_ar', p.name_ar,
        'name_en', p.name_en,
        'sku', p.sku,
        'image_url', p.image_url,
        'base_price', p.base_price,
        'is_active', p.is_active,
        'is_archived', p.archived_at is not null,
        'category_id', p.category_id,
        'category_name_ar', cat.name_ar,
        'category_name_en', cat.name_en
      ) order by (p.archived_at is not null), p.sort_order, p.name_ar)
      from catalog.products p
      left join catalog.categories cat on cat.id = p.category_id
    ), '[]'::jsonb)
  );
end;
$fn$;

comment on function public.admin_coupon_targets is
  'Categories and products a coupon can be scoped to, including archived products already used by a coupon.';

revoke all on function public.admin_coupon_targets() from public, anon;
grant execute on function public.admin_coupon_targets() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Create or update a coupon and replace its scope in one transaction.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_coupon(p_coupon jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id           uuid;
  v_code         text;
  v_title_ar     text;
  v_title_en     text;
  v_desc_ar      text;
  v_desc_en      text;
  v_type         text;
  v_value        numeric;
  v_max_discount numeric;
  v_min_order    numeric := 0;
  v_applies      text;
  v_usage_limit  integer;
  v_per_user     integer := 1;
  v_starts       timestamptz;
  v_ends         timestamptz;
  v_active       boolean := true;
  v_created      boolean := false;
  v_old          jsonb;
  v_scope_json   jsonb;
  v_scope_ids    uuid[];
  v_scope_count  integer;
  v_new          jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_coupon is null or jsonb_typeof(p_coupon) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    if coalesce(btrim(p_coupon ->> 'id'), '') <> '' then
      v_id := btrim(p_coupon ->> 'id')::uuid;
    end if;
    v_active := coalesce((p_coupon ->> 'is_active')::boolean, true);
  exception
    when invalid_text_representation or null_value_not_allowed then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  v_code := upper(btrim(coalesce(p_coupon ->> 'code', '')));
  v_title_ar := btrim(coalesce(p_coupon ->> 'title_ar', ''));
  v_title_en := btrim(coalesce(p_coupon ->> 'title_en', ''));
  v_desc_ar := nullif(btrim(coalesce(p_coupon ->> 'description_ar', '')), '');
  v_desc_en := nullif(btrim(coalesce(p_coupon ->> 'description_en', '')), '');
  v_type := lower(btrim(coalesce(p_coupon ->> 'discount_type', '')));
  v_applies := lower(btrim(coalesce(p_coupon ->> 'applies_to', 'all')));

  if v_code !~ '^[A-Z0-9][A-Z0-9_-]{2,31}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_code');
  end if;
  if v_title_ar = '' or v_title_en = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_title');
  end if;
  if length(v_title_ar) > 120 or length(v_title_en) > 120 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_title');
  end if;
  if (v_desc_ar is not null and length(v_desc_ar) > 500)
     or (v_desc_en is not null and length(v_desc_en) > 500) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;
  if v_type not in ('percentage', 'fixed_amount') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_discount');
  end if;
  if v_applies not in ('all', 'category', 'product') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
  end if;

  begin
    v_value := (p_coupon ->> 'discount_value')::numeric;
    if nullif(btrim(p_coupon ->> 'max_discount'), '') is not null then
      v_max_discount := (p_coupon ->> 'max_discount')::numeric;
    end if;
    if nullif(btrim(p_coupon ->> 'min_order_amount'), '') is not null then
      v_min_order := (p_coupon ->> 'min_order_amount')::numeric;
    end if;
    if nullif(btrim(p_coupon ->> 'usage_limit'), '') is not null then
      v_usage_limit := (p_coupon ->> 'usage_limit')::integer;
    end if;
    if nullif(btrim(p_coupon ->> 'per_user_limit'), '') is not null then
      v_per_user := (p_coupon ->> 'per_user_limit')::integer;
    end if;
    if nullif(btrim(p_coupon ->> 'starts_at'), '') is not null then
      v_starts := (p_coupon ->> 'starts_at')::timestamptz;
    end if;
    if nullif(btrim(p_coupon ->> 'ends_at'), '') is not null then
      v_ends := (p_coupon ->> 'ends_at')::timestamptz;
    end if;
  exception
    when invalid_text_representation
      or numeric_value_out_of_range
      or datetime_field_overflow then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  if v_value is null or v_value <= 0 or v_value > 1000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_discount');
  end if;
  if v_type = 'percentage' and v_value > 100 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_discount');
  end if;
  if v_type = 'percentage' then
    if v_max_discount is not null and (v_max_discount <= 0 or v_max_discount > 1000000) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_discount');
    end if;
  else
    v_max_discount := null;
  end if;
  if v_min_order is null or v_min_order < 0 or v_min_order > 1000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_discount');
  end if;

  if v_per_user is null or v_per_user < 1 or v_per_user > 1000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_limit');
  end if;
  if v_usage_limit is not null and (v_usage_limit < 1 or v_usage_limit > 1000000) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_limit');
  end if;
  if v_usage_limit is not null and v_per_user > v_usage_limit then
    return jsonb_build_object('ok', false, 'reason', 'invalid_limit');
  end if;

  if v_starts is not null and v_ends is not null and v_ends <= v_starts then
    return jsonb_build_object('ok', false, 'reason', 'invalid_window');
  end if;

  if exists (
    select 1
      from marketing.coupons c
     where c.code = v_code
       and (v_id is null or c.id <> v_id)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
  end if;

  -- Scope: all clears both mappings, a category coupon needs existing
  -- categories, a product coupon needs existing products (archived products
  -- stay valid so an old coupon keeps its history).
  v_scope_ids := null;
  if v_applies = 'category' then
    v_scope_json := p_coupon -> 'category_ids';
    if v_scope_json is not null and jsonb_typeof(v_scope_json) = 'array' then
      begin
        select array_agg(distinct scope.value::uuid)
          into v_scope_ids
          from jsonb_array_elements_text(v_scope_json) as scope(value)
         where nullif(btrim(scope.value), '') is not null;
      exception
        when invalid_text_representation then
          return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
      end;
    elsif v_scope_json is not null and jsonb_typeof(v_scope_json) <> 'null' then
      return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
    end if;

    if v_scope_ids is null or cardinality(v_scope_ids) = 0 then
      return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
    end if;
    select count(*) into v_scope_count
      from catalog.categories c
     where c.id = any (v_scope_ids);
    if v_scope_count <> cardinality(v_scope_ids) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
    end if;
  elsif v_applies = 'product' then
    v_scope_json := p_coupon -> 'product_ids';
    if v_scope_json is not null and jsonb_typeof(v_scope_json) = 'array' then
      begin
        select array_agg(distinct scope.value::uuid)
          into v_scope_ids
          from jsonb_array_elements_text(v_scope_json) as scope(value)
         where nullif(btrim(scope.value), '') is not null;
      exception
        when invalid_text_representation then
          return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
      end;
    elsif v_scope_json is not null and jsonb_typeof(v_scope_json) <> 'null' then
      return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
    end if;

    if v_scope_ids is null or cardinality(v_scope_ids) = 0 then
      return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
    end if;
    select count(*) into v_scope_count
      from catalog.products p
     where p.id = any (v_scope_ids);
    if v_scope_count <> cardinality(v_scope_ids) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
    end if;
  end if;

  v_new := jsonb_build_object(
    'code', v_code,
    'title_ar', v_title_ar,
    'title_en', v_title_en,
    'description_ar', v_desc_ar,
    'description_en', v_desc_en,
    'discount_type', v_type,
    'discount_value', v_value,
    'max_discount', v_max_discount,
    'min_order_amount', v_min_order,
    'applies_to', v_applies,
    'usage_limit', v_usage_limit,
    'per_user_limit', v_per_user,
    'starts_at', v_starts,
    'ends_at', v_ends,
    'is_active', v_active,
    'category_ids', case when v_applies = 'category' then to_jsonb(v_scope_ids) else '[]'::jsonb end,
    'product_ids', case when v_applies = 'product' then to_jsonb(v_scope_ids) else '[]'::jsonb end
  );

  if v_id is null then
    insert into marketing.coupons
      (code, title_ar, title_en, description_ar, description_en,
       discount_type, discount_value, max_discount, min_order_amount,
       applies_to, usage_limit, per_user_limit, starts_at, ends_at, is_active)
    values
      (v_code, v_title_ar, v_title_en, v_desc_ar, v_desc_en,
       v_type, v_value, v_max_discount, v_min_order,
       v_applies, v_usage_limit, v_per_user, v_starts, v_ends, v_active)
    returning id into v_id;
    v_created := true;
  else
    select to_jsonb(c) into v_old
      from marketing.coupons c
     where c.id = v_id;

    if v_old is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    update marketing.coupons
       set code = v_code,
           title_ar = v_title_ar,
           title_en = v_title_en,
           description_ar = v_desc_ar,
           description_en = v_desc_en,
           discount_type = v_type,
           discount_value = v_value,
           max_discount = v_max_discount,
           min_order_amount = v_min_order,
           applies_to = v_applies,
           usage_limit = v_usage_limit,
           per_user_limit = v_per_user,
           starts_at = v_starts,
           ends_at = v_ends,
           is_active = v_active
     where id = v_id;
  end if;

  delete from marketing.coupons_categories where coupon_id = v_id;
  delete from marketing.coupons_products where coupon_id = v_id;

  if v_applies = 'category' then
    insert into marketing.coupons_categories (coupon_id, category_id)
    select v_id, scoped.id
      from unnest(v_scope_ids) as scoped(id);
  elsif v_applies = 'product' then
    insert into marketing.coupons_products (coupon_id, product_id)
    select v_id, scoped.id
      from unnest(v_scope_ids) as scoped(id);
  end if;

  perform identity.audit(
    case when v_created then 'marketing.coupon.create' else 'marketing.coupon.update' end,
    'coupon',
    v_id,
    v_old,
    v_new
  );

  return jsonb_build_object('ok', true, 'id', v_id, 'created', v_created);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
  when foreign_key_violation then
    return jsonb_build_object('ok', false, 'reason', 'invalid_scope');
  when check_violation then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
end;
$fn$;

comment on function public.admin_save_coupon is
  'Create or update a coupon and replace its category/product scope atomically.';

revoke all on function public.admin_save_coupon(jsonb) from public, anon;
grant execute on function public.admin_save_coupon(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Pause / activate.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_coupon_active(
  p_coupon_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  select to_jsonb(c) into v_old
    from marketing.coupons c
   where c.id = p_coupon_id;

  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  update marketing.coupons
     set is_active = coalesce(p_active, false)
   where id = p_coupon_id;

  perform identity.audit(
    case when coalesce(p_active, false)
      then 'marketing.coupon.activate'
      else 'marketing.coupon.pause'
    end,
    'coupon',
    p_coupon_id,
    v_old,
    jsonb_build_object('is_active', coalesce(p_active, false))
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_coupon_active is
  'Pause or reactivate a coupon without touching its redemption history.';

revoke all on function public.admin_set_coupon_active(uuid, boolean) from public, anon;
grant execute on function public.admin_set_coupon_active(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Delete only a coupon that was never redeemed.
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_coupon(p_coupon_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  select to_jsonb(c) into v_old
    from marketing.coupons c
   where c.id = p_coupon_id;

  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if exists (
    select 1
      from marketing.coupon_redemptions r
     where r.coupon_id = p_coupon_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'has_redemptions');
  end if;

  delete from marketing.coupons where id = p_coupon_id;

  perform identity.audit(
    'marketing.coupon.delete',
    'coupon',
    p_coupon_id,
    v_old,
    null
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_delete_coupon is
  'Delete a coupon that has no redemptions; a redeemed coupon can only be paused.';

revoke all on function public.admin_delete_coupon(uuid) from public, anon;
grant execute on function public.admin_delete_coupon(uuid) to authenticated;

notify pgrst, 'reload schema';
