-- A customer card checkout is a draft until Moyasar confirms payment.
-- Keeping the payload here avoids creating an order (and triggering stock,
-- coupon, loyalty, and order.placed side effects) before payment succeeds.
create table if not exists public.moyasar_checkout_intents (
  payment_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  checkout_payload jsonb not null,
  checkout_key text not null,
  amount numeric(12,2) not null check (amount > 0),
  currency_code text not null default 'SAR',
  status text not null default 'pending'
    check (status in ('pending','captured','failed','refunded','finalized')),
  order_id uuid references orders.orders(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_moyasar_checkout_active_key
  on public.moyasar_checkout_intents(user_id, checkout_key)
  where status in ('pending','captured','finalized');

alter table public.moyasar_checkout_intents enable row level security;
revoke all on public.moyasar_checkout_intents from public, anon, authenticated;
grant all on public.moyasar_checkout_intents to service_role;

create or replace function public.finalize_moyasar_checkout(
  p_payment_id uuid,
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_auth_user_id uuid := auth.uid();
  v_user_id uuid := coalesce(auth.uid(), p_user_id);
  v_intent public.moyasar_checkout_intents%rowtype;
  v_order record;
  v_saved orders.orders%rowtype;
  v_payload jsonb;
  v_method_id uuid;
begin
  if v_user_id is null or
     (v_auth_user_id is null and auth.role() <> 'service_role') or
     (v_auth_user_id is not null and p_user_id is not null
       and v_auth_user_id <> p_user_id) then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_intent
    from public.moyasar_checkout_intents
   where payment_id = p_payment_id and user_id = v_user_id
   for update;
  if not found then
    raise exception 'payment checkout not found' using errcode = 'P0002';
  end if;

  if v_intent.status = 'finalized' and v_intent.order_id is not null then
    select * into v_saved from orders.orders where id = v_intent.order_id;
  else
    if v_intent.status <> 'captured' then
      raise exception 'payment has not been verified' using errcode = '42501';
    end if;
    v_payload := v_intent.checkout_payload;
    if v_auth_user_id is null then
      perform set_config('request.jwt.claim.sub', v_user_id::text, true);
    end if;

    if nullif(v_payload->>'scheduled_pickup_at', '') is not null then
      if to_regprocedure(
        'public.place_order_with_pickup_schedule(uuid,jsonb,text,numeric,uuid,text,text,uuid,timestamptz,uuid)'
      ) is null then
        raise exception 'scheduled pickup is not available on this checkout'
          using errcode = '23514';
      end if;
      select * into v_order from public.place_order_with_pickup_schedule(
        (v_payload->>'branch_id')::uuid,
        v_payload->'lines',
        v_payload->>'idempotency_key',
        v_intent.amount,
        nullif(v_payload->>'delivery_zone_id', '')::uuid,
        nullif(v_payload->>'coupon_code', ''),
        null,
        nullif(v_payload->>'address_id', '')::uuid,
        (v_payload->>'scheduled_pickup_at')::timestamptz,
        nullif(v_payload->>'subscription_run_id', '')::uuid
      );
    else
      select * into v_order from public.place_order_with_quote(
        (v_payload->>'branch_id')::uuid,
        v_payload->'lines',
        v_payload->>'idempotency_key',
        v_payload->>'fulfillment_type',
        v_intent.amount,
        nullif(v_payload->>'delivery_zone_id', '')::uuid,
        nullif(v_payload->>'coupon_code', ''),
        null,
        nullif(v_payload->>'address_id', '')::uuid,
        nullif(v_payload->>'subscription_run_id', '')::uuid
      );
    end if;

    select id into v_method_id
      from payments.payment_methods
     where code = coalesce(v_payload->>'payment_method_code', 'card')
     limit 1;

    -- The transaction and order are committed together. A failure in order
    -- repricing, stock validation, or invoice creation rolls this whole RPC
    -- back; no unpaid order or stock/loyalty side effect is left behind.
    insert into payments.payment_transactions (
      order_id, provider, provider_reference, amount, currency_code,
      status, paid_at, verified_by_server
    ) values (
      v_order.order_id, 'moyasar', p_payment_id::text, v_intent.amount,
      v_intent.currency_code, 'captured', now(), true
    );

    update orders.orders
       set payment_method_id = coalesce(v_method_id, payment_method_id),
           payment_status = 'paid'
     where id = v_order.order_id and user_id = v_user_id;

    update public.moyasar_checkout_intents
       set status = 'finalized', order_id = v_order.order_id,
           updated_at = now()
     where payment_id = p_payment_id;
    select * into v_saved from orders.orders where id = v_order.order_id;
  end if;

  if v_saved.id is null or v_saved.payment_status <> 'paid' then
    raise exception 'verified payment has no paid order' using errcode = '23514';
  end if;

  return jsonb_build_object(
    'order_id', v_saved.id,
    'order_number', v_saved.order_number,
    'subtotal', v_saved.subtotal,
    'discount_total', v_saved.discount_total,
    'delivery_fee', v_saved.delivery_fee,
    'tax_total', v_saved.tax_total,
    'grand_total', v_saved.grand_total,
    'points_earned', v_saved.loyalty_points_earned,
    'product_discount_total', v_saved.product_discount_total,
    'placed_at', v_saved.placed_at,
    'payment_status', v_saved.payment_status
  );
end;
$fn$;

revoke all on function public.finalize_moyasar_checkout(uuid, uuid)
  from public, anon;
grant execute on function public.finalize_moyasar_checkout(uuid, uuid)
  to authenticated, service_role;
