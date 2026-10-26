-- 166_admin_loyalty_rule.sql
-- Give the admin ownership of the earning program itself:
--   * how many points every 1 unit of currency earns;
--   * what one point is worth at redemption;
--   * whether the program is running.
--
-- Order creation already reads the newest active rule, so editing the same
-- rule the overview shows is enough for new orders to use the new rate.

create or replace function public.admin_save_loyalty_rule(p_rule jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id      uuid;
  v_rate    numeric(12,4);
  v_value   numeric(12,2);
  v_active  boolean;
  v_created boolean := false;
  v_old     jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.write') then
    raise exception 'missing permission: loyalty.write' using errcode = '42501';
  end if;
  if p_rule is null or jsonb_typeof(p_rule) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    if coalesce(btrim(p_rule ->> 'id'), '') <> '' then
      v_id := btrim(p_rule ->> 'id')::uuid;
    end if;
    v_rate := (p_rule ->> 'points_per_currency_unit')::numeric;
    v_value := (p_rule ->> 'point_value')::numeric;
    v_active := coalesce((p_rule ->> 'is_active')::boolean, true);
  exception
    when invalid_text_representation
      or numeric_value_out_of_range
      or null_value_not_allowed then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  if v_rate is null or v_rate <= 0 or v_rate > 1000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_rate');
  end if;
  if v_value is null or v_value < 0 or v_value > 1000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_value');
  end if;

  -- With no explicit rule, edit the one the admin page shows. Only an empty
  -- table falls through to creating the default program.
  if v_id is null then
    select r.id into v_id
      from loyalty.loyalty_rules r
     order by r.is_active desc, r.valid_from desc
     limit 1;
  end if;

  if v_id is null then
    insert into loyalty.loyalty_rules
      (code, name_ar, name_en, points_per_currency_unit, point_value, is_active)
    values
      ('default_earn', 'نقاط الطلب الافتراضية', 'Default earn rate', v_rate, v_value, v_active)
    returning id into v_id;
    v_created := true;
  else
    select to_jsonb(r) into v_old
      from loyalty.loyalty_rules r
     where r.id = v_id;

    if v_old is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    update loyalty.loyalty_rules
       set points_per_currency_unit = v_rate,
           point_value = v_value,
           is_active = v_active,
           updated_at = now()
     where id = v_id;
  end if;

  perform identity.audit(
    case when v_created then 'loyalty.rule.create' else 'loyalty.rule.update' end,
    'loyalty_rule',
    v_id,
    v_old,
    jsonb_build_object(
      'points_per_currency_unit', v_rate,
      'point_value', v_value,
      'is_active', v_active
    )
  );

  return jsonb_build_object('ok', true, 'id', v_id, 'created', v_created);
exception
  when numeric_value_out_of_range then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
end;
$fn$;

comment on function public.admin_save_loyalty_rule is
  'Edit the points earning rate, point value and active flag of the program rule.';

revoke all on function public.admin_save_loyalty_rule(jsonb) from public, anon;
grant execute on function public.admin_save_loyalty_rule(jsonb) to authenticated;
