-- Let both the customer quote and the home reminder render the exact offered venue.
create or replace function public.list_my_customer_event_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc)
    from (
      select e.*, b.name_ar as branch_name_ar, b.name_en as branch_name_en,
             t.name as quoted_space_name,
             t.image_url as quoted_space_image_url
        from floor.customer_event_requests e
        join core.branches b on b.id = e.branch_id
        left join floor.tables t on t.id = e.quoted_space_id
       where e.user_id = v_uid
    ) x
  ), '[]'::jsonb);
end;
$fn$;
revoke all on function public.list_my_customer_event_requests() from public, anon;
grant execute on function public.list_my_customer_event_requests() to authenticated;

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
    'quoted_space_name', t.name,
    'quoted_space_image_url', t.image_url
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

notify pgrst, 'reload schema';
