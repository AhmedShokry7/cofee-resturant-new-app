-- Confirmed event reservations also receive a customer-owned notification.
create or replace function floor.notify_customer_event_confirmation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' then
    insert into engagement.notifications (
      user_id, type, title_ar, title_en, body_ar, body_en, payload,
      related_entity_type, related_entity_id, dedupe_key
    ) values (
      new.user_id,
      'system',
      'تم تأكيد حجز مناسبتك',
      'Your event booking is confirmed',
      'تم تأكيد حجز مناسبتك. افتح حجوزاتي لمراجعة تفاصيل الموعد والمكان.',
      'Your event booking is confirmed. Open My Reservations to review the time and place.',
      jsonb_build_object(
        'destination', 'my_reservations',
        'event_request_id', new.id
      ),
      'event_request',
      new.id,
      'event_confirmed:' || new.id::text
    ) on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  end if;
  return new;
end;
$fn$;

revoke all on function floor.notify_customer_event_confirmation()
  from public, anon, authenticated;

drop trigger if exists tr_customer_event_confirmation_notification
  on floor.customer_event_requests;
create trigger tr_customer_event_confirmation_notification
  after update of status on floor.customer_event_requests
  for each row execute function floor.notify_customer_event_confirmation();
