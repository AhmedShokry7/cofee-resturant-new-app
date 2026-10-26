-- Migration 181: the POS checkout accepts a dine-in order with no table label.
--
-- 180 made the dining table optional on the table-aware wrapper, which calls
-- public.admin_pos_place_order with a null table label for counter sales that
-- are not seated. The label-only checkout still rejected that case, so the
-- guard is removed here. Table-aware sales keep passing a real table name and
-- retain the 20-character label check. The function stays internal: 177
-- revoked it from API roles, so the wrapper remains the only entry point.

create or replace function public.admin_pos_place_order(
  p_branch_id         uuid,
  p_lines             jsonb,
  p_fulfillment_type  text,
  p_payment_method_id uuid,
  p_idempotency_key   text,
  p_table_number      text default null,
  p_note              text default null,
  p_customer_id       uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid                uuid := auth.uid();
  v_existing           orders.orders%rowtype;
  v_existing_method    payments.payment_methods%rowtype;
  v_branch             core.branches%rowtype;
  v_method             payments.payment_methods%rowtype;
  v_line               jsonb;
  v_row                jsonb;
  v_items              jsonb := '[]'::jsonb;
  v_options            jsonb;
  v_option_ids         uuid[];
  v_product_id         uuid;
  v_quantity           integer;
  v_note               text;
  v_line_note          text;
  v_name_ar            text;
  v_name_en            text;
  v_sku                text;
  v_image              text;
  v_group_ar           text;
  v_group_en           text;
  v_price              numeric;
  v_regular            numeric;
  v_available          boolean;
  v_reason             text;
  v_discount           numeric;
  v_currency           text;
  v_tax_rate           numeric := 0;
  v_tax_included       boolean := true;
  v_subtotal           numeric := 0;
  v_tax                numeric := 0;
  v_total              numeric := 0;
  v_table              text;
  v_order_id           uuid;
  v_item_id            uuid;
  v_number             text;
  v_stock              record;
  v_on_hand            integer;
  v_allow_neg          boolean;
  v_user_id            uuid;
  v_pos_customer_id    uuid;
  v_customer_name      text;
  v_customer_phone     text;
  v_customer_source    text;
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

    if v_existing.user_id is not null then
      select p.full_name, p.phone
        into v_customer_name, v_customer_phone
        from identity.profiles p
       where p.id = v_existing.user_id;
      v_customer_source := 'registered';
    elsif v_existing.pos_customer_id is not null then
      select c.full_name, c.phone
        into v_customer_name, v_customer_phone
        from orders.pos_customers c
       where c.id = v_existing.pos_customer_id;
      v_customer_source := 'walk_in';
    end if;

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
      'customer_id', coalesce(v_existing.user_id, v_existing.pos_customer_id),
      'customer_name', v_customer_name,
      'customer_phone', v_customer_phone,
      'customer_source', v_customer_source,
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
    if char_length(v_table) > 20 then
      raise exception 'table number is too long' using errcode = '23514';
    end if;
  else
    v_table := null;
  end if;

  -- A registered customer links the order to their account, so their history
  -- and notifications stay complete. A counter customer needs no auth row.
  if p_customer_id is not null then
    select p.full_name, p.phone
      into v_customer_name, v_customer_phone
      from identity.profiles p
     where p.id = p_customer_id
       and not p.is_blacklisted
       and not exists (
         select 1 from identity.staff_members sm where sm.user_id = p.id
       );

    if found then
      v_user_id := p_customer_id;
      v_customer_source := 'registered';
    else
      select c.full_name, c.phone
        into v_customer_name, v_customer_phone
        from orders.pos_customers c
       where c.id = p_customer_id;

      if found then
        v_pos_customer_id := p_customer_id;
        v_customer_source := 'walk_in';
      else
        raise exception 'customer not found' using errcode = 'P0002';
      end if;
    end if;
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
    idempotency_key, pos_customer_id
  ) values (
    v_number, v_user_id, p_branch_id, p_fulfillment_type, 'pos',
    v_table, 'confirmed', v_method.id, 'paid',
    v_subtotal, 0, 0, v_tax, v_total,
    v_currency, v_note, 0,
    p_idempotency_key, v_pos_customer_id
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
      'customer_id', coalesce(v_user_id, v_pos_customer_id),
      'customer_source', v_customer_source,
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
      'payment_method', v_method.code,
      'customer_id', coalesce(v_user_id, v_pos_customer_id),
      'customer_source', v_customer_source,
      'customer_name', v_customer_name
    ),
    p_branch_id
  );

  -- The order insert already created its kitchen ticket through 174's trigger.
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
    'customer_id', coalesce(v_user_id, v_pos_customer_id),
    'customer_name', v_customer_name,
    'customer_phone', v_customer_phone,
    'customer_source', v_customer_source,
    'placed_at', now(),
    'reused', false
  );
end;
$fn$;

comment on function public.admin_pos_place_order(
  uuid, jsonb, text, uuid, text, text, text, uuid
) is
  'Atomic, idempotent POS checkout with an optional customer. Server-priced,
   stock-aware, paid at the counter and dispatched to the kitchen. A dine-in
   table label is optional; the table-aware wrapper owns floor validation.';

notify pgrst, 'reload schema';
