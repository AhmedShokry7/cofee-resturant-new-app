-- 060_customer_address_default.sql
-- Atomic default-address selection for customer_addresses.

create or replace function identity.set_default_address(p_address_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
      from identity.customer_addresses ca
     where ca.id = p_address_id
       and ca.user_id = v_uid
       and ca.archived_at is null
  ) then
    raise exception 'address not found' using errcode = 'P0002';
  end if;

  update identity.customer_addresses
     set is_default = false
   where user_id = v_uid
     and archived_at is null
     and id <> p_address_id;

  update identity.customer_addresses
     set is_default = true
   where id = p_address_id
     and user_id = v_uid;
end;
$fn$;

revoke all on function identity.set_default_address(uuid) from public, anon;
grant execute on function identity.set_default_address(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';
