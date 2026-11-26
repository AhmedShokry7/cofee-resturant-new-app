begin;

create or replace function public.admin_delete_customer_event_request(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event floor.customer_event_requests%rowtype;
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

  -- Preserve the actual table reservation and only remove its link to this request.
  update floor.reservations
  set linked_event_id = null
  where linked_event_id = v_event.id;

  delete from floor.customer_event_requests where id = v_event.id;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.admin_delete_customer_event_request(uuid) from public, anon;
grant execute on function public.admin_delete_customer_event_request(uuid) to authenticated;

commit;
