-- Keep Phase 1.3 reader roles compatible with identity.roles_code_check.
-- Encode the run UUID as letters so the role code remains run-specific while
-- satisfying the existing ^[a-z_]+$ constraint. No permission or grant changes.
create or replace function payments.register_phase13_test_identity(
  p_user_id uuid,p_run_id uuid,p_identity_kind text,p_expires_at timestamptz,p_branch_id uuid default null
)
returns void language plpgsql security definer set search_path = ''
as $fn$
declare v_email text; v_role_id uuid; v_role_code text; v_staff_id uuid; v_orders_read uuid;
begin
  if p_user_id is null or p_run_id is null
     or p_identity_kind not in ('customer','customer_denied','staff_reader','staff_denied')
     or p_expires_at<=now() or p_expires_at>now()+interval '48 hours' then
    raise exception 'invalid Phase 1.3 test identity registration' using errcode='22023';
  end if;
  select u.email into v_email from auth.users u where u.id=p_user_id;
  if not found or v_email is null or lower(v_email) not like '%@example.invalid' then
    raise exception 'only newly provisioned .invalid test accounts can be registered' using errcode='42501';
  end if;
  if exists(select 1 from identity.staff_members sm where sm.user_id=p_user_id)
     or exists(select 1 from payments.phase13_test_identities ti where ti.user_id=p_user_id) then
    raise exception 'identity is already in use; no existing account may be repurposed' using errcode='23505';
  end if;
  if p_identity_kind='staff_reader' then
    if p_branch_id is null or not exists(select 1 from core.branches b where b.id=p_branch_id
      and b.settings->>'phase13_test_run_id'=p_run_id::text and not b.is_active
      and exists(select 1 from payments.phase13_test_seller_profiles p where p.branch_id=b.id
        and p.run_id=p_run_id and p.expires_at>now())) then
      raise exception 'a dedicated inactive Phase 1.3 test branch is required' using errcode='22023';
    end if;
  elsif p_branch_id is not null then
    raise exception 'branch scope is only valid for the dedicated test reader' using errcode='22023';
  end if;
  insert into payments.phase13_test_identities(user_id,run_id,identity_kind,branch_id,expires_at)
    values(p_user_id,p_run_id,p_identity_kind,p_branch_id,p_expires_at);
  if p_identity_kind='customer' then
    insert into payments.phase13_test_customers(user_id,run_id,expires_at) values(p_user_id,p_run_id,p_expires_at);
  elsif p_identity_kind in ('staff_reader','staff_denied') then
    insert into identity.staff_members(user_id,status,full_name,email,accepted_at)
      values(p_user_id,'active','Phase 1.3 Test Staff',v_email,now()) returning id into v_staff_id;
    if p_identity_kind='staff_reader' then
      v_role_code:='phase_invoice_reader_'||
        translate(replace(p_run_id::text,'-',''),'0123456789abcdef','abcdefghijklmnop');
      insert into identity.roles(code,name_ar,name_en,description,is_system)
        values(v_role_code,'قارئ فواتير الاختبار','Phase 1.3 invoice test reader',
          'Temporary test-only role limited to orders.read on one dedicated test branch.',false)
        returning id into v_role_id;
      select p.id into v_orders_read from identity.permissions p where p.code='orders.read';
      if v_orders_read is null then raise exception 'orders.read permission is unavailable'; end if;
      insert into identity.role_permissions(role_id,permission_id) values(v_role_id,v_orders_read);
      insert into identity.staff_roles(staff_id,role_id,branch_id) values(v_staff_id,v_role_id,p_branch_id);
    end if;
  end if;
end;
$fn$;
revoke all on function payments.register_phase13_test_identity(uuid,uuid,text,timestamptz,uuid) from public,anon,authenticated;
grant execute on function payments.register_phase13_test_identity(uuid,uuid,text,timestamptz,uuid) to service_role;
