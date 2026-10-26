-- 164_subscription_plan_product_selection.sql
-- Let administrators restrict a subscription plan to a chosen set of products.
--
-- Adds:
--   * admin_subscription_product_options(): the searchable product list the
--     plan editor needs (guarded by the subscriptions permission, not by the
--     catalog write permission).
--   * admin_subscription_plans(): now returns the selected products per plan.
--   * admin_save_subscription_plan(): accepts product_scope/product_ids and
--     keeps subscriptions.plan_products in sync inside the same transaction.

create or replace function public.admin_subscription_product_options()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id,
      'name_ar', p.name_ar,
      'name_en', p.name_en,
      'sku', p.sku,
      'image_url', p.image_url,
      'base_price', p.base_price,
      'is_active', p.is_active,
      'category_name_ar', c.name_ar,
      'category_name_en', c.name_en
    ) order by p.is_active desc, p.sort_order, p.name_ar)
    from catalog.products p
    left join catalog.categories c on c.id = p.category_id
    where p.archived_at is null
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscription_product_options() from public, anon;
grant execute on function public.admin_subscription_product_options() to authenticated;

create or replace function public.admin_subscription_plans()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id,
      'code', p.code,
      'name_ar', p.name_ar,
      'name_en', p.name_en,
      'description_ar', p.description_ar,
      'description_en', p.description_en,
      'price', p.price,
      'currency_code', p.currency_code,
      'duration_days', p.duration_days,
      'cups_per_cycle', p.cups_per_cycle,
      'bonus_type', p.bonus_type,
      'bonus_value', p.bonus_value,
      'bonus_expires_with_cycle', p.bonus_expires_with_cycle,
      'rollover_cap_cups', p.rollover_cap_cups,
      'renewal_policy', p.renewal_policy,
      'auto_renew_supported', p.auto_renew_supported,
      'all_branches', p.all_branches,
      'product_scope', p.product_scope,
      'is_active', p.is_active,
      'is_for_sale', p.is_for_sale,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'subscribers_count', coalesce(stats.subscribers_count, 0),
      'active_subscribers', coalesce(stats.active_subscribers, 0),
      'products', case
        when p.product_scope = 'selected' then coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', pr.id,
            'name_ar', pr.name_ar,
            'name_en', pr.name_en,
            'sku', pr.sku,
            'image_url', pr.image_url,
            'base_price', pr.base_price,
            'is_active', pr.is_active,
            'category_name_ar', c.name_ar,
            'category_name_en', c.name_en
          ) order by pr.name_ar)
          from subscriptions.plan_products pp
          join catalog.products pr on pr.id = pp.product_id
          left join catalog.categories c on c.id = pr.category_id
          where pp.plan_id = p.id
        ), '[]'::jsonb)
        else '[]'::jsonb
      end
    ) order by p.is_active desc, p.price, p.created_at)
    from subscriptions.plans p
    left join lateral (
      select
        count(*)::int as subscribers_count,
        count(*) filter (
          where s.status = 'active'
            and (s.ends_at is null or s.ends_at > now())
        )::int as active_subscribers
      from subscriptions.subscriptions s
      where s.plan_id = p.id
    ) stats on true
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscription_plans() from public, anon;
grant execute on function public.admin_subscription_plans() to authenticated;

create or replace function public.admin_save_subscription_plan(p_plan jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
  v_code text;
  v_name_ar text;
  v_name_en text;
  v_description_ar text;
  v_description_en text;
  v_price numeric;
  v_currency text;
  v_duration integer;
  v_cups integer;
  v_bonus_type text;
  v_bonus_value numeric;
  v_bonus_expires boolean;
  v_rollover integer;
  v_renewal text;
  v_auto_renew boolean;
  v_all_branches boolean;
  v_product_scope text;
  v_product_ids uuid[];
  v_active boolean;
  v_for_sale boolean;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;
  if p_plan is null or jsonb_typeof(p_plan) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    if coalesce(btrim(p_plan ->> 'id'), '') <> '' then
      v_id := btrim(p_plan ->> 'id')::uuid;
    end if;
    v_code := upper(btrim(coalesce(p_plan ->> 'code', '')));
    v_name_ar := btrim(coalesce(p_plan ->> 'name_ar', ''));
    v_name_en := btrim(coalesce(p_plan ->> 'name_en', ''));
    v_description_ar := nullif(btrim(coalesce(p_plan ->> 'description_ar', '')), '');
    v_description_en := nullif(btrim(coalesce(p_plan ->> 'description_en', '')), '');
    v_price := coalesce((p_plan ->> 'price')::numeric, -1);
    v_currency := upper(btrim(coalesce(p_plan ->> 'currency_code', 'SAR')));
    v_duration := coalesce((p_plan ->> 'duration_days')::integer, 0);
    v_cups := coalesce((p_plan ->> 'cups_per_cycle')::integer, -1);
    v_bonus_type := coalesce(p_plan ->> 'bonus_type', 'none');
    v_bonus_value := coalesce((p_plan ->> 'bonus_value')::numeric, -1);
    v_bonus_expires := coalesce((p_plan ->> 'bonus_expires_with_cycle')::boolean, true);
    v_rollover := coalesce((p_plan ->> 'rollover_cap_cups')::integer, -1);
    v_renewal := coalesce(p_plan ->> 'renewal_policy', 'manual');
    v_auto_renew := coalesce((p_plan ->> 'auto_renew_supported')::boolean, false);
    v_all_branches := (p_plan ->> 'all_branches')::boolean;
    v_product_scope := nullif(btrim(coalesce(p_plan ->> 'product_scope', '')), '');
    v_active := coalesce((p_plan ->> 'is_active')::boolean, true);
    v_for_sale := coalesce((p_plan ->> 'is_for_sale')::boolean, true);
  exception
    when invalid_text_representation or numeric_value_out_of_range then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  if v_code !~ '^[A-Z0-9_-]{2,40}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_code');
  end if;
  if v_name_ar = '' or v_name_en = '' then
    return jsonb_build_object('ok', false, 'reason', 'missing_name');
  end if;
  if v_price < 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_price');
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_currency');
  end if;
  if v_duration <= 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_duration');
  end if;
  if v_cups < 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_cups');
  end if;
  if v_bonus_type not in ('none', 'percent', 'fixed', 'points') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_bonus');
  end if;
  if v_bonus_type = 'none' then
    v_bonus_value := 0;
  elsif v_bonus_value < 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_bonus');
  end if;
  if v_rollover < 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_rollover');
  end if;
  if v_renewal not in ('manual', 'auto') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_renewal');
  end if;
  if v_renewal = 'auto' and not v_auto_renew then
    return jsonb_build_object('ok', false, 'reason', 'invalid_renewal');
  end if;
  if v_product_scope is not null and v_product_scope not in ('all', 'selected') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  if v_product_scope = 'selected' then
    if not (p_plan ? 'product_ids')
       or jsonb_typeof(p_plan -> 'product_ids') <> 'array' then
      return jsonb_build_object('ok', false, 'reason', 'missing_products');
    end if;

    begin
      select coalesce(array_agg(distinct item::uuid), '{}'::uuid[])
        into v_product_ids
        from jsonb_array_elements_text(p_plan -> 'product_ids') as item
       where btrim(item) <> '';
    exception
      when invalid_text_representation
        or invalid_parameter_value
        or datatype_mismatch then
        return jsonb_build_object('ok', false, 'reason', 'invalid_products');
    end;

    if coalesce(array_length(v_product_ids, 1), 0) = 0 then
      return jsonb_build_object('ok', false, 'reason', 'missing_products');
    end if;

    if exists (
      select 1
        from unnest(v_product_ids) as wanted(product_id)
       where not exists (
         select 1 from catalog.products p where p.id = wanted.product_id
       )
    ) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_products');
    end if;
  end if;

  if exists (
    select 1
      from subscriptions.plans
     where code = v_code
       and (v_id is null or id <> v_id)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
  end if;

  if v_id is null then
    insert into subscriptions.plans (
      code, name_ar, name_en, description_ar, description_en,
      price, currency_code, duration_days, cups_per_cycle,
      bonus_type, bonus_value, bonus_expires_with_cycle,
      rollover_cap_cups, renewal_policy, auto_renew_supported,
      all_branches, product_scope, is_active, is_for_sale
    )
    values (
      v_code, v_name_ar, v_name_en, v_description_ar, v_description_en,
      v_price, v_currency, v_duration, v_cups,
      v_bonus_type, v_bonus_value, v_bonus_expires,
      v_rollover, v_renewal, v_auto_renew,
      coalesce(v_all_branches, true), coalesce(v_product_scope, 'all'),
      v_active, v_for_sale
    )
    returning id into v_id;
  else
    update subscriptions.plans
       set code = v_code,
           name_ar = v_name_ar,
           name_en = v_name_en,
           description_ar = v_description_ar,
           description_en = v_description_en,
           price = v_price,
           currency_code = v_currency,
           duration_days = v_duration,
           cups_per_cycle = v_cups,
           bonus_type = v_bonus_type,
           bonus_value = v_bonus_value,
           bonus_expires_with_cycle = v_bonus_expires,
           rollover_cap_cups = v_rollover,
           renewal_policy = v_renewal,
           auto_renew_supported = v_auto_renew,
           all_branches = coalesce(v_all_branches, all_branches),
           product_scope = coalesce(v_product_scope, product_scope),
           is_active = v_active,
           is_for_sale = v_for_sale
     where id = v_id;

    if not found then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
  end if;

  if v_product_scope = 'all' then
    delete from subscriptions.plan_products where plan_id = v_id;
  elsif v_product_scope = 'selected' then
    delete from subscriptions.plan_products where plan_id = v_id;
    insert into subscriptions.plan_products (plan_id, product_id)
    select v_id, product_id
      from unnest(v_product_ids) as wanted(product_id)
    on conflict (plan_id, product_id) do nothing;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$fn$;

revoke all on function public.admin_save_subscription_plan(jsonb) from public, anon;
grant execute on function public.admin_save_subscription_plan(jsonb) to authenticated;
