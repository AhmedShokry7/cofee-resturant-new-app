-- Keep confirmed event reservations distinct from their original request row
-- while carrying the occasion name into the customer's bookings list.
create or replace function public.list_my_reservations()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.reserved_for desc)
    from (
      select r.id, r.branch_id, r.table_id, r.user_id, r.source, r.status,
             r.reservation_type, r.reserved_for, r.requested_end_at,
             r.reserved_until, r.duration_minutes, r.party_size, r.customer_name,
             r.customer_phone, r.note, r.customer_note, r.admin_note,
             r.cancellation_reason, r.reviewed_at, r.created_at, r.updated_at,
             r.linked_event_id,
             b.name_ar as branch_name_ar, b.name_en as branch_name_en,
             t.name as table_name, t.area as table_area,
             e.occasion_name, e.occasion_type
        from floor.reservations r
        left join core.branches b on b.id = r.branch_id
        left join floor.tables t on t.id = r.table_id
        left join floor.customer_event_requests e on e.id = r.linked_event_id
       where r.user_id = v_uid
       order by r.reserved_for desc
    ) x
  ), '[]'::jsonb);
end;
$fn$;
revoke all on function public.list_my_reservations() from public, anon;
grant execute on function public.list_my_reservations() to authenticated;
