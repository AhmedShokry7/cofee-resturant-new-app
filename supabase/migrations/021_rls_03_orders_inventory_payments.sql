-- 021_rls_03_orders_inventory_payments.sql
--
-- The three schemas where a mistake is most expensive.
--
-- orders  : customer owns their rows; NO client INSERT policy exists at all.
--           Orders are only created by orders.place_order().
-- inventory: never visible to a customer. Staff need inventory.read, and
--           branch-scoped staff only see their own branches (D1).
-- payments: a customer sees their own transactions and can never write.

-- ---------------------------------------------------------------------------
-- orders.carts : owner reads. There is intentionally NO insert/update/delete
-- policy -- all writes go through orders.upsert_cart_item().
-- ---------------------------------------------------------------------------
create policy carts_select_own on orders.carts
  for select to authenticated
  using (user_id = auth.uid());

create policy cart_items_select_own on orders.cart_items
  for select to authenticated
  using (
    exists (
      select 1 from orders.carts c
      where c.id = cart_items.cart_id and c.user_id = auth.uid()
    )
  );

create policy cart_item_options_select_own on orders.cart_item_options
  for select to authenticated
  using (
    exists (
      select 1
      from orders.cart_items ci
      join orders.carts c on c.id = ci.cart_id
      where ci.id = cart_item_options.cart_item_id and c.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- orders.orders : owner read, staff read within branch scope, no client insert.
-- ---------------------------------------------------------------------------
create policy orders_select_own on orders.orders
  for select to authenticated
  using (user_id = auth.uid());

create policy orders_select_staff on orders.orders
  for select to authenticated
  using (identity.has_permission('orders.read') and identity.can_manage_branch(branch_id));

create policy order_items_select_own on orders.order_items
  for select to authenticated
  using (
    exists (
      select 1 from orders.orders o
      where o.id = order_items.order_id and o.user_id = auth.uid()
    )
  );

create policy order_items_select_staff on orders.order_items
  for select to authenticated
  using (
    identity.has_permission('orders.read')
    and exists (
      select 1 from orders.orders o
      where o.id = order_items.order_id
        and identity.can_manage_branch(o.branch_id)
    )
  );

create policy order_item_options_select_own on orders.order_item_options
  for select to authenticated
  using (
    exists (
      select 1
      from orders.order_items oi
      join orders.orders o on o.id = oi.order_id
      where oi.id = order_item_options.order_item_id and o.user_id = auth.uid()
    )
  );

create policy order_item_options_select_staff on orders.order_item_options
  for select to authenticated
  using (
    identity.has_permission('orders.read')
    and exists (
      select 1
      from orders.order_items oi
      join orders.orders o on o.id = oi.order_id
      where oi.id = order_item_options.order_item_id
        and identity.can_manage_branch(o.branch_id)
    )
  );

create policy order_status_history_select_own on orders.order_status_history
  for select to authenticated
  using (
    exists (
      select 1 from orders.orders o
      where o.id = order_status_history.order_id and o.user_id = auth.uid()
    )
  );

create policy order_status_history_select_staff on orders.order_status_history
  for select to authenticated
  using (
    identity.has_permission('orders.read')
    and exists (
      select 1 from orders.orders o
      where o.id = order_status_history.order_id
        and identity.can_manage_branch(o.branch_id)
    )
  );

create policy order_events_select_staff on orders.order_events
  for select to authenticated
  using (
    identity.has_permission('orders.read')
    and exists (
      select 1 from orders.orders o
      where o.id = order_events.order_id
        and identity.can_manage_branch(o.branch_id)
    )
  );

-- status_transitions is a static lookup used by the staff UI.
create policy status_transitions_read on orders.status_transitions
  for select to authenticated
  using (identity.has_permission('orders.read'));

-- ---------------------------------------------------------------------------
-- inventory : never public, never customer-visible.
-- ---------------------------------------------------------------------------
create policy branch_stock_staff_read on inventory.branch_stock
  for select to authenticated
  using (identity.has_permission('inventory.read') and identity.can_manage_branch(branch_id));

create policy stock_movements_staff_read on inventory.stock_movements
  for select to authenticated
  using (identity.has_permission('inventory.read') and identity.can_manage_branch(branch_id));

-- No INSERT/UPDATE/DELETE policy: movements are appended only by
-- orders.place_order(), orders.cancel_order() and inventory.adjust_stock().

-- ---------------------------------------------------------------------------
-- payments
-- ---------------------------------------------------------------------------
create policy payment_methods_public_read on payments.payment_methods
  for select to anon, authenticated
  using (is_active);

create policy payment_methods_admin_write on payments.payment_methods
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

create policy payment_attempts_select_own on payments.payment_attempts
  for select to authenticated
  using (
    exists (
      select 1 from orders.orders o
      where o.id = payment_attempts.order_id and o.user_id = auth.uid()
    )
  );

create policy payment_attempts_select_staff on payments.payment_attempts
  for select to authenticated
  using (
    identity.has_permission('payments.read')
    and exists (
      select 1 from orders.orders o
      where o.id = payment_attempts.order_id
        and identity.can_manage_branch(o.branch_id)
    )
  );

create policy payment_tx_select_own on payments.payment_transactions
  for select to authenticated
  using (
    exists (
      select 1 from orders.orders o
      where o.id = payment_transactions.order_id and o.user_id = auth.uid()
    )
  );

create policy payment_tx_select_staff on payments.payment_transactions
  for select to authenticated
  using (
    identity.has_permission('payments.read')
    and exists (
      select 1 from orders.orders o
      where o.id = payment_transactions.order_id
        and identity.can_manage_branch(o.branch_id)
    )
  );

-- No client INSERT/UPDATE policy: a customer can never mark a payment paid
-- (acceptance test 25, enforced further by the trigger in 013).