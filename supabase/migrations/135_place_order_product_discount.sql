-- 135_place_order_product_discount.sql
--
-- The order that comes back from the checkout states the product discount, so
-- the receipt can show what the promotion saved.
--
-- The figure comes from the order row: migration 134 writes it when the
-- order lines are inserted, so it is the database that decides it.

drop function if exists public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid
);

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
  reused_existing_order boolean,
  product_discount_total numeric
)
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  v_order record;
  v_product_discount numeric := 0;
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

  select o.product_discount_total into v_product_discount
    from orders.orders o
   where o.id = v_order.order_id;

  return query select v_order.order_id, v_order.order_number,
    v_order.subtotal, v_order.discount_total, v_order.delivery_fee,
    v_order.tax_total, v_order.grand_total, v_order.points_earned,
    v_order.reused_existing_order, coalesce(v_product_discount, 0);
end;
$fn$;

revoke all on function public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid
) from public, anon;
grant execute on function public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid
) to authenticated, service_role;

notify pgrst, 'reload schema';
