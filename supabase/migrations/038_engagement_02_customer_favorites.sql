-- 038_engagement_02_customer_favorites.sql
--
-- Customer-owned product bookmarks. The Flutter favorites screen previously
-- persisted only product ids on the device, so signing in on another device
-- lost the list and removing a product left a stale id behind.
--
-- This adds a deliberately small table:
--   * no price, quantity, branch or order semantics;
--   * one row per customer/product;
--   * product deletion removes its bookmarks automatically;
--   * owner-only RLS for every operation;
--   * direct writes only by the row owner, with no SECURITY DEFINER helper;
--   * a thin public.bridge view, because PostgREST serves only public here.

create table if not exists engagement.customer_favorites (
  id         uuid primary key default extensions.gen_random_uuid(),
  user_id    uuid not null references identity.profiles(id) on delete cascade,
  product_id uuid not null references catalog.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

comment on table engagement.customer_favorites is
  'Customer-owned product bookmarks. One row per customer and product.';

create index if not exists ix_customer_favorites_user
  on engagement.customer_favorites (user_id, created_at desc);
create index if not exists ix_customer_favorites_product
  on engagement.customer_favorites (product_id);

alter table engagement.customer_favorites enable row level security;

revoke all on table engagement.customer_favorites from anon, authenticated;
grant select on table engagement.customer_favorites to service_role;

create policy customer_favorites_all_own on engagement.customer_favorites
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

comment on policy customer_favorites_all_own on engagement.customer_favorites is
  'Owner-only favorites. No staff read and no cross-customer access.';

grant select, insert, delete on table engagement.customer_favorites
  to authenticated;
revoke all on table engagement.customer_favorites from anon;

create or replace view public.customer_favorites with (security_invoker = true) as
  select * from engagement.customer_favorites;

grant select, insert, delete on public.customer_favorites to authenticated;
revoke all on public.customer_favorites from anon;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
