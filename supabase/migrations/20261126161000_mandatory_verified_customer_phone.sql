-- Mandatory verified phone identity for customer accounts.
-- The application uses auth.users.phone as proof; this is a guarded mirror for
-- profile/POS reads. No historical account or order is merged by this change.

alter table identity.profiles
  add column if not exists phone_verified_at timestamptz;

create or replace function identity.phone_e164(p_phone text)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if v_digits = '' then return null; end if;
  if left(v_digits, 2) = '00' then
    v_digits := substr(v_digits, 3);
  elsif left(v_digits, 3) = '966' then
    null;
  elsif left(v_digits, 2) = '05' then
    v_digits := '966' || substr(v_digits, 2);
  elsif left(v_digits, 1) = '5' and length(v_digits) = 9 then
    v_digits := '966' || v_digits;
  elsif left(coalesce(p_phone, ''), 1) <> '+' then
    -- Without a country code, only Saudi local mobile formats are unambiguous.
    return null;
  end if;
  if length(v_digits) not between 8 and 15 or left(v_digits, 1) = '0' then
    return null;
  end if;
  return '+' || v_digits;
end;
$fn$;

create unique index if not exists uq_profiles_verified_phone
  on identity.profiles (identity.phone_e164(phone))
  where phone_verified_at is not null and phone is not null;

create or replace function identity.protect_verified_customer_phone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_auth_phone text;
  v_confirmed_at timestamptz;
begin
  select u.phone, u.phone_confirmed_at
    into v_auth_phone, v_confirmed_at
    from auth.users u
   where u.id = new.id;

  if tg_op = 'INSERT' then
    if new.phone is not null or new.phone_verified_at is not null then
      if v_confirmed_at is null
         or new.phone is distinct from v_auth_phone
         or new.phone_verified_at is distinct from v_confirmed_at then
        raise exception 'phone must be verified by Supabase Auth'
          using errcode = '42501';
      end if;
    end if;
  elsif new.phone is distinct from old.phone
     or new.phone_verified_at is distinct from old.phone_verified_at then
    if v_confirmed_at is null
       and new.phone is null
       and new.phone_verified_at is null then
      null;
    elsif v_confirmed_at is null
       or new.phone is distinct from v_auth_phone
       or new.phone_verified_at is distinct from v_confirmed_at then
      raise exception 'phone must be verified by Supabase Auth'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

revoke all on function identity.protect_verified_customer_phone() from public, anon, authenticated;
revoke all on function identity.phone_e164(text) from public, anon, authenticated;
grant execute on function identity.phone_e164(text) to authenticated;

-- Reserve in-flight phone-change requests globally. Supabase Auth remains the
-- account/session authority; this index closes the race between two accounts
-- both requesting verification for the same number.
create unique index if not exists uq_auth_users_pending_phone_change
  on auth.users (identity.phone_e164(phone_change))
  where nullif(phone_change, '') is not null;

drop trigger if exists tr_profiles_verified_phone_guard on identity.profiles;
create trigger tr_profiles_verified_phone_guard
  before insert or update on identity.profiles
  for each row execute function identity.protect_verified_customer_phone();

create or replace function identity.sync_verified_customer_phone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.phone is not null and new.phone_confirmed_at is not null then
    update identity.profiles
       set phone = new.phone,
           phone_verified_at = new.phone_confirmed_at
     where id = new.id
       and (phone is distinct from new.phone
         or phone_verified_at is distinct from new.phone_confirmed_at);
  else
    update identity.profiles
       set phone = null,
           phone_verified_at = null
     where id = new.id
       and (phone is not null or phone_verified_at is not null);
  end if;
  return new;
end;
$fn$;

revoke all on function identity.sync_verified_customer_phone() from public, anon, authenticated;
grant execute on function identity.sync_verified_customer_phone() to supabase_auth_admin;

drop trigger if exists tr_auth_sync_verified_customer_phone on auth.users;
create trigger tr_auth_sync_verified_customer_phone
  after insert or update of phone, phone_confirmed_at on auth.users
  for each row execute function identity.sync_verified_customer_phone();

create or replace function identity.current_customer_phone_verified()
returns boolean
language sql
stable
set search_path = ''
as $fn$
  select exists (
    select 1
      from identity.profiles p
     where p.id = auth.uid()
       and p.phone_verified_at is not null
  );
$fn$;

revoke all on function identity.current_customer_phone_verified() from public, anon;
grant execute on function identity.current_customer_phone_verified() to authenticated, service_role;

-- The customer checkout RPC is SECURITY DEFINER, so enforce the verified-phone
-- requirement here as well as in Flutter's route gate.
do $migration$
declare
  v_definition text;
  v_anchor text :=
    'if v_uid is null then raise exception ''authentication required'' using errcode = ''42501''; end if;';
  v_replacement text :=
    v_anchor || E'\n  if not identity.current_customer_phone_verified() then\n' ||
    '    raise exception ''verified phone required'' using errcode = ''42501'';' ||
    E'\n  end if;';
begin
  v_definition := pg_get_functiondef(
    'orders.place_order_with_lines(uuid,jsonb,text,text,uuid,text,text,uuid)'::regprocedure
  );
  if position(v_anchor in v_definition) = 0 then
    raise exception 'customer checkout authorization changed; review migration';
  end if;
  execute replace(v_definition, v_anchor, v_replacement);
end;
$migration$;

-- Make the cashier's existing create/reuse path resolve only verified customer
-- identities, and normalize international E.164 and Saudi-local spellings.
do $migration$
declare
  v_definition text;
  v_updated text;
  v_old text;
  v_new text;
begin
  v_definition := pg_get_functiondef(
    'public.admin_pos_customer_create(text,text,text,text)'::regprocedure
  );
  v_old := 'v_phone_norm := nullif(regexp_replace(v_phone, ''[^0-9+]'', '''', ''g''), '''');';
  v_new := 'v_phone_norm := identity.phone_e164(v_phone);';
  if position(v_old in v_definition) = 0 then
    raise exception 'POS customer create phone normalization changed; review migration';
  end if;
  v_updated := replace(v_definition, v_old, v_new);
  v_new := regexp_replace(
    v_updated,
    $re$where regexp_replace\(coalesce\(p\.phone, ''\), '\[\^0-9\+\]', '', 'g'\)[[:space:]]*=[[:space:]]*v_phone_norm$re$,
    $replacement$where p.phone_verified_at is not null and identity.phone_e164(p.phone) = v_phone_norm$replacement$
  );
  if v_new = v_updated then
    raise exception 'POS registered customer lookup changed; review migration';
  end if;
  execute v_new;
end;
$migration$;

do $migration$
declare
  v_definition text;
  v_updated text;
  v_old text;
  v_new text;
begin
  v_definition := pg_get_functiondef(
    'public.admin_pos_customer_create(text,text,text,text)'::regprocedure
  );
  v_old := 'v_reused     boolean := false;';
  v_new := v_old || E'\n  v_match_count integer := 0;';
  if position(v_old in v_definition) = 0 then
    raise exception 'POS customer variables changed; review migration';
  end if;
  v_updated := replace(v_definition, v_old, v_new);

  v_old := '  insert into orders.pos_customers (';
  v_new := $block$  if v_phone_norm is not null then
    select count(*)::integer into v_match_count
      from orders.pos_customers c
     where identity.phone_e164(c.phone) = v_phone_norm;
    if v_match_count > 1 then
      raise exception 'multiple POS customers match this phone; manual review required'
        using errcode = '23505';
    elsif v_match_count = 1 then
      select * into v_customer
        from orders.pos_customers c
       where identity.phone_e164(c.phone) = v_phone_norm
       limit 1;
      v_reused := true;
    end if;
  end if;

  if v_customer.id is null then
  insert into orders.pos_customers ($block$;
  if position(v_old in v_updated) = 0 then
    raise exception 'POS customer insertion changed; review migration';
  end if;
  v_updated := replace(v_updated, v_old, v_new);

  v_old := '  returning * into v_customer;';
  v_new := v_old || E'\n  end if;';
  if position(v_old in v_updated) = 0 then
    raise exception 'POS customer insert return changed; review migration';
  end if;
  v_updated := replace(v_updated, v_old, v_new);
  execute v_updated;
end;
$migration$;

do $migration$
declare
  v_definition text;
  v_updated text;
begin
  v_definition := pg_get_functiondef(
    'public.admin_pos_customers(text,integer)'::regprocedure
  );
  v_updated := replace(
    v_definition,
    'where not p.is_blacklisted',
    'where p.phone_verified_at is not null and not p.is_blacklisted'
  );
  if v_updated = v_definition then
    raise exception 'POS registered customer filter changed; review migration';
  end if;
  v_definition := v_updated;
  v_updated := regexp_replace(
    v_definition,
    $re$p\.phone,[[:space:]]*p\.avatar_url,$re$,
    $replacement$case when p.phone_verified_at is not null then p.phone else null end as phone, p.avatar_url,$replacement$
  );
  if v_updated = v_definition then
    raise exception 'POS customer result shape changed; review migration';
  end if;
  v_definition := v_updated;
  v_updated := regexp_replace(
    v_definition,
    $re$when coalesce\(p\.phone, ''\) ilike '%' \|\| v_term \|\| '%' then 0$re$,
    $replacement$when p.phone_verified_at is not null and (coalesce(p.phone, '') ilike '%' || v_term || '%' or identity.phone_e164(p.phone) = identity.phone_e164(v_term)) then 0$replacement$
  );
  if v_updated = v_definition then
    raise exception 'POS customer sort expression changed; review migration';
  end if;
  v_definition := v_updated;
  v_updated := regexp_replace(
    v_definition,
    $re$or coalesce\(p\.phone, ''\) ilike '%' \|\| v_term \|\| '%'$re$,
    $replacement$or (p.phone_verified_at is not null and (coalesce(p.phone, '') ilike '%' || v_term || '%' or identity.phone_e164(p.phone) = identity.phone_e164(v_term)))$replacement$
  );
  if v_updated = v_definition then
    raise exception 'POS customer search expression changed; review migration';
  end if;
  execute v_updated;
end;
$migration$;
