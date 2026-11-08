-- Opening the customer notifications inbox marks all of that customer's
-- unread notifications as read. Null means all rows owned by auth.uid(); an
-- explicit UUID array keeps the existing per-notification behavior.
create or replace function engagement.mark_notifications_read(
  p_ids uuid[] default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_n integer;
begin
  update engagement.notifications
     set is_read = true,
         read_at = now()
   where user_id = auth.uid()
     and not is_read
     and (p_ids is null or id = any(p_ids));
  get diagnostics v_n = row_count;
  return v_n;
end;
$fn$;

create or replace function public.mark_notifications_read(
  p_ids uuid[] default null
)
returns integer
language sql
security invoker
set search_path = ''
as $fn$
  select engagement.mark_notifications_read(p_ids);
$fn$;
