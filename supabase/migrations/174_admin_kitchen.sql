-- 174_admin_kitchen.sql
-- Kitchen Display System (KDS) for the café / restaurant back office, plus the
-- order fields the upcoming point-of-sale screen needs.
--
-- Why a kitchen schema instead of reading orders directly
-- -------------------------------------------------------
-- The admin order directory answers "what did we sell?". A kitchen board answers
-- "what do we cook next?" and needs a different shape:
--   * one ticket per order, with its own lifecycle (queued -> preparing ->
--     ready -> completed) that survives an order status changed elsewhere;
--   * per-line progress, because a ticket with four drinks can be half ready;
--   * a stable queue position and time stamps for prep-time metrics.
-- Hiding those concerns inside orders.orders would make every order update
-- ambiguous, so the kitchen gets its own tables mirrored from the order.
--
-- Data flow
-- ---------
--   customer places order  ->  trigger creates kitchen ticket + ticket items
--   kitchen starts ticket  ->  ticket preparing; order pending/confirmed -> preparing
--   kitchen marks ready    ->  ticket ready; order preparing -> ready
--   kitchen completes      ->  ticket completed; pickup/dine-in order -> completed
--   order cancelled elsewhere -> ticket cancelled (earlier kitchen work stops)
--
-- The same triggers work for POS orders, so a future POS page only has to create
-- an order: it lands on the board automatically.
--
-- POS preparation in this migration
-- ---------------------------------
--   orders.orders.order_source  ('online' | 'pos', default 'online')
--   orders.orders.table_number  (dine-in table, nullable)
--   fulfillment_type            extended with 'dine_in'
--
-- Everything is idempotent so it can be re-applied after a partial run.

-- ---------------------------------------------------------------------------
-- 1. POS-ready order fields
-- ---------------------------------------------------------------------------
alter table orders.orders
  add column if not exists order_source text;

update orders.orders
   set order_source = 'online'
 where order_source is null;

alter table orders.orders
  alter column order_source set default 'online';

alter table orders.orders
  alter column order_source set not null;

alter table orders.orders
  add column if not exists table_number text;

comment on column orders.orders.order_source is
  'Where the order was created: online customer app or staff point of sale.';
comment on column orders.orders.table_number is
  'Dine-in table label captured by the POS or the customer app.';

do $$
declare
  v_constraint record;
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'orders.orders'::regclass
       and conname  = 'ck_orders_order_source'
  ) then
    alter table orders.orders
      add constraint ck_orders_order_source
      check (order_source in ('online', 'pos'));
  end if;

  if not exists (
    select 1 from pg_constraint
     where conrelid = 'orders.orders'::regclass
       and conname  = 'ck_orders_table_number'
  ) then
    alter table orders.orders
      add constraint ck_orders_table_number
      check (
        table_number is null
        or (btrim(table_number) <> '' and char_length(table_number) <= 20)
      );
  end if;
end;
$$;

-- The original inline CHECK does not allow dine_in. Drop exactly the
-- fulfillment-type constraint (identified by the pickup value) and replace it
-- with a named one, leaving ck_orders_delivery_needs_zone untouched.
do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select c.conname
      from pg_constraint c
     where c.conrelid = 'orders.orders'::regclass
       and c.contype  = 'c'
       and pg_get_constraintdef(c.oid) ilike '%fulfillment_type%'
       and pg_get_constraintdef(c.oid) ilike '%pickup%'
  loop
    execute format(
      'alter table orders.orders drop constraint %I',
      v_constraint.conname
    );
  end loop;

  if not exists (
    select 1 from pg_constraint
     where conrelid = 'orders.orders'::regclass
       and conname  = 'ck_orders_fulfillment_type'
  ) then
    alter table orders.orders
      add constraint ck_orders_fulfillment_type
      check (fulfillment_type in ('pickup', 'delivery', 'dine_in'));
  end if;
end;
$$;

-- Recalling a ticket that is already ready returns the order to preparing.
-- Completed orders are intentionally not reopened by a kitchen recall.
insert into orders.status_transitions (from_status, to_status, is_allowed)
values ('ready', 'preparing', true)
on conflict (from_status, to_status)
do update set is_allowed = excluded.is_allowed;

-- ---------------------------------------------------------------------------
-- 2. Permissions and the kitchen role
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('kitchen.read',
   'عرض المطبخ',
   'View kitchen',
   'Open the kitchen display board and see live tickets.'),
  ('kitchen.manage',
   'إدارة المطبخ',
   'Manage kitchen',
   'Start, ready, complete and recall kitchen tickets and their items.')
on conflict (code) do update
  set name_ar     = excluded.name_ar,
      name_en     = excluded.name_en,
      description = excluded.description;

insert into identity.roles (code, name_ar, name_en, description, is_system) values
  ('kitchen',
   'المطبخ',
   'Kitchen',
   'Kitchen display access. Starts and completes preparation tickets.',
   true)
on conflict (code) do nothing;

-- Manager and branch manager supervise the kitchen.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('kitchen.read', 'kitchen.manage')
 where r.code in ('manager', 'branch_manager')
on conflict do nothing;

-- The kitchen role prepares orders but does not browse the sales directory.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('kitchen.read', 'kitchen.manage', 'orders.read')
 where r.code = 'kitchen'
on conflict do nothing;

-- The cashier watches the board from the counter.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code = 'kitchen.read'
 where r.code = 'cashier'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 3. Schema and tables
-- ---------------------------------------------------------------------------
create schema if not exists kitchen;

create table if not exists kitchen.tickets (
  id            uuid primary key default extensions.gen_random_uuid(),
  order_id      uuid not null unique references orders.orders(id) on delete cascade,
  branch_id     uuid not null references core.branches(id) on delete restrict,
  status        text not null default 'queued'
                  check (status in ('queued','preparing','ready','completed','cancelled')),
  placed_at     timestamptz not null default now(),
  started_at    timestamptz,
  ready_at      timestamptz,
  completed_at  timestamptz,
  completed_by  uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table kitchen.tickets is
  'One preparation ticket per order. Created by trigger so online and POS orders both reach the kitchen.';

create index if not exists ix_kitchen_tickets_branch_status
  on kitchen.tickets (branch_id, status, placed_at);
create index if not exists ix_kitchen_tickets_placed
  on kitchen.tickets (placed_at);
create index if not exists ix_kitchen_tickets_completed
  on kitchen.tickets (completed_at desc)
  where completed_at is not null;

drop trigger if exists tr_kitchen_tickets_updated_at on kitchen.tickets;
create trigger tr_kitchen_tickets_updated_at
  before update on kitchen.tickets
  for each row execute function core.set_updated_at();

create table if not exists kitchen.ticket_items (
  id             uuid primary key default extensions.gen_random_uuid(),
  ticket_id      uuid not null references kitchen.tickets(id) on delete cascade,
  order_item_id  uuid not null unique references orders.order_items(id) on delete cascade,
  status         text not null default 'pending'
                   check (status in ('pending','preparing','ready')),
  started_at     timestamptz,
  ready_at       timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

comment on table kitchen.ticket_items is
  'Per-line preparation state. A ticket can be half ready; the ticket summary follows its items.';

create index if not exists ix_kitchen_ticket_items_ticket
  on kitchen.ticket_items (ticket_id);
create index if not exists ix_kitchen_ticket_items_status
  on kitchen.ticket_items (status);

drop trigger if exists tr_kitchen_ticket_items_updated_at on kitchen.ticket_items;
create trigger tr_kitchen_ticket_items_updated_at
  before update on kitchen.ticket_items
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. RLS. Reads are allowed for realtime subscribers; writes only via RPCs.
-- ---------------------------------------------------------------------------
alter table kitchen.tickets enable row level security;
alter table kitchen.ticket_items enable row level security;

drop policy if exists kitchen_tickets_staff_read on kitchen.tickets;
create policy kitchen_tickets_staff_read on kitchen.tickets
  for select to authenticated
  using (
    identity.has_permission('kitchen.read')
    and identity.can_manage_branch(branch_id)
  );

drop policy if exists kitchen_ticket_items_staff_read on kitchen.ticket_items;
create policy kitchen_ticket_items_staff_read on kitchen.ticket_items
  for select to authenticated
  using (
    identity.has_permission('kitchen.read')
    and exists (
      select 1
        from kitchen.tickets t
       where t.id = ticket_id
         and identity.can_manage_branch(t.branch_id)
    )
  );

revoke all on table kitchen.tickets from public, anon, authenticated;
revoke all on table kitchen.ticket_items from public, anon, authenticated;
grant select on table kitchen.tickets to authenticated;
grant select on table kitchen.ticket_items to authenticated;

revoke all on schema kitchen from public, anon;
grant usage on schema kitchen to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Internal guards and order-status sync
-- ---------------------------------------------------------------------------
create or replace function kitchen.require_permission(p_code text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission(p_code) then
    raise exception 'missing permission: %', p_code using errcode = '42501';
  end if;
end;
$fn$;

comment on function kitchen.require_permission(text) is
  'Raise 42501 unless the caller is active staff holding p_code. Internal helper.';

revoke all on function kitchen.require_permission(text) from public, anon, authenticated;

create or replace function kitchen.require_branch(p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if p_branch_id is null
     or not exists (select 1 from core.branches b where b.id = p_branch_id) then
    raise exception 'branch not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
end;
$fn$;

comment on function kitchen.require_branch(uuid) is
  'Raise when the branch does not exist or is outside the caller scope. Internal helper.';

revoke all on function kitchen.require_branch(uuid) from public, anon, authenticated;

-- Move the order forward without letting the kitchen bypass the whole flow:
-- pending is confirmed first, then preparing. Completed, cancelled and
-- out-for-delivery orders are never rewritten by the kitchen.
create or replace function kitchen.sync_order_status(
  p_order_id uuid,
  p_target text
)
returns text
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
begin
  select * into v_order
    from orders.orders o
   where o.id = p_order_id
   for update;
  if not found then
    return null;
  end if;

  if p_target = 'preparing' then
    if v_order.status = 'pending' then
      update orders.orders set status = 'confirmed' where id = p_order_id;
      insert into orders.order_status_history
        (order_id, from_status, to_status, changed_by, note)
      values
        (p_order_id, 'pending', 'confirmed', auth.uid(), 'kitchen.start');
      v_order.status := 'confirmed';
    end if;

    if v_order.status in ('confirmed', 'ready') then
      update orders.orders set status = 'preparing' where id = p_order_id;
      insert into orders.order_status_history
        (order_id, from_status, to_status, changed_by, note)
      values
        (p_order_id, v_order.status, 'preparing', auth.uid(), 'kitchen.start');
      return 'preparing';
    end if;

    return v_order.status;
  end if;

  if p_target = 'ready' then
    if v_order.status = 'preparing' then
      update orders.orders set status = 'ready' where id = p_order_id;
      insert into orders.order_status_history
        (order_id, from_status, to_status, changed_by, note)
      values
        (p_order_id, 'preparing', 'ready', auth.uid(), 'kitchen.ready');
      return 'ready';
    end if;
    return v_order.status;
  end if;

  if p_target = 'completed' then
    -- Delivery orders stay ready until the courier hands them over.
    if v_order.status = 'ready'
       and v_order.fulfillment_type in ('pickup', 'dine_in') then
      update orders.orders
         set status = 'completed',
             completed_at = now()
       where id = p_order_id;
      insert into orders.order_status_history
        (order_id, from_status, to_status, changed_by, note)
      values
        (p_order_id, 'ready', 'completed', auth.uid(), 'kitchen.complete');
      return 'completed';
    end if;
    return v_order.status;
  end if;

  return v_order.status;
end;
$fn$;

comment on function kitchen.sync_order_status(uuid, text) is
  'Advance an order to preparing/ready/completed for the kitchen, writing status history. Internal helper.';

revoke all on function kitchen.sync_order_status(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Ticket creation: one ticket per order, one item row per line
-- ---------------------------------------------------------------------------
create or replace function kitchen.create_ticket_for_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  insert into kitchen.tickets (order_id, branch_id, status, placed_at, started_at, ready_at, completed_at)
  values (
    new.id,
    new.branch_id,
    case
      when new.status = 'preparing' then 'preparing'
      when new.status = 'ready' then 'ready'
      when new.status in ('out_for_delivery', 'completed') then 'completed'
      when new.status = 'cancelled' then 'cancelled'
      else 'queued'
    end,
    new.placed_at,
    case when new.status in ('preparing','ready','out_for_delivery','completed')
         then new.placed_at end,
    case when new.status in ('ready','out_for_delivery','completed')
         then new.placed_at end,
    case when new.status in ('out_for_delivery','completed')
         then coalesce(new.completed_at, new.placed_at) end
  )
  on conflict (order_id) do nothing;
  return new;
end;
$fn$;

comment on function kitchen.create_ticket_for_order() is
  'Mirror every new order onto the kitchen board. Trigger only.';

revoke all on function kitchen.create_ticket_for_order() from public, anon, authenticated;

drop trigger if exists tr_orders_create_kitchen_ticket on orders.orders;
create trigger tr_orders_create_kitchen_ticket
  after insert on orders.orders
  for each row execute function kitchen.create_ticket_for_order();

create or replace function kitchen.create_ticket_item_for_order_item()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_ticket_id uuid;
  v_branch_id uuid;
  v_placed_at timestamptz;
begin
  select t.id into v_ticket_id
    from kitchen.tickets t
   where t.order_id = new.order_id;

  if v_ticket_id is null then
    select o.branch_id, o.placed_at
      into v_branch_id, v_placed_at
      from orders.orders o
     where o.id = new.order_id;

    insert into kitchen.tickets (order_id, branch_id, placed_at)
    values (new.order_id, v_branch_id, coalesce(v_placed_at, now()))
    on conflict (order_id) do update set order_id = excluded.order_id
    returning id into v_ticket_id;
  end if;

  insert into kitchen.ticket_items (ticket_id, order_item_id)
  values (v_ticket_id, new.id)
  on conflict (order_item_id) do nothing;

  return new;
end;
$fn$;

comment on function kitchen.create_ticket_item_for_order_item() is
  'Add each order line to its kitchen ticket. Trigger only.';

revoke all on function kitchen.create_ticket_item_for_order_item()
  from public, anon, authenticated;

drop trigger if exists tr_order_items_create_kitchen_item on orders.order_items;
create trigger tr_order_items_create_kitchen_item
  after insert on orders.order_items
  for each row execute function kitchen.create_ticket_item_for_order_item();

-- Keep the board honest when the order status is changed from the orders page,
-- the POS or a cancellation flow.
create or replace function kitchen.sync_ticket_from_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status is distinct from old.status then
    update kitchen.tickets t
       set status = case
             when new.status = 'cancelled' then 'cancelled'
             when new.status in ('out_for_delivery','completed') then 'completed'
             when new.status = 'ready' then 'ready'
             when new.status = 'preparing' then 'preparing'
             else t.status
           end,
           started_at = case
             when new.status = 'preparing' and t.started_at is null then now()
             else t.started_at
           end,
           ready_at = case
             when new.status = 'ready' and t.ready_at is null then now()
             else t.ready_at
           end,
           completed_at = case
             when new.status in ('out_for_delivery','completed')
                  and t.completed_at is null then now()
             else t.completed_at
           end
     where t.order_id = new.id
       and t.status not in ('completed','cancelled');

    if new.status in ('ready','out_for_delivery','completed') then
      update kitchen.ticket_items ti
         set status = 'ready',
             started_at = coalesce(ti.started_at, now()),
             ready_at = coalesce(ti.ready_at, now())
        from kitchen.tickets t
       where t.order_id = new.id
         and ti.ticket_id = t.id
         and ti.status <> 'ready';
    end if;
  end if;
  return new;
end;
$fn$;

comment on function kitchen.sync_ticket_from_order() is
  'Mirror order status changes onto the kitchen ticket. Trigger only.';

revoke all on function kitchen.sync_ticket_from_order() from public, anon, authenticated;

drop trigger if exists tr_orders_sync_kitchen_ticket on orders.orders;
create trigger tr_orders_sync_kitchen_ticket
  after update of status on orders.orders
  for each row execute function kitchen.sync_ticket_from_order();

-- Backfill open orders once. Completed and cancelled history stays out of the
-- kitchen: nobody cooks it again.
insert into kitchen.tickets (
  order_id, branch_id, status, placed_at, started_at, ready_at, completed_at
)
select
  o.id,
  o.branch_id,
  case
    when o.status = 'preparing' then 'preparing'
    when o.status = 'ready' then 'ready'
    when o.status = 'out_for_delivery' then 'completed'
    else 'queued'
  end,
  o.placed_at,
  case when o.status in ('preparing','ready','out_for_delivery') then o.updated_at end,
  case when o.status in ('ready','out_for_delivery') then o.updated_at end,
  case when o.status = 'out_for_delivery' then o.updated_at end
from orders.orders o
where o.status not in ('completed','cancelled')
on conflict (order_id) do nothing;

insert into kitchen.ticket_items (
  ticket_id, order_item_id, status, started_at, ready_at
)
select
  t.id,
  oi.id,
  case when t.status in ('ready','completed') then 'ready' else 'pending' end,
  case when t.status in ('ready','completed') then t.started_at end,
  case when t.status in ('ready','completed') then t.ready_at end
from kitchen.tickets t
join orders.order_items oi on oi.order_id = t.order_id
where t.status <> 'cancelled'
on conflict (order_item_id) do nothing;

-- ---------------------------------------------------------------------------
-- 7. Board: all live tickets with their lines, server-side branch and search
--    scoping. Completed tickets stay for three hours so a mistake can be
--    recalled without leaving the screen.
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
        coalesce(p.full_name, '') as customer_name,
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
      where t.branch_id in (select id from scoped)
        and (
          t.status in ('queued', 'preparing', 'ready')
          or (t.status = 'completed'
              and t.completed_at >= now() - interval '3 hours')
        )
        and (
          v_term is null
          or o.order_number ilike '%' || v_term || '%'
          or coalesce(p.full_name, '') ilike '%' || v_term || '%'
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
  'Live kitchen tickets with their lines, options and notes, scoped to the branches the caller manages.';

revoke all on function public.admin_kitchen_board(uuid, text, int) from public, anon;
grant execute on function public.admin_kitchen_board(uuid, text, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Headline metrics: queue health and today's prep performance.
-- ---------------------------------------------------------------------------
create or replace function public.admin_kitchen_metrics(p_branch_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
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
    )
    select jsonb_build_object(
      'queued', count(*) filter (where t.status = 'queued'),
      'preparing', count(*) filter (where t.status = 'preparing'),
      'ready', count(*) filter (where t.status = 'ready'),
      'active', count(*) filter (where t.status in ('queued','preparing','ready')),
      'completed_today', count(*) filter (
        where t.status = 'completed'
          and t.completed_at >= date_trunc('day', now())
      ),
      'late', count(*) filter (
        where t.status in ('queued','preparing')
          and t.placed_at <= now() - interval '15 minutes'
      ),
      'oldest_wait_minutes', coalesce(round((
        max(extract(epoch from (now() - t.placed_at)))
          filter (where t.status in ('queued','preparing'))
      ) / 60), 0),
      'avg_prep_minutes', coalesce(round((
        avg(extract(epoch from (t.ready_at - t.started_at)))
          filter (
            where t.ready_at is not null
              and t.started_at is not null
              and t.ready_at >= date_trunc('day', now())
          )
      ) / 60, 1), 0)
    )
    from kitchen.tickets t
    where t.branch_id in (select id from scoped)
  );
end;
$fn$;

comment on function public.admin_kitchen_metrics(uuid) is
  'Queue counts, late tickets, oldest wait and today''s average prep time.';

revoke all on function public.admin_kitchen_metrics(uuid) from public, anon;
grant execute on function public.admin_kitchen_metrics(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Filter options: branches in scope.
-- ---------------------------------------------------------------------------
create or replace function public.admin_kitchen_filters()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform kitchen.require_permission('kitchen.read');

  return jsonb_build_object(
    'branches', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', b.id,
                 'code', b.code,
                 'name_ar', b.name_ar,
                 'name_en', b.name_en,
                 'is_active', b.is_active
               )
               order by b.is_active desc, b.name_ar
             )
        from core.branches b
       where identity.can_manage_branch(b.id)
    ), '[]'::jsonb)
  );
end;
$fn$;

comment on function public.admin_kitchen_filters() is
  'Branches the caller may display on the kitchen board.';

revoke all on function public.admin_kitchen_filters() from public, anon;
grant execute on function public.admin_kitchen_filters() to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Ticket actions
-- ---------------------------------------------------------------------------
create or replace function public.admin_kitchen_set_ticket_status(
  p_ticket_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_ticket kitchen.tickets%rowtype;
  v_target text := lower(btrim(coalesce(p_status, '')));
  v_now    timestamptz := now();
begin
  perform kitchen.require_permission('kitchen.manage');
  if p_ticket_id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  select * into v_ticket
    from kitchen.tickets t
   where t.id = p_ticket_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  perform kitchen.require_branch(v_ticket.branch_id);

  if v_target not in ('preparing', 'ready', 'completed') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;

  if v_ticket.status = 'cancelled' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;

  if v_target = v_ticket.status then
    return jsonb_build_object(
      'ok', true,
      'status', v_ticket.status,
      'changed', false
    );
  end if;

  if not (
       (v_ticket.status = 'queued' and v_target = 'preparing')
    or (v_ticket.status = 'preparing' and v_target = 'ready')
    or (v_ticket.status = 'ready' and v_target = 'completed')
    or (v_ticket.status = 'ready' and v_target = 'preparing')
    or (v_ticket.status = 'completed' and v_target = 'preparing')
  ) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_transition');
  end if;

  if v_target = 'preparing' then
    update kitchen.tickets
       set status = 'preparing',
           started_at = coalesce(started_at, v_now),
           ready_at = null,
           completed_at = null,
           completed_by = null
     where id = p_ticket_id;

    -- A recall reopens every line so the kitchen can work through them again.
    if v_ticket.status in ('ready', 'completed') then
      update kitchen.ticket_items
         set status = 'preparing',
             started_at = coalesce(started_at, v_now),
             ready_at = null
       where ticket_id = p_ticket_id;
    end if;

    perform kitchen.sync_order_status(v_ticket.order_id, 'preparing');
  elsif v_target = 'ready' then
    update kitchen.tickets
       set status = 'ready',
           ready_at = coalesce(ready_at, v_now)
     where id = p_ticket_id;

    update kitchen.ticket_items
       set status = 'ready',
           started_at = coalesce(started_at, v_now),
           ready_at = coalesce(ready_at, v_now)
     where ticket_id = p_ticket_id
       and status <> 'ready';

    perform kitchen.sync_order_status(v_ticket.order_id, 'ready');
  else
    update kitchen.tickets
       set status = 'completed',
           completed_at = coalesce(completed_at, v_now),
           completed_by = auth.uid()
     where id = p_ticket_id;

    update kitchen.ticket_items
       set status = 'ready',
           started_at = coalesce(started_at, v_now),
           ready_at = coalesce(ready_at, v_now)
     where ticket_id = p_ticket_id
       and status <> 'ready';

    perform kitchen.sync_order_status(v_ticket.order_id, 'completed');
  end if;

  perform identity.audit(
    'kitchen.ticket.update',
    'kitchen_ticket',
    p_ticket_id,
    jsonb_build_object('status', v_ticket.status),
    jsonb_build_object('status', v_target),
    v_ticket.branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'status', v_target,
    'changed', true
  );
end;
$fn$;

comment on function public.admin_kitchen_set_ticket_status(uuid, text) is
  'Start, ready, complete or recall a kitchen ticket, syncing the order status through allowed transitions.';

revoke all on function public.admin_kitchen_set_ticket_status(uuid, text)
  from public, anon;
grant execute on function public.admin_kitchen_set_ticket_status(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Item actions. The ticket follows its lines: first line preparation
--     starts the ticket, the last ready line marks the ticket ready.
-- ---------------------------------------------------------------------------
create or replace function public.admin_kitchen_set_item_status(
  p_ticket_item_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_item     kitchen.ticket_items%rowtype;
  v_ticket   kitchen.tickets%rowtype;
  v_target   text := lower(btrim(coalesce(p_status, '')));
  v_now      timestamptz := now();
  v_total    int;
  v_ready    int;
  v_ticket_status text;
begin
  perform kitchen.require_permission('kitchen.manage');
  if p_ticket_item_id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  select * into v_item
    from kitchen.ticket_items ti
   where ti.id = p_ticket_item_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  select * into v_ticket
    from kitchen.tickets t
   where t.id = v_item.ticket_id
   for update;

  perform kitchen.require_branch(v_ticket.branch_id);

  if v_target not in ('pending', 'preparing', 'ready') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;
  if v_ticket.status in ('cancelled', 'completed') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;
  if v_target = v_item.status then
    return jsonb_build_object(
      'ok', true,
      'status', v_item.status,
      'ticket_status', v_ticket.status,
      'changed', false
    );
  end if;

  update kitchen.ticket_items
     set status = v_target,
         started_at = case
           when v_target = 'pending' then null
           else coalesce(started_at, v_now)
         end,
         ready_at = case
           when v_target = 'ready' then v_now
           else null
         end
   where id = p_ticket_item_id;

  select count(*), count(*) filter (where ti.status = 'ready')
    into v_total, v_ready
    from kitchen.ticket_items ti
   where ti.ticket_id = v_ticket.id;

  v_ticket_status := v_ticket.status;

  if v_ticket.status = 'queued' and v_target in ('preparing', 'ready') then
    update kitchen.tickets
       set status = 'preparing',
           started_at = coalesce(started_at, v_now)
     where id = v_ticket.id;
    v_ticket_status := 'preparing';
    perform kitchen.sync_order_status(v_ticket.order_id, 'preparing');
  end if;

  if v_total > 0 and v_ready = v_total then
    if v_ticket_status <> 'ready' then
      update kitchen.tickets
         set status = 'ready',
             ready_at = coalesce(ready_at, v_now)
       where id = v_ticket.id;
      v_ticket_status := 'ready';
      perform kitchen.sync_order_status(v_ticket.order_id, 'ready');
    end if;
  elsif v_ticket_status in ('ready', 'completed') then
    update kitchen.tickets
       set status = 'preparing',
           ready_at = null,
           completed_at = null,
           completed_by = null
     where id = v_ticket.id;
    v_ticket_status := 'preparing';
    perform kitchen.sync_order_status(v_ticket.order_id, 'preparing');
  end if;

  perform identity.audit(
    'kitchen.item.update',
    'kitchen_ticket',
    v_ticket.id,
    jsonb_build_object('item_id', p_ticket_item_id, 'status', v_item.status),
    jsonb_build_object('item_id', p_ticket_item_id, 'status', v_target),
    v_ticket.branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'status', v_target,
    'ticket_status', v_ticket_status,
    'changed', true
  );
end;
$fn$;

comment on function public.admin_kitchen_set_item_status(uuid, text) is
  'Check off one kitchen line and move the ticket and order forward automatically.';

revoke all on function public.admin_kitchen_set_item_status(uuid, text)
  from public, anon;
grant execute on function public.admin_kitchen_set_item_status(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 12. Realtime: the board is a live screen, not a pull-to-refresh list.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname    = 'supabase_realtime'
       and schemaname = 'kitchen'
       and tablename  = 'tickets'
  ) then
    alter publication supabase_realtime add table kitchen.tickets;
  end if;

  if not exists (
    select 1
      from pg_publication_tables
     where pubname    = 'supabase_realtime'
       and schemaname = 'kitchen'
       and tablename  = 'ticket_items'
  ) then
    alter publication supabase_realtime add table kitchen.ticket_items;
  end if;
end;
$$;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
