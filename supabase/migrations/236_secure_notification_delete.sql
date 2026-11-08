-- Make deletion callable through the public PostgREST schema while keeping the
-- ownership check inside the definer function. NULL p_ids means delete all of
-- the signed-in customer's notifications; a list means delete only those ids.
create or replace function public.delete_notifications(p_ids uuid[] default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  affected integer;
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  delete from engagement.notifications
   where user_id = caller_id
     and (p_ids is null or id = any(p_ids));
  get diagnostics affected = row_count;
  return affected;
end;
$fn$;

revoke all on function public.delete_notifications(uuid[]) from public, anon;
grant execute on function public.delete_notifications(uuid[]) to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
