-- 179_admin_pos_tax_invoice.sql
-- Seller tax identity and the data a ZATCA simplified tax invoice needs.
--
-- The POS printed a plain receipt: it had no seller VAT registration number,
-- no taxable/VAT split (prices are VAT-inclusive, so orders.tax_total is 0 by
-- design) and no product discount totals. This migration:
--
--   1. stores the legal name and VAT registration number on the branch, so the
--      back office enters real data instead of hard-coding it in the app;
--   2. exposes them through admin_branches / admin_save_branch so the branch
--      dialog can maintain them;
--   3. adds payments.pos_invoice_summary(order_id), which derives the
--      before-discount total, the taxable amount and the VAT portion from the
--      stored order at the brand's real tax rate;
--   4. appends that summary (and the seller identity) to the POS checkout
--      response, so the receipt can print without a second round trip.
--
-- Nothing here invents a VAT number, a legal name or a tax rate. When the
-- branch has no VAT number the app disables the tax-invoice print and points
-- the user at the branch settings.
--
-- Phase 1 (simplified invoice + TLV QR code) is what the app prints. Phase 2
-- (XML, UUID, cryptographic stamp and ZATCA clearance) needs the merchant's
-- onboarding credentials and a signing service; it is outside this migration.

-- ---------------------------------------------------------------------------
-- 1. Seller identity on the branch.
-- ---------------------------------------------------------------------------
alter table core.branches
  add column if not exists vat_number text;

alter table core.branches
  add column if not exists legal_name text;

comment on column core.branches.vat_number is
  'Saudi VAT registration number (15 digits, starts and ends with 3). Printed
   on the simplified tax invoice; null when the branch cannot issue one.';

comment on column core.branches.legal_name is
  'Seller legal name printed on the tax invoice. Falls back to name_ar.';

-- Guard the shape of the number without forcing every branch to have one.
do $$
begin
  if not exists (
    select 1
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'core'
       and t.relname = 'branches'
       and c.conname = 'ck_branches_vat_number'
  ) then
    alter table core.branches
      add constraint ck_branches_vat_number
      check (
        vat_number is null
        or btrim(vat_number) = ''
        or btrim(vat_number) ~ '^3[0-9]{13}3$'
      );
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Branch directory gains the tax identity.
-- ---------------------------------------------------------------------------
create or replace function public.admin_branches()
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
      'id', b.id,
      'code', b.code,
      'name_ar', b.name_ar,
      'name_en', b.name_en,
      'address', b.address,
      'address_ar', b.address_ar,
      'address_en', b.address_en,
      'legal_name', b.legal_name,
      'vat_number', b.vat_number,
      'latitude', b.latitude,
      'longitude', b.longitude,
      'phone', b.phone,
      'is_active', b.is_active,
      'opens_at', b.opens_at,
      'closes_at', b.closes_at,
      'image_url', b.image_url,
      'created_at', b.created_at,
      'staff_count', coalesce(st.staff_count, 0),
      'zone_count', coalesce(zn.zone_count, 0),
      'orders_30d', coalesce(ord.orders_30d, 0),
      'last_order_at', ord.last_order_at
    ) order by b.is_active desc, b.name_ar)
    from core.branches b
    left join lateral (
      select count(distinct sr.staff_id)::integer as staff_count
        from identity.staff_roles sr
        join identity.staff_members sm on sm.id = sr.staff_id
       where sr.branch_id = b.id
         and sm.status = 'active'
    ) st on true
    left join lateral (
      select count(distinct dzb.zone_id)::integer as zone_count
        from core.delivery_zone_branches dzb
        join core.delivery_zones dz on dz.id = dzb.zone_id
       where dzb.branch_id = b.id
         and dz.is_active
    ) zn on true
    left join lateral (
      select count(*) filter (
               where o.status <> 'cancelled'
                 and o.placed_at >= now() - interval '30 days'
             )::integer as orders_30d,
             max(o.placed_at) filter (
               where o.status <> 'cancelled'
             ) as last_order_at
        from orders.orders o
       where o.branch_id = b.id
    ) ord on true
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_branches is
  'Every branch with its tax identity, assigned staff, active delivery zones,
   30-day orders and latest order time for the admin directory.';

revoke all on function public.admin_branches() from public, anon;
grant execute on function public.admin_branches() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Saving a branch validates and stores the tax identity.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_branch(p_branch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id         uuid;
  v_brand_id   uuid;
  v_code       text;
  v_name_ar    text;
  v_name_en    text;
  v_address    text;
  v_phone      text;
  v_legal_name text;
  v_vat_number text;
  v_lat        numeric;
  v_lng        numeric;
  v_opens_at   time;
  v_closes_at  time;
  v_old        jsonb;
  v_new        jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_branch is null or jsonb_typeof(p_branch) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    v_id := nullif(btrim(coalesce(p_branch->>'id', '')), '')::uuid;
    v_lat := nullif(btrim(coalesce(p_branch->>'latitude', '')), '')::numeric;
    v_lng := nullif(btrim(coalesce(p_branch->>'longitude', '')), '')::numeric;
    v_opens_at := nullif(btrim(coalesce(p_branch->>'opens_at', '')), '')::time;
    v_closes_at := nullif(btrim(coalesce(p_branch->>'closes_at', '')), '')::time;
  exception
    when data_exception then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  v_code := upper(btrim(coalesce(p_branch->>'code', '')));
  v_name_ar := btrim(coalesce(p_branch->>'name_ar', ''));
  v_name_en := btrim(coalesce(p_branch->>'name_en', ''));
  v_address := btrim(coalesce(p_branch->>'address', ''));
  v_phone := nullif(btrim(coalesce(p_branch->>'phone', '')), '');
  v_legal_name := nullif(btrim(coalesce(p_branch->>'legal_name', '')), '');
  v_vat_number := nullif(btrim(coalesce(p_branch->>'vat_number', '')), '');

  if v_code !~ '^[A-Z0-9_-]{1,24}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_code');
  end if;
  if v_name_ar = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if v_address = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_address');
  end if;
  if (v_lat is null) <> (v_lng is null)
     or (v_lat is not null and v_lat not between -90 and 90)
     or (v_lng is not null and v_lng not between -180 and 180) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_location');
  end if;
  if (v_opens_at is null) <> (v_closes_at is null)
     or (v_opens_at is not null and v_opens_at >= v_closes_at) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_hours');
  end if;
  if v_vat_number is not null and v_vat_number !~ '^3[0-9]{13}3$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_vat_number');
  end if;
  if v_legal_name is not null and char_length(v_legal_name) > 200 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_legal_name');
  end if;
  if v_name_en = '' then
    v_name_en := v_name_ar;
  end if;

  if exists (
    select 1 from core.branches b
     where upper(b.code) = v_code
       and (v_id is null or b.id <> v_id)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
  end if;

  if v_id is null then
    select b.id into v_brand_id
      from core.brands b
     order by b.created_at
     limit 1;
    if v_brand_id is null then
      return jsonb_build_object('ok', false, 'reason', 'no_brand');
    end if;

    begin
      insert into core.branches (
        brand_id, code, name_ar, name_en, address, address_ar, address_en,
        latitude, longitude, phone, opens_at, closes_at,
        legal_name, vat_number
      ) values (
        v_brand_id, v_code, v_name_ar, v_name_en, v_address, v_address,
        v_address, v_lat, v_lng, v_phone, v_opens_at, v_closes_at,
        v_legal_name, v_vat_number
      ) returning id into v_id;
    exception
      when unique_violation then
        return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
    end;
  else
    select jsonb_build_object(
             'code', b.code,
             'name_ar', b.name_ar,
             'name_en', b.name_en,
             'address', b.address,
             'legal_name', b.legal_name,
             'vat_number', b.vat_number,
             'latitude', b.latitude,
             'longitude', b.longitude,
             'phone', b.phone,
             'opens_at', b.opens_at,
             'closes_at', b.closes_at
           ) into v_old
      from core.branches b
     where b.id = v_id;
    if v_old is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    begin
      update core.branches b
         set code = v_code,
             name_ar = v_name_ar,
             name_en = v_name_en,
             address = v_address,
             address_ar = v_address,
             address_en = v_address,
             latitude = v_lat,
             longitude = v_lng,
             phone = v_phone,
             opens_at = v_opens_at,
             closes_at = v_closes_at,
             legal_name = v_legal_name,
             vat_number = v_vat_number
       where b.id = v_id;
    exception
      when unique_violation then
        return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
    end;
  end if;

  select jsonb_build_object(
           'code', b.code,
           'name_ar', b.name_ar,
           'name_en', b.name_en,
           'address', b.address,
           'legal_name', b.legal_name,
           'vat_number', b.vat_number,
           'latitude', b.latitude,
           'longitude', b.longitude,
           'phone', b.phone,
           'opens_at', b.opens_at,
           'closes_at', b.closes_at
         ) into v_new
    from core.branches b
   where b.id = v_id;

  perform identity.audit(
    case when v_old is null then 'core.branch.create' else 'core.branch.update' end,
    'branch',
    v_id,
    v_old,
    v_new
  );

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$fn$;

comment on function public.admin_save_branch is
  'Create or update one branch with code, location, opening-hour and seller tax
   identity validation.';

revoke all on function public.admin_save_branch(jsonb) from public, anon;
grant execute on function public.admin_save_branch(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Invoice summary for one stored POS order.
--
-- orders.tax_total is zero when prices include VAT (the default), so the VAT
-- portion has to be derived from the grand total. The function keeps both
-- branches: added tax when prices exclude VAT, included VAT otherwise.
-- ---------------------------------------------------------------------------
create or replace function payments.pos_invoice_summary(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_order        orders.orders%rowtype;
  v_branch       core.branches%rowtype;
  v_tax_rate     numeric := 0;
  v_tax_included boolean := true;
  v_vat          numeric := 0;
  v_taxable      numeric := 0;
  v_before       numeric := 0;
begin
  select * into v_order
    from orders.orders o
   where o.id = p_order_id;
  if not found then
    return '{}'::jsonb;
  end if;

  select * into v_branch
    from core.branches b
   where b.id = v_order.branch_id;

  select coalesce(b.tax_rate, 0),
         coalesce(b.tax_included, true)
    into v_tax_rate, v_tax_included
    from core.brands b
   limit 1;

  v_before := round(
    coalesce(v_order.subtotal, 0)
    + coalesce(v_order.product_discount_total, 0)
    + coalesce(v_order.discount_total, 0),
    2
  );

  if v_tax_rate > 0 and v_tax_included then
    v_vat := round(v_order.grand_total * v_tax_rate / (100 + v_tax_rate), 2);
    v_taxable := round(v_order.grand_total - v_vat, 2);
  else
    v_vat := coalesce(v_order.tax_total, 0);
    v_taxable := round(
      coalesce(v_order.subtotal, 0) - coalesce(v_order.discount_total, 0),
      2
    );
  end if;

  return jsonb_build_object(
    'product_discount_total', coalesce(v_order.product_discount_total, 0),
    'discount_total', coalesce(v_order.discount_total, 0),
    'before_discount_total', v_before,
    'taxable_total', v_taxable,
    'vat_total', v_vat,
    'tax_rate', v_tax_rate,
    'tax_included', v_tax_included,
    'seller_name_ar', v_branch.name_ar,
    'seller_name_en', v_branch.name_en,
    'seller_legal_name', coalesce(
      nullif(btrim(v_branch.legal_name), ''),
      v_branch.name_ar
    ),
    'seller_vat_number', nullif(btrim(v_branch.vat_number), ''),
    'seller_address_ar', coalesce(
      nullif(btrim(v_branch.address_ar), ''),
      v_branch.address
    ),
    'seller_address_en', coalesce(
      nullif(btrim(v_branch.address_en), ''),
      v_branch.address
    ),
    'seller_phone', v_branch.phone
  );
end;
$fn$;

comment on function payments.pos_invoice_summary(uuid) is
  'Discount, taxable, VAT and seller identity for a ZATCA simplified tax
   invoice. Internal helper for the POS checkout response.';

revoke all on function payments.pos_invoice_summary(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Table checkout response carries the invoice summary.
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
    || payments.pos_invoice_summary(v_order_id)
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
  'Atomic POS checkout for a real dining table: locks the table, checks
   occupancy and bookings, links a seated reservation, then delegates to the
   priced, stock-aware, kitchen-dispatching checkout. Accepts one or two
   cash/card tenders whose amounts must equal the order total, and returns the
   discount, tax and seller identity needed by the tax invoice.';

revoke all on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) from public, anon;
grant execute on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid, jsonb
) to authenticated;
