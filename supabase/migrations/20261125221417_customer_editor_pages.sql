create or replace function core.app_design_is_valid(p_document jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_page        jsonb;
  v_check       jsonb;
  v_ids         jsonb := '[]'::jsonb;
  v_version     numeric;
  v_theme       jsonb;
  v_brand       jsonb;
begin
  if jsonb_typeof(p_document) <> 'object' then
    return 'document';
  end if;
  if jsonb_typeof(p_document -> 'schema_version') <> 'number' then
    return 'schema_version';
  end if;
  v_version := (p_document ->> 'schema_version')::numeric;
  if v_version not in (1, 2) then
    return 'schema_version';
  end if;
  if jsonb_typeof(p_document -> 'pages') <> 'array'
     or jsonb_array_length(p_document -> 'pages') = 0 then
    return 'pages';
  end if;
  if jsonb_array_length(p_document -> 'pages') > 48 then
    return 'page_count';
  end if;
  if exists (
    select 1
      from jsonb_array_elements(p_document -> 'pages') p
     where coalesce(p ->> 'page', '') not in
       ('splash', 'welcome', 'onboarding', 'auth', 'sign_up', 'forget_password', 'reset_password', 'phone_auth', 'email_auth', 'home', 'categories', 'search', 'product_details', 'cart', 'favourites', 'settings', 'checkout', 'shipping_addresses', 'add_address', 'payment_method', 'add_card', 'payment_success', 'e_receipt', 'coupon', 'orders', 'edit_profile', 'saved_cards', 'addresses', 'address_form', 'loyalty', 'subscription_plans', 'subscription_details', 'cashier_subscription', 'notifications', 'notification_settings', 'help', 'privacy', 'assistant_memory', 'my_bundles', 'customer_bundle_editor', 'my_reservations', 'reservation_form', 'event_request_form', 'my_product_subscriptions', 'product_subscription_form')
  ) then
    return 'page_key';
  end if;
  if (
    select count(distinct p ->> 'page')
      from jsonb_array_elements(p_document -> 'pages') p
  ) <> jsonb_array_length(p_document -> 'pages') then
    return 'page_duplicate';
  end if;

  for v_page in select jsonb_array_elements(p_document -> 'pages') loop
    if jsonb_typeof(v_page) <> 'object' then
      return 'page_entry';
    end if;
    v_check := core.app_design_node_check(v_page -> 'root', 1);
    if not (v_check ->> 'ok')::boolean then
      return coalesce(v_check ->> 'reason', 'root');
    end if;
    v_ids := v_ids || (v_check -> 'ids');
  end loop;

  if jsonb_array_length(v_ids) > 400 then
    return 'node_count';
  end if;
  if (
    select count(distinct i) from jsonb_array_elements_text(v_ids) i
  ) <> jsonb_array_length(v_ids) then
    return 'node_duplicate';
  end if;

  ---------------------------------------------------------------------------
  -- The theme block, including the brand identity (244).
  ---------------------------------------------------------------------------
  v_theme := p_document -> 'theme';
  if v_theme is not null then
    if v_version <> 2 then
      return 'theme_version';
    end if;
    if jsonb_typeof(v_theme) <> 'object' then
      return 'theme';
    end if;
    if exists (
      select 1
        from jsonb_object_keys(v_theme) k
       where k not in ('colors', 'text_scale', 'radius_scale', 'brand')
    ) then
      return 'theme_key';
    end if;

    if v_theme ? 'colors' then
      if jsonb_typeof(v_theme -> 'colors') <> 'object' then
        return 'theme_colors';
      end if;
      if exists (
        select 1
          from jsonb_object_keys(v_theme -> 'colors') r
         where r not in (
           'primary', 'secondary', 'background', 'surface',
           'text_primary', 'text_secondary', 'border',
           'success', 'error', 'disabled')
      ) then
        return 'theme_color_role';
      end if;
      if exists (
        select 1
          from jsonb_each(v_theme -> 'colors') c
         where jsonb_typeof(c.value) <> 'string'
            or c.value #>> '{}' !~ '^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$'
      ) then
        return 'theme_color_value';
      end if;
    end if;

    if v_theme ? 'text_scale' and (
      jsonb_typeof(v_theme -> 'text_scale') <> 'string'
      or v_theme ->> 'text_scale' not in
         ('default', 'compact', 'comfortable', 'large')
    ) then
      return 'theme_text_scale';
    end if;
    if v_theme ? 'radius_scale' and (
      jsonb_typeof(v_theme -> 'radius_scale') <> 'string'
      or v_theme ->> 'radius_scale' not in
         ('default', 'sharp', 'soft', 'round', 'pill')
    ) then
      return 'theme_radius_scale';
    end if;

    -------------------------------------------------------------------------
    -- The brand identity: name in both languages and a logo URL.
    -- A field that is present must read as a usable value; the empty brand
    -- (no keys) is allowed and means the shipped identity, the same rule the
    -- theme block uses for colours.
    -------------------------------------------------------------------------
    if v_theme ? 'brand' then
      v_brand := v_theme -> 'brand';
      if jsonb_typeof(v_brand) <> 'object' then
        return 'brand';
      end if;
      if exists (
        select 1
          from jsonb_object_keys(v_brand) k
         where k not in ('name_ar', 'name_en', 'logo_url')
      ) then
        return 'brand_key';
      end if;
      if exists (
        select 1 from jsonb_each(v_brand) b
         where jsonb_typeof(b.value) <> 'string'
      ) then
        return 'brand_value';
      end if;
      if (v_brand ? 'name_ar' and char_length(v_brand ->> 'name_ar') > 80)
         or (v_brand ? 'name_en' and char_length(v_brand ->> 'name_en') > 80)
      then
        return 'brand_name';
      end if;
      if v_brand ? 'logo_url' then
        if char_length(v_brand ->> 'logo_url') > 2048
           or v_brand ->> 'logo_url' !~ '^https?://'
        then
          return 'brand_logo_url';
        end if;
      end if;
    end if;
  end if;

  return null;
end;
$fn$;

