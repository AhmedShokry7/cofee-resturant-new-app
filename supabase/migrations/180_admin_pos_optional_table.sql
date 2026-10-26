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
