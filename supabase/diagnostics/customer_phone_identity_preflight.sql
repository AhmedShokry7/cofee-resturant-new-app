-- Read-only audit before applying
-- 20261126161000_mandatory_verified_customer_phone.sql.
-- Customer numbers use the exact normalizer the migration/POS RPC will use.
-- Only masked phone suffixes are returned. IDs are included for manual review.

with customer_accounts as (
  select
    u.id,
    u.email,
    u.phone,
    u.phone_confirmed_at,
    identity.phone_e164(u.phone) as phone_key
  from auth.users u
  where not exists (
    select 1 from identity.staff_members sm where sm.user_id = u.id
  )
)
select
  id as customer_id,
  case
    when nullif(email, '') is null and nullif(phone, '') is null then 'no_email_no_phone'
    when nullif(email, '') is null then 'phone_only'
    when nullif(phone, '') is null then 'email_only'
    else 'email_and_phone'
  end as account_kind,
  phone_confirmed_at is not null as phone_verified,
  case when phone_key is null then null else '***' || right(phone_key, 2) end as masked_phone
from customer_accounts
order by account_kind, customer_id;

-- Duplicate customer Auth phone ownership, after canonical E.164 normalization.
with customer_accounts as (
  select u.id, u.phone_confirmed_at, identity.phone_e164(u.phone) phone_key
  from auth.users u
  where nullif(u.phone, '') is not null
    and not exists (
      select 1 from identity.staff_members sm where sm.user_id = u.id
    )
)
select
  array_agg(id order by id) as customer_ids,
  '***' || right(phone_key, 2) as masked_phone,
  count(*) as account_count,
  bool_or(phone_confirmed_at is not null) as any_verified
from customer_accounts
where phone_key is not null
group by phone_key
having count(*) > 1
order by account_count desc;

-- Historical profile and walk-in records stay separate. This lists normalized
-- collisions without moving orders, loyalty entries, or account ownership.
with all_customers as (
  select 'profile'::text source, p.id, p.phone,
         identity.phone_e164(p.phone) phone_key
    from identity.profiles p
   where nullif(p.phone, '') is not null
     and not exists (
       select 1 from identity.staff_members sm where sm.user_id = p.id
     )
  union all
  select 'pos_walk_in', c.id, c.phone,
         identity.phone_e164(c.phone)
    from orders.pos_customers c
   where nullif(c.phone, '') is not null
),
duplicates as (
  select phone_key, array_agg(source || ':' || id::text order by source, id) customer_records,
         count(*) record_count
    from all_customers
   where phone_key is not null
   group by phone_key
  having count(*) > 1
)
select customer_records, '***' || right(phone_key, 2) masked_phone, record_count
from duplicates
order by record_count desc;
