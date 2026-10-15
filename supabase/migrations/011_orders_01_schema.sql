-- 011_orders_01_schema.sql
--
-- The most important table set in the project.
--
-- Two Flutter defects are fixed here:
--   1. OrderItemModel had NO price and NO date, so
--      order_details_page.dart:78 recomputed the total from the LIVE
--      catalog price on every render. Old invoices changed when prices moved.
--      -> order_items carries full snapshots.
--   2. CartItem.note flattened the chosen size/sugar into free text, so the
--      option identity was lost.
--      -> cart_item_options stores structured selections.

-- ---------------------------------------------------------------------------
-- Carts. One active cart per customer (D1: the cart is bound to a branch).
-- ---------------------------------------------------------------------------
create table if not exists orders.carts (
  id         uuid primary key default extensions.gen_random_uuid(),
  user_id    uuid not null references identity.profiles(id) on delete cascade,
  branch_id  uuid not null references core.branches(id) on delete restrict,
  status     text not null default 'active'
               check (status in ('active','converted','abandoned')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table orders.carts is
  'Customer carts, scoped to a branch. Writes go through orders.upsert_cart_item() only.';

-- Exactly one active cart per customer.
create unique index if not exists uq_carts_one_active
  on orders.carts (user_id) where status = 'active';
create index if not exists ix_carts_branch on orders.carts (branch_id);
create index if not exists ix_carts_expires on orders.carts (expires_at) where status = 'active';

create trigger tr_carts_updated_at
  before update on orders.carts
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists orders.cart_items (
  id         uuid primary key default extensions.gen_random_uuid(),
  cart_id    uuid not null references orders.carts(id) on delete cascade,
  product_id uuid not null references catalog.products(id) on delete restrict,
  quantity   integer not null default 1 check (quantity > 0 and quantity <= 99),
  note       text not null default '',
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  created_at timestamptz not null default now(),
  constraint ck_cart_items_total check (line_total = round(unit_price * quantity, 2)),
  -- one row per (product, note) -- mirrors CartCubit.add() merge key
  unique (cart_id, product_id, note)
);

comment on table orders.cart_items is
  'Cart lines. unit_price is ALWAYS recomputed server-side; never trusted from the client.';

create index if not exists ix_cart_items_cart on orders.cart_items (cart_id);
create index if not exists ix_cart_items_product on orders.cart_items (product_id);

create table if not exists orders.cart_item_options (
  id             uuid primary key default extensions.gen_random_uuid(),
  cart_item_id   uuid not null references orders.cart_items(id) on delete cascade,
  option_value_id uuid not null references catalog.option_values(id) on delete restrict,
  option_name_ar text not null,
  option_name_en text not null,
  price_delta    numeric(12,2) not null default 0,
  unique (cart_item_id, option_value_id)
);

comment on table orders.cart_item_options is
  'Structured option selections per cart line (replaces the flattened CartItem.note string).';

create index if not exists ix_cart_item_options_item on orders.cart_item_options (cart_item_id);

-- ---------------------------------------------------------------------------
-- Orders.
-- grand_total has a CHECK: tampering is arithmetically impossible.
-- idempotency_key has a UNIQUE: retrying can never double-order.
-- ---------------------------------------------------------------------------
create table if not exists orders.orders (
  id                      uuid primary key default extensions.gen_random_uuid(),
  order_number            text not null unique,
  user_id                 uuid not null references identity.profiles(id) on delete restrict,
  branch_id               uuid not null references core.branches(id) on delete restrict,
  fulfillment_type        text not null check (fulfillment_type in ('pickup','delivery')),
  delivery_zone_id        uuid references core.delivery_zones(id) on delete restrict,
  delivery_address_snapshot jsonb not null default '{}'::jsonb,
  status                  text not null check (status in
                            ('pending','confirmed','preparing','ready',
                             'out_for_delivery','completed','cancelled')),
  payment_method_id       uuid,
  payment_status          text not null default 'unpaid'
                            check (payment_status in ('unpaid','pending','paid','failed','refunded')),
  subtotal                numeric(12,2) not null check (subtotal >= 0),
  discount_total          numeric(12,2) not null default 0 check (discount_total >= 0),
  delivery_fee            numeric(12,2) not null default 0 check (delivery_fee >= 0),
  tax_total               numeric(12,2) not null default 0 check (tax_total >= 0),
  grand_total             numeric(12,2) not null check (grand_total >= 0),
  currency_code           text not null default 'SAR',
  customer_note           text not null default '',
  loyalty_points_earned   integer not null default 0 check (loyalty_points_earned >= 0),
  loyalty_points_redeemed integer not null default 0 check (loyalty_points_redeemed >= 0),
  idempotency_key         text not null unique,
  placed_at               timestamptz not null default now(),
  completed_at            timestamptz,
  cancelled_at            timestamptz,
  cancel_reason           text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  -- Server-side arithmetic is enforced by the database, not by the app.
  constraint ck_orders_total check (
    grand_total = round(subtotal - discount_total + delivery_fee + tax_total, 2)
  ),
  constraint ck_orders_discount_capped check (discount_total <= subtotal),
  constraint ck_orders_delivery_needs_zone check (
    fulfillment_type <> 'delivery' or delivery_zone_id is not null
  )
);

comment on table orders.orders is
  'Orders. Totals are CHECK-constrained; idempotency_key UNIQUE prevents duplicate orders.';

create index if not exists ix_orders_user
  on orders.orders (user_id, placed_at desc);
create index if not exists ix_orders_branch_status
  on orders.orders (branch_id, status, placed_at desc);
create index if not exists ix_orders_open
  on orders.orders (status, placed_at desc)
  where status not in ('completed','cancelled');
create index if not exists ix_orders_placed on orders.orders (placed_at desc);

create trigger tr_orders_updated_at
  before update on orders.orders
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Order lines: full snapshots. Nothing here is ever read from the catalog.
-- ---------------------------------------------------------------------------
create table if not exists orders.order_items (
  id                   uuid primary key default extensions.gen_random_uuid(),
  order_id             uuid not null references orders.orders(id) on delete restrict,
  product_id           uuid references catalog.products(id) on delete set null,
  option_group_name_ar text not null default '',
  option_group_name_en text not null default '',
  product_name_ar      text not null,
  product_name_en      text not null,
  sku_snapshot         text not null,
  image_snapshot       text,
  unit_price           numeric(12,2) not null check (unit_price >= 0),
  quantity             integer not null check (quantity > 0),
  line_total           numeric(12,2) not null check (line_total >= 0),
  note                 text not null default '',
  created_at           timestamptz not null default now(),
  constraint ck_order_items_total check (line_total = round(unit_price * quantity, 2))
);

comment on table orders.order_items is
  'Order lines with name/price/sku snapshots. The historical invoice never moves again.';

create index if not exists ix_order_items_order on orders.order_items (order_id);
create index if not exists ix_order_items_product on orders.order_items (product_id);

create table if not exists orders.order_item_options (
  id              uuid primary key default extensions.gen_random_uuid(),
  order_item_id   uuid not null references orders.order_items(id) on delete cascade,
  option_value_id uuid references catalog.option_values(id) on delete set null,
  option_name_ar  text not null,
  option_name_en  text not null,
  price_delta     numeric(12,2) not null default 0
);

comment on table orders.order_item_options is
  'Option snapshots per order line. Names are frozen, not looked up.';

create index if not exists ix_order_item_options_item
  on orders.order_item_options (order_item_id);

-- ---------------------------------------------------------------------------
-- Status history. Satisfies the "order status transitions" requirement that
-- did not exist at all in the Flutter app (a 3-value enum, no history).
-- ---------------------------------------------------------------------------
create table if not exists orders.order_status_history (
  id          uuid primary key default extensions.gen_random_uuid(),
  order_id    uuid not null references orders.orders(id) on delete cascade,
  from_status text,
  to_status   text not null,
  changed_by  uuid references auth.users(id) on delete set null,
  note        text,
  created_at  timestamptz not null default now()
);

comment on table orders.order_status_history is
  'Every status transition, who made it and when.';

create index if not exists ix_order_status_history_order
  on orders.order_status_history (order_id, created_at);

-- ---------------------------------------------------------------------------
create table if not exists orders.order_events (
  id         bigserial primary key,
  order_id   uuid not null references orders.orders(id) on delete cascade,
  event_type text not null,
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table orders.order_events is
  'Operational event log for support and debugging.';

create index if not exists ix_order_events_order
  on orders.order_events (order_id, created_at);

-- ---------------------------------------------------------------------------
-- Allowed status transitions. A lookup table, not a CHECK, so the admin can
-- extend the flow without a migration.
-- ---------------------------------------------------------------------------
create table if not exists orders.status_transitions (
  from_status text not null,
  to_status   text not null,
  is_allowed  boolean not null default true,
  primary key (from_status, to_status)
);

comment on table orders.status_transitions is
  'Allowed order status transitions, enforced by orders.update_order_status().';

insert into orders.status_transitions (from_status, to_status, is_allowed) values
  ('pending',            'confirmed',        true),
  ('pending',            'cancelled',        true),
  ('confirmed',          'preparing',        true),
  ('confirmed',          'cancelled',        true),
  ('preparing',          'ready',            true),
  ('preparing',          'cancelled',        true),
  ('ready',              'out_for_delivery', true),
  ('ready',              'completed',        true),
  ('out_for_delivery',   'completed',        true),
  -- terminal states allow no onward transition
  ('completed',          'preparing',        false),
  ('cancelled',          'pending',          false),
  ('cancelled',          'confirmed',        false)
on conflict do nothing;