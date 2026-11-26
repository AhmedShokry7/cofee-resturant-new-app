-- Notify the customer when the branch sends or revises an event quote.
create or replace function public.admin_offer_customer_event_request(
  p_id uuid,
  p_quote_amount numeric,
  p_space_id uuid,
  p_quoted_start_at timestamptz,
  p_quoted_end_at timestamptz,
  p_quote_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_event floor.customer_event_requests%rowtype;
  v_space floor.tables%rowtype;
  v_staff uuid;
  v_amount numeric(12,2);
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;

  select * into v_event
    from floor.customer_event_requests e
   where e.id = p_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not identity.can_manage_branch(v_event.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_event.status not in ('pending', 'quoted', 'quote_declined') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;
  if p_quote_amount is null or p_quote_amount < 0 or p_quote_amount > 10000000
     or p_quote_note is not null and char_length(p_quote_note) > 1000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_quote');
  end if;
  if p_quoted_start_at is null or p_quoted_end_at is null
     or p_quoted_start_at <= now() or p_quoted_end_at <= p_quoted_start_at
     or p_quoted_end_at - p_quoted_start_at < interval '30 minutes'
     or p_quoted_end_at - p_quoted_start_at > interval '8 hours'
     or p_quoted_start_at::date > current_date + 365 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_time');
  end if;

  select * into v_space
    from floor.tables t
   where t.id = p_space_id
     and t.branch_id = v_event.branch_id
     and t.is_active;
  if not found or v_space.capacity < v_event.guest_count then
    return jsonb_build_object('ok', false, 'reason', 'invalid_space');
  end if;
  if v_event.requested_space_type = 'room' and v_space.area <> 'private_room'
     or v_event.requested_space_type = 'table' and v_space.area = 'private_room' then
    return jsonb_build_object('ok', false, 'reason', 'space_type_mismatch');
  end if;

  select s.id into v_staff
    from identity.staff_members s
   where s.user_id = auth.uid()
   limit 1;
  v_amount := round(p_quote_amount, 2);

  update floor.customer_event_requests
     set status = 'quoted',
         quote_amount = v_amount,
         quote_note = nullif(btrim(coalesce(p_quote_note, '')), ''),
         quoted_space_id = p_space_id,
         quoted_start_at = p_quoted_start_at,
         quoted_end_at = p_quoted_end_at,
         quote_expires_at = now() + interval '48 hours',
         reviewed_by = coalesce(v_staff, reviewed_by),
         reviewed_at = now(),
         updated_at = now()
   where id = v_event.id;

  insert into engagement.notifications (
    user_id, type, title_ar, title_en, body_ar, body_en, payload,
    related_entity_type, related_entity_id, dedupe_key
  ) values (
    v_event.user_id,
    'system',
    'وصلك عرض لحجز مناسبتك',
    'You received an offer for your event',
    'أرسل الفرع عرضًا بقيمة ' || v_amount::text || ' ريال. افتح حجوزاتي لمراجعة الموعد والمكان والرد على العرض.',
    'The branch offered ' || v_amount::text || ' SAR. Open My Reservations to review the time and place and respond.',
    jsonb_build_object(
      'destination', 'my_reservations',
      'event_request_id', v_event.id
    ),
    'event_request',
    v_event.id,
    'event_quote:' || v_event.id::text || ':' || gen_random_uuid()::text
  );

  return jsonb_build_object('ok', true, 'reason', 'quoted');
end;
$fn$;

revoke all on function public.admin_offer_customer_event_request(
  uuid, numeric, uuid, timestamptz, timestamptz, text
) from public, anon;
grant execute on function public.admin_offer_customer_event_request(
  uuid, numeric, uuid, timestamptz, timestamptz, text
) to authenticated;
