-- Remove the original table status check; migration 270 added the expanded
-- floor_reservations_status_check but left this older constraint in place.
begin;

alter table floor.reservations
  drop constraint if exists reservations_status_check;

commit;
