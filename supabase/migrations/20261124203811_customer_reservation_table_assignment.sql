-- Customer reservation requests stay unassigned until staff approves them.
-- The trigger continues to require a table for every non-pending reservation.
begin;

alter table floor.reservations
  alter column table_id drop not null;

commit;
