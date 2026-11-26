begin;

create or replace function floor.sync_customer_event_reservation_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.linked_event_id is not null
     and new.status = 'cancelled'
     and old.status is distinct from new.status then
    update floor.customer_event_requests
       set status = 'cancelled', cancelled_at = coalesce(new.cancelled_at, now()),
           updated_at = now()
     where id = new.linked_event_id and status = 'confirmed';
  end if;
  return new;
end;
$$;

drop trigger if exists tr_sync_customer_event_reservation_status
  on floor.reservations;
create trigger tr_sync_customer_event_reservation_status
after update of status on floor.reservations
for each row execute function floor.sync_customer_event_reservation_status();

commit;
