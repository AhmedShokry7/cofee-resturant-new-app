-- 270_customer_bundles_subscriptions_reservations.sql
-- Customer personal bundles, customer product subscriptions, and customer
-- reservation requests. Additive / idempotent where possible.
--
-- Design notes:
-- - Personal bundles are customer-owned rows in public schema for direct client
--   access under RLS; admin management goes through SECURITY DEFINER RPCs.
-- - Product subscriptions are recurring personal product orders, separate from
--   existing plan subscriptions (subscriptions.subscriptions / subscriptions.plans).
-- - Reservations extend the existing floor.reservations model so admin/POS and
--   customer booking share one source of truth.

begin;

-- ---------------------------------------------------------------------------
-- Shared helper: updated_at touch
-- ---------------------------------------------------------------------------
create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- A. Personal Bundles
-- ---------------------------------------------------------------------------
create table if not exists public.customer_bundles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text,
  is_favorite boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_customer_bundles_name check (char_length(btrim(name)) between 1 and 80),
  constraint ck_customer_bundles_description check (description is null or char_length(description) <= 500)
);

create index if not exists ix_customer_bundles_user_created
  on public.customer_bundles(user_id, created_at desc);
create index if not exists ix_customer_bundles_user_active
  on public.customer_bundles(user_id, is_active, updated_at desc);

create table if not exists public.customer_bundle_items (
  id uuid primary key default gen_random_uuid(),
  bundle_id uuid not null references public.customer_bundles(id) on delete cascade,
  product_id uuid not null references catalog.products(id) on delete restrict,
  quantity integer not null default 1,
  sort_order integer not null default 0,
  selected_options jsonb not null default '{}'::jsonb,
  allow_options boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_customer_bundle_items_qty check (quantity > 0 and quantity <= 99),
  constraint ck_customer_bundle_items_note check (note is null or char_length(note) <= 300),
  constraint ck_customer_bundle_items_options check (jsonb_typeof(selected_options) = 'object')
);

create index if not exists ix_customer_bundle_items_bundle
  on public.customer_bundle_items(bundle_id, sort_order, created_at);

-- Prevent exact duplicate product rows inside same bundle for simple MVP.
create unique index if not exists uq_customer_bundle_items_bundle_product
  on public.customer_bundle_items(bundle_id, product_id);

drop trigger if exists trg_customer_bundles_updated_at on public.customer_bundles;
create trigger trg_customer_bundles_updated_at
before update on public.customer_bundles
for each row execute function public.tg_set_updated_at();

drop trigger if exists trg_customer_bundle_items_updated_at on public.customer_bundle_items;
create trigger trg_customer_bundle_items_updated_at
before update on public.customer_bundle_items
for each row execute function public.tg_set_updated_at();

alter table public.customer_bundles enable row level security;
alter table public.customer_bundle_items enable row level security;

drop policy if exists customer_bundles_select_own on public.customer_bundles;
create policy customer_bundles_select_own on public.customer_bundles
  for select to authenticated
  using (auth.uid() = user_id or identity.is_staff());

drop policy if exists customer_bundles_insert_own on public.customer_bundles;
create policy customer_bundles_insert_own on public.customer_bundles
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists customer_bundles_update_own on public.customer_bundles;
create policy customer_bundles_update_own on public.customer_bundles
  for update to authenticated
  using (auth.uid() = user_id or identity.is_staff())
  with check (auth.uid() = user_id or identity.is_staff());

drop policy if exists customer_bundles_delete_own on public.customer_bundles;
create policy customer_bundles_delete_own on public.customer_bundles
  for delete to authenticated
  using (auth.uid() = user_id or identity.is_staff());

drop policy if exists customer_bundle_items_select_own on public.customer_bundle_items;
create policy customer_bundle_items_select_own on public.customer_bundle_items
  for select to authenticated
  using (
    exists (
      select 1 from public.customer_bundles b
      where b.id = bundle_id and (b.user_id = auth.uid() or identity.is_staff())
    )
  );

drop policy if exists customer_bundle_items_insert_own on public.customer_bundle_items;
create policy customer_bundle_items_insert_own on public.customer_bundle_items
  for insert to authenticated
  with check (
    exists (
      select 1 from public.customer_bundles b
      where b.id = bundle_id and b.user_id = auth.uid()
    )
  );

drop policy if exists customer_bundle_items_update_own on public.customer_bundle_items;
create policy customer_bundle_items_update_own on public.customer_bundle_items
  for update to authenticated
  using (
    exists (
      select 1 from public.customer_bundles b
      where b.id = bundle_id and (b.user_id = auth.uid() or identity.is_staff())
    )
  )
  with check (
    exists (
      select 1 from public.customer_bundles b
      where b.id = bundle_id and (b.user_id = auth.uid() or identity.is_staff())
    )
  );

drop policy if exists customer_bundle_items_delete_own on public.customer_bundle_items;
create policy customer_bundle_items_delete_own on public.customer_bundle_items
  for delete to authenticated
  using (
    exists (
      select 1 from public.customer_bundles b
      where b.id = bundle_id and (b.user_id = auth.uid() or identity.is_staff())
    )
  );

grant select, insert, update, delete on public.customer_bundles to authenticated;
grant select, insert, update, delete on public.customer_bundle_items to authenticated;

create or replace function public.admin_list_customer_bundles(
  p_query text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 200));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_q text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if exists (select 1 from identity.permissions p where p.code = 'bundles.read')
     and not identity.has_permission('bundles.read')
     and not identity.has_permission('bundles.manage') then
    raise exception 'missing permission: bundles.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc)
    from (
      select
        b.id,
        b.user_id,
        b.name,
        b.description,
        b.is_favorite,
        b.is_active,
        b.created_at,
        b.updated_at,
        coalesce(pr.full_name, pr.phone, b.user_id::text) as owner_label,
        (select count(*)::int from public.customer_bundle_items i where i.bundle_id = b.id) as item_count
      from public.customer_bundles b
      left join identity.profiles pr on pr.id = b.user_id
      where v_q is null
         or b.name ilike '%' || v_q || '%'
         or coalesce(pr.full_name, '') ilike '%' || v_q || '%'
         or coalesce(pr.phone, '') ilike '%' || v_q || '%'
      order by b.created_at desc
      limit v_limit offset v_offset
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_customer_bundles(text, integer, integer) from public, anon;
grant execute on function public.admin_list_customer_bundles(text, integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- B. Customer Product Subscriptions (separate from plan subscriptions)
-- ---------------------------------------------------------------------------
create table if not exists subscriptions.customer_product_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text,
  status text not null default 'active',
  recurrence_type text not null,
  interval_value integer not null default 1,
  start_date date not null,
  next_run_at timestamptz,
  branch_id uuid not null references core.branches(id),
  fulfillment_type text not null,
  delivery_address_id uuid references identity.customer_addresses(id) on delete set null,
  notes text,
  paused_at timestamptz,
  cancelled_at timestamptz,
  last_run_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_cps_status check (status in ('active','paused','cancelled','expired')),
  constraint ck_cps_recurrence check (recurrence_type in ('weekly','monthly')),
  constraint ck_cps_interval check (interval_value between 1 and 12),
  constraint ck_cps_fulfillment check (fulfillment_type in ('pickup','delivery')),
  constraint ck_cps_name check (name is null or char_length(btrim(name)) between 1 and 80),
  constraint ck_cps_notes check (notes is null or char_length(notes) <= 500)
);

create index if not exists ix_cps_user_created
  on subscriptions.customer_product_subscriptions(user_id, created_at desc);
create index if not exists ix_cps_next_run
  on subscriptions.customer_product_subscriptions(status, next_run_at)
  where status = 'active';

create table if not exists subscriptions.customer_product_subscription_items (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references subscriptions.customer_product_subscriptions(id) on delete cascade,
  product_id uuid not null references catalog.products(id) on delete restrict,
  quantity integer not null default 1,
  selected_options jsonb not null default '{}'::jsonb,
  note text,
  created_at timestamptz not null default now(),
  constraint ck_cpsi_qty check (quantity > 0 and quantity <= 99),
  constraint ck_cpsi_note check (note is null or char_length(note) <= 300),
  constraint ck_cpsi_options check (jsonb_typeof(selected_options) = 'object')
);

create index if not exists ix_cpsi_subscription
  on subscriptions.customer_product_subscription_items(subscription_id);

-- Execution history / idempotency for scheduled runs
create table if not exists subscriptions.customer_product_subscription_runs (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references subscriptions.customer_product_subscriptions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  scheduled_for timestamptz not null,
  executed_at timestamptz,
  status text not null default 'pending',
  order_id uuid references orders.orders(id) on delete set null,
  error text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  constraint ck_cpsr_status check (status in ('pending','completed','failed','skipped')),
  constraint uq_cpsr_idempotency unique (idempotency_key)
);

create index if not exists ix_cpsr_subscription
  on subscriptions.customer_product_subscription_runs(subscription_id, scheduled_for desc);

drop trigger if exists trg_cps_updated_at on subscriptions.customer_product_subscriptions;
create trigger trg_cps_updated_at
before update on subscriptions.customer_product_subscriptions
for each row execute function public.tg_set_updated_at();

alter table subscriptions.customer_product_subscriptions enable row level security;
alter table subscriptions.customer_product_subscription_items enable row level security;
alter table subscriptions.customer_product_subscription_runs enable row level security;

drop policy if exists cps_select_own on subscriptions.customer_product_subscriptions;
create policy cps_select_own on subscriptions.customer_product_subscriptions
  for select to authenticated
  using (auth.uid() = user_id or identity.is_staff());

drop policy if exists cps_insert_own on subscriptions.customer_product_subscriptions;
create policy cps_insert_own on subscriptions.customer_product_subscriptions
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists cps_update_own on subscriptions.customer_product_subscriptions;
create policy cps_update_own on subscriptions.customer_product_subscriptions
  for update to authenticated
  using (auth.uid() = user_id or identity.is_staff())
  with check (auth.uid() = user_id or identity.is_staff());

drop policy if exists cpsi_select_own on subscriptions.customer_product_subscription_items;
create policy cpsi_select_own on subscriptions.customer_product_subscription_items
  for select to authenticated
  using (
    exists (
      select 1 from subscriptions.customer_product_subscriptions s
      where s.id = subscription_id and (s.user_id = auth.uid() or identity.is_staff())
    )
  );

drop policy if exists cpsi_insert_own on subscriptions.customer_product_subscription_items;
create policy cpsi_insert_own on subscriptions.customer_product_subscription_items
  for insert to authenticated
  with check (
    exists (
      select 1 from subscriptions.customer_product_subscriptions s
      where s.id = subscription_id and s.user_id = auth.uid()
    )
  );

drop policy if exists cpsi_update_own on subscriptions.customer_product_subscription_items;
create policy cpsi_update_own on subscriptions.customer_product_subscription_items
  for update to authenticated
  using (
    exists (
      select 1 from subscriptions.customer_product_subscriptions s
      where s.id = subscription_id and (s.user_id = auth.uid() or identity.is_staff())
    )
  )
  with check (
    exists (
      select 1 from subscriptions.customer_product_subscriptions s
      where s.id = subscription_id and (s.user_id = auth.uid() or identity.is_staff())
    )
  );

drop policy if exists cpsi_delete_own on subscriptions.customer_product_subscription_items;
create policy cpsi_delete_own on subscriptions.customer_product_subscription_items
  for delete to authenticated
  using (
    exists (
      select 1 from subscriptions.customer_product_subscriptions s
      where s.id = subscription_id and (s.user_id = auth.uid() or identity.is_staff())
    )
  );

drop policy if exists cpsr_select_own on subscriptions.customer_product_subscription_runs;
create policy cpsr_select_own on subscriptions.customer_product_subscription_runs
  for select to authenticated
  using (auth.uid() = user_id or identity.is_staff());

grant select, insert, update, delete on subscriptions.customer_product_subscriptions to authenticated;
grant select, insert, update, delete on subscriptions.customer_product_subscription_items to authenticated;
grant select on subscriptions.customer_product_subscription_runs to authenticated;

-- compute next run
create or replace function subscriptions.customer_product_subscription_next_run(
  p_from timestamptz,
  p_recurrence_type text,
  p_interval_value integer
)
returns timestamptz
language sql
immutable
as $$
  select case
    when p_recurrence_type = 'weekly' then p_from + make_interval(weeks => greatest(1, coalesce(p_interval_value, 1)))
    else p_from + make_interval(months => greatest(1, coalesce(p_interval_value, 1)))
  end;
$$;

-- Customer RPCs
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
      select
        s.*,
        (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', i.id,
            'product_id', i.product_id,
            'quantity', i.quantity,
            'selected_options', i.selected_options,
            'note', i.note,
            'product_name_ar', p.name_ar,
            'product_name_en', p.name_en
          ) order by i.created_at), '[]'::jsonb)
          from subscriptions.customer_product_subscription_items i
          left join catalog.products p on p.id = i.product_id
          where i.subscription_id = s.id
        ) as items
      from subscriptions.customer_product_subscriptions s
      where s.user_id = v_uid
      order by s.created_at desc
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_my_customer_product_subscriptions() from public, anon;
grant execute on function public.list_my_customer_product_subscriptions() to authenticated;

create or replace function public.create_customer_product_subscription(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_name text := nullif(btrim(coalesce(p_payload->>'name','')), '');
  v_recurrence text := lower(btrim(coalesce(p_payload->>'recurrence_type','weekly')));
  v_interval integer := greatest(1, least(coalesce((p_payload->>'interval_value')::int, 1), 12));
  v_start date := coalesce((p_payload->>'start_date')::date, current_date);
  v_branch uuid := nullif(p_payload->>'branch_id','')::uuid;
  v_fulfillment text := lower(btrim(coalesce(p_payload->>'fulfillment_type','pickup')));
  v_delivery uuid := nullif(p_payload->>'delivery_address_id','')::uuid;
  v_notes text := nullif(btrim(coalesce(p_payload->>'notes','')), '');
  v_next_run timestamptz;
  v_item jsonb;
  v_product uuid;
  v_qty integer;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if v_recurrence not in ('weekly','monthly') then raise exception 'invalid recurrence_type'; end if;
  if v_fulfillment not in ('pickup','delivery') then raise exception 'invalid fulfillment_type'; end if;
  if v_branch is null then raise exception 'branch_id required'; end if;
  if not exists (select 1 from core.branches b where b.id = v_branch and b.is_active = true) then
    raise exception 'invalid branch';
  end if;
  if v_fulfillment = 'delivery' and v_delivery is not null then
    if not exists (select 1 from identity.customer_addresses a where a.id = v_delivery and a.user_id = v_uid) then
      raise exception 'invalid delivery address';
    end if;
  end if;

  v_next_run := subscriptions.customer_product_subscription_next_run(v_start::timestamptz, v_recurrence, v_interval);
  if v_next_run < now() then
    v_next_run := subscriptions.customer_product_subscription_next_run(now(), v_recurrence, v_interval);
  end if;

  insert into subscriptions.customer_product_subscriptions (
    id, user_id, name, status, recurrence_type, interval_value, start_date, next_run_at,
    branch_id, fulfillment_type, delivery_address_id, notes
  ) values (
    v_id, v_uid, v_name, 'active', v_recurrence, v_interval, v_start, v_next_run,
    v_branch, v_fulfillment, v_delivery, v_notes
  );

  for v_item in select * from jsonb_array_elements(coalesce(p_payload->'items','[]'::jsonb))
  loop
    v_product := nullif(v_item->>'product_id','')::uuid;
    v_qty := greatest(1, least(coalesce((v_item->>'quantity')::int, 1), 99));
    if v_product is null then continue; end if;
    if not exists (select 1 from catalog.products p where p.id = v_product and p.is_active = true) then
      raise exception 'invalid product %', v_product;
    end if;
    insert into subscriptions.customer_product_subscription_items (
      subscription_id, product_id, quantity, selected_options, note
    ) values (
      v_id,
      v_product,
      v_qty,
      coalesce(v_item->'selected_options', '{}'::jsonb),
      nullif(btrim(coalesce(v_item->>'note','')), '')
    );
  end loop;

  if not exists (select 1 from subscriptions.customer_product_subscription_items i where i.subscription_id = v_id) then
    raise exception 'at least one item required';
  end if;

  return v_id;
end;
$$;
revoke all on function public.create_customer_product_subscription(jsonb) from public, anon;
grant execute on function public.create_customer_product_subscription(jsonb) to authenticated;

create or replace function public.pause_my_customer_product_subscription(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  update subscriptions.customer_product_subscriptions
     set status = 'paused', paused_at = now(), updated_at = now()
   where id = p_id and user_id = v_uid and status = 'active';
  return found;
end;
$$;
revoke all on function public.pause_my_customer_product_subscription(uuid) from public, anon;
grant execute on function public.pause_my_customer_product_subscription(uuid) to authenticated;

create or replace function public.resume_my_customer_product_subscription(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_rec subscriptions.customer_product_subscriptions%rowtype;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  select * into v_rec
    from subscriptions.customer_product_subscriptions
   where id = p_id and user_id = v_uid
   for update;
  if not found or v_rec.status <> 'paused' then return false; end if;
  update subscriptions.customer_product_subscriptions
     set status = 'active',
         paused_at = null,
         next_run_at = case
           when v_rec.next_run_at is null or v_rec.next_run_at < now()
             then subscriptions.customer_product_subscription_next_run(now(), v_rec.recurrence_type, v_rec.interval_value)
           else v_rec.next_run_at
         end,
         updated_at = now()
   where id = p_id;
  return true;
end;
$$;
revoke all on function public.resume_my_customer_product_subscription(uuid) from public, anon;
grant execute on function public.resume_my_customer_product_subscription(uuid) to authenticated;

create or replace function public.cancel_my_customer_product_subscription(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  update subscriptions.customer_product_subscriptions
     set status = 'cancelled', cancelled_at = now(), updated_at = now()
   where id = p_id and user_id = v_uid and status in ('active','paused');
  return found;
end;
$$;
revoke all on function public.cancel_my_customer_product_subscription(uuid) from public, anon;
grant execute on function public.cancel_my_customer_product_subscription(uuid) to authenticated;

-- Admin RPCs for product subscriptions
create or replace function public.admin_list_customer_product_subscriptions(
  p_status text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 200));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc)
    from (
      select
        s.*,
        coalesce(pr.full_name, pr.phone, s.user_id::text) as owner_label,
        (select count(*)::int from subscriptions.customer_product_subscription_items i where i.subscription_id = s.id) as item_count
      from subscriptions.customer_product_subscriptions s
      left join identity.profiles pr on pr.id = s.user_id
      where v_status is null or s.status = v_status
      order by s.created_at desc
      limit v_limit offset v_offset
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_customer_product_subscriptions(text, integer, integer) from public, anon;
grant execute on function public.admin_list_customer_product_subscriptions(text, integer, integer) to authenticated;

create or replace function public.admin_set_customer_product_subscription_status(p_id uuid, p_status text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := lower(btrim(coalesce(p_status,'')));
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_status not in ('active','paused','cancelled','expired') then
    raise exception 'invalid status';
  end if;
  update subscriptions.customer_product_subscriptions
     set status = v_status,
         paused_at = case when v_status = 'paused' then now() else paused_at end,
         cancelled_at = case when v_status = 'cancelled' then now() else cancelled_at end,
         updated_at = now()
   where id = p_id;
  return found;
end;
$$;
revoke all on function public.admin_set_customer_product_subscription_status(uuid, text) from public, anon;
grant execute on function public.admin_set_customer_product_subscription_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- C. Reservations - extend existing floor.reservations for customer booking
-- ---------------------------------------------------------------------------
alter table floor.reservations
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists source text not null default 'staff',
  add column if not exists reservation_type text not null default 'table',
  add column if not exists customer_note text,
  add column if not exists admin_note text,
  add column if not exists linked_event_id uuid,
  add column if not exists cancellation_reason text,
  add column if not exists reviewed_by uuid references identity.staff_members(id) on delete set null,
  add column if not exists reviewed_at timestamptz,
  add column if not exists approved_at timestamptz,
  add column if not exists rejected_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists reserved_until timestamptz,
  add column if not exists requested_end_at timestamptz;

update floor.reservations
   set reserved_until = reserved_for + make_interval(mins => coalesce(duration_minutes, 90))
 where reserved_until is null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'ck_floor_reservations_source'
  ) then
    alter table floor.reservations
      add constraint ck_floor_reservations_source check (source in ('admin','customer'));
  end if;
end $$;

-- Extend status check to include customer booking lifecycle.
-- Original: confirmed, seated, completed, cancelled, no_show
-- Add: pending, approved, rejected
alter table floor.reservations drop constraint if exists floor_reservations_status_check;
alter table floor.reservations
  add constraint floor_reservations_status_check
  check (status in ('pending','approved','rejected','confirmed','seated','completed','cancelled','no_show'));

create index if not exists ix_floor_reservations_user
  on floor.reservations(user_id, reserved_for desc)
  where user_id is not null;
create index if not exists ix_floor_reservations_source_status
  on floor.reservations(source, status, reserved_for desc);

-- Update overlap validation: approved should block like confirmed.
create or replace function floor.validate_reservation()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  v_table_branch uuid;
  v_table_active boolean;
  v_start        timestamptz;
  v_end          timestamptz;
  v_buffer       interval := interval '15 minutes';
  v_conflict     uuid;
begin
  if new.table_id is null then
    raise exception 'reservation table is required' using errcode = '23502';
  end if;

  if new.reserved_for is null then
    raise exception 'reservation time is required' using errcode = '23502';
  end if;

  if coalesce(new.duration_minutes, 0) < 30
     or coalesce(new.duration_minutes, 0) > 480 then
    raise exception 'invalid reservation duration' using errcode = '22023';
  end if;

  select t.branch_id, t.is_active
    into v_table_branch, v_table_active
    from floor.tables t
   where t.id = new.table_id
   for share;

  if v_table_branch is null then
    raise exception 'table not found' using errcode = '23503';
  end if;

  new.branch_id := v_table_branch;

  if new.status in ('approved','confirmed', 'seated') and not v_table_active then
    raise exception 'table is inactive' using errcode = '23514';
  end if;

  new.duration_minutes := coalesce(new.duration_minutes, 90);
  new.reserved_until := new.reserved_for
    + make_interval(mins => new.duration_minutes);
  new.requested_end_at := coalesce(new.requested_end_at, new.reserved_until);

  if new.status in ('approved','confirmed', 'seated') then
    v_start := new.reserved_for - v_buffer;
    v_end := new.reserved_until + v_buffer;

    select r.id into v_conflict
      from floor.reservations r
     where r.table_id = new.table_id
       and r.id is distinct from new.id
       and r.status in ('approved','confirmed', 'seated')
       and tstzrange(r.reserved_for - v_buffer,
                     r.reserved_until + v_buffer, '[)') &&
           tstzrange(v_start, v_end, '[)')
     limit 1
     for share;

    if v_conflict is not null then
      raise exception 'reservation overlaps another booking'
        using errcode = '23P01';
    end if;
  end if;

  return new;
end;
$fn$;

-- Customer-facing reservation RPCs
create or replace function public.list_my_reservations()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.reserved_for desc)
    from (
      select
        r.id, r.branch_id, r.table_id, r.user_id, r.source, r.status,
        r.reserved_for, r.reserved_until, r.duration_minutes,
        r.party_size, r.customer_name, r.customer_phone, r.note,
        r.customer_note, r.admin_note, r.reviewed_at, r.created_at, r.updated_at,
        b.name_ar as branch_name_ar, b.name_en as branch_name_en,
        t.name as table_name, t.area as table_area
      from floor.reservations r
      left join core.branches b on b.id = r.branch_id
      left join floor.tables t on t.id = r.table_id
      where r.user_id = v_uid
      order by r.reserved_for desc
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_my_reservations() from public, anon;
grant execute on function public.list_my_reservations() to authenticated;

create or replace function public.create_customer_reservation(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_branch uuid := nullif(p_payload->>'branch_id','')::uuid;
  v_table uuid := nullif(p_payload->>'table_id','')::uuid;
  v_reserved_for timestamptz := (p_payload->>'reserved_for')::timestamptz;
  v_duration integer := greatest(30, least(coalesce((p_payload->>'duration_minutes')::int, 90), 480));
  v_party integer := greatest(1, least(coalesce((p_payload->>'party_size')::int, 2), 50));
  v_name text := nullif(btrim(coalesce(p_payload->>'customer_name','')), '');
  v_phone text := nullif(btrim(coalesce(p_payload->>'customer_phone','')), '');
  v_note text := nullif(btrim(coalesce(p_payload->>'note','')), '');
  v_customer_note text := nullif(btrim(coalesce(p_payload->>'customer_note','')), '');
  v_type text := lower(btrim(coalesce(p_payload->>'reservation_type','table')));
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if v_branch is null then raise exception 'branch_id required'; end if;
  if v_reserved_for is null then raise exception 'reserved_for required'; end if;
  if v_reserved_for < now() - interval '5 minutes' then raise exception 'reservation must be in the future'; end if;
  if not exists (select 1 from core.branches b where b.id = v_branch and b.is_active = true) then
    raise exception 'invalid branch';
  end if;
  if v_table is not null then
    if not exists (select 1 from floor.tables t where t.id = v_table and t.branch_id = v_branch and t.is_active = true) then
      raise exception 'invalid table';
    end if;
  end if;

  insert into floor.reservations (
    id, branch_id, table_id, user_id, source, status, reserved_for, duration_minutes,
    party_size, customer_name, customer_phone, note, customer_note, reserved_until, requested_end_at
  ) values (
    v_id, v_branch, v_table, v_uid, 'customer', 'pending', v_reserved_for, v_duration,
    v_party, coalesce(v_name, ''), coalesce(v_phone, ''), v_note, coalesce(v_customer_note, v_note),
    v_reserved_for + make_interval(mins => v_duration),
    v_reserved_for + make_interval(mins => v_duration)
  );
  return v_id;
end;
$$;
revoke all on function public.create_customer_reservation(jsonb) from public, anon;
grant execute on function public.create_customer_reservation(jsonb) to authenticated;

create or replace function public.cancel_my_reservation(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  update floor.reservations
     set status = 'cancelled', cancelled_at = now(), updated_at = now()
   where id = p_id and user_id = v_uid and status in ('pending','approved','confirmed');
  return found;
end;
$$;
revoke all on function public.cancel_my_reservation(uuid) from public, anon;
grant execute on function public.cancel_my_reservation(uuid) to authenticated;

-- Admin RPCs for customer reservations
create or replace function public.admin_list_customer_reservations(
  p_branch_id uuid default null,
  p_status text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 200));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_status text := nullif(btrim(coalesce(p_status,'')), '');
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.read') and not identity.has_permission('tables.manage') then
    if exists (select 1 from identity.permissions p where p.code = 'tables.read') then
      raise exception 'missing permission: tables.read' using errcode = '42501';
    end if;
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.reserved_for desc)
    from (
      select
        r.id, r.branch_id, r.table_id, r.user_id, r.source, r.status,
        r.reserved_for, r.reserved_until, r.duration_minutes, r.party_size,
        r.customer_name, r.customer_phone, r.note, r.customer_note, r.admin_note,
        r.reviewed_at, r.reviewed_by, r.created_at, r.updated_at,
        coalesce(pr.full_name, pr.phone, r.user_id::text) as owner_label,
        b.name_ar as branch_name_ar, b.name_en as branch_name_en,
        t.name as table_name, t.area as table_area
      from floor.reservations r
      left join identity.profiles pr on pr.id = r.user_id
      left join core.branches b on b.id = r.branch_id
      left join floor.tables t on t.id = r.table_id
      where r.source = 'customer'
        and (p_branch_id is null or r.branch_id = p_branch_id)
        and (v_status is null or r.status = v_status)
        and (identity.is_admin() or identity.can_manage_branch(r.branch_id))
      order by r.reserved_for desc
      limit v_limit offset v_offset
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_customer_reservations(uuid, text, integer, integer) from public, anon;
grant execute on function public.admin_list_customer_reservations(uuid, text, integer, integer) to authenticated;

create or replace function public.admin_set_customer_reservation_status(
  p_id uuid,
  p_status text,
  p_admin_note text default null,
  p_table_id uuid default null,
  p_cancellation_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := lower(btrim(coalesce(p_status,'')));
  v_res floor.reservations%rowtype;
  v_staff uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_status not in ('approved','rejected','cancelled','completed','no_show','confirmed') then
    raise exception 'invalid status';
  end if;

  select * into v_res from floor.reservations where id = p_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if not identity.is_admin() and not identity.can_manage_branch(v_res.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if exists (select 1 from identity.permissions p where p.code = 'tables.manage')
     and not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;

  if p_table_id is not null then
    if not exists (select 1 from floor.tables t where t.id = p_table_id and t.branch_id = v_res.branch_id and t.is_active = true) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_table');
    end if;
  end if;

  select s.id into v_staff from identity.staff_members s where s.user_id = auth.uid() limit 1;

  update floor.reservations
     set status = v_status,
         admin_note = coalesce(nullif(btrim(coalesce(p_admin_note,'')), ''), admin_note),
         table_id = coalesce(p_table_id, table_id),
         reviewed_by = coalesce(v_staff, reviewed_by),
         reviewed_at = now(),
         cancelled_at = case when v_status in ('rejected','cancelled') then now() else cancelled_at end,
         completed_at = case when v_status = 'completed' then now() else completed_at end,
         updated_at = now()
   where id = p_id;

  return jsonb_build_object('ok', true, 'reason', '');
exception
  when sqlstate '23P01' then
    return jsonb_build_object('ok', false, 'reason', 'overlap');
end;
$$;
revoke all on function public.admin_set_customer_reservation_status(uuid, text, text, uuid, text) from public, anon;
grant execute on function public.admin_set_customer_reservation_status(uuid, text, text, uuid, text) to authenticated;

commit;
