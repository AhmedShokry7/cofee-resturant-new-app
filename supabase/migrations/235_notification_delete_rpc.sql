-- Allow a signed-in customer to remove only their own in-app notifications.
create or replace function engagement.delete_notifications(p_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  affected integer;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  delete from engagement.notifications
   where id = any(coalesce(p_ids, '{}'::uuid[]))
     and user_id = auth.uid();
  get diagnostics affected = row_count;
  return affected;
end;
$fn$;

create or replace function public.delete_notifications(p_ids uuid[] default null)
returns integer
language sql
security invoker
set search_path = ''
as $fn$
  select engagement.delete_notifications(p_ids);
$fn$;

revoke all on function engagement.delete_notifications(uuid[]) from public, anon;
grant execute on function engagement.delete_notifications(uuid[]) to authenticated;
revoke all on function public.delete_notifications(uuid[]) from public, anon;
grant execute on function public.delete_notifications(uuid[]) to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
