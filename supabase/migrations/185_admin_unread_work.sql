-- 185_admin_unread_work.sql
--
-- The unread work behind the sidebar badges.
--
-- The navigation panel already tells the staff how much work is waiting. It
-- cannot tell them how much of that work nobody has looked at yet, because no
-- row records that anyone opened it. This adds one stamp per side of the
-- counter and the two functions that set it.
--
-- One stamp per row, not one per staff member: when any member of the team
-- opens an order, the order stops being unread for all of them. A per-staff
-- table would need a row for every staff member times every order, and the
-- dashboard would count the same order again for a colleague who has not
-- opened it, which is not a number anyone can act on.
--
-- What counts as unread, per section, is deliberately not one rule:
--   * unread orders   orders.orders with status 'pending' (a customer order
--                     still waiting for a confirmation) and no viewed_at. A
--                     POS sale is born 'confirmed' and paid at the counter, so
--                     it never waits for a confirmation here.
--   * unread kitchen  kitchen.tickets still on the board ('queued',
--                     'preparing' or 'ready') and no viewed_at. A ticket leaves
--                     the counter when it is completed or cancelled even if
--                     nobody ever opened the board, because it is no longer
--                     work.
--
-- The stamp is set by the two mark functions below and by nothing else. A
-- status change does not set it, so confirming an order from the list does not
-- silently clear the order a colleague still has to look at. Both functions
-- only write when the stamp is still null, so the counter can never be
-- decremented twice for the same row.
--
-- Both counters stay limited to the branches the caller may manage, exactly
-- like the queue counters they replace. A counter the caller cannot act on is
-- not shown.

-- ---------------------------------------------------------------------------
-- 1. The stamps
-- ---------------------------------------------------------------------------
alter table orders.orders
  add column if not exists viewed_at timestamptz;

comment on column orders.orders.viewed_at is
  'When any staff member first opened this order in the dashboard. Null means no one has opened it.';

alter table kitchen.tickets
  add column if not exists viewed_at timestamptz;

comment on column kitchen.tickets.viewed_at is
  'When this ticket was first shown on a kitchen board. Null means no board ever showed it.';

-- Everything that already happened is history, not unread work. Without this
-- the badges would open at the size of the backlog the first time anyone signs
-- in.
update orders.orders
   set viewed_at = placed_at
 where viewed_at is null;

update kitchen.tickets
   set viewed_at = placed_at
 where viewed_at is null;

-- The counters read these two halves of the tables, so they are indexed as
-- partial indexes: they stay small and the counting never scans completed work.
create index if not exists ix_orders_unread_pending
  on orders.orders (branch_id)
 where status = 'pending' and viewed_at is null;

create index if not exists ix_kitchen_tickets_unread_open
  on kitchen.tickets (branch_id)
 where status in ('queued', 'preparing', 'ready') and viewed_at is null;

-- ---------------------------------------------------------------------------
-- 2. Opening one order marks that order read
-- ---------------------------------------------------------------------------
create or replace function public.admin_mark_order_viewed(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_branch_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  select o.branch_id into v_branch_id
    from orders.orders o
   where o.id = p_order_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if not identity.can_manage_branch(v_branch_id) then
    return jsonb_build_object('ok', false, 'reason', 'branch_denied');
  end if;

  -- Only an unopened order is stamped, so opening it twice is a no-op.
  update orders.orders
     set viewed_at = now()
   where id = p_order_id
     and viewed_at is null;

  return jsonb_build_object('ok', true, 'changed', found);
end;
$fn$;

comment on function public.admin_mark_order_viewed(uuid) is
  'Stamps an order the caller may manage as opened, once. Never decrements a counter twice.';

revoke all on function public.admin_mark_order_viewed(uuid) from public, anon;
grant execute on function public.admin_mark_order_viewed(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Showing the board marks the tickets it showed as read
-- ---------------------------------------------------------------------------
create or replace function public.admin_mark_kitchen_tickets_viewed(
  p_ticket_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  -- The board holds at most 300 tickets, so a longer list is a client bug.
  v_ids     uuid[] := (
    select array_agg(x)
      from (select unnest(coalesce(p_ticket_ids, '{}'::uuid[])) as x limit 300) s
  );
  v_changed integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('kitchen.read') then
    raise exception 'missing permission: kitchen.read' using errcode = '42501';
  end if;

  if v_ids is null or cardinality(v_ids) = 0 then
    return jsonb_build_object('ok', true, 'changed', 0);
  end if;

  -- The board is the kitchen display: a ticket it renders has been shown.
  -- Completed and cancelled tickets are skipped, they are not work, and the
  -- ids of another branch are skipped by the same gate that read them.
  with picked as (
    select t.id
      from kitchen.tickets t
     where t.id = any (v_ids)
       and t.viewed_at is null
       and t.status in ('queued', 'preparing', 'ready')
       and identity.can_manage_branch(t.branch_id)
  ),
  stamped as (
    update kitchen.tickets t
       set viewed_at = now()
      from picked p
     where t.id = p.id
    returning t.id
  )
  select count(*) into v_changed from stamped;

  return jsonb_build_object('ok', true, 'changed', v_changed);
end;
$fn$;

comment on function public.admin_mark_kitchen_tickets_viewed(uuid[]) is
  'Stamps the kitchen tickets a board just showed as seen, skipping finished work and other branches.';

revoke all on function public.admin_mark_kitchen_tickets_viewed(uuid[])
  from public, anon;
grant execute on function public.admin_mark_kitchen_tickets_viewed(uuid[])
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. The badges count unread work instead of raw queue size
-- ---------------------------------------------------------------------------
create or replace function public.admin_nav_counts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_unread_orders  integer := 0;
  v_unread_kitchen integer := 0;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if identity.has_permission('orders.read') then
    select count(*) into v_unread_orders
      from orders.orders o
     where o.status = 'pending'
       and o.viewed_at is null
       and identity.can_manage_branch(o.branch_id);
  end if;

  if identity.has_permission('kitchen.read') then
    select count(*) into v_unread_kitchen
      from kitchen.tickets t
     where t.status in ('queued', 'preparing', 'ready')
       and t.viewed_at is null
       and identity.can_manage_branch(t.branch_id);
  end if;

  return jsonb_build_object(
    'unread_orders', v_unread_orders,
    'unread_kitchen', v_unread_kitchen
  );
end;
$fn$;

comment on function public.admin_nav_counts() is
  'Orders and kitchen tickets waiting in the branches the caller can manage that no one has opened yet.';

revoke all on function public.admin_nav_counts() from public, anon;
grant execute on function public.admin_nav_counts() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Realtime: the sidebar badge reacts the moment work arrives or is read
-- ---------------------------------------------------------------------------
-- kitchen.tickets already joined the publication in 174; orders.orders never
-- did, because only the kitchen page used realtime so far.
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname    = 'supabase_realtime'
       and schemaname = 'orders'
       and tablename  = 'orders'
  ) then
    alter publication supabase_realtime add table orders.orders;
  end if;
end;
$$;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
