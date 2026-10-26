-- 176_admin_pos_customers.sql
--
-- A counter sale now knows whose order it is.
--
-- Two kinds of customer can be attached:
--   1. a registered customer (identity.profiles). The order is linked through
--      orders.orders.user_id, so it appears in that customer's history and
--      status updates notify them, exactly like an online order;
--   2. a walk-in customer created at the counter. That person has no auth
--      account, so the record lives in orders.pos_customers and the order
--      points at it through orders.orders.pos_customer_id.
--
-- Why the walk-in table instead of an auth user:
--   identity.profiles.id references auth.users(id). Creating an auth user
--   needs the service role, which must never live in the admin app. The POS
--   keeps its own lightweight customer record, searches it together with the
--   registered customers, and never invents a login for someone.
--
-- The kitchen already receives every POS order through the insert trigger of
-- 174. This migration only teaches the kitchen board and the orders directory
-- to name a walk-in customer too.
--
-- What this adds:
--   1. orders.pos_customers, the counter customer record;
--   2. orders.orders.pos_customer_id;
--   3. admin_pos_customers: search registered + walk-in customers;
--   4. admin_pos_customer_create: create (or reuse) a counter customer;
--   5. admin_pos_place_order gains p_customer_id and returns customer fields;
--   6. admin_orders and admin_kitchen_board resolve the walk-in customer name.

-- ---------------------------------------------------------------------------
-- 1. The counter customer record
-- ---------------------------------------------------------------------------
create table if not exists orders.pos_customers (
  id               uuid primary key default extensions.gen_random_uuid(),
  full_name        text not null,
  phone            text,
  phone_normalized text,
  email            text,
  note             text,
  created_by       uuid references auth.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint ck_pos_customers_name check (
    char_length(btrim(full_name)) between 1 and 120
  ),
  constraint ck_pos_customers_phone check (
    phone is null or char_length(btrim(phone)) <= 40
  ),
  constraint ck_pos_customers_email check (
    email is null or char_length(btrim(email)) <= 160
  ),
  constraint ck_pos_customers_note check (
    note is null or char_length(note) <= 500
  )
);

comment on table orders.pos_customers is
  'Counter customers without an auth account. Created by staff at the point of sale; never used as a login.';

comment on column orders.pos_customers.phone_normalized is
  'Digits and + only, used for duplicate detection. Kept in sync by admin_pos_customer_create.';

create unique index if not exists uq_pos_customers_phone_normalized
  on orders.pos_customers (phone_normalized)
  where phone_normalized is not null;

create index if not exists ix_pos_customers_created
  on orders.pos_customers (created_at desc);

drop trigger if exists tr_pos_customers_updated_at on orders.pos_customers;
create trigger tr_pos_customers_updated_at
  before update on orders.pos_customers
  for each row execute function core.set_updated_at();

alter table orders.pos_customers enable row level security;
revoke all on table orders.pos_customers from anon, authenticated;
grant select on table orders.pos_customers to service_role;

-- ---------------------------------------------------------------------------
-- 2. The order link
-- ---------------------------------------------------------------------------
alter table orders.orders
  add column if not exists pos_customer_id uuid
    references orders.pos_customers(id) on delete set null;

comment on column orders.orders.pos_customer_id is
  'The counter customer of a POS order. NULL for online orders and anonymous walk-ins.';

create index if not exists ix_orders_pos_customer
  on orders.orders (pos_customer_id)
  where pos_customer_id is not null;

-- ---------------------------------------------------------------------------
-- 3. Search: registered customers and counter customers in one list
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_customers(
  p_search text default null,
  p_limit  integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_term  text := nullif(btrim(left(coalesce(p_search, ''), 80)), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(
             jsonb_build_object(
               'id', r.id,
               'source', r.source,
               'full_name', r.full_name,
               'email', r.email,
               'phone', r.phone,
               'avatar_url', r.avatar_url,
               'is_vip', r.is_vip,
               'orders_count', r.orders_count,
               'last_order_at', r.last_order_at
             )
             order by r.sort_rank, r.last_order_at desc nulls last, r.full_name
           )
      from (
        select
          p.id,
          'registered'::text as source,
          coalesce(
            nullif(btrim(p.full_name), ''),
            nullif(btrim(p.email), ''),
            ''
          ) as full_name,
          p.email,
          p.phone,
          p.avatar_url,
          p.is_vip,
          coalesce(o.cnt, 0) as orders_count,
          o.last_order_at,
          case
            when v_term is null then 3
            when coalesce(p.phone, '') ilike '%' || v_term || '%' then 0
            when coalesce(p.full_name, '') ilike '%' || v_term || '%' then 1
            else 2
          end as sort_rank
        from identity.profiles p
        left join lateral (
          select count(*)::integer as cnt, max(o.placed_at) as last_order_at
            from orders.orders o
           where o.user_id = p.id
        ) o on true
        where not p.is_blacklisted
          and not exists (
            select 1 from identity.staff_members sm where sm.user_id = p.id
          )
          and (
            v_term is null
            or coalesce(p.full_name, '') ilike '%' || v_term || '%'
            or coalesce(p.email, '') ilike '%' || v_term || '%'
            or coalesce(p.phone, '') ilike '%' || v_term || '%'
          )

        union all

        select
          c.id,
          'walk_in'::text as source,
          c.full_name,
          c.email,
          c.phone,
          null::text as avatar_url,
          false as is_vip,
          coalesce(o.cnt, 0) as orders_count,
          o.last_order_at,
          case
            when v_term is null then 3
            when coalesce(c.phone, '') ilike '%' || v_term || '%' then 0
            when c.full_name ilike '%' || v_term || '%' then 1
            else 2
          end as sort_rank
        from orders.pos_customers c
        left join lateral (
          select count(*)::integer as cnt, max(o.placed_at) as last_order_at
            from orders.orders o
           where o.pos_customer_id = c.id
        ) o on true
        where v_term is null
          or c.full_name ilike '%' || v_term || '%'
          or coalesce(c.email, '') ilike '%' || v_term || '%'
          or coalesce(c.phone, '') ilike '%' || v_term || '%'
        order by sort_rank, last_order_at desc nulls last, full_name
        limit v_limit
      ) r
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_pos_customers(text, integer) is
  'Search registered and counter customers for the point of sale. Never exposes staff or blacklisted profiles.';

revoke all on function public.admin_pos_customers(text, integer) from public, anon;
grant execute on function public.admin_pos_customers(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Create or reuse a counter customer
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_customer_create(
  p_full_name text,
  p_phone     text default null,
  p_email     text default null,
  p_note      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid        uuid := auth.uid();
  v_name       text := btrim(left(coalesce(p_full_name, ''), 120));
  v_phone      text := nullif(btrim(left(coalesce(p_phone, ''), 40)), '');
  v_phone_norm text;
  v_email      text := lower(nullif(btrim(left(coalesce(p_email, ''), 160)), ''));
  v_note       text := nullif(btrim(left(coalesce(p_note, ''), 500)), '');
  v_customer   orders.pos_customers%rowtype;
  v_registered identity.profiles%rowtype;
  v_reused     boolean := false;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  if v_name = '' then
    raise exception 'customer name is required' using errcode = '22023';
  end if;

  if v_phone is not null then
    v_phone_norm := nullif(regexp_replace(v_phone, '[^0-9+]', '', 'g'), '');
    if v_phone_norm is not null and char_length(v_phone_norm) < 6 then
      raise exception 'phone number is too short' using errcode = '22023';
    end if;
    if v_phone_norm is not null and char_length(v_phone_norm) > 20 then
      raise exception 'phone number is too long' using errcode = '22023';
    end if;
  end if;

  if v_email is not null and (
    position('@' in v_email) < 2
    or position('.' in split_part(v_email, '@', 2)) < 2
  ) then
    raise exception 'email address is invalid' using errcode = '22023';
  end if;

  -- A registered app customer may already own this phone number. Link the
  -- sale to that account instead of creating a duplicate counter record.
  if v_phone_norm is not null then
    select * into v_registered
      from identity.profiles p
     where regexp_replace(coalesce(p.phone, ''), '[^0-9+]', '', 'g')
             = v_phone_norm
       and not p.is_blacklisted
       and not exists (
         select 1 from identity.staff_members sm where sm.user_id = p.id
       )
     order by p.created_at
     limit 1;

    if found then
      return jsonb_build_object(
        'id', v_registered.id,
        'source', 'registered',
        'full_name', coalesce(
          nullif(btrim(v_registered.full_name), ''),
          nullif(btrim(v_registered.email), ''),
          ''
        ),
        'email', v_registered.email,
        'phone', v_registered.phone,
        'avatar_url', v_registered.avatar_url,
        'is_vip', v_registered.is_vip,
        'orders_count', (
          select count(*)::integer
            from orders.orders o
           where o.user_id = v_registered.id
        ),
        'last_order_at', (
          select max(o.placed_at)
            from orders.orders o
           where o.user_id = v_registered.id
        ),
        'reused', true
      );
    end if;
  end if;

  -- A phone number identifies the counter customer; calling again with the
  -- same number selects the existing record instead of duplicating it.
  insert into orders.pos_customers (
    full_name, phone, phone_normalized, email, note, created_by
  ) values (
    v_name, v_phone, v_phone_norm, v_email, v_note, v_uid
  )
  on conflict (phone_normalized) where phone_normalized is not null do nothing
  returning * into v_customer;

  if v_customer.id is null then
    select * into v_customer
      from orders.pos_customers c
     where c.phone_normalized = v_phone_norm;
    v_reused := true;
  end if;

  if not v_reused then
    perform identity.audit(
      'pos.customer.create',
      'pos_customer',
      v_customer.id,
      null,
      jsonb_build_object(
        'full_name', v_customer.full_name,
        'phone', v_customer.phone,
        'email', v_customer.email
      ),
      null
    );
  end if;

  return jsonb_build_object(
    'id', v_customer.id,
    'source', 'walk_in',
    'full_name', v_customer.full_name,
    'email', v_customer.email,
    'phone', v_customer.phone,
    'avatar_url', null,
    'is_vip', false,
    'orders_count', (
      select count(*)::integer
        from orders.orders o
       where o.pos_customer_id = v_customer.id
    ),
    'last_order_at', (
      select max(o.placed_at)
        from orders.orders o
       where o.pos_customer_id = v_customer.id
    ),
    'reused', v_reused
  );
end;
$fn$;

comment on function public.admin_pos_customer_create(text, text, text, text) is
  'Create a counter customer, or return the existing one with the same phone number.';

revoke all on function public.admin_pos_customer_create(text, text, text, text)
  from public, anon;
grant execute on function public.admin_pos_customer_create(text, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Place a walk-in order with an optional customer
--
-- The old seven-argument function is dropped so PostgREST never has to choose
-- between two overloads for the same named call.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_pos_place_order(uuid, jsonb, text, uuid, text, text, text);

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
    if v_table is null then
      raise exception 'table number is required for dine-in' using errcode = '23514';
    end if;
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

comment on function public.admin_pos_place_order(uuid, jsonb, text, uuid, text, text, text, uuid) is
  'Atomic, idempotent POS checkout with an optional customer. Server-priced, stock-aware, paid at the counter, feeds the kitchen.';

revoke all on function public.admin_pos_place_order(uuid, jsonb, text, uuid, text, text, text, uuid)
  from public, anon;
grant execute on function public.admin_pos_place_order(uuid, jsonb, text, uuid, text, text, text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Orders directory: name a counter customer too
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
      'pos_customer_id', o.pos_customer_id,
      'customer_name', coalesce(p.full_name, pc.full_name),
      'customer_email', coalesce(p.email, pc.email),
      'customer_phone', coalesce(p.phone, pc.phone),
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
    left join orders.pos_customers pc on pc.id = o.pos_customer_id
    left join core.branches b on b.id = o.branch_id
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_orders() is
  'Every order with its customer, branch, source, table and line snapshots.';

revoke all on function public.admin_orders() from public, anon;
grant execute on function public.admin_orders() to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Kitchen board: a counter customer has a name on the ticket too
-- ---------------------------------------------------------------------------
create or replace function public.admin_kitchen_board(
  p_branch_id uuid default null,
  p_search text default null,
  p_limit int default 150
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_term  text := nullif(btrim(left(coalesce(p_search, ''), 120)), '');
  v_limit int  := greatest(1, least(coalesce(p_limit, 150), 300));
begin
  perform kitchen.require_permission('kitchen.read');
  if p_branch_id is not null then
    perform kitchen.require_branch(p_branch_id);
  end if;

  return (
    with scoped as (
      select b.id
        from core.branches b
       where (p_branch_id is null or b.id = p_branch_id)
         and identity.can_manage_branch(b.id)
    ),
    base as (
      select
        t.id,
        t.status,
        t.placed_at,
        t.started_at,
        t.ready_at,
        t.completed_at,
        o.id as order_id,
        o.order_number,
        o.status as order_status,
        o.fulfillment_type,
        o.order_source,
        o.table_number,
        o.customer_note,
        b.id as branch_id,
        b.code as branch_code,
        b.name_ar as branch_name_ar,
        b.name_en as branch_name_en,
        coalesce(p.full_name, pc.full_name, '') as customer_name,
        (select count(*)
           from kitchen.ticket_items ti
          where ti.ticket_id = t.id) as item_count,
        (select count(*)
           from kitchen.ticket_items ti
          where ti.ticket_id = t.id and ti.status = 'ready') as ready_count
      from kitchen.tickets t
      join orders.orders o on o.id = t.order_id
      join core.branches b on b.id = t.branch_id
      left join identity.profiles p on p.id = o.user_id
      left join orders.pos_customers pc on pc.id = o.pos_customer_id
      where t.branch_id in (select id from scoped)
        and (
          t.status in ('queued', 'preparing', 'ready')
          or (t.status = 'completed'
              and t.completed_at >= now() - interval '3 hours')
        )
        and (
          v_term is null
          or o.order_number ilike '%' || v_term || '%'
          or coalesce(p.full_name, pc.full_name, '') ilike '%' || v_term || '%'
          or coalesce(o.table_number, '') ilike '%' || v_term || '%'
          or exists (
            select 1
              from kitchen.ticket_items ti
              join orders.order_items oi on oi.id = ti.order_item_id
             where ti.ticket_id = t.id
               and (
                 oi.product_name_ar ilike '%' || v_term || '%'
                 or oi.product_name_en ilike '%' || v_term || '%'
                 or coalesce(oi.note, '') ilike '%' || v_term || '%'
               )
          )
        )
    ),
    page as (
      select *
        from base
       order by
         case status
           when 'queued' then 0
           when 'preparing' then 1
           when 'ready' then 2
           else 3
         end,
         case when status = 'completed' then completed_at end desc nulls last,
         placed_at asc
       limit v_limit
    )
    select jsonb_build_object(
      'rows', coalesce((
        select jsonb_agg(
                 jsonb_build_object(
                   'id', p.id,
                   'status', p.status,
                   'placed_at', p.placed_at,
                   'started_at', p.started_at,
                   'ready_at', p.ready_at,
                   'completed_at', p.completed_at,
                   'order_id', p.order_id,
                   'order_number', p.order_number,
                   'order_status', p.order_status,
                   'fulfillment_type', p.fulfillment_type,
                   'order_source', p.order_source,
                   'table_number', p.table_number,
                   'customer_note', p.customer_note,
                   'customer_name', p.customer_name,
                   'branch_id', p.branch_id,
                   'branch_code', p.branch_code,
                   'branch_name_ar', p.branch_name_ar,
                   'branch_name_en', p.branch_name_en,
                   'item_count', p.item_count,
                   'ready_count', p.ready_count,
                   'items', coalesce((
                     select jsonb_agg(
                              jsonb_build_object(
                                'id', ti.id,
                                'status', ti.status,
                                'quantity', oi.quantity,
                                'product_name_ar', oi.product_name_ar,
                                'product_name_en', oi.product_name_en,
                                'note', oi.note,
                                'option_group_name_ar', oi.option_group_name_ar,
                                'option_group_name_en', oi.option_group_name_en,
                                'options', coalesce((
                                  select jsonb_agg(
                                           jsonb_build_object(
                                             'name_ar', oio.option_name_ar,
                                             'name_en', oio.option_name_en
                                           )
                                           order by oio.option_name_ar
                                         )
                                    from orders.order_item_options oio
                                   where oio.order_item_id = oi.id
                                ), '[]'::jsonb)
                              )
                              order by oi.created_at, oi.id
                            )
                       from kitchen.ticket_items ti
                       join orders.order_items oi on oi.id = ti.order_item_id
                      where ti.ticket_id = p.id
                   ), '[]'::jsonb)
                 )
                 order by
                   case p.status
                     when 'queued' then 0
                     when 'preparing' then 1
                     when 'ready' then 2
                     else 3
                   end,
                   case when p.status = 'completed' then p.completed_at end desc nulls last,
                   p.placed_at asc
               )
          from page p
      ), '[]'::jsonb),
      'total', (select count(*) from base)
    )
  );
end;
$fn$;

comment on function public.admin_kitchen_board(uuid, text, int) is
  'Live kitchen tickets with their lines, options, notes and customer name, scoped to the branches the caller manages.';

revoke all on function public.admin_kitchen_board(uuid, text, int) from public, anon;
grant execute on function public.admin_kitchen_board(uuid, text, int) to authenticated;

notify pgrst, 'reload schema';
