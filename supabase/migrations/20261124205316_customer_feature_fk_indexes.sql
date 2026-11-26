-- Index foreign keys for customer bundle, subscription, and reservation paths.
begin;

create index if not exists ix_customer_bundle_items_product
  on public.customer_bundle_items(product_id);
create index if not exists ix_cpsi_product
  on subscriptions.customer_product_subscription_items(product_id);
create index if not exists ix_cpsr_order
  on subscriptions.customer_product_subscription_runs(order_id);
create index if not exists ix_cpsr_user
  on subscriptions.customer_product_subscription_runs(user_id);
create index if not exists ix_cps_branch
  on subscriptions.customer_product_subscriptions(branch_id);
create index if not exists ix_cps_delivery_address
  on subscriptions.customer_product_subscriptions(delivery_address_id);
create index if not exists ix_floor_reservations_created_by
  on floor.reservations(created_by);
create index if not exists ix_floor_reservations_reviewed_by
  on floor.reservations(reviewed_by);

commit;
