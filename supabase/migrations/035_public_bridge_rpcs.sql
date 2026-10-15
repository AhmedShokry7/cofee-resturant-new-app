-- 035_public_bridge_rpcs.sql
--
-- RPCs for the Flutter client.
--
-- PostgREST can only serve the public schema on this project, so the business
-- functions that live in catalog/orders/marketing/loyalty/engagement are
-- re-published in public. Nothing is reimplemented: each wrapper calls the
-- function that already carries the real logic, so there is still exactly one
-- place where a price is decided or stock is deducted.
--
-- The functions themselves are unchanged and still SECURITY DEFINER with
-- search_path = ''. A wrapper does not weaken that: it forwards the caller's
-- JWT untouched, so the callee still sees auth.uid() as the caller and still
-- runs its own permission checks.

-- Catalog ------------------------------------------------------------------
create or replace function public.search_products(
  p_query       text default null,
  p_branch_id   uuid default null,
  p_category_id uuid default null,
  p_min_price   numeric default null,
  p_max_price   numeric default null,
  p_sort        text default 'relevance',
  p_page        integer default 1,
  p_page_size   integer default 20
)
returns table (
  id uuid, slug text, name_ar text, name_en text,
  description_ar text, description_en text, image_url text,
  base_price numeric, effective_price numeric, is_available boolean,
  category_id uuid, category_name_ar text, category_name_en text,
  rank real, total_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from catalog.search_products(
    p_query, p_branch_id, p_category_id, p_min_price, p_max_price,
    p_sort, p_page, p_page_size);
$fn$;

create or replace function public.get_best_sellers(
  p_branch_id uuid,
  p_period interval default '30 days',
  p_limit integer default 10
)
returns table (
  product_id uuid, name_ar text, name_en text, image_url text,
  units_sold bigint, revenue numeric
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from catalog.get_best_sellers(p_branch_id, p_period, p_limit);
$fn$;

create or replace function public.get_featured(
  p_branch_id uuid,
  p_limit integer default 10
)
returns table (
  product_id uuid, name_ar text, name_en text, image_url text,
  effective_price numeric, source text
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from catalog.get_featured(p_branch_id, p_limit);
$fn$;

create or replace function public.resolve_effective_price(
  p_branch_id  uuid,
  p_product_id uuid,
  p_option_value_ids uuid[] default '{}'
)
returns table (
  unit_price numeric, currency_code text, is_available boolean,
  option_deltas numeric, unavailable_reason text
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from catalog.resolve_effective_price(p_branch_id, p_product_id, p_option_value_ids);
$fn$;

-- Branches -----------------------------------------------------------------
create or replace function public.active_branches()
returns table (
  id uuid, code text, name_ar text, name_en text,
  address text, latitude numeric, longitude numeric, phone text
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from core.active_branches();
$fn$;

-- Cart and orders ----------------------------------------------------------
create or replace function public.get_or_create_cart(p_branch_id uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$
  select orders.get_or_create_cart(p_branch_id);
$fn$;

create or replace function public.upsert_cart_item(
  p_branch_id        uuid,
  p_product_id       uuid,
  p_quantity         integer default 1,
  p_note             text default '',
  p_option_value_ids uuid[] default '{}'
)
returns table (cart_item_id uuid, unit_price numeric, line_total numeric, item_count integer)
language sql
security invoker
set search_path = ''
as $fn$
  select * from orders.upsert_cart_item(
    p_branch_id, p_product_id, p_quantity, p_note, p_option_value_ids);
$fn$;

create or replace function public.remove_cart_item(p_cart_item_id uuid)
returns integer
language sql
security invoker
set search_path = ''
as $fn$
  select orders.remove_cart_item(p_cart_item_id);
$fn$;

create or replace function public.get_cart_summary(p_cart_id uuid)
returns table (subtotal numeric, item_count integer)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from orders.get_cart_summary(p_cart_id);
$fn$;

create or replace function public.place_order(
  p_cart_id          uuid,
  p_idempotency_key  text,
  p_fulfillment_type text,
  p_delivery_zone_id uuid default null,
  p_coupon_code      text default null,
  p_note             text default null
)
returns table (
  order_id uuid, order_number text, subtotal numeric, discount_total numeric,
  delivery_fee numeric, tax_total numeric, grand_total numeric,
  points_earned integer, reused_existing_order boolean
)
language sql
security invoker
set search_path = ''
as $fn$
  select * from orders.place_order(
    p_cart_id, p_idempotency_key, p_fulfillment_type,
    p_delivery_zone_id, p_coupon_code, p_note);
$fn$;

create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns boolean
language sql
security invoker
set search_path = ''
as $fn$
  select orders.cancel_order(p_order_id, p_reason);
$fn$;

create or replace function public.update_order_status(
  p_order_id uuid, p_to_status text, p_note text default null
)
returns boolean
language sql
security invoker
set search_path = ''
as $fn$
  select orders.update_order_status(p_order_id, p_to_status, p_note);
$fn$;

-- Marketing and loyalty ----------------------------------------------------
create or replace function public.validate_coupon(
  p_code text, p_subtotal numeric, p_branch_id uuid default null
)
returns table (coupon_id uuid, code text, discount numeric, message text)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from marketing.validate_coupon(p_code, p_subtotal, p_branch_id);
$fn$;

create or replace function public.redeem_reward(p_product_id uuid, p_branch_id uuid)
returns integer
language sql
security invoker
set search_path = ''
as $fn$
  select loyalty.redeem_reward(p_product_id, p_branch_id);
$fn$;

create or replace function public.mark_notifications_read(p_ids uuid[])
returns integer
language sql
security invoker
set search_path = ''
as $fn$
  select engagement.mark_notifications_read(p_ids);
$fn$;

-- ---------------------------------------------------------------------------
-- Grants.
--
-- Reads are open to anon so the menu renders before sign-in. Everything that
-- touches a cart, an order or a balance requires a session, and the wrapped
-- function still checks the caller itself.
-- ---------------------------------------------------------------------------
grant execute on function
  public.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer),
  public.get_best_sellers(uuid, interval, integer),
  public.get_featured(uuid, integer),
  public.resolve_effective_price(uuid, uuid, uuid[]),
  public.active_branches()
  to anon, authenticated;

grant execute on function
  public.get_or_create_cart(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[]),
  public.remove_cart_item(uuid),
  public.get_cart_summary(uuid),
  public.place_order(uuid, text, text, uuid, text, text),
  public.cancel_order(uuid, text),
  public.update_order_status(uuid, text, text),
  public.validate_coupon(text, numeric, uuid),
  public.redeem_reward(uuid, uuid),
  public.mark_notifications_read(uuid[])
  to authenticated;

-- Never to a role that has not signed in.
revoke execute on function
  public.get_or_create_cart(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[]),
  public.remove_cart_item(uuid),
  public.get_cart_summary(uuid),
  public.place_order(uuid, text, text, uuid, text, text),
  public.cancel_order(uuid, text),
  public.update_order_status(uuid, text, text),
  public.validate_coupon(text, numeric, uuid),
  public.redeem_reward(uuid, uuid),
  public.mark_notifications_read(uuid[])
  from anon;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';