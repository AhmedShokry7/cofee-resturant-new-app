-- Behaviour checks for 20261126161000_mandatory_verified_customer_phone.sql.
-- Run against a local Supabase database after applying migrations. All fixtures
-- are rolled back at the end; this file must never be run against production.

begin;

insert into auth.users (id, email)
values
  ('7d100000-0000-4000-8000-000000000001', 'phone-one@test.local'),
  ('7d100000-0000-4000-8000-000000000002', 'phone-two@test.local');

select set_config('request.jwt.claim.sub', '7d100000-0000-4000-8000-000000000001', true);
do $test$
begin
  if identity.current_customer_phone_verified() then
    raise exception 'unverified customer was treated as phone verified';
  end if;
  begin
    update identity.profiles
       set phone = '+966501234567'
     where id = '7d100000-0000-4000-8000-000000000001';
    raise exception 'client profile write accepted an unverified phone';
  exception when insufficient_privilege then
    null;
  end;
end;
$test$;

update auth.users
   set phone = '+966501234567',
       phone_confirmed_at = now()
 where id = '7d100000-0000-4000-8000-000000000001';

do $test$
begin
  if not identity.current_customer_phone_verified() then
    raise exception 'verified Supabase Auth phone was not mirrored';
  end if;
  if not exists (
    select 1 from identity.profiles
     where id = '7d100000-0000-4000-8000-000000000001'
       and phone = '+966501234567'
       and phone_verified_at is not null
  ) then
    raise exception 'verified E.164 phone is missing from customer profile';
  end if;
  if identity.phone_e164('050 123 4567') <> '+966501234567'
     or identity.phone_e164('+966 50 123 4567') <> '+966501234567' then
    raise exception 'Saudi local and international formats did not normalize';
  end if;
  begin
    update auth.users
       set phone = '+966501234567',
           phone_confirmed_at = now()
     where id = '7d100000-0000-4000-8000-000000000002';
    raise exception 'duplicate verified phone was accepted';
  exception when unique_violation then
    null;
  end;
end;
$test$;

update auth.users
   set phone = null,
       phone_confirmed_at = null
 where id = '7d100000-0000-4000-8000-000000000001';

do $test$
begin
  if identity.current_customer_phone_verified() then
    raise exception 'removed Auth phone remained verified in customer profile';
  end if;
  if exists (
    select 1 from identity.profiles
     where id = '7d100000-0000-4000-8000-000000000001'
       and (phone is not null or phone_verified_at is not null)
  ) then
    raise exception 'removed Auth phone was not cleared from customer profile';
  end if;
end;
$test$;

rollback;
