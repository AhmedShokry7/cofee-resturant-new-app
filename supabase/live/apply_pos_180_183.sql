-- POS checkout, cashier shifts and sidebar counters: apply migrations 180,
-- 181, 182 and 183 in order.
-- Paste this whole file into the Supabase SQL Editor and run it once.
-- Safe to re-run: tables, functions and triggers are created or replaced.

begin;

-- ===== 180_admin_pos_optional_table.sql =====

-- Migration 180: the dining table is optional on POS orders.
--
-- The counter can send a paid walk-in order to the kitchen without assigning
-- it to a table. Choosing a table keeps the 179 behaviour: it must be an
-- active table of the branch, it is locked against concurrent sales while
-- occupancy and nearby bookings are checked, and a seated reservation is
-- linked to the order. Without a table the same priced, stock-aware,
-- kitchen-dispatching checkout runs and no floor record is touched.
-- Migration 181 relaxes the label-only checkout that this wrapper calls so it
-- no longer demands a table number for dine-in.

create or replace function public.admin_pos_place_table_order(
  p_branch_id         uuid,
  p_lines             jsonb,
  p_fulfillment_type  text,
  p_payment_method_id uuid,
  p_idempotency_key   text,
  p_table_id          uuid,
  p_note              text default null,
  p_customer_id       uuid default null,
  p_payments          jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_existing        orders.orders%rowtype;
  v_table           floor.tables%rowtype;
  v_reservation_id  uuid;
  v_active_order    text;
  v_result          jsonb;
  v_tenders         jsonb;
  v_order_id        uuid;
  v_table_name      text;
  v_table_number    text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'idempotency key required' using errcode = '22023';
  end if;

  -- Retries return the committed order before any table check.
  select * into v_existing
    from orders.orders o
   where o.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.order_source <> 'pos' then
      raise exception 'idempotency key already used by another order'
        using errcode = '23505';
    end if;
    if v_existing.floor_table_id is not null then
      select t.name
        into v_table_name
        from floor.tables t
       where t.id = v_existing.floor_table_id;
    end if;

    v_result := public.admin_pos_place_order(
      p_branch_id,
      p_lines,
      p_fulfillment_type,
      p_payment_method_id,
      p_idempotency_key,
      v_existing.table_number,
      p_note,
      p_customer_id
    );

    return v_result
      || payments.pos_tender_breakdown(v_existing.id)
      || payments.pos_invoice_summary(v_existing.id)
      || jsonb_build_object(
           'table_id', v_existing.floor_table_id,
           'table_name', coalesce(v_table_name, v_existing.table_number),
           'reservation_id', v_existing.dining_reservation_id
         );
  end if;

  if p_fulfillment_type is distinct from 'dine_in' then
    raise exception 'pos orders are dine-in only' using errcode = '22023';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  if p_table_id is not null then
    select * into v_table
      from floor.tables t
     where t.id = p_table_id
       and t.branch_id = p_branch_id
       and t.is_active;
    if not found then
      raise exception 'table is not available' using errcode = '23514';
    end if;
    v_table_number := v_table.name;

    perform pg_advisory_xact_lock(hashtext('floor.table:' || p_table_id::text));

    -- The same key may have committed while this call waited for the lock.
    select * into v_existing
      from orders.orders o
     where o.idempotency_key = p_idempotency_key;
    if found then
      select t.name
        into v_table_name
        from floor.tables t
       where t.id = v_existing.floor_table_id;

      v_result := public.admin_pos_place_order(
        p_branch_id,
        p_lines,
        p_fulfillment_type,
        p_payment_method_id,
        p_idempotency_key,
        v_existing.table_number,
        p_note,
        p_customer_id
      );

      return v_result
        || payments.pos_tender_breakdown(v_existing.id)
        || payments.pos_invoice_summary(v_existing.id)
        || jsonb_build_object(
             'table_id', v_existing.floor_table_id,
             'table_name', coalesce(v_table_name, v_existing.table_number),
             'reservation_id', v_existing.dining_reservation_id
           );
    end if;

    select o.order_number
      into v_active_order
      from orders.orders o
     where o.floor_table_id = p_table_id
       and o.status not in ('completed', 'cancelled')
     order by o.placed_at desc
     limit 1;
    if found then
      raise exception 'table is occupied' using errcode = '23514';
    end if;

    select r.id
      into v_reservation_id
      from floor.reservations r
     where r.table_id = p_table_id
       and r.status = 'seated'
     order by r.reserved_for
     limit 1;

    if v_reservation_id is null and exists (
      select 1
        from floor.reservations r
       where r.table_id = p_table_id
         and r.status = 'confirmed'
         and r.reserved_for <= now() + interval '30 minutes'
         and r.reserved_for + make_interval(mins => r.duration_minutes) > now()
    ) then
      raise exception 'table is reserved' using errcode = '23514';
    end if;
  end if;

  v_result := public.admin_pos_place_order(
    p_branch_id,
    p_lines,
    'dine_in',
    p_payment_method_id,
    p_idempotency_key,
    v_table_number,
    p_note,
    p_customer_id
  );
  v_order_id := (v_result->>'order_id')::uuid;

  if p_table_id is not null then
    update orders.orders
       set floor_table_id = p_table_id,
           dining_reservation_id = v_reservation_id
     where id = v_order_id;

    if v_reservation_id is not null then
      update floor.reservations
         set order_id = v_order_id
       where id = v_reservation_id
         and (order_id is null or order_id = v_order_id);
    end if;
  end if;

  -- The base checkout already created the order, its stock movements, its
  -- kitchen ticket and one placeholder capture. This swaps the capture for
  -- one row per tender and rejects the whole transaction if the split is
  -- invalid.
  v_tenders := payments.replace_pos_tenders(
    v_order_id,
    v_result->>'order_number',
    (v_result->>'grand_total')::numeric,
    v_result->>'currency_code',
    p_payment_method_id,
    p_payments
  );

  return v_result
    || v_tenders
    || payments.pos_invoice_summary(v_order_id)
    || jsonb_build_object(
         'table_id', p_table_id,
         'table_name', v_table_number,
         'reservation_id', v_reservation_id
       );
end;
$fn$;

comment on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) is
  'Atomic POS checkout for dine-in where the table is optional. A chosen table '
  'is locked and checked against occupancy and bookings; the checkout prices '
  'the lines, moves stock, dispatches the kitchen ticket, accepts one or two '
  'cash/card tenders that must equal the total, and returns the tax invoice '
  'summary.';

revoke all on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) from public, anon;
grant execute on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) to authenticated;

notify pgrst, 'reload schema';

-- ===== 181_admin_pos_tableless_checkout.sql =====

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

-- ===== 182_admin_pos_cashier_shifts.sql =====

-- Migration 182: cashier shifts and the cash-drawer close.
--
-- The counter could take a paid order but had no register session: there was
-- no opening float, no record of paid-in/paid-out cash and no end-of-shift
-- count. This migration adds the missing cashier controls:
--
--   1. payments.pos_shifts — one open shift per branch. The branch is the
--      drawer: every counter terminal in that branch sells into the same
--      session, so the expected cash can never be double-counted when two
--      cashiers work the same floor.
--   2. payments.pos_shift_movements — paid-in and paid-out cash with a reason,
--      stamped with the staff member who recorded it.
--   3. orders.orders.pos_shift_id — every counter sale belongs to the shift
--      that was open when it was confirmed.
--   4. public.admin_pos_* RPCs to open a shift, read it, record a movement,
--      close it (counting the drawer and storing the variance) and browse the
--      shift history of a branch.
--   5. The table-aware checkout now refuses a sale without an open shift and
--      stamps the order with it. A shift close waits for in-flight checkouts,
--      so the Z totals always include every sale of the session.
--
-- Money is numeric(12,2) and computed on the server. The expected cash is:
--   opening float + captured cash tenders + paid-in − paid-out.
-- Card tenders never affect the drawer. The values are snapshotted when the
-- shift closes so a later refund or catalog change cannot rewrite the report.

-- ---------------------------------------------------------------------------
-- 1. The shift (one open drawer per branch)
-- ---------------------------------------------------------------------------
create table if not exists payments.pos_shifts (
  id              uuid primary key default extensions.gen_random_uuid(),
  branch_id       uuid not null references core.branches(id) on delete restrict,
  status          text not null default 'open'
                    check (status in ('open', 'closed')),
  opening_float   numeric(12,2) not null default 0
                    check (opening_float >= 0),
  opened_by       uuid not null references identity.staff_members(id)
                    on delete restrict,
  opened_at       timestamptz not null default now(),
  closed_by       uuid references identity.staff_members(id) on delete set null,
  closed_at       timestamptz,
  -- Snapshotted when the drawer is counted, null while the shift is open.
  cash_sales      numeric(12,2) check (cash_sales is null or cash_sales >= 0),
  card_sales      numeric(12,2) check (card_sales is null or card_sales >= 0),
  sales_total     numeric(12,2) check (sales_total is null or sales_total >= 0),
  order_count     integer check (order_count is null or order_count >= 0),
  cash_in_total   numeric(12,2)
                    check (cash_in_total is null or cash_in_total >= 0),
  cash_out_total  numeric(12,2)
                    check (cash_out_total is null or cash_out_total >= 0),
  expected_cash   numeric(12,2)
                    check (expected_cash is null or expected_cash >= 0),
  counted_cash    numeric(12,2) check (counted_cash is null or counted_cash >= 0),
  variance        numeric(12,2),
  note            text not null default '',
  close_note      text not null default '',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint ck_pos_shift_closed check (
    (
      status = 'open'
      and closed_at is null
      and closed_by is null
      and counted_cash is null
      and expected_cash is null
      and variance is null
    )
    or (
      status = 'closed'
      and closed_at is not null
      and closed_by is not null
      and counted_cash is not null
      and expected_cash is not null
      and variance is not null
    )
  ),
  constraint ck_pos_shift_variance check (
    variance is null or variance = round(counted_cash - expected_cash, 2)
  )
);

comment on table payments.pos_shifts is
  'Cashier shift / register session. One open shift per branch; the branch is '
  'the cash drawer. Closed rows keep the Z totals counted at close time.';

create unique index if not exists uq_pos_shift_open_branch
  on payments.pos_shifts (branch_id)
  where status = 'open';

create index if not exists ix_pos_shift_branch_time
  on payments.pos_shifts (branch_id, opened_at desc);

drop trigger if exists tr_pos_shifts_updated_at on payments.pos_shifts;
create trigger tr_pos_shifts_updated_at
  before update on payments.pos_shifts
  for each row execute function core.set_updated_at();

alter table payments.pos_shifts enable row level security;
revoke all on payments.pos_shifts from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Paid-in / paid-out cash
-- ---------------------------------------------------------------------------
create table if not exists payments.pos_shift_movements (
  id          uuid primary key default extensions.gen_random_uuid(),
  shift_id    uuid not null references payments.pos_shifts(id) on delete cascade,
  kind        text not null check (kind in ('cash_in', 'cash_out')),
  amount      numeric(12,2) not null check (amount > 0),
  reason      text not null check (btrim(reason) <> ''),
  created_by  uuid not null references identity.staff_members(id)
                on delete restrict,
  created_at  timestamptz not null default now()
);

comment on table payments.pos_shift_movements is
  'Cash paid into or taken out of the drawer during a shift. Every row names '
  'the staff member and the reason.';

create index if not exists ix_pos_shift_movements_shift
  on payments.pos_shift_movements (shift_id, created_at desc);

alter table payments.pos_shift_movements enable row level security;
revoke all on payments.pos_shift_movements from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Every counter order belongs to the shift that sold it
-- ---------------------------------------------------------------------------
alter table orders.orders
  add column if not exists pos_shift_id uuid
    references payments.pos_shifts(id) on delete set null;

comment on column orders.orders.pos_shift_id is
  'The cashier shift that confirmed this counter order. Null for app orders '
  'and for counter orders that predate shifts.';

create index if not exists ix_orders_pos_shift
  on orders.orders (pos_shift_id)
  where pos_shift_id is not null;

-- ---------------------------------------------------------------------------
-- 4. Live totals of a shift
-- ---------------------------------------------------------------------------
create or replace function payments.pos_shift_totals(p_shift_id uuid)
returns table (
  cash_sales     numeric,
  card_sales     numeric,
  sales_total    numeric,
  order_count    integer,
  cash_in_total  numeric,
  cash_out_total numeric
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select
    coalesce((
      select sum(t.amount)
        from orders.orders o
        join payments.payment_transactions t
          on t.order_id = o.id
         and t.provider = 'pos_counter'
         and t.status = 'captured'
        join payments.payment_methods m
          on m.id = coalesce(t.method_id, o.payment_method_id)
       where o.pos_shift_id = p_shift_id
         and m.code = 'cash'
    ), 0)::numeric,
    coalesce((
      select sum(t.amount)
        from orders.orders o
        join payments.payment_transactions t
          on t.order_id = o.id
         and t.provider = 'pos_counter'
         and t.status = 'captured'
        join payments.payment_methods m
          on m.id = coalesce(t.method_id, o.payment_method_id)
       where o.pos_shift_id = p_shift_id
         and m.code = 'card'
    ), 0)::numeric,
    coalesce((
      select sum(o.grand_total)
        from orders.orders o
       where o.pos_shift_id = p_shift_id
    ), 0)::numeric,
    coalesce((
      select count(*)::integer
        from orders.orders o
       where o.pos_shift_id = p_shift_id
    ), 0),
    coalesce((
      select sum(mv.amount)
        from payments.pos_shift_movements mv
       where mv.shift_id = p_shift_id
         and mv.kind = 'cash_in'
    ), 0)::numeric,
    coalesce((
      select sum(mv.amount)
        from payments.pos_shift_movements mv
       where mv.shift_id = p_shift_id
         and mv.kind = 'cash_out'
    ), 0)::numeric;
$fn$;

comment on function payments.pos_shift_totals(uuid) is
  'Live tender totals of a shift: cash, card, sales, orders and cash movements.';

revoke all on function payments.pos_shift_totals(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. One JSON shape for the shift, its drawer maths and its movements
-- ---------------------------------------------------------------------------
create or replace function payments.pos_shift_json(
  p_shift_id uuid,
  p_with_movements boolean default true
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_shift         payments.pos_shifts%rowtype;
  v_totals        record;
  v_currency      text;
  v_opened_name   text;
  v_closed_name   text;
  v_cash_sales    numeric;
  v_card_sales    numeric;
  v_sales_total   numeric;
  v_order_count   integer;
  v_cash_in       numeric;
  v_cash_out      numeric;
  v_expected      numeric;
  v_movements     jsonb := '[]'::jsonb;
begin
  select *
    into v_shift
    from payments.pos_shifts s
   where s.id = p_shift_id;
  if not found then
    return null;
  end if;

  select * into v_totals from payments.pos_shift_totals(p_shift_id);

  if v_shift.status = 'closed' then
    v_cash_sales := coalesce(v_shift.cash_sales, 0);
    v_card_sales := coalesce(v_shift.card_sales, 0);
    v_sales_total := coalesce(v_shift.sales_total, 0);
    v_order_count := coalesce(v_shift.order_count, 0);
    v_cash_in := coalesce(v_shift.cash_in_total, 0);
    v_cash_out := coalesce(v_shift.cash_out_total, 0);
    v_expected := coalesce(v_shift.expected_cash, 0);
  else
    v_cash_sales := coalesce(v_totals.cash_sales, 0);
    v_card_sales := coalesce(v_totals.card_sales, 0);
    v_sales_total := coalesce(v_totals.sales_total, 0);
    v_order_count := coalesce(v_totals.order_count, 0);
    v_cash_in := coalesce(v_totals.cash_in_total, 0);
    v_cash_out := coalesce(v_totals.cash_out_total, 0);
    v_expected := round(
      v_shift.opening_float + v_cash_sales + v_cash_in - v_cash_out,
      2
    );
  end if;

  select coalesce(b.currency_code, 'SAR')
    into v_currency
    from core.brands b
   limit 1;

  select sm.full_name
    into v_opened_name
    from identity.staff_members sm
   where sm.id = v_shift.opened_by;

  if v_shift.closed_by is not null then
    select sm.full_name
      into v_closed_name
      from identity.staff_members sm
     where sm.id = v_shift.closed_by;
  end if;

  if p_with_movements then
    select coalesce(jsonb_agg(
             jsonb_build_object(
               'id', mv.id,
               'kind', mv.kind,
               'amount', mv.amount,
               'reason', mv.reason,
               'created_at', mv.created_at,
               'created_by_name', sm.full_name
             ) order by mv.created_at desc
           ), '[]'::jsonb)
      into v_movements
      from payments.pos_shift_movements mv
      left join identity.staff_members sm on sm.id = mv.created_by
     where mv.shift_id = p_shift_id;
  end if;

  return jsonb_build_object(
    'id', v_shift.id,
    'branch_id', v_shift.branch_id,
    'status', v_shift.status,
    'opening_float', v_shift.opening_float,
    'cash_sales', v_cash_sales,
    'card_sales', v_card_sales,
    'sales_total', v_sales_total,
    'order_count', v_order_count,
    'cash_in', v_cash_in,
    'cash_out', v_cash_out,
    'expected_cash', v_expected,
    'counted_cash', v_shift.counted_cash,
    'variance', v_shift.variance,
    'currency_code', coalesce(v_currency, 'SAR'),
    'opened_at', v_shift.opened_at,
    'closed_at', v_shift.closed_at,
    'opened_by_name', coalesce(v_opened_name, ''),
    'closed_by_name', coalesce(v_closed_name, ''),
    'note', v_shift.note,
    'close_note', v_shift.close_note,
    'movements', v_movements
  );
end;
$fn$;

comment on function payments.pos_shift_json(uuid, boolean) is
  'The shift report: live totals while open, the stored Z totals once closed.';

revoke all on function payments.pos_shift_json(uuid, boolean)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Public RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_shift(p_branch_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_shift_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select s.id
    into v_shift_id
    from payments.pos_shifts s
   where s.branch_id = p_branch_id
     and s.status = 'open';

  if v_shift_id is null then
    return null;
  end if;
  return payments.pos_shift_json(v_shift_id, true);
end;
$fn$;

comment on function public.admin_pos_shift(uuid) is
  'The open cashier shift of a branch, or null when the drawer is closed.';

create or replace function public.admin_pos_open_shift(
  p_branch_id     uuid,
  p_opening_float numeric,
  p_note          text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_staff_id  uuid;
  v_shift_id  uuid;
  v_existing  uuid;
  v_note      text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if not exists (
    select 1 from core.branches b where b.id = p_branch_id and b.is_active
  ) then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;
  if p_opening_float is null
     or p_opening_float < 0
     or p_opening_float > 1000000 then
    raise exception 'invalid opening float' using errcode = '22023';
  end if;

  select sm.id
    into v_staff_id
    from identity.staff_members sm
   where sm.user_id = auth.uid()
     and sm.status = 'active';
  if v_staff_id is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  v_note := left(btrim(coalesce(p_note, '')), 240);

  -- Opening twice is harmless: the first open shift is returned instead of
  -- creating a second drawer for the same branch.
  select s.id
    into v_existing
    from payments.pos_shifts s
   where s.branch_id = p_branch_id
     and s.status = 'open';
  if v_existing is not null then
    return payments.pos_shift_json(v_existing, true)
      || jsonb_build_object('already_open', true);
  end if;

  begin
    insert into payments.pos_shifts (
      branch_id, status, opening_float, opened_by, note
    ) values (
      p_branch_id, 'open', round(p_opening_float, 2), v_staff_id, v_note
    )
    returning id into v_shift_id;
  exception
    when unique_violation then
      select s.id
        into v_shift_id
        from payments.pos_shifts s
       where s.branch_id = p_branch_id
         and s.status = 'open';
      if v_shift_id is null then
        raise;
      end if;
      return payments.pos_shift_json(v_shift_id, true)
        || jsonb_build_object('already_open', true);
  end;

  perform identity.audit(
    'pos.shift.open',
    'pos_shift',
    v_shift_id,
    null,
    jsonb_build_object(
      'branch_id', p_branch_id,
      'opening_float', round(p_opening_float, 2)
    ),
    p_branch_id
  );

  return payments.pos_shift_json(v_shift_id, true)
    || jsonb_build_object('already_open', false);
end;
$fn$;

comment on function public.admin_pos_open_shift(uuid, numeric, text) is
  'Opens the branch drawer with an opening float. Idempotent while a shift is '
  'already open.';

create or replace function public.admin_pos_record_cash_movement(
  p_shift_id uuid,
  p_kind     text,
  p_amount   numeric,
  p_reason   text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_staff_id uuid;
  v_shift    payments.pos_shifts%rowtype;
  v_reason   text;
  v_amount   numeric;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  select sm.id
    into v_staff_id
    from identity.staff_members sm
   where sm.user_id = auth.uid()
     and sm.status = 'active';
  if v_staff_id is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_shift
    from payments.pos_shifts s
   where s.id = p_shift_id
   for update;
  if not found then
    raise exception 'cashier shift not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_shift.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_shift.status <> 'open' then
    raise exception 'cashier shift is closed' using errcode = '23514';
  end if;
  if p_kind is null or p_kind not in ('cash_in', 'cash_out') then
    raise exception 'invalid cash movement kind' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    raise exception 'invalid cash movement amount' using errcode = '22023';
  end if;

  v_amount := round(p_amount, 2);
  v_reason := left(btrim(coalesce(p_reason, '')), 240);
  if v_reason = '' then
    raise exception 'a cash movement needs a reason' using errcode = '22023';
  end if;

  insert into payments.pos_shift_movements (
    shift_id, kind, amount, reason, created_by
  ) values (
    p_shift_id, p_kind, v_amount, v_reason, v_staff_id
  );

  perform identity.audit(
    'pos.shift.' || p_kind,
    'pos_shift',
    p_shift_id,
    null,
    jsonb_build_object('amount', v_amount, 'reason', v_reason),
    v_shift.branch_id
  );

  return payments.pos_shift_json(p_shift_id, true);
end;
$fn$;

comment on function public.admin_pos_record_cash_movement(uuid, text, numeric, text) is
  'Records cash paid into or taken out of the open drawer, with a reason.';

create or replace function public.admin_pos_close_shift(
  p_shift_id     uuid,
  p_counted_cash numeric,
  p_close_note   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_staff_id uuid;
  v_shift    payments.pos_shifts%rowtype;
  v_totals   record;
  v_expected numeric;
  v_counted  numeric;
  v_variance numeric;
  v_note     text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  select sm.id
    into v_staff_id
    from identity.staff_members sm
   where sm.user_id = auth.uid()
     and sm.status = 'active';
  if v_staff_id is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  -- The row lock waits for in-flight checkouts that hold the same shift in
  -- share mode, so every sale of the session is in the Z totals.
  select *
    into v_shift
    from payments.pos_shifts s
   where s.id = p_shift_id
   for update;
  if not found then
    raise exception 'cashier shift not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_shift.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_shift.status <> 'open' then
    raise exception 'cashier shift is closed' using errcode = '23514';
  end if;
  if p_counted_cash is null
     or p_counted_cash < 0
     or p_counted_cash > 1000000 then
    raise exception 'invalid counted cash' using errcode = '22023';
  end if;

  select * into v_totals from payments.pos_shift_totals(p_shift_id);

  v_counted := round(p_counted_cash, 2);
  v_expected := round(
    v_shift.opening_float
    + coalesce(v_totals.cash_sales, 0)
    + coalesce(v_totals.cash_in_total, 0)
    - coalesce(v_totals.cash_out_total, 0),
    2
  );
  v_variance := round(v_counted - v_expected, 2);
  v_note := left(btrim(coalesce(p_close_note, '')), 500);

  update payments.pos_shifts
     set status = 'closed',
         closed_by = v_staff_id,
         closed_at = now(),
         cash_sales = coalesce(v_totals.cash_sales, 0),
         card_sales = coalesce(v_totals.card_sales, 0),
         sales_total = coalesce(v_totals.sales_total, 0),
         order_count = coalesce(v_totals.order_count, 0),
         cash_in_total = coalesce(v_totals.cash_in_total, 0),
         cash_out_total = coalesce(v_totals.cash_out_total, 0),
         expected_cash = v_expected,
         counted_cash = v_counted,
         variance = v_variance,
         close_note = v_note
   where id = p_shift_id;

  perform identity.audit(
    'pos.shift.close',
    'pos_shift',
    p_shift_id,
    jsonb_build_object('status', 'open'),
    jsonb_build_object(
      'expected_cash', v_expected,
      'counted_cash', v_counted,
      'variance', v_variance,
      'order_count', coalesce(v_totals.order_count, 0)
    ),
    v_shift.branch_id
  );

  return payments.pos_shift_json(p_shift_id, true);
end;
$fn$;

comment on function public.admin_pos_close_shift(uuid, numeric, text) is
  'Counts the drawer, stores the Z totals and the variance, and closes the '
  'shift.';

create or replace function public.admin_pos_shifts(
  p_branch_id uuid,
  p_limit     integer default 20,
  p_offset    integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_limit  integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(
           payments.pos_shift_json(s.id, false) order by s.opened_at desc
         ), '[]'::jsonb)
    into v_result
    from (
      select s.id, s.opened_at
        from payments.pos_shifts s
       where s.branch_id = p_branch_id
       order by s.opened_at desc
       limit v_limit
       offset v_offset
    ) s;

  return v_result;
end;
$fn$;

comment on function public.admin_pos_shifts(uuid, integer, integer) is
  'The branch shift history, newest first, without movement rows.';

create or replace function public.admin_pos_shift_detail(p_shift_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_branch_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  select s.branch_id
    into v_branch_id
    from payments.pos_shifts s
   where s.id = p_shift_id;
  if v_branch_id is null then
    raise exception 'cashier shift not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  return payments.pos_shift_json(p_shift_id, true);
end;
$fn$;

comment on function public.admin_pos_shift_detail(uuid) is
  'One shift report with its cash movements, for the history detail view.';

-- ---------------------------------------------------------------------------
-- 7. The checkout joins the open shift
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_place_table_order(
  p_branch_id         uuid,
  p_lines             jsonb,
  p_fulfillment_type  text,
  p_payment_method_id uuid,
  p_idempotency_key   text,
  p_table_id          uuid,
  p_note              text default null,
  p_customer_id       uuid default null,
  p_payments          jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_existing        orders.orders%rowtype;
  v_table           floor.tables%rowtype;
  v_shift           payments.pos_shifts%rowtype;
  v_reservation_id  uuid;
  v_active_order    text;
  v_result          jsonb;
  v_tenders         jsonb;
  v_order_id        uuid;
  v_table_name      text;
  v_table_number    text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'idempotency key required' using errcode = '22023';
  end if;

  -- Retries return the committed order before any shift or table check.
  select * into v_existing
    from orders.orders o
   where o.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.order_source <> 'pos' then
      raise exception 'idempotency key already used by another order'
        using errcode = '23505';
    end if;
    if v_existing.floor_table_id is not null then
      select t.name
        into v_table_name
        from floor.tables t
       where t.id = v_existing.floor_table_id;
    end if;

    v_result := public.admin_pos_place_order(
      p_branch_id,
      p_lines,
      p_fulfillment_type,
      p_payment_method_id,
      p_idempotency_key,
      v_existing.table_number,
      p_note,
      p_customer_id
    );

    return v_result
      || payments.pos_tender_breakdown(v_existing.id)
      || payments.pos_invoice_summary(v_existing.id)
      || jsonb_build_object(
           'table_id', v_existing.floor_table_id,
           'table_name', coalesce(v_table_name, v_existing.table_number),
           'reservation_id', v_existing.dining_reservation_id,
           'shift_id', v_existing.pos_shift_id
         );
  end if;

  if p_fulfillment_type is distinct from 'dine_in' then
    raise exception 'pos orders are dine-in only' using errcode = '22023';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  -- A counter sale must belong to an open drawer. The share lock lets several
  -- checkouts run together while a close waits for them to commit.
  select *
    into v_shift
    from payments.pos_shifts s
   where s.branch_id = p_branch_id
     and s.status = 'open'
   for share;
  if not found then
    raise exception 'open a cashier shift before checkout'
      using errcode = '23514';
  end if;

  if p_table_id is not null then
    select * into v_table
      from floor.tables t
     where t.id = p_table_id
       and t.branch_id = p_branch_id
       and t.is_active;
    if not found then
      raise exception 'table is not available' using errcode = '23514';
    end if;
    v_table_number := v_table.name;

    perform pg_advisory_xact_lock(hashtext('floor.table:' || p_table_id::text));

    -- The same key may have committed while this call waited for the lock.
    select * into v_existing
      from orders.orders o
     where o.idempotency_key = p_idempotency_key;
    if found then
      select t.name
        into v_table_name
        from floor.tables t
       where t.id = v_existing.floor_table_id;

      v_result := public.admin_pos_place_order(
        p_branch_id,
        p_lines,
        p_fulfillment_type,
        p_payment_method_id,
        p_idempotency_key,
        v_existing.table_number,
        p_note,
        p_customer_id
      );

      return v_result
        || payments.pos_tender_breakdown(v_existing.id)
        || payments.pos_invoice_summary(v_existing.id)
        || jsonb_build_object(
             'table_id', v_existing.floor_table_id,
             'table_name', coalesce(v_table_name, v_existing.table_number),
             'reservation_id', v_existing.dining_reservation_id,
             'shift_id', v_existing.pos_shift_id
           );
    end if;

    select o.order_number
      into v_active_order
      from orders.orders o
     where o.floor_table_id = p_table_id
       and o.status not in ('completed', 'cancelled')
     order by o.placed_at desc
     limit 1;
    if found then
      raise exception 'table is occupied' using errcode = '23514';
    end if;

    select r.id
      into v_reservation_id
      from floor.reservations r
     where r.table_id = p_table_id
       and r.status = 'seated'
     order by r.reserved_for
     limit 1;

    if v_reservation_id is null and exists (
      select 1
        from floor.reservations r
       where r.table_id = p_table_id
         and r.status = 'confirmed'
         and r.reserved_for <= now() + interval '30 minutes'
         and r.reserved_for + make_interval(mins => r.duration_minutes) > now()
    ) then
      raise exception 'table is reserved' using errcode = '23514';
    end if;
  end if;

  v_result := public.admin_pos_place_order(
    p_branch_id,
    p_lines,
    'dine_in',
    p_payment_method_id,
    p_idempotency_key,
    v_table_number,
    p_note,
    p_customer_id
  );
  v_order_id := (v_result->>'order_id')::uuid;

  update orders.orders
     set pos_shift_id = v_shift.id
   where id = v_order_id;

  if p_table_id is not null then
    update orders.orders
       set floor_table_id = p_table_id,
           dining_reservation_id = v_reservation_id
     where id = v_order_id;

    if v_reservation_id is not null then
      update floor.reservations
         set order_id = v_order_id
       where id = v_reservation_id
         and (order_id is null or order_id = v_order_id);
    end if;
  end if;

  -- The base checkout already created the order, its stock movements, its
  -- kitchen ticket and one placeholder capture. This swaps the capture for
  -- one row per tender and rejects the whole transaction if the split is
  -- invalid.
  v_tenders := payments.replace_pos_tenders(
    v_order_id,
    v_result->>'order_number',
    (v_result->>'grand_total')::numeric,
    v_result->>'currency_code',
    p_payment_method_id,
    p_payments
  );

  return v_result
    || v_tenders
    || payments.pos_invoice_summary(v_order_id)
    || jsonb_build_object(
         'table_id', p_table_id,
         'table_name', v_table_number,
         'reservation_id', v_reservation_id,
         'shift_id', v_shift.id
       );
end;
$fn$;

comment on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) is
  'Atomic POS checkout for dine-in where the table is optional and the sale '
  'belongs to the open branch shift. A chosen table is locked and checked '
  'against occupancy and bookings; the checkout prices the lines, moves stock, '
  'dispatches the kitchen ticket, accepts one or two cash/card tenders that '
  'must equal the total, and returns the tax invoice summary.';

revoke all on function public.admin_pos_shift(uuid) from public, anon;
grant execute on function public.admin_pos_shift(uuid) to authenticated;

revoke all on function public.admin_pos_open_shift(uuid, numeric, text)
  from public, anon;
grant execute on function public.admin_pos_open_shift(uuid, numeric, text)
  to authenticated;

revoke all on function public.admin_pos_record_cash_movement(
  uuid, text, numeric, text
) from public, anon;
grant execute on function public.admin_pos_record_cash_movement(
  uuid, text, numeric, text
) to authenticated;

revoke all on function public.admin_pos_close_shift(uuid, numeric, text)
  from public, anon;
grant execute on function public.admin_pos_close_shift(uuid, numeric, text)
  to authenticated;

revoke all on function public.admin_pos_shifts(uuid, integer, integer)
  from public, anon;
grant execute on function public.admin_pos_shifts(uuid, integer, integer)
  to authenticated;

revoke all on function public.admin_pos_shift_detail(uuid)
  from public, anon;
grant execute on function public.admin_pos_shift_detail(uuid)
  to authenticated;

revoke all on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) from public, anon;
grant execute on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) to authenticated;

-- ===== 183_admin_nav_counts.sql =====

-- Migration 183: the live counters behind the sidebar badges.
--
-- The navigation panel tells the staff how much work is waiting without
-- opening a page: orders that still need confirmation, and kitchen tickets
-- that have not been started yet. Both counters are computed on the server so
-- the dashboard never downloads whole directories just to count them.
--
-- What counts as work:
--   * new orders     orders.orders with status 'pending'. A POS sale is born
--                    'confirmed' and paid at the counter, so it belongs to the
--                    kitchen queue instead of waiting for a confirmation.
--   * kitchen queue  kitchen.tickets with status 'queued'.
--
-- Both counters are limited to the branches the caller may manage, exactly
-- like the kitchen board. A counter the caller cannot act on is not shown.

create or replace function public.admin_nav_counts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_new_orders    integer := 0;
  v_kitchen_queue integer := 0;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if identity.has_permission('orders.read') then
    select count(*) into v_new_orders
      from orders.orders o
     where o.status = 'pending'
       and identity.can_manage_branch(o.branch_id);
  end if;

  if identity.has_permission('kitchen.read') then
    select count(*) into v_kitchen_queue
      from kitchen.tickets t
     where t.status = 'queued'
       and identity.can_manage_branch(t.branch_id);
  end if;

  return jsonb_build_object(
    'new_orders', v_new_orders,
    'kitchen_queue', v_kitchen_queue
  );
end;
$fn$;

comment on function public.admin_nav_counts() is
  'Pending orders and queued kitchen tickets in the branches the caller can manage.';

revoke all on function public.admin_nav_counts() from public, anon;
grant execute on function public.admin_nav_counts() to authenticated;

notify pgrst, 'reload schema';

commit;
