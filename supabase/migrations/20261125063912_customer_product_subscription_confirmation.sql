begin;

-- A due occurrence waits for the customer; no order or charge is created by
-- the scheduler. The pending run is unique and stays pending until checkout
-- places its order, or the customer explicitly skips it.
create or replace function subscriptions.enqueue_due_customer_product_subscription_runs()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_subscription record;
  v_run_id uuid;
  v_count integer := 0;
  v_key text;
begin
  for v_subscription in
    select s.id, s.user_id, s.name, s.next_run_at
      from subscriptions.customer_product_subscriptions s
     where s.status = 'active'
       and s.next_run_at is not null
       and s.next_run_at <= now()
       and not exists (
         select 1 from subscriptions.customer_product_subscription_runs r
          where r.subscription_id = s.id and r.status = 'pending'
       )
     order by s.next_run_at
     for update of s skip locked
  loop
    v_key := 'cps-run:' || v_subscription.id::text || ':' ||
      to_char(v_subscription.next_run_at at time zone 'UTC', 'YYYYMMDDHH24MISSMS');
    insert into subscriptions.customer_product_subscription_runs (
      subscription_id, user_id, scheduled_for, status, idempotency_key
    ) values (
      v_subscription.id, v_subscription.user_id, v_subscription.next_run_at,
      'pending', v_key
    )
    on conflict (idempotency_key) do nothing
    returning id into v_run_id;

    if v_run_id is null then
      continue;
    end if;

    insert into engagement.notifications (
      user_id, type, title_ar, title_en, body_ar, body_en, payload,
      related_entity_type, related_entity_id, dedupe_key
    ) values (
      v_subscription.user_id, 'subscription',
      'موعد طلبك المتكرر', 'Your recurring order is due',
      case when nullif(btrim(v_subscription.name), '') is null
        then 'راجع منتجات اشتراكك وأكّد الطلب من صفحة اشتراكات المنتجات.'
        else 'حان موعد ' || v_subscription.name || '. راجع المنتجات وأكّد الطلب من صفحة اشتراكات المنتجات.' end,
      case when nullif(btrim(v_subscription.name), '') is null
        then 'Review your subscription items and confirm the order from Product Subscriptions.'
        else 'It is time for ' || v_subscription.name || '. Review the items and confirm the order from Product Subscriptions.' end,
      jsonb_build_object(
        'destination', 'product_subscriptions',
        'subscription_run_id', v_run_id
      ),
      'product_subscription_run', v_run_id,
      'customer-product-subscription-run:' || v_run_id::text
    )
    on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
    v_count := v_count + 1;
    v_run_id := null;
  end loop;
  return v_count;
end;
$$;
revoke all on function subscriptions.enqueue_due_customer_product_subscription_runs() from public, anon, authenticated;

-- The in-app list includes pending confirmation requests next to each schedule.
create or replace function public.list_my_customer_product_subscriptions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc)
      from (
        select s.*,
          (select coalesce(jsonb_agg(jsonb_build_object(
            'id', i.id, 'product_id', i.product_id, 'quantity', i.quantity,
            'selected_options', i.selected_options, 'note', i.note,
            'product_name_ar', p.name_ar, 'product_name_en', p.name_en
          ) order by i.created_at), '[]'::jsonb)
             from subscriptions.customer_product_subscription_items i
             left join catalog.products p on p.id = i.product_id
            where i.subscription_id = s.id) as items,
          (select coalesce(jsonb_agg(jsonb_build_object(
            'id', r.id, 'scheduled_for', r.scheduled_for, 'status', r.status
          ) order by r.scheduled_for), '[]'::jsonb)
             from subscriptions.customer_product_subscription_runs r
            where r.subscription_id = s.id and r.user_id = v_uid
              and r.status = 'pending') as pending_runs
          from subscriptions.customer_product_subscriptions s
         where s.user_id = v_uid
         order by s.created_at desc
      ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_my_customer_product_subscriptions() from public, anon;
grant execute on function public.list_my_customer_product_subscriptions() to authenticated;

create or replace function public.skip_my_customer_product_subscription_run(p_run_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_run subscriptions.customer_product_subscription_runs%rowtype;
  v_subscription subscriptions.customer_product_subscriptions%rowtype;
  v_next timestamptz;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  select * into v_run
    from subscriptions.customer_product_subscription_runs
   where id = p_run_id and user_id = v_uid and status = 'pending'
   for update;
  if not found then return false; end if;
  select * into v_subscription
    from subscriptions.customer_product_subscriptions
   where id = v_run.subscription_id and user_id = v_uid
   for update;
  if not found then return false; end if;

  update subscriptions.customer_product_subscription_runs
     set status = 'skipped', executed_at = now()
   where id = v_run.id and status = 'pending';

  if v_subscription.status = 'active' then
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
       set next_run_at = v_next, updated_at = now()
     where id = v_subscription.id;
  end if;
  return true;
end;
$$;
revoke all on function public.skip_my_customer_product_subscription_run(uuid) from public, anon;
grant execute on function public.skip_my_customer_product_subscription_run(uuid) to authenticated;

-- Place the normal, repriced checkout order and consume its pending run in the
-- same transaction. Retrying the same run reuses the order idempotency key.
drop function if exists public.place_order_with_quote(
  uuid, jsonb, text, text, numeric, uuid, text, text, uuid
);
create function public.place_order_with_quote(
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
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_order record;
  v_run subscriptions.customer_product_subscription_runs%rowtype;
  v_subscription subscriptions.customer_product_subscriptions%rowtype;
  v_next timestamptz;
  v_item_count integer;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_expected_total is null then
    raise exception 'checkout quote required' using errcode = '22023';
  end if;

  if p_subscription_run_id is not null then
    select * into v_run
      from subscriptions.customer_product_subscription_runs r
     where r.id = p_subscription_run_id and r.user_id = v_uid
     for update;
    if not found or v_run.status <> 'pending' or v_run.scheduled_for > now() then
      raise exception 'subscription order is no longer awaiting confirmation' using errcode = '22023';
    end if;
    select * into v_subscription
      from subscriptions.customer_product_subscriptions s
     where s.id = v_run.subscription_id and s.user_id = v_uid
     for update;
    if not found or v_subscription.status <> 'active'
       or v_subscription.branch_id <> p_branch_id
       or v_subscription.fulfillment_type <> p_fulfillment_type
       or (v_subscription.fulfillment_type = 'delivery'
           and v_subscription.delivery_address_id is distinct from p_address_id) then
      raise exception 'subscription checkout settings changed' using errcode = '22023';
    end if;

    select count(*) into v_item_count
      from subscriptions.customer_product_subscription_items i
     where i.subscription_id = v_subscription.id;
    if jsonb_typeof(p_lines) <> 'array'
       or jsonb_array_length(p_lines) <> v_item_count
       or exists (
         select 1
           from subscriptions.customer_product_subscription_items i
          where i.subscription_id = v_subscription.id
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
    update subscriptions.customer_product_subscription_runs
       set status = 'completed', order_id = v_order.order_id,
           executed_at = now(), error = null
     where id = v_run.id and user_id = v_uid and status = 'pending';
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

-- Process due schedules frequently. A pending occurrence blocks future ones
-- until the customer confirms or skips it.
do $$
declare v_job record;
begin
  for v_job in select jobid from cron.job
    where jobname = 'customer-product-subscription-run-schedule'
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;
end;
$$;
select cron.schedule(
  'customer-product-subscription-run-schedule',
  '*/5 * * * *',
  $job$select subscriptions.enqueue_due_customer_product_subscription_runs();$job$
);

notify pgrst, 'reload schema';
commit;
