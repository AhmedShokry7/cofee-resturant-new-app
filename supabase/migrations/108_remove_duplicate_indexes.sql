-- Remove redundant indexes added by 088 when an equivalent older index was
-- already present. Identical indexes increase storage and add work to every
-- insert/update/delete without giving the planner a different access path.
-- Keep the original index names used by the earlier schema migrations.

drop index if exists identity.ix_customer_addresses_user_active;
drop index if exists inventory.ix_stock_movements_branch_created_desc;
drop index if exists inventory.ix_stock_movements_reference;
drop index if exists loyalty.ix_loyalty_tx_user_created_desc;
drop index if exists orders.ix_cart_items_cart_id;
drop index if exists orders.ix_order_items_order_id;
drop index if exists orders.ix_order_items_product_id;
drop index if exists orders.ix_orders_user_placed_desc;
drop index if exists orders.ix_orders_branch_status_placed_desc;

comment on index orders.ix_order_items_order is
  'Supports order item lookups by order_id; duplicate ix_order_items_order_id removed in migration 108.';
