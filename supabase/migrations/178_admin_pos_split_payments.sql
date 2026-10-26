-- 178_admin_pos_split_payments.sql
-- Cash, card, or both: split tenders for a POS checkout.
--
-- The counter took exactly one payment method and wrote one payment row. This
-- migration:
--   1. adds payments.payment_transactions.method_id so a tender names its
--      method instead of being inferred from the order;
--   2. adds private helpers that validate cash/card allocations, replace the
--      counter's payment rows, and return the tender breakdown;
--   3. replaces the table-aware POS checkout so one order can be paid partly
--      in cash and partly by card, while keeping table locking, idempotency,
--      stock deduction and kitchen dispatch atomic.
--
-- Only cash and card are accepted at the counter. The helper raises before the
-- transaction commits, so an invalid split rolls back the whole order.

-- ---------------------------------------------------------------------------
-- 1. A payment row remembers its method
-- ---------------------------------------------------------------------------
alter table payments.payment_transactions
  add column if not exists method_id uuid
    references payments.payment_methods(id) on delete set null;

create index if not exists ix_payment_tx_method
  on payments.payment_transactions (method_id)
  where method_id is not null;

comment on column payments.payment_transactions.method_id is
  'The payment method of this tender. A split counter sale has one row per method.';

-- Existing counter transactions belong to the order's single method.
update payments.payment_transactions t
   set method_id = o.payment_method_id
  from orders.orders o
 where t.order_id = o.id
   and t.provider = 'pos_counter'
   and t.method_id is null
   and o.payment_method_id is not null;

-- ---------------------------------------------------------------------------
-- 2. Private tender helpers
-- ---------------------------------------------------------------------------
create or replace function payments.pos_tender_breakdown(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_payments jsonb;
  v_method   payments.payment_methods%rowtype;
begin
  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', t.id,
             'method_id', t.method_id,
             'method_code', m.code,
             'method_name_ar', m.name_ar,
             'method_name_en', m.name_en,
             'amount', t.amount
           ) order by m.sort_order, m.code, t.created_at
         ), '[]'::jsonb)
    into v_payments
    from payments.payment_transactions t
    left join payments.payment_methods m on m.id = t.method_id
   where t.order_id = p_order_id
     and t.provider = 'pos_counter';

  select m.*
    into v_method
    from orders.orders o
    join payments.payment_methods m on m.id = o.payment_method_id
   where o.id = p_order_id;

  return jsonb_build_object(
    'payments', v_payments,
    'payment_method_id', v_method.id,
    'payment_method_code', v_method.code,
    'payment_method_name_ar', v_method.name_ar,
    'payment_method_name_en', v_method.name_en
  );
end;
$fn$;

comment on function payments.pos_tender_breakdown(uuid) is
  'The cash/card tenders of one POS order plus its primary method.';

create or replace function payments.replace_pos_tenders(
  p_order_id         uuid,
  p_order_number     text,
  p_total            numeric,
  p_currency         text,
  p_primary_method_id uuid,
  p_payments         jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_payments          jsonb := p_payments;
  v_normalized        jsonb := '[]'::jsonb;
  v_count             integer;
  v_tender            jsonb;
  v_method            payments.payment_methods%rowtype;
  v_method_id         uuid;
  v_amount            numeric;
  v_sum               numeric := 0;
  v_method_ids        uuid[] := '{}'::uuid[];
  v_primary_method_id uuid;
begin
  if v_payments is not null and jsonb_typeof(v_payments) <> 'array' then
    raise exception 'payments must be an array' using errcode = '22023';
  end if;

  v_count := coalesce(jsonb_array_length(v_payments), 0);
  if v_count > 2 then
    raise exception 'at most two payment methods are allowed'
      using errcode = '23514';
  end if;

  -- An older caller can still send only the primary method. A free order has
  -- no tender at all.
  if p_total > 0 and v_count = 0 then
    if p_primary_method_id is null then
      raise exception 'a payment method is required' using errcode = '23514';
    end if;
    v_payments := jsonb_build_array(jsonb_build_object(
      'method_id', p_primary_method_id,
      'amount', p_total
    ));
    v_count := 1;
  elsif p_total <= 0 and v_count > 0 then
    raise exception 'a free order cannot take a payment'
      using errcode = '23514';
  end if;

  for v_tender in
    select value from jsonb_array_elements(coalesce(v_payments, '[]'::jsonb))
  loop
    v_method_id := nullif(v_tender->>'method_id', '')::uuid;
    if v_method_id is null then
      raise exception 'every payment needs a method' using errcode = '23514';
    end if;

    begin
      v_amount := round(coalesce((v_tender->>'amount')::numeric, 0), 2);
    exception when others then
      raise exception 'invalid payment amount' using errcode = '22023';
    end;

    if v_amount <= 0 then
      raise exception 'payment amount must be greater than zero'
        using errcode = '23514';
    end if;
    if v_method_id = any(v_method_ids) then
      raise exception 'duplicate payment method' using errcode = '23514';
    end if;

    select *
      into v_method
      from payments.payment_methods m
     where m.id = v_method_id
       and m.is_active;
    if not found then
      raise exception 'payment method not found or inactive'
        using errcode = 'P0002';
    end if;
    if v_method.code not in ('cash', 'card') then
      raise exception 'payment method is not available at the counter'
        using errcode = '23514';
    end if;

    v_method_ids := v_method_ids || v_method.id;
    v_sum := v_sum + v_amount;
    v_normalized := v_normalized || jsonb_build_array(jsonb_build_object(
      'method_id', v_method.id,
      'code', v_method.code,
      'amount', v_amount
    ));
  end loop;

  if round(v_sum, 2) <> round(p_total, 2) then
    raise exception 'payment total does not match the order total'
      using errcode = '23514';
  end if;

  -- The base checkout writes one placeholder capture for the whole order.
  -- Replacing it keeps the payment ledger equal to what the cashier took.
  delete from payments.payment_transactions t
   where t.order_id = p_order_id
     and t.provider = 'pos_counter';

  for v_tender in select value from jsonb_array_elements(v_normalized)
  loop
    insert into payments.payment_transactions (
      order_id, method_id, provider, provider_reference, amount,
      currency_code, status, paid_at, verified_by_server
    ) values (
      p_order_id,
      (v_tender->>'method_id')::uuid,
      'pos_counter',
      case
        when v_count = 1 then p_order_number
        else p_order_number || ':' || (v_tender->>'code')
      end,
      (v_tender->>'amount')::numeric,
      p_currency,
      'captured',
      now(),
      true
    );
  end loop;

  if v_count > 0 then
    select (tender->>'method_id')::uuid
      into v_primary_method_id
      from jsonb_array_elements(v_normalized) tender
     order by (tender->>'amount')::numeric desc,
              case when tender->>'code' = 'cash' then 0 else 1 end
     limit 1;

    update orders.orders
       set payment_method_id = v_primary_method_id
     where id = p_order_id;
  end if;

  return payments.pos_tender_breakdown(p_order_id);
end;
$fn$;

comment on function payments.replace_pos_tenders(
  uuid, text, numeric, text, uuid, jsonb
) is
  'Validates the counter tenders, replaces the POS payment rows and returns '
  'the authoritative breakdown. Cash and card only.';

revoke all on function payments.pos_tender_breakdown(uuid)
  from public, anon, authenticated;
revoke all on function payments.replace_pos_tenders(
  uuid, text, numeric, text, uuid, jsonb
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Table-aware checkout with split tenders
-- ---------------------------------------------------------------------------
drop function if exists public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid
);

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
  v_existing           orders.orders%rowtype;
  v_table              floor.tables%rowtype;
  v_reservation_id     uuid;
  v_active_order       text;
  v_result             jsonb;
  v_tenders            jsonb;
  v_order_id           uuid;
  v_table_name         text;
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

  -- Retries must return the existing order without re-checking occupancy.
  select * into v_existing
    from orders.orders o
   where o.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.order_source <> 'pos' then
      raise exception 'idempotency key already used by another order'
        using errcode = '23505';
    end if;

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
      || jsonb_build_object(
           'table_id', v_existing.floor_table_id,
           'table_name', coalesce(v_table_name, v_existing.table_number),
           'reservation_id', v_existing.dining_reservation_id
         );
  end if;

  if p_fulfillment_type is distinct from 'dine_in' then
    raise exception 'pos orders are dine-in only' using errcode = '22023';
  end if;
  if p_table_id is null then
    raise exception 'table is required for dine-in' using errcode = '23514';
  end if;

  select * into v_table
    from floor.tables t
   where t.id = p_table_id
     and t.branch_id = p_branch_id
     and t.is_active;
  if not found then
    raise exception 'table is not available' using errcode = '23514';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

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

  v_result := public.admin_pos_place_order(
    p_branch_id,
    p_lines,
    'dine_in',
    p_payment_method_id,
    p_idempotency_key,
    v_table.name,
    p_note,
    p_customer_id
  );
  v_order_id := (v_result->>'order_id')::uuid;

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
    || jsonb_build_object(
         'table_id', p_table_id,
         'table_name', v_table.name,
         'reservation_id', v_reservation_id
       );
end;
$fn$;

comment on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) is
  'Atomic POS checkout for a real dining table: locks the table, checks '
  'occupancy and bookings, links a seated reservation, then delegates to the '
  'priced, stock-aware, kitchen-dispatching checkout. Accepts one or two '
  'cash/card tenders whose amounts must equal the order total.';

revoke all on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) from public, anon;
grant execute on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) to authenticated;

-- The label-only checkout cannot enforce the floor plan, so it is no longer
-- callable by API roles. The table-aware wrapper above calls it internally as
-- the function owner.
revoke execute on function public.admin_pos_place_order(
  uuid, jsonb, text, uuid, text, text, text, uuid
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Payments directory: name the method of each tender
-- ---------------------------------------------------------------------------
create or replace function public.admin_payments()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id,
      'order_id', t.order_id,
      'order_number', o.order_number,
      'customer_name', p.full_name,
      'provider', t.provider,
      'provider_reference', t.provider_reference,
      'method_id', t.method_id,
      'method_code', m.code,
      'method_name_ar', m.name_ar,
      'method_name_en', m.name_en,
      'amount', t.amount,
      'currency_code', t.currency_code,
      'status', t.status,
      'paid_at', t.paid_at,
      'refunded_at', t.refunded_at,
      'card_brand', t.card_brand,
      'card_last4', t.card_last4,
      'card_holder_name', t.card_holder_name,
      'verified_by_server', t.verified_by_server,
      'created_at', t.created_at
    ) order by t.created_at desc)
    from payments.payment_transactions t
    left join orders.orders o on o.id = t.order_id
    left join identity.profiles p on p.id = o.user_id
    left join payments.payment_methods m on m.id = t.method_id
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_payments() is
  'Every payment transaction with its order, customer and, for counter sales, '
  'the cash/card method of the tender.';

revoke all on function public.admin_payments() from public, anon;
grant execute on function public.admin_payments() to authenticated;

notify pgrst, 'reload schema';
