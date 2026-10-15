-- 022_rls_04_loyalty_marketing_engagement.sql
-- Policies for loyalty, marketing and engagement.

-- ---------------------------------------------------------------------------
-- loyalty : D9. A customer reads and writes ONLY their own account and
-- ledger. Rules and rewards are public reference data (the app shows them).
-- Balances are changed exclusively by loyalty.apply_points() -- there is no
-- UPDATE policy on loyalty_accounts.
-- ---------------------------------------------------------------------------
create policy loyalty_accounts_select_own on loyalty.loyalty_accounts
  for select to authenticated
  using (user_id = auth.uid());

create policy loyalty_accounts_staff_read on loyalty.loyalty_accounts
  for select to authenticated
  using (identity.has_permission('loyalty.read'));

create policy loyalty_tx_select_own on loyalty.loyalty_transactions
  for select to authenticated
  using (user_id = auth.uid());

create policy loyalty_tx_staff_read on loyalty.loyalty_transactions
  for select to authenticated
  using (identity.has_permission('loyalty.read'));

create policy loyalty_rules_public_read on loyalty.loyalty_rules
  for select to anon, authenticated
  using (is_active);

create policy loyalty_rules_admin_write on loyalty.loyalty_rules
  for all to authenticated
  using (identity.has_permission('loyalty.write'))
  with check (identity.has_permission('loyalty.write'));

create policy loyalty_rewards_public_read on loyalty.loyalty_rewards
  for select to anon, authenticated
  using (is_active);

create policy loyalty_rewards_admin_write on loyalty.loyalty_rewards
  for all to authenticated
  using (identity.has_permission('loyalty.write'))
  with check (identity.has_permission('loyalty.write'));

-- ---------------------------------------------------------------------------
-- marketing
-- ---------------------------------------------------------------------------
create policy banners_public_read on marketing.banners
  for select to anon, authenticated
  using (is_published);

create policy banners_admin_write on marketing.banners
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

-- Coupon codes are readable by anyone (the app shows a promo banner), but a
-- customer still cannot forge a redemption: those rows have no INSERT policy.
create policy coupons_public_read on marketing.coupons
  for select to anon, authenticated
  using (is_active);

create policy coupons_admin_write on marketing.coupons
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

create policy coupons_categories_public_read on marketing.coupons_categories
  for select to anon, authenticated
  using (true);

create policy coupons_categories_admin_write on marketing.coupons_categories
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

create policy coupon_redemptions_select_own on marketing.coupon_redemptions
  for select to authenticated
  using (user_id = auth.uid());

create policy coupon_redemptions_select_staff on marketing.coupon_redemptions
  for select to authenticated
  using (identity.has_permission('orders.read'));

-- ---------------------------------------------------------------------------
-- engagement
-- ---------------------------------------------------------------------------
create policy reviews_public_read on engagement.product_reviews
  for select to anon, authenticated
  using (is_published);

create policy reviews_insert_own on engagement.product_reviews
  for insert to authenticated
  with check (user_id = auth.uid());

create policy reviews_update_own on engagement.product_reviews
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy reviews_delete_own on engagement.product_reviews
  for delete to authenticated
  using (user_id = auth.uid());

create policy reviews_staff_moderate on engagement.product_reviews
  for update to authenticated
  using (identity.has_permission('reviews.moderate'))
  with check (identity.has_permission('reviews.moderate'));

-- Notifications: owner only, and NO insert policy. Rows are created by
-- database triggers on order status changes, never by the client.
create policy notifications_select_own on engagement.notifications
  for select to authenticated
  using (user_id = auth.uid());

create policy notifications_update_own on engagement.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy notifications_staff_read on engagement.notifications
  for select to authenticated
  using (identity.has_permission('notifications.read'));

create policy notification_prefs_all_own on engagement.notification_preferences
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy device_tokens_all_own on engagement.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());