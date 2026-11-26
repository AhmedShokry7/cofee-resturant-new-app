-- Existing confirmations predate reminder_at; bring them into the same schedule.
update floor.customer_event_requests
set reminder_at = quoted_start_at - (reminder_minutes * interval '1 minute')
where status = 'confirmed'
  and reminder_at is null
  and quoted_start_at is not null;

select floor.dispatch_due_customer_event_reminders();
