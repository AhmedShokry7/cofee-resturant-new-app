begin;

-- Keep the public checkout wrapper as SECURITY INVOKER. Small, ownership-checked
-- helpers take the required row locks and update only the caller's pending run.
create or replace function subscriptions.lock_customer_product_subscription_run(
  p_run_id uuid
)
returns table (
  run_id uuid,
  subscription_id uuid,
  scheduled_for timestamptz,
  branch_id uuid,
  fulfillment_type text,
  delivery_address_id uuid,
  recurrence_type text,
  interval_value integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_run subscriptions.customer_product_subscription_runs%rowtype;
  v_subscription subscriptions.customer_product_subscriptions%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  select * into v_run
    from subscriptions.customer_product_subscription_runs r
   where r.id = p_run_id and r.user_id = v_uid
   for update;
  if not found or v_run.status <> 'pending' or v_run.scheduled_for > now() then
    raise exception 'subscription order is no longer awaiting confirmation' using errcode = '22023';
  end if;
  select * into v_subscription
    from subscriptions.customer_product_subscriptions s
   where s.id = v_run.subscription_id and s.user_id = v_uid
   for update;
  if not found or v_subscription.status <> 'active' then
    raise exception 'subscription is not active' using errcode = '22023';
  end if;

  run_id := v_run.id;
  subscription_id := v_subscription.id;
  scheduled_for := v_run.scheduled_for;
  branch_id := v_subscription.branch_id;
  fulfillment_type := v_subscription.fulfillment_type;
  delivery_address_id := v_subscription.delivery_address_id;
  recurrence_type := v_subscription.recurrence_type;
  interval_value := v_subscription.interval_value;
  return next;
end;
$$;

create or replace function subscriptions.complete_customer_product_subscription_run(
  p_run_id uuid,
  p_order_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_run subscriptions.customer_product_subscription_runs%rowtype;
  v_subscription subscriptions.customer_product_subscriptions%rowtype;
  v_order orders.orders%rowtype;
  v_expected_count integer;
  v_order_count integer;
  v_next timestamptz;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  select * into v_run
    from subscriptions.customer_product_subscription_runs r
   where r.id = p_run_id and r.user_id = v_uid
   for update;
  if not found or v_run.status <> 'pending' or v_run.scheduled_for > now() then
    raise exception 'subscription order is no longer awaiting confirmation' using errcode = '22023';
  end if;
  select * into v_subscription
    from subscriptions.customer_product_subscriptions s
   where s.id = v_run.subscription_id and s.user_id = v_uid
   for update;
  if not found or v_subscription.status <> 'active' then
    raise exception 'subscription is not active' using errcode = '22023';
  end if;
  select * into v_order from orders.orders o
   where o.id = p_order_id and o.user_id = v_uid;
  if not found
     or v_order.branch_id <> v_subscription.branch_id
     or v_order.fulfillment_type <> v_subscription.fulfillment_type then
    raise exception 'order does not match the subscription' using errcode = '22023';
  end if;

  select count(*) into v_expected_count
    from subscriptions.customer_product_subscription_items i
   where i.subscription_id = v_subscription.id;
  select count(*) into v_order_count
    from orders.order_items oi where oi.order_id = v_order.id;
  if v_order_count <> v_expected_count or exists (
    select 1 from subscriptions.customer_product_subscription_items i
     where i.subscription_id = v_subscription.id
       and not exists (
         select 1 from orders.order_items oi
          where oi.order_id = v_order.id
            and oi.product_id = i.product_id
            and oi.quantity = i.quantity
       )
  ) then
    raise exception 'order items do not match the subscription' using errcode = '22023';
  end if;

  update subscriptions.customer_product_subscription_runs
     set status = 'completed', order_id = v_order.id,
         executed_at = now(), error = null
   where id = v_run.id and status = 'pending';
  if not found then
    raise exception 'subscription order was already completed' using errcode = '40001';
  end if;

  v_next := subscriptions.customer_product_subscription_next_run(
    v_run.scheduled_for, v_subscription.recurrence_type,
    v_subscription.interval_value
  );
  while v_next <= now() loop
    v_next := subscriptions.customer_product_subscription_next_run(
      v_next, v_subscription.recurrence_type, v_subscription.interval_value
    );
  end loop;
  update subscriptions.customer_product_subscriptions
     set next_run_at = v_next, last_run_at = now(), updated_at = now()
   where id = v_subscription.id and user_id = v_uid and status = 'active';
  return true;
end;
$$;

revoke all on function subscriptions.lock_customer_product_subscription_run(uuid) from public, anon;
grant execute on function subscriptions.lock_customer_product_subscription_run(uuid) to authenticated;
revoke all on function subscriptions.complete_customer_product_subscription_run(uuid, uuid) from public, anon;
grant execute on function subscriptions.complete_customer_product_subscription_run(uuid, uuid) to authenticated;

create or replace function public.place_order_with_quote(
  p_branch_id uuid,
  p_lines jsonb,
  p_idempotency_key text,
  p_fulfillment_type text,
  p_expected_total numeric,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_note text default null,
  p_address_id uuid default null,
  p_subscription_run_id uuid default null
)
returns table (
  order_id uuid, order_number text, subtotal numeric, discount_total numeric,
  delivery_fee numeric, tax_total numeric, grand_total numeric,
  points_earned integer, reused_existing_order boolean
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_order record;
  v_run record;
  v_item_count integer;
begin
  if p_expected_total is null then
    raise exception 'checkout quote required' using errcode = '22023';
  end if;
  if p_subscription_run_id is not null then
    select * into v_run
      from subscriptions.lock_customer_product_subscription_run(p_subscription_run_id);
    if v_run.branch_id <> p_branch_id
       or v_run.fulfillment_type <> p_fulfillment_type
       or (v_run.fulfillment_type = 'delivery'
           and v_run.delivery_address_id is distinct from p_address_id) then
      raise exception 'subscription checkout settings changed' using errcode = '22023';
    end if;

    select count(*) into v_item_count
      from subscriptions.customer_product_subscription_items i
     where i.subscription_id = v_run.subscription_id;
    if coalesce(jsonb_typeof(p_lines), '') <> 'array'
       or jsonb_array_length(p_lines) <> v_item_count
       or exists (
         select 1
           from subscriptions.customer_product_subscription_items i
          where i.subscription_id = v_run.subscription_id
            and not exists (
              select 1 from jsonb_array_elements(p_lines) line
               where line->>'product_id' = i.product_id::text
                 and coalesce((line->>'quantity')::integer, 0) = i.quantity
            )
       ) then
      raise exception 'checkout items do not match the scheduled subscription' using errcode = '22023';
    end if;
  end if;

  select * into v_order from public.place_order_with_lines(
    p_branch_id, p_lines, p_idempotency_key, p_fulfillment_type,
    p_delivery_zone_id, p_coupon_code, p_note, p_address_id
  );
  if abs(v_order.grand_total - p_expected_total) > 0.005 then
    raise exception 'checkout total changed; refresh quote' using errcode = '40001';
  end if;
  if p_subscription_run_id is not null then
    perform subscriptions.complete_customer_product_subscription_run(
      p_subscription_run_id, v_order.order_id
    );
  end if;
  return query select v_order.order_id, v_order.order_number,
    v_order.subtotal, v_order.discount_total, v_order.delivery_fee,
    v_order.tax_total, v_order.grand_total, v_order.points_earned,
    v_order.reused_existing_order;
end;
$$;
revoke all on function public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid, uuid
) from public, anon;
grant execute on function public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid, uuid
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
