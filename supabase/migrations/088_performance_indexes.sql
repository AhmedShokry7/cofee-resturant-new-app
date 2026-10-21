-- 088_performance_indexes.sql
--
-- فهارس مركبة للاستعلامات المتكررة في التطبيق (قوائم الطلبات، المخزون، الولاء،
-- العناوين، الكوبونات، الإشعارات). الغرض تقليص عدد الصفوف التي يُفحصها
-- Postgres في كل استعلام، خاصة مع جداول كبيرة تصل إلى الملايين.

-- --- orders.orders ---
create index if not exists ix_orders_user_placed_desc
  on orders.orders (user_id, placed_at desc);

create index if not exists ix_orders_branch_status_placed_desc
  on orders.orders (branch_id, status, placed_at desc);

create index if not exists ix_orders_status_active_desc
  on orders.orders (status)
  where status not in ('completed', 'cancelled');

create index if not exists ix_orders_idempotency
  on orders.orders (user_id, idempotency_key);

-- --- orders.order_items ---
create index if not exists ix_order_items_order_id
  on orders.order_items (order_id);

create index if not exists ix_order_items_product_id
  on orders.order_items (product_id);

-- --- orders.carts ---
create index if not exists ix_carts_user_branch_active
  on orders.carts (user_id, branch_id)
  where status = 'active';

-- --- orders.cart_items ---
create index if not exists ix_cart_items_cart_id
  on orders.cart_items (cart_id);

-- --- inventory.branch_stock ---
create index if not exists ix_branch_stock_branch_product_variant
  on inventory.branch_stock (branch_id, product_id, variant_key);

create index if not exists ix_branch_stock_product_available
  on inventory.branch_stock (product_id)
  where quantity_on_hand > 0;

-- --- inventory.stock_movements ---
create index if not exists ix_stock_movements_branch_created_desc
  on inventory.stock_movements (branch_id, created_at desc);

create index if not exists ix_stock_movements_reference
  on inventory.stock_movements (reference_type, reference_id);

-- --- loyalty.loyalty_accounts ---
create index if not exists ix_loyalty_accounts_user_tier
  on loyalty.loyalty_accounts (user_id, tier);

-- --- loyalty.loyalty_transactions ---
create index if not exists ix_loyalty_tx_user_created_desc
  on loyalty.loyalty_transactions (user_id, created_at desc);

create index if not exists ix_loyalty_tx_reference
  on loyalty.loyalty_transactions (reference_type, reference_id);

-- --- identity.customer_addresses ---
create index if not exists ix_customer_addresses_user_active
  on identity.customer_addresses (user_id)
  where archived_at is null;

-- --- marketing.coupons ---
create index if not exists ix_coupons_code_active
  on marketing.coupons (code)
  where is_active = true;

-- --- engagement.notifications ---
create index if not exists ix_notifications_user_created_desc
  on engagement.notifications (user_id, created_at desc);

-- --- catalog.products (additional to existing GIN) ---
create index if not exists ix_products_category_active
  on catalog.products (category_id)
  where is_active = true and archived_at is null;

-- --- catalog.product_images ---
create index if not exists ix_product_images_product_primary
  on catalog.product_images (product_id)
  where is_primary = true;

notify pgrst, 'reload schema';
