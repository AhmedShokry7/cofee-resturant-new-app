-- 059_customer_websites.sql
-- Customer-owned website configuration with row-level ownership.

create table if not exists engagement.customer_websites (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references identity.profiles(id) on delete cascade,
  title text not null default '',
  description text not null default '',
  contact_email text not null default '',
  contact_phone text not null default '',
  theme text not null default 'default',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table engagement.customer_websites is
  'Customer-owned website configuration. One row per customer.';

create unique index if not exists uq_customer_websites_user
  on engagement.customer_websites (user_id);

create index if not exists ix_customer_websites_user
  on engagement.customer_websites (user_id);

create trigger tr_customer_websites_updated_at
  before update on engagement.customer_websites
  for each row execute function core.set_updated_at();

alter table engagement.customer_websites enable row level security;

drop policy if exists customer_websites_select_own on engagement.customer_websites;
create policy customer_websites_select_own
  on engagement.customer_websites
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists customer_websites_insert_own on engagement.customer_websites;
create policy customer_websites_insert_own
  on engagement.customer_websites
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists customer_websites_update_own on engagement.customer_websites;
create policy customer_websites_update_own
  on engagement.customer_websites
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists customer_websites_delete_own on engagement.customer_websites;
create policy customer_websites_delete_own
  on engagement.customer_websites
  for delete
  to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on engagement.customer_websites to authenticated;
grant select on engagement.customer_websites to anon;

notify pgrst, 'reload schema';
