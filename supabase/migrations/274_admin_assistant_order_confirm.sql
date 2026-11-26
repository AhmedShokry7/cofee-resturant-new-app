-- Assistant order execution delegates to the existing POS transaction. If
-- its authoritative total differs from the approved preview, raising inside
-- this function rolls back the nested checkout, stock, payment and audit rows.
create or replace function public.admin_assistant_pos_order_create(
  p_branch_id uuid,
  p_lines jsonb,
  p_payment_method_id uuid,
  p_idempotency_key text,
  p_table_id uuid,
  p_customer_id uuid,
  p_expected_total numeric
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_result jsonb;
  v_actual numeric;
begin
  if not identity.is_staff()
     or not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if p_expected_total is null or p_expected_total < 0 then
    raise exception 'invalid approved order total' using errcode = '22023';
  end if;
  if p_branch_id is null or not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  v_result := public.admin_pos_place_table_order(
    p_branch_id,
    p_lines,
    'dine_in',
    p_payment_method_id,
    p_idempotency_key,
    p_table_id,
    null,
    p_customer_id,
    null
  );
  v_actual := nullif(v_result->>'grand_total', '')::numeric;
  if v_actual is null or abs(v_actual - p_expected_total) >= 0.01 then
    raise exception 'assistant order preview is stale; review the new total before confirming again'
      using errcode = '40001';
  end if;
  return v_result;
end;
$$;

revoke all on function public.admin_assistant_pos_order_create(uuid, jsonb, uuid, text, uuid, uuid, numeric) from public, anon;
grant execute on function public.admin_assistant_pos_order_create(uuid, jsonb, uuid, text, uuid, uuid, numeric) to authenticated;
