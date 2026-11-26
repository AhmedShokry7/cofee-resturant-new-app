-- Set the chosen reminder time once the customer accepts the venue's quote.
create or replace function floor.set_customer_event_reminder_time()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' then
    new.reminder_at := new.quoted_start_at - (new.reminder_minutes * interval '1 minute');
    new.reminder_sent_at := null;
  end if;
  return new;
end;
$fn$;
revoke all on function floor.set_customer_event_reminder_time() from public, anon, authenticated;
drop trigger if exists tr_set_customer_event_reminder_time on floor.customer_event_requests;
create trigger tr_set_customer_event_reminder_time
before update of status on floor.customer_event_requests
for each row execute function floor.set_customer_event_reminder_time();

-- Home screen reads only reminders that are due and whose event is still upcoming.
create or replace function public.list_my_event_reminders()
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select to_jsonb(e) || jsonb_build_object(
    'branch_name_ar', b.name_ar,
    'branch_name_en', b.name_en,
    'quoted_space_name', t.name
  )
  from floor.customer_event_requests e
  join core.branches b on b.id = e.branch_id
  left join floor.tables t on t.id = e.quoted_space_id
  where e.user_id = auth.uid()
    and e.status = 'confirmed'
    and e.reminder_at <= now()
    and e.quoted_start_at > now()
  order by e.reminder_at;
$fn$;
revoke all on function public.list_my_event_reminders() from public, anon;
grant execute on function public.list_my_event_reminders() to authenticated;

-- Persist and notify once; the existing notification trigger handles push delivery.
create or replace function floor.dispatch_due_customer_event_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_event floor.customer_event_requests%rowtype;
  v_count integer := 0;
begin
  for v_event in
    select * from floor.customer_event_requests e
    where e.status = 'confirmed'
      and e.reminder_at <= now()
      and e.quoted_start_at > now()
      and e.reminder_sent_at is null
    order by e.reminder_at
    for update skip locked
  loop
    insert into engagement.notifications (
      user_id, type, title_ar, title_en, body_ar, body_en, payload,
      related_entity_type, related_entity_id, dedupe_key
    ) values (
      v_event.user_id, 'system', 'تذكير بمناسبتك القادمة', 'Reminder for your upcoming event',
      'موعد مناسبتك اقترب. افتح حجوزاتي لمراجعة تفاصيل الموعد والمكان.',
      'Your event is coming up. Open My Reservations to review the time and place.',
      jsonb_build_object('destination', 'my_reservations', 'event_request_id', v_event.id),
      'event_request', v_event.id, 'event_reminder:' || v_event.id::text
    ) on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
    update floor.customer_event_requests set reminder_sent_at = now(), updated_at = now()
    where id = v_event.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$fn$;
revoke all on function floor.dispatch_due_customer_event_reminders() from public, anon, authenticated;

do $cron$
declare v_job bigint;
begin
  for v_job in select jobid from cron.job where jobname = 'customer-event-reminders' loop
    perform cron.unschedule(v_job);
  end loop;
  perform cron.schedule(
    'customer-event-reminders',
    '*/5 * * * *',
    'select floor.dispatch_due_customer_event_reminders()'
  );
end;
$cron$;

-- Surface due confirmations in the event requests navigation badge.
create or replace function public.admin_nav_counts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_unread_orders integer := 0;
  v_unread_kitchen integer := 0;
  v_event_requests integer := 0;
begin
  if not identity.is_staff() then raise exception 'not authenticated' using errcode = '42501'; end if;
  if identity.has_permission('orders.read') then
    select count(*) into v_unread_orders from orders.orders o
    where o.status = 'pending' and o.viewed_at is null and identity.can_manage_branch(o.branch_id);
  end if;
  if identity.has_permission('kitchen.read') then
    select count(*) into v_unread_kitchen from kitchen.tickets t
    where t.status in ('queued', 'preparing', 'ready') and t.viewed_at is null and identity.can_manage_branch(t.branch_id);
  end if;
  if identity.has_permission('tables.read') or identity.has_permission('tables.manage') then
    select count(*) into v_event_requests from floor.customer_event_requests e
    where identity.can_manage_branch(e.branch_id)
      and (e.status in ('pending', 'quote_declined') or
        (e.status = 'confirmed' and e.reminder_at <= now() and e.quoted_start_at > now()));
  end if;
  return jsonb_build_object('unread_orders', v_unread_orders, 'unread_kitchen', v_unread_kitchen, 'event_requests', v_event_requests);
end;
$fn$;
revoke all on function public.admin_nav_counts() from public, anon;
grant execute on function public.admin_nav_counts() to authenticated;

notify pgrst, 'reload schema';
