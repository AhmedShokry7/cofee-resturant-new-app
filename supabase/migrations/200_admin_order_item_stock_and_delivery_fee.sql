-- 200_admin_order_item_stock_and_delivery_fee.sql
--
-- Closes the two remaining open decisions of the orders audit, recorded as
-- topic C and the delivery-fee half of topic B in supabase/proposals/README.md
-- and left out of 186/191 on purpose until the owner decided. Both are now
-- decided: the orders feature has to be correct on production, and an admin edit
-- that changes what the branch physically has or what the customer is charged is
-- not correct.
--
-- C. Inventory.  admin_add_order_item inserted a line and never took the units
--    off the shelf; admin_remove_order_item deleted one and never put them back.
--    Every other write path deducts and restores: orders.place_order (103),
--    POS checkout (175/176/181), loyalty rewards (167), and
--    orders.cancel_order (107) gives back what the ledger says was taken. So an
--    order edited by an admin was priced, printed and cancellable while its
--    stock was wrong in both directions.
--
--    The pattern copied here is 167:903-934, the closest sibling: lock the stock
--    row, refuse unless allow_negative, deduct, write one 'sale' movement.
--
--    One wrinkle the sibling does not have: `uq_movement_sale_once` (012:77) is
--    UNIQUE on (reference_id, product_id, variant_key, reason) for reason='sale'.
--    An admin can add a second line of a product the order already contains, and
--    a plain insert would abort the whole edit with 23505. The movement is
--    therefore aggregated per order and product, which is also what 055 introduced
--    the aggregation for on the checkout path.
--
--    Removal shrinks that same movement instead of adding a 'return' row, because
--    cancel_order restores exactly sum(sale movements): leave the row at its old
--    size and the units an admin already gave back come back a second time on a
--    later cancellation. Shrinking keeps the ledger's arithmetic honest - sale(-q)
--    then a removed line leaves sale(-(q-r)) and on-hand +r, so the order still
--    holds only what it will be allowed to take. When the shrink reaches zero the
--    row is deleted, since ck_movement_delta_nonzero forbids a zero delta and a
--    product the order no longer contains has no business appearing in its ledger.
--
--    As in every sibling, a product with no branch_stock row is not deducted and
--    so is not restored: the ledger, not the order line, is the record of what was
--    really taken (that is 107's whole point).
--
-- E. Delivery fee.  admin_recompute_order_totals left `delivery_fee` at the value
--    the customer's checkout quote put there, while it recomputed subtotal,
--    discount, tax and grand_total. core.delivery_zone_fee (068) makes the fee a
--    function of the subtotal - it is waived at or above free_delivery_over - so
--    adding a line that crosses that threshold left the branch charging delivery
--    on an order the rules say is free, and removing one left a free delivery
--    below the threshold.
--
--    Recompute now asks the zone for the fee at the new subtotal, using the
--    latitude/longitude stored in delivery_address_snapshot, exactly as the
--    checkout quote does (134:301). It only reprices a delivery order that still
--    carries a zone; a pickup, dine-in or legacy row keeps its fee untouched, so
--    no number is invented for an order that has no zone to ask.
--
--    What is deliberately NOT re-enforced here: min_order_amount. The zone
--    minimum is an acceptance rule at checkout (134:298), not a property of the
--    invoice, and refusing an admin edit because the order dropped under it would
--    strand them - unable to shrink the order, unable to leave it. The fee
--    follows the rules; the minimum stays where the customer agreed to it.
--
--    ck_orders_total keeps holding because grand_total is written from the same
--    numbers in the same statement.
--
-- Permissions, branch guards and the return shapes are unchanged from 191: this
-- is arithmetic and the ledger, not a new surface.

-- ---------------------------------------------------------------------------
-- 1. Totals, including the fee the zone actually charges now.
-- ---------------------------------------------------------------------------
create or replace function public.admin_recompute_order_totals(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_subtotal numeric;
  v_discount numeric;
  v_tax_rate numeric := 0;
  v_tax_inc  boolean := true;
  v_tax      numeric;
  v_fee      numeric;
  v_kind     text;
  v_zone_id  uuid;
begin
  select coalesce(round(sum(oi.line_total), 2), 0)
    into v_subtotal
    from orders.order_items oi
   where oi.order_id = p_order_id;

  -- The invoice keeps the coupon the customer used, capped at the new subtotal
  -- so ck_orders_discount_capped still holds.
  select least(coalesce(o.discount_total, 0), v_subtotal),
         o.delivery_fee,
         o.fulfillment_type,
         o.delivery_zone_id
    into v_discount, v_fee, v_kind, v_zone_id
    from orders.orders o
   where o.id = p_order_id;

  select b.tax_rate, b.tax_included
    into v_tax_rate, v_tax_inc
    from core.brands b
   limit 1;

  if v_tax_inc then
    v_tax := 0;
  else
    v_tax := round((v_subtotal - v_discount) * coalesce(v_tax_rate, 0) / 100, 2);
  end if;

  -- The zone is the only authority on the fee, and its answer depends on the
  -- subtotal the order has now reached: free_delivery_over waives it, and a
  -- per_km zone prices the same distance every time. Coordinates come from the
  -- snapshot the order carries, exactly as quote_checkout reads them (134:301).
  -- Anything that is not a delivery order with a zone keeps the fee it has.
  if v_kind = 'delivery' and v_zone_id is not null then
    select core.delivery_zone_fee(
             o.delivery_zone_id, o.branch_id,
             (o.delivery_address_snapshot ->> 'latitude')::numeric,
             (o.delivery_address_snapshot ->> 'longitude')::numeric,
             v_subtotal
           )
      into v_fee
      from orders.orders o
     where o.id = p_order_id;
  end if;

  update orders.orders o
     set subtotal = v_subtotal,
         discount_total = v_discount,
         delivery_fee = v_fee,
         tax_total = v_tax,
         grand_total = round(
           v_subtotal - v_discount + v_fee + v_tax, 2),
         product_discount_total = coalesce((
           select round(sum(oi.product_discount_total), 2)
             from orders.order_items oi
            where oi.order_id = p_order_id
         ), 0),
         updated_at = now()
   where o.id = p_order_id;
end;
$fn$;

revoke all on function public.admin_recompute_order_totals(uuid) from public, anon, authenticated;
grant execute on function public.admin_recompute_order_totals(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 2. Adding a line: priced by the catalogue, taken off the shelf.
-- ---------------------------------------------------------------------------
create or replace function public.admin_add_order_item(p_order_id uuid, p_product_id uuid, p_quantity integer)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_item_id    uuid;
  v_order      orders.orders%rowtype;
  v_product    catalog.products%rowtype;
  v_unit_price numeric;
  v_regular    numeric;
  v_available  boolean;
  v_line_total numeric;
  v_discount   numeric;
  v_uid        uuid := auth.uid();
  v_stock      integer;
  v_allow_neg  boolean;
  v_on_shelf   boolean;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid quantity' using errcode = '22023';
  end if;

  select * into v_order from orders.orders where id = p_order_id for update;
  if not found then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_order.branch_id) then
    raise exception 'you do not manage this branch' using errcode = '42501';
  end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'order is not editable' using errcode = '22023';
  end if;
  if v_order.payment_status = 'refunded' then
    raise exception 'refunded order is not editable' using errcode = '22023';
  end if;

  select * into v_product from catalog.products where id = p_product_id;
  if not found then
    raise exception 'product not found' using errcode = '22023';
  end if;

  -- The price truth of 175:219 — branch price, product discount, no options.
  -- base_price was the list price the customer was never charged.
  select ep.unit_price, ep.regular_price, ep.is_available
    into v_unit_price, v_regular, v_available
    from catalog.resolve_effective_price(v_order.branch_id, p_product_id) ep;
  if not v_available then
    raise exception 'product is not available in this branch' using errcode = '22023';
  end if;
  v_unit_price := round(v_unit_price, 2);
  v_line_total := round(v_unit_price * p_quantity, 2);
  -- ck_order_items_total pins line_total to unit_price * quantity, so the
  -- product discount is recorded next to the line, never inside it (134).
  v_discount := greatest(round((coalesce(v_regular, v_unit_price) - v_unit_price)
                               * p_quantity, 2), 0);

  -- The shelf question is answered before the line is written, so a refusal
  -- leaves the order exactly as it was instead of an invoice for goods the
  -- branch does not have. Same rule, same message and same errcode as the
  -- loyalty reward path (167:911).
  select bs.quantity_on_hand, bs.allow_negative
    into v_stock, v_allow_neg
    from inventory.branch_stock bs
   where bs.branch_id = v_order.branch_id
     and bs.product_id = p_product_id
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
   for update;

  v_on_shelf := found;

  if v_on_shelf and not coalesce(v_allow_neg, false)
     and coalesce(v_stock, 0) < p_quantity then
    raise exception 'insufficient stock for product %', p_product_id
      using errcode = '23514';
  end if;

  insert into orders.order_items (
    order_id, product_id, product_name_ar, product_name_en, sku_snapshot,
    image_snapshot, unit_price, quantity, line_total, discount_total,
    product_discount_total, options_key, note
  )
  values (
    p_order_id, p_product_id, v_product.name_ar, v_product.name_en, v_product.sku,
    v_product.image_url, v_unit_price, p_quantity, v_line_total, 0,
    v_discount, '', ''
  )
  returning id into v_item_id;

  -- The shelf and its ledger move together, and only for a product the branch
  -- actually stocks (167:919): a line for something with no branch_stock row is
  -- priced and written, but nothing was taken, so the ledger must not claim it
  -- was. cancel_order gives back sum(sale movements), so a phantom row here would
  -- become stock out of nowhere on a later cancellation.
  if v_on_shelf then
    update inventory.branch_stock
       set quantity_on_hand = quantity_on_hand - p_quantity,
           updated_at = now()
     where branch_id = v_order.branch_id
       and product_id = p_product_id
       and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

    -- One 'sale' row per order and product, per uq_movement_sale_once: an admin
    -- adding a second line of something the order already carries widens that
    -- row rather than colliding with it. Both sides are negative, so widening is
    -- a sum: -2 plus -1 is -3. The row is what cancel_order later gives back, so
    -- a smaller number here would restock less than the order actually took.
    insert into inventory.stock_movements (
      branch_id, product_id, variant_key, quantity_delta, reason,
      reference_type, reference_id, actor_user_id, note
    ) values (
      v_order.branch_id, p_product_id,
      '00000000-0000-0000-0000-000000000000'::uuid,
      -p_quantity, 'sale', 'order', p_order_id, v_uid, 'admin item add'
    )
    on conflict (reference_id, product_id, variant_key, reason)
      where reason = 'sale' and reference_id is not null
    do update set quantity_delta =
      inventory.stock_movements.quantity_delta + excluded.quantity_delta;
  end if;

  perform public.admin_recompute_order_totals(p_order_id);

  insert into orders.order_events (order_id, event_type, payload)
  values (
    p_order_id, 'order_status',
    jsonb_build_object('action', 'add_item', 'item_id', v_item_id,
                       'product_id', p_product_id, 'quantity', p_quantity,
                       'unit_price', v_unit_price)
  );

  perform identity.audit(
    'order.item.add', 'order', p_order_id, '{}'::jsonb,
    jsonb_build_object('product_id', p_product_id, 'quantity', p_quantity),
    v_order.branch_id
  );

  return v_item_id;
end;
$fn$;

revoke all on function public.admin_add_order_item(uuid, uuid, int) from public, anon;
grant execute on function public.admin_add_order_item(uuid, uuid, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Removing a line: the units go back, and the ledger says so.
-- ---------------------------------------------------------------------------
create or replace function public.admin_remove_order_item(p_order_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order      orders.orders%rowtype;
  v_product_id uuid;
  v_quantity   integer;
  v_move_id    bigint;
  v_delta      integer;
  v_restore    integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;

  select o.* into v_order
    from orders.order_items oi
    join orders.orders o on o.id = oi.order_id
   where oi.id = p_order_item_id
   for update of o;
  if not found then
    raise exception 'order item not found' using errcode = '22023';
  end if;
  if not identity.can_manage_branch(v_order.branch_id) then
    raise exception 'you do not manage this branch' using errcode = '42501';
  end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'order is not editable' using errcode = '22023';
  end if;
  if v_order.payment_status = 'refunded' then
    raise exception 'refunded order is not editable' using errcode = '22023';
  end if;

  -- What the line took, read before it disappears.
  select oi.product_id, oi.quantity
    into v_product_id, v_quantity
    from orders.order_items oi
   where oi.id = p_order_item_id;

  delete from orders.order_items where id = p_order_item_id;

  -- The units an admin removes from an order that is still open were never sold,
  -- so they go back on the shelf. Only what this order really deducted: the sale
  -- movement is the record, and an order line for a product that had no stock row
  -- at placement deducted nothing and must not create stock now (107).
  select sm.id, sm.quantity_delta
    into v_move_id, v_delta
    from inventory.stock_movements sm
   where sm.reference_type = 'order'
     and sm.reference_id = v_order.id
     and sm.product_id = v_product_id
     and sm.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
     and sm.reason = 'sale'
   for update;

  if found and coalesce(v_delta, 0) < 0 then
    v_restore := least(v_quantity, -v_delta);

    update inventory.branch_stock
       set quantity_on_hand = quantity_on_hand + v_restore,
           updated_at = now()
     where branch_id = v_order.branch_id
       and product_id = v_product_id
       and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

    -- Shrink the sale, never add a compensating row: cancel_order gives back
    -- sum(sale movements), so a stale row would return these units a second
    -- time. ck_movement_delta_nonzero forbids a zero, so a fully removed
    -- product leaves no row at all. The shrink stands even when the stock row
    -- itself is gone - the order still does not hold those units.
    if v_delta + v_restore = 0 then
      delete from inventory.stock_movements where id = v_move_id;
    else
      update inventory.stock_movements
         set quantity_delta = v_delta + v_restore
       where id = v_move_id;
    end if;
  end if;

  perform public.admin_recompute_order_totals(v_order.id);

  insert into orders.order_events (order_id, event_type, payload)
  values (
    v_order.id, 'order_status',
    jsonb_build_object('action', 'remove_item', 'item_id', p_order_item_id)
  );

  perform identity.audit(
    'order.item.remove', 'order', v_order.id, '{}'::jsonb,
    jsonb_build_object('item_id', p_order_item_id,
                       'stock_restored', coalesce(v_restore, 0)),
    v_order.branch_id
  );
end;
$fn$;

revoke all on function public.admin_remove_order_item(uuid) from public, anon;
grant execute on function public.admin_remove_order_item(uuid) to authenticated;

comment on function public.admin_add_order_item(uuid, uuid, integer) is
  'Adds a line to an editable order at the branch price, deducts the stock the '
  'branch really holds and reprices the invoice, delivery fee included.';

comment on function public.admin_remove_order_item(uuid) is
  'Removes a line from an editable order, returns the units this order had '
  'deducted and reprices the invoice, delivery fee included.';

notify pgrst, 'reload schema';


