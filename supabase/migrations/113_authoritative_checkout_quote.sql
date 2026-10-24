begin;

-- Return the same repriced subtotal, coupon discount, delivery method, tax and
-- total that place_order_impl will use. The active cart is refreshed inside
-- this transaction so bundle and option pricing follows the normal checkout
-- path instead of trusting prices supplied by the app.
create or replace function public.quote_checkout(
  p_branch_id uuid,
  p_lines jsonb,
  p_fulfillment_type text,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_address_id uuid default null
)
returns table (
  subtotal numeric,
  discount_total numeric,
  delivery_fee numeric,
  tax_total numeric,
  grand_total numeric,
  currency_code text
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_cart uuid;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_fee numeric := 0;
  v_tax numeric := 0;
  v_total numeric := 0;
  v_rate numeric := 0;
  v_tax_included boolean := false;
  v_currency text;
  v_coupon_reason text;
  v_zone core.delivery_zones%rowtype;
  v_address identity.customer_addresses%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_fulfillment_type not in ('pickup', 'delivery') then
    raise exception 'invalid fulfillment type' using errcode = '22023';
  end if;

  v_cart := orders.replace_customer_cart(p_branch_id, p_lines);
  perform orders.reprice_cart(v_cart, true);
  select coalesce(round(sum(ci.line_total), 2), 0)
    into v_subtotal from orders.cart_items ci where ci.cart_id = v_cart;

  if p_fulfillment_type = 'delivery' then
    if p_delivery_zone_id is null or p_address_id is null then
      raise exception 'delivery zone and address required' using errcode = '23514';
    end if;
    select dz.* into v_zone
      from core.delivery_zones dz
      join core.delivery_zone_branches dzb on dzb.zone_id = dz.id
     where dz.id = p_delivery_zone_id and dzb.branch_id = p_branch_id
       and dz.is_active;
    if not found then
      raise exception 'delivery zone unavailable' using errcode = '23514';
    end if;
    select a.* into v_address from identity.customer_addresses a
     where a.id = p_address_id and a.user_id = v_uid and a.archived_at is null;
    if not found then
      raise exception 'delivery address not found' using errcode = '23514';
    end if;
    if not core.zone_covers_point(
      p_delivery_zone_id, v_address.latitude, v_address.longitude
    ) then
      raise exception 'delivery address outside selected zone' using errcode = '23514';
    end if;
    if v_subtotal < v_zone.min_order_amount then
      raise exception 'order total below delivery minimum' using errcode = '23514';
    end if;
    v_fee := core.delivery_zone_fee(
      p_delivery_zone_id, p_branch_id, v_address.latitude,
      v_address.longitude, v_subtotal
    );
  end if;

  if nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    select v.discount, v.reason_code into v_discount, v_coupon_reason
      from marketing.validate_coupon(
        p_coupon_code, v_subtotal, p_branch_id
      ) v;
    if v_coupon_reason is distinct from 'applied'
       or coalesce(v_discount, 0) <= 0 then
      raise exception 'coupon cannot be applied: %',
        coalesce(v_coupon_reason, 'not_applicable') using errcode = '23514';
    end if;
    v_discount := least(v_discount, v_subtotal);
  end if;

  select b.currency_code, b.tax_rate, b.tax_included
    into v_currency, v_rate, v_tax_included from core.brands b limit 1;
  if not coalesce(v_tax_included, false) then
    v_tax := round((v_subtotal - v_discount) * coalesce(v_rate, 0) / 100, 2);
  end if;
  v_total := round(v_subtotal - v_discount + v_fee + v_tax, 2);
  return query select v_subtotal, v_discount, v_fee, v_tax, v_total, v_currency;
end;
$fn$;

revoke all on function public.quote_checkout(uuid, jsonb, text, uuid, text, uuid)
  from public, anon;
grant execute on function public.quote_checkout(uuid, jsonb, text, uuid, text, uuid)
  to authenticated, service_role;

-- Reject a stale amount before an order can commit. Raising from this wrapper
-- rolls back the nested order transaction and lets the app refresh the quote.
create or replace function public.place_order_with_quote(
  p_branch_id uuid,
  p_lines jsonb,
  p_idempotency_key text,
  p_fulfillment_type text,
  p_expected_total numeric,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_note text default null,
  p_address_id uuid default null
)
returns table (
  order_id uuid,
  order_number text,
  subtotal numeric,
  discount_total numeric,
  delivery_fee numeric,
  tax_total numeric,
  grand_total numeric,
  points_earned integer,
  reused_existing_order boolean
)
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  v_order record;
begin
  if p_expected_total is null then
    raise exception 'checkout quote required' using errcode = '22023';
  end if;
  select * into v_order from public.place_order_with_lines(
    p_branch_id, p_lines, p_idempotency_key, p_fulfillment_type,
    p_delivery_zone_id, p_coupon_code, p_note, p_address_id
  );
  if abs(v_order.grand_total - p_expected_total) > 0.005 then
    raise exception 'checkout total changed; refresh quote' using errcode = '40001';
  end if;
  return query select v_order.order_id, v_order.order_number,
    v_order.subtotal, v_order.discount_total, v_order.delivery_fee,
    v_order.tax_total, v_order.grand_total, v_order.points_earned,
    v_order.reused_existing_order;
end;
$fn$;

revoke all on function public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid
) from public, anon;
grant execute on function public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
