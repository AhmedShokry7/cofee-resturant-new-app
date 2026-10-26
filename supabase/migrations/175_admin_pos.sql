-- 175_admin_pos.sql
--
-- The point of sale. A cashier builds a walk-in order from the real menu, the
-- server prices it, the counter payment is recorded, and the very same order
-- insert feeds the kitchen board through the triggers of 174.
--
-- Why this is not the customer checkout:
--   * a walk-in order has no customer account, so orders.orders.user_id has
--     to accept NULL and the status notification trigger has to skip it;
--   * the customer checkout is bound to one active cart per user; a shared
--     counter cannot live in that model;
--   * the POS must not award loyalty points or redeem coupons for the cashier.
--
-- What this migration adds:
--   1. the pos.manage permission and its role grants;
--   2. nullable walk-in orders and the notification fix;
--   3. one shared price helper so the menu can show the discounted price
--      without inventing a fake option selection for required groups;
--   4. the POS catalogue RPC: branches, categories, payment methods, products,
--      effective prices, stock and option groups in one call;
--   5. admin_pos_place_order: atomic, idempotent, server-priced, stock-aware,
--      paid at the counter, with the order entering the kitchen queue;
--   6. admin_orders carries order_source and table_number so the orders page
--      can tell a walk-in from an online customer.

-- ---------------------------------------------------------------------------
-- 1. Permission and role grants
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('pos.manage',
   'إدارة نقطة البيع',
   'Manage point of sale',
   'Open the point of sale, build walk-in orders and take payment.')
on conflict (code) do update
  set name_ar     = excluded.name_ar,
      name_en     = excluded.name_en,
      description = excluded.description;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code = 'pos.manage'
 where r.code in ('manager', 'branch_manager', 'cashier')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Walk-in orders
-- ---------------------------------------------------------------------------
alter table orders.orders
  alter column user_id drop not null;

comment on column orders.orders.user_id is
  'The customer account, NULL for a point-of-sale walk-in order.';

-- A status update on a walk-in order used to abort: the notification table
-- requires a profile, and the trigger tried to insert with a NULL user.
create or replace function engagement.notify_order_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_user uuid;
  v_dedupe text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  select user_id into v_user from orders.orders where id = new.id;

  -- Walk-in orders have nobody to notify, and the kitchen must still be able
  -- to move them forward.
  if v_user is null then
    return new;
  end if;

  v_dedupe := 'order:' || new.id::text || ':' || new.status;

  insert into engagement.notifications
    (user_id, type, title_ar, title_en, body_ar, body_en,
     payload, related_entity_type, related_entity_id, dedupe_key)
  values (
    v_user,
    'order_status',
    'تحديث حالة الطلب ' || new.order_number,
    'Order ' || new.order_number || ' updated',
    'حالة طلبك الآن: ' || new.status,
    'Your order status is now: ' || new.status,
    jsonb_build_object('order_id', new.id, 'order_number', new.order_number,
                       'status', new.status, 'total', new.grand_total,
                       'branch_id', new.branch_id),
    'order',
    new.id,
    v_dedupe
  )
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  return new;
end;
$fn$;

comment on function engagement.notify_order_status() is
  'After an order status change: create one in-app notification. Walk-in orders are skipped.';

-- ---------------------------------------------------------------------------
-- 3. One price truth for products without an option selection
--
-- resolve_effective_price() validates the option selection first. A required
-- size group therefore makes an empty selection invalid, which is right at
-- checkout but blocks the menu from showing the starting price. The price of
-- the product itself now lives in its own function and resolve_effective_price
-- adds the options on top, so both paths share one implementation.
-- ---------------------------------------------------------------------------
create or replace function catalog.resolve_product_base_price(
  p_branch_id  uuid,
  p_product_id uuid
)
returns table (
  unit_price           numeric,
  currency_code        text,
  is_available         boolean,
  unavailable_reason   text,
  regular_price        numeric,
  discount_percentage  numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_base         numeric;
  v_override     numeric;
  v_available    boolean;
  v_reason       text;
  v_active       boolean;
  v_archived     timestamptz;
  v_currency     text;
  v_regular      numeric;
  v_now          timestamptz := now();
  v_general_pct  numeric;
  v_branch_pct   numeric;
  v_use_general  boolean;
  v_branch_start timestamptz;
  v_branch_end   timestamptz;
  v_general_start timestamptz;
  v_general_end  timestamptz;
  v_pct          numeric;
begin
  select p.base_price, p.is_active, p.archived_at,
         p.discount_percentage, p.discount_starts_at, p.discount_ends_at
    into v_base, v_active, v_archived, v_general_pct, v_general_start, v_general_end
    from catalog.products p
   where p.id = p_product_id;

  if not found then
    raise exception 'product % not found', p_product_id using errcode = 'P0002';
  end if;

  select b.currency_code into v_currency from core.brands b limit 1;

  select bpp.price_override, bpp.is_available, bpp.unavailable_reason,
         bpp.discount_percentage, bpp.discount_starts_at, bpp.discount_ends_at,
         bpp.use_general_discount
    into v_override, v_available, v_reason, v_branch_pct, v_branch_start, v_branch_end, v_use_general
    from catalog.branch_product_pricing bpp
   where bpp.branch_id = p_branch_id and bpp.product_id = p_product_id;

  v_available := coalesce(v_available, true);
  if not v_active or v_archived is not null then
    v_available := false;
    v_reason := coalesce(v_reason, 'product inactive');
  end if;

  v_regular := coalesce(v_override, v_base);

  -- General discount is active only inside its window.
  if v_general_pct is null
     or (v_general_start is not null and v_now < v_general_start)
     or (v_general_end is not null and v_now > v_general_end) then
    v_general_pct := 0;
  end if;

  -- Branch discount is active only inside its window.
  if v_branch_pct is null
     or (v_branch_start is not null and v_now < v_branch_start)
     or (v_branch_end is not null and v_now > v_branch_end) then
    v_branch_pct := null;
  end if;

  v_use_general := coalesce(v_use_general, true);

  if v_branch_pct is not null then
    v_pct := v_branch_pct;
  elsif v_use_general then
    v_pct := v_general_pct;
  else
    v_pct := 0;
  end if;

  return query
  select round(v_regular * (1 - v_pct / 100.0), 2),
         v_currency,
         v_available,
         v_reason,
         round(v_regular, 2),
         round(v_pct, 2);
end;
$fn$;

comment on function catalog.resolve_product_base_price(uuid, uuid) is
  'The branch price of a product before options, including product and branch discounts.';

revoke all on function catalog.resolve_product_base_price(uuid, uuid)
  from public, anon, authenticated;

create or replace function catalog.resolve_effective_price(
  p_branch_id  uuid,
  p_product_id uuid,
  p_option_value_ids uuid[] default '{}'
)
returns table (
  unit_price      numeric,
  currency_code   text,
  is_available    boolean,
  option_deltas   numeric,
  unavailable_reason text,
  regular_price   numeric,
  discount_percentage numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_base   record;
  v_deltas numeric;
begin
  perform catalog.validate_product_option_selection(p_product_id, p_option_value_ids);

  select r.unit_price, r.currency_code, r.is_available, r.unavailable_reason,
         r.regular_price, r.discount_percentage
    into v_base
    from catalog.resolve_product_base_price(p_branch_id, p_product_id) r;

  select coalesce(sum(ov.price_delta), 0)
    into v_deltas
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids)
     and ov.is_active;

  return query
  select round(v_base.unit_price + v_deltas, 2),
         v_base.currency_code,
         v_base.is_available,
         round(v_deltas, 2),
         v_base.unavailable_reason,
         round(v_base.regular_price + v_deltas, 2),
         v_base.discount_percentage;
end;
$fn$;

comment on function catalog.resolve_effective_price(uuid, uuid, uuid[]) is
  'Server-side price truth including options, general and branch-specific discounts.';

-- POS order lines have no source cart item. Their product discount is written
-- by the order RPC, so the trigger must keep the provided value instead of
-- zeroing it. Cart-backed lines behave exactly as before.
create or replace function orders.fill_order_item_product_discount()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.source_cart_item_id is null then
    return new;
  end if;

  new.product_discount_total := orders.cart_line_product_discount(
    new.source_cart_item_id, new.unit_price, new.quantity);
  return new;
end;
$fn$;

comment on function orders.fill_order_item_product_discount() is
  'Fill the product discount of a cart-backed line. Direct lines (POS) provide their own.';

-- ---------------------------------------------------------------------------
-- 4. POS catalogue
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_catalog(
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_branch       uuid;
  v_currency     text;
  v_tax_rate     numeric := 0;
  v_tax_included boolean := true;
  v_branches     jsonb;
  v_categories   jsonb;
  v_products     jsonb;
  v_methods      jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  -- Resolve the branch: the requested one, otherwise the cashier's branch,
  -- otherwise the first active branch for an owner or a global manager.
  if p_branch_id is null then
    select sr.branch_id
      into v_branch
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
    raise exception 'no branch is available for this staff member'
      using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from core.branches b where b.id = v_branch and b.is_active
  ) then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_branch) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select b.currency_code,
         coalesce(b.tax_rate, 0),
         coalesce(b.tax_included, true)
    into v_currency, v_tax_rate, v_tax_included
    from core.brands b
   limit 1;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', b.id,
             'code', b.code,
             'name_ar', b.name_ar,
             'name_en', b.name_en
           ) order by b.name_ar
         ), '[]'::jsonb)
    into v_branches
    from core.branches b
   where b.is_active
     and identity.can_manage_branch(b.id);

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', c.id,
             'name_ar', c.name_ar,
             'name_en', c.name_en,
             'image_url', c.image_url,
             'sort_order', c.sort_order,
             'product_count', coalesce(pc.product_count, 0)
           ) order by c.sort_order, c.name_ar
         ), '[]'::jsonb)
    into v_categories
    from catalog.categories c
    left join lateral (
      select count(*)::integer as product_count
        from catalog.products p
       where p.category_id = c.id
         and p.is_active
         and p.archived_at is null
    ) pc on true
   where c.is_active;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', m.id,
             'code', m.code,
             'name_ar', m.name_ar,
             'name_en', m.name_en,
             'is_online', m.is_online,
             'requires_saved_card', m.requires_saved_card,
             'sort_order', m.sort_order
           ) order by m.sort_order, m.name_ar
         ), '[]'::jsonb)
    into v_methods
    from payments.payment_methods m
   where m.is_active;

  select coalesce(jsonb_agg(
           to_jsonb(page)
           order by page.sort_order, page.name_ar
         ), '[]'::jsonb)
    into v_products
    from (
      select p.id,
             p.category_id,
             p.sku,
             p.name_ar,
             p.name_en,
             p.description_ar,
             p.description_en,
             p.image_url,
             p.sort_order,
             p.is_featured,
             p.prep_minutes,
             c.name_ar as category_name_ar,
             c.name_en as category_name_en,
             r.unit_price,
             r.regular_price,
             r.discount_percentage,
             r.is_available,
             r.unavailable_reason,
             coalesce(bs.quantity_on_hand, 0) as stock_quantity,
             (bs.product_id is not null) as track_stock,
             coalesce(bs.allow_negative, false) as allow_negative,
             (
               bs.product_id is not null
               and not bs.allow_negative
               and bs.quantity_on_hand <= 0
             ) as sold_out,
             coalesce((
               select jsonb_agg(
                        jsonb_build_object(
                          'id', g.id,
                          'name_ar', g.name_ar,
                          'name_en', g.name_en,
                          'selection_type', g.selection_type,
                          'min_select', case
                            when pog.is_required or g.is_required
                              then greatest(g.min_select, 1)
                            else g.min_select
                          end,
                          'max_select', case
                            when g.selection_type = 'single' then 1
                            else g.max_select
                          end,
                          'is_required', pog.is_required or g.is_required,
                          'sort_order', pog.sort_order,
                          'values', coalesce((
                            select jsonb_agg(
                                     jsonb_build_object(
                                       'id', ov.id,
                                       'name_ar', ov.name_ar,
                                       'name_en', ov.name_en,
                                       'price_delta', ov.price_delta,
                                       'is_default', ov.is_default,
                                       'sort_order', ov.sort_order
                                     ) order by ov.sort_order, ov.name_ar
                                   )
                              from catalog.option_values ov
                             where ov.group_id = g.id
                               and ov.is_active
                          ), '[]'::jsonb)
                        ) order by pog.sort_order, g.sort_order, g.name_ar
                      )
                 from catalog.product_option_groups pog
                 join catalog.option_groups g on g.id = pog.group_id
                where pog.product_id = p.id
                  and g.is_active
                  and exists (
                    select 1 from catalog.option_values av
                     where av.group_id = g.id and av.is_active
                  )
             ), '[]'::jsonb) as option_groups
        from catalog.products p
        join catalog.categories c on c.id = p.category_id
        cross join lateral catalog.resolve_product_base_price(v_branch, p.id) r
        left join inventory.branch_stock bs
          on bs.branch_id = v_branch
         and bs.product_id = p.id
         and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
       where p.is_active
         and p.archived_at is null
         and c.is_active
    ) page;

  return jsonb_build_object(
    'branch_id', v_branch,
    'currency_code', v_currency,
    'tax_rate', v_tax_rate,
    'tax_included', v_tax_included,
    'branches', v_branches,
    'categories', v_categories,
    'payment_methods', v_methods,
    'products', v_products
  );
end;
$fn$;

comment on function public.admin_pos_catalog(uuid) is
  'The POS menu of one branch: products, effective prices, stock, options and payment methods.';

revoke all on function public.admin_pos_catalog(uuid) from public, anon;
grant execute on function public.admin_pos_catalog(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Place a walk-in order
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_place_order(
  p_branch_id         uuid,
  p_lines             jsonb,
  p_fulfillment_type  text,
  p_payment_method_id uuid,
  p_idempotency_key   text,
  p_table_number      text default null,
  p_note              text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid          uuid := auth.uid();
  v_existing     orders.orders%rowtype;
  v_existing_method payments.payment_methods%rowtype;
  v_branch       core.branches%rowtype;
  v_method       payments.payment_methods%rowtype;
  v_line         jsonb;
  v_row          jsonb;
  v_items        jsonb := '[]'::jsonb;
  v_options      jsonb;
  v_option_ids   uuid[];
  v_product_id   uuid;
  v_quantity     integer;
  v_note         text;
  v_line_note    text;
  v_name_ar      text;
  v_name_en      text;
  v_sku          text;
  v_image        text;
  v_group_ar     text;
  v_group_en     text;
  v_price        numeric;
  v_regular      numeric;
  v_available    boolean;
  v_reason       text;
  v_discount     numeric;
  v_currency     text;
  v_tax_rate     numeric := 0;
  v_tax_included boolean := true;
  v_subtotal     numeric := 0;
  v_tax          numeric := 0;
  v_total        numeric := 0;
  v_table        text;
  v_order_id     uuid;
  v_item_id      uuid;
  v_number       text;
  v_stock        record;
  v_on_hand      integer;
  v_allow_neg    boolean;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  v_note := left(btrim(coalesce(p_note, '')), 500);
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'idempotency key required' using errcode = '22023';
  end if;

  -- Serialise retries of the same checkout before looking the key up.
  perform pg_advisory_xact_lock(hashtext(p_idempotency_key));

  select * into v_existing
    from orders.orders o
   where o.idempotency_key = p_idempotency_key;

  if found then
    if v_existing.order_source <> 'pos' then
      raise exception 'idempotency key already used by another order'
        using errcode = '23505';
    end if;

    select * into v_existing_method
      from payments.payment_methods m
     where m.id = v_existing.payment_method_id;

    return jsonb_build_object(
      'order_id', v_existing.id,
      'order_number', v_existing.order_number,
      'subtotal', v_existing.subtotal,
      'tax_total', v_existing.tax_total,
      'grand_total', v_existing.grand_total,
      'currency_code', v_existing.currency_code,
      'fulfillment_type', v_existing.fulfillment_type,
      'table_number', v_existing.table_number,
      'payment_method_id', v_existing.payment_method_id,
      'payment_method_code', v_existing_method.code,
      'payment_method_name_ar', v_existing_method.name_ar,
      'payment_method_name_en', v_existing_method.name_en,
      'placed_at', v_existing.placed_at,
      'reused', true
    );
  end if;

  if p_fulfillment_type is null
     or p_fulfillment_type not in ('dine_in', 'pickup') then
    raise exception 'fulfillment type must be dine_in or pickup'
      using errcode = '22023';
  end if;

  v_table := nullif(btrim(coalesce(p_table_number, '')), '');
  if p_fulfillment_type = 'dine_in' then
    if v_table is null then
      raise exception 'table number is required for dine-in' using errcode = '23514';
    end if;
    if char_length(v_table) > 20 then
      raise exception 'table number is too long' using errcode = '23514';
    end if;
  else
    v_table := null;
  end if;

  select * into v_branch
    from core.branches b
   where b.id = p_branch_id
     and b.is_active;
  if not found then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select * into v_method
    from payments.payment_methods m
   where m.id = p_payment_method_id
     and m.is_active;
  if not found then
    raise exception 'payment method not found or inactive' using errcode = 'P0002';
  end if;

  if p_lines is null
     or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception 'an order needs at least one line' using errcode = '23514';
  end if;
  if jsonb_array_length(p_lines) > 100 then
    raise exception 'an order cannot have more than 100 lines' using errcode = '23514';
  end if;

  select coalesce(b.currency_code, 'SAR'),
         coalesce(b.tax_rate, 0),
         coalesce(b.tax_included, true)
    into v_currency, v_tax_rate, v_tax_included
    from core.brands b
   limit 1;

  -- Price and validate every line before anything is written.
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_product_id := nullif(v_line->>'product_id', '')::uuid;
    if v_product_id is null then
      raise exception 'every line needs a product' using errcode = '23514';
    end if;

    v_quantity := least(greatest(coalesce((v_line->>'quantity')::integer, 0), 0), 99);
    if v_quantity < 1 then
      raise exception 'quantity must be between 1 and 99' using errcode = '23514';
    end if;

    v_line_note := left(btrim(coalesce(v_line->>'note', '')), 240);

    if v_line ? 'option_value_ids'
       and jsonb_typeof(v_line->'option_value_ids') <> 'array' then
      raise exception 'option_value_ids must be an array' using errcode = '22023';
    end if;

    select coalesce(array_agg(value::uuid), '{}'::uuid[])
      into v_option_ids
      from jsonb_array_elements_text(
             case
               when v_line ? 'option_value_ids'
                 then v_line->'option_value_ids'
               else '[]'::jsonb
             end
           ) value;

    select p.name_ar, p.name_en, p.sku, p.image_url
      into v_name_ar, v_name_en, v_sku, v_image
      from catalog.products p
     where p.id = v_product_id
       and p.is_active
       and p.archived_at is null;

    if not found then
      raise exception 'product % is not on the menu', v_product_id
        using errcode = '23514';
    end if;

    select r.unit_price, r.regular_price, r.is_available, r.unavailable_reason
      into v_price, v_regular, v_available, v_reason
      from catalog.resolve_effective_price(
             p_branch_id, v_product_id, v_option_ids
           ) r;

    if not coalesce(v_available, false) then
      raise exception 'product % is not available at this branch: %',
        v_product_id, coalesce(v_reason, 'unavailable') using errcode = '23514';
    end if;

    select coalesce(string_agg(distinct g.name_ar, '، '), ''),
           coalesce(string_agg(distinct g.name_en, ', '), '')
      into v_group_ar, v_group_en
      from catalog.option_values ov
      join catalog.option_groups g on g.id = ov.group_id
     where ov.id = any(v_option_ids);

    select coalesce(jsonb_agg(
             jsonb_build_object(
               'option_value_id', ov.id,
               'name_ar', ov.name_ar,
               'name_en', ov.name_en,
               'price_delta', ov.price_delta
             ) order by g.sort_order, ov.sort_order
           ), '[]'::jsonb)
      into v_options
      from catalog.option_values ov
      join catalog.option_groups g on g.id = ov.group_id
     where ov.id = any(v_option_ids);

    v_discount := round(greatest(v_regular - v_price, 0) * v_quantity, 2);
    v_subtotal := round(v_subtotal + v_price * v_quantity, 2);

    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product_id,
        'name_ar', v_name_ar,
        'name_en', v_name_en,
        'sku', v_sku,
        'image_url', v_image,
        'group_ar', v_group_ar,
        'group_en', v_group_en,
        'unit_price', v_price,
        'quantity', v_quantity,
        'note', v_line_note,
        'discount', v_discount,
        'options', v_options
      )
    );
  end loop;

  if v_tax_included then
    v_tax := 0;
  else
    v_tax := round(v_subtotal * v_tax_rate / 100, 2);
  end if;
  v_total := round(v_subtotal + v_tax, 2);

  -- Lock and prove every tracked product before the order exists.
  for v_stock in
    select (item->>'product_id')::uuid as product_id,
           sum((item->>'quantity')::integer)::integer as quantity
      from jsonb_array_elements(v_items) item
     group by 1
     order by 1
  loop
    select bs.quantity_on_hand, bs.allow_negative
      into v_on_hand, v_allow_neg
      from inventory.branch_stock bs
     where bs.branch_id = p_branch_id
       and bs.product_id = v_stock.product_id
       and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
     for update;

    if found and not v_allow_neg and v_on_hand < v_stock.quantity then
      raise exception 'insufficient stock for product %', v_stock.product_id
        using errcode = '23514';
    end if;
  end loop;

  v_number := 'POS-' || to_char(now(), 'YYYY') || '-' ||
              lpad(nextval('orders.order_number_seq')::text, 6, '0');

  insert into orders.orders (
    order_number, user_id, branch_id, fulfillment_type, order_source,
    table_number, status, payment_method_id, payment_status,
    subtotal, discount_total, delivery_fee, tax_total, grand_total,
    currency_code, customer_note, loyalty_points_earned,
    idempotency_key
  ) values (
    v_number, null, p_branch_id, p_fulfillment_type, 'pos',
    v_table, 'confirmed', v_method.id, 'paid',
    v_subtotal, 0, 0, v_tax, v_total,
    v_currency, v_note, 0,
    p_idempotency_key
  ) returning id into v_order_id;

  -- Freeze the lines. The after-statement trigger sums product_discount_total
  -- into the order.
  for v_row in select value from jsonb_array_elements(v_items)
  loop
    insert into orders.order_items (
      order_id, product_id, option_group_name_ar, option_group_name_en,
      product_name_ar, product_name_en, sku_snapshot, image_snapshot,
      unit_price, quantity, line_total, note, product_discount_total
    ) values (
      v_order_id,
      (v_row->>'product_id')::uuid,
      v_row->>'group_ar',
      v_row->>'group_en',
      v_row->>'name_ar',
      v_row->>'name_en',
      v_row->>'sku',
      v_row->>'image_url',
      (v_row->>'unit_price')::numeric,
      (v_row->>'quantity')::integer,
      round((v_row->>'unit_price')::numeric * (v_row->>'quantity')::integer, 2),
      v_row->>'note',
      (v_row->>'discount')::numeric
    ) returning id into v_item_id;

    insert into orders.order_item_options (
      order_item_id, option_value_id, option_name_ar, option_name_en, price_delta
    )
    select v_item_id,
           (option->>'option_value_id')::uuid,
           option->>'name_ar',
           option->>'name_en',
           (option->>'price_delta')::numeric
      from jsonb_array_elements(v_row->'options') option;
  end loop;

  -- Deduct stock exactly once per product, with one ledger row per product.
  for v_stock in
    select (item->>'product_id')::uuid as product_id,
           sum((item->>'quantity')::integer)::integer as quantity
      from jsonb_array_elements(v_items) item
     group by 1
     order by 1
  loop
    if exists (
      select 1 from inventory.branch_stock bs
       where bs.branch_id = p_branch_id
         and bs.product_id = v_stock.product_id
         and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
    ) then
      update inventory.branch_stock
         set quantity_on_hand = quantity_on_hand - v_stock.quantity,
             updated_at = now()
       where branch_id = p_branch_id
         and product_id = v_stock.product_id
         and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

      insert into inventory.stock_movements (
        branch_id, product_id, variant_key, quantity_delta, reason,
        reference_type, reference_id, actor_user_id
      ) values (
        p_branch_id, v_stock.product_id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        -v_stock.quantity, 'sale', 'order', v_order_id, v_uid
      );
    end if;
  end loop;

  -- Counter payment. The cashier confirms the money at the counter, so the
  -- RPC records the capture itself; this is not a provider callback.
  if v_total > 0 then
    insert into payments.payment_transactions (
      order_id, provider, provider_reference, amount, currency_code,
      status, paid_at, verified_by_server
    ) values (
      v_order_id, 'pos_counter', v_number, v_total, v_currency,
      'captured', now(), true
    );
  end if;

  insert into orders.order_status_history (
    order_id, from_status, to_status, changed_by, note
  ) values (
    v_order_id, null, 'confirmed', v_uid, 'pos.placed'
  );

  insert into orders.order_events (order_id, event_type, payload)
  values (
    v_order_id,
    'order.placed',
    jsonb_build_object(
      'source', 'pos',
      'branch_id', p_branch_id,
      'staff_user_id', v_uid,
      'fulfillment_type', p_fulfillment_type,
      'table_number', v_table,
      'payment_method', v_method.code,
      'total', v_total
    )
  );

  perform identity.audit(
    'pos.order.create',
    'order',
    v_order_id,
    null,
    jsonb_build_object(
      'order_number', v_number,
      'total', v_total,
      'fulfillment_type', p_fulfillment_type,
      'table_number', v_table,
      'payment_method', v_method.code
    ),
    p_branch_id
  );

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_number,
    'subtotal', v_subtotal,
    'tax_total', v_tax,
    'grand_total', v_total,
    'currency_code', v_currency,
    'fulfillment_type', p_fulfillment_type,
    'table_number', v_table,
    'payment_method_id', v_method.id,
    'payment_method_code', v_method.code,
    'payment_method_name_ar', v_method.name_ar,
    'payment_method_name_en', v_method.name_en,
    'placed_at', now(),
    'reused', false
  );
end;
$fn$;

comment on function public.admin_pos_place_order(uuid, jsonb, text, uuid, text, text, text) is
  'Atomic, idempotent POS checkout. Server-priced, stock-aware, paid at the counter, feeds the kitchen.';

revoke all on function public.admin_pos_place_order(uuid, jsonb, text, uuid, text, text, text)
  from public, anon;
grant execute on function public.admin_pos_place_order(uuid, jsonb, text, uuid, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. The orders directory learns where an order came from
-- ---------------------------------------------------------------------------
create or replace function public.admin_orders()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id,
      'order_number', o.order_number,
      'user_id', o.user_id,
      'customer_name', p.full_name,
      'customer_email', p.email,
      'customer_phone', p.phone,
      'customer_avatar_url', p.avatar_url,
      'branch_id', o.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'branch_latitude', b.latitude,
      'branch_longitude', b.longitude,
      'fulfillment_type', o.fulfillment_type,
      'order_source', o.order_source,
      'table_number', o.table_number,
      'status', o.status,
      'payment_method_id', o.payment_method_id,
      'payment_status', o.payment_status,
      'subtotal', o.subtotal,
      'discount_total', o.discount_total,
      'product_discount_total', o.product_discount_total,
      'delivery_fee', o.delivery_fee,
      'tax_total', o.tax_total,
      'grand_total', o.grand_total,
      'currency_code', o.currency_code,
      'customer_note', o.customer_note,
      'placed_at', o.placed_at,
      'completed_at', o.completed_at,
      'delivery_address_snapshot', o.delivery_address_snapshot,
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', oi.id,
          'product_id', oi.product_id,
          'product_name_ar', oi.product_name_ar,
          'product_name_en', oi.product_name_en,
          'image_url', oi.image_snapshot,
          'option_group_name_ar', oi.option_group_name_ar,
          'option_group_name_en', oi.option_group_name_en,
          'quantity', oi.quantity,
          'unit_price', oi.unit_price,
          'line_total', oi.line_total,
          'note', oi.note
        ) order by oi.id)
        from orders.order_items oi
        where oi.order_id = o.id
      ), '[]'::jsonb)
    ) order by o.placed_at desc)
    from orders.orders o
    left join identity.profiles p on p.id = o.user_id
    left join core.branches b on b.id = o.branch_id
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_orders() is
  'Every order with its customer, branch, source, table and line snapshots.';

revoke all on function public.admin_orders() from public, anon;
grant execute on function public.admin_orders() to authenticated;

notify pgrst, 'reload schema';
