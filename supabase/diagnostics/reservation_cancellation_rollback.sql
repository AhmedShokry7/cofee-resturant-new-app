begin;
CREATE OR REPLACE FUNCTION public.cancel_my_customer_event_request(p_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  update floor.customer_event_requests
     set status='cancelled', cancelled_at=now(), updated_at=now()
   where id=p_id and user_id=auth.uid()
     and status in ('pending','quoted','quote_declined');
  return found;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.cancel_my_reservation(p_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  update floor.reservations
     set status = 'cancelled', cancelled_at = now(), updated_at = now()
   where id = p_id and user_id = v_uid and status in ('pending','approved','confirmed');
  return found;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.list_my_customer_event_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'not authenticated' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc) from (
  select e.*,b.name_ar as branch_name_ar,b.name_en as branch_name_en,t.name as quoted_space_name,t.image_url as quoted_space_image_url
  from floor.customer_event_requests e join core.branches b on b.id=e.branch_id left join floor.tables t on t.id=e.quoted_space_id where e.user_id=v_uid
 ) x),'[]'::jsonb);
end;$function$
;
CREATE OR REPLACE FUNCTION public.list_my_reservations()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'not authenticated' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(row_to_json(x)::jsonb order by x.reserved_for desc) from (
  select r.id,r.branch_id,r.table_id,r.user_id,r.source,r.status,r.reservation_type,r.reserved_for,r.requested_end_at,r.reserved_until,r.duration_minutes,r.party_size,r.customer_name,r.customer_phone,r.note,r.customer_note,r.admin_note,r.cancellation_reason,r.reviewed_at,r.created_at,r.updated_at,r.linked_event_id,b.name_ar as branch_name_ar,b.name_en as branch_name_en,t.name as table_name,t.area as table_area,e.occasion_name,e.occasion_type
  from floor.reservations r left join core.branches b on b.id=r.branch_id left join floor.tables t on t.id=r.table_id left join floor.customer_event_requests e on e.id=r.linked_event_id where r.user_id=v_uid order by r.reserved_for desc
 ) x),'[]'::jsonb);
end;$function$
;
drop function public.admin_get_reservation_cancellation_policy(uuid);
drop function public.admin_set_reservation_cancellation_policy(uuid,integer,integer);
notify pgrst, 'reload schema'; commit;
