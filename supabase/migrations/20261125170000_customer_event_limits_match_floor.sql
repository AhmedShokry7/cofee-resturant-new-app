begin;

alter table floor.customer_event_requests
  drop constraint if exists ck_customer_event_guest_count,
  drop constraint if exists ck_customer_event_note;

alter table floor.customer_event_requests
  add constraint ck_customer_event_guest_count check (guest_count between 2 and 40),
  add constraint ck_customer_event_note check (
    customer_note is null or char_length(customer_note) <= 500
  );

commit;
