-- 020_rls_02_core_catalog.sql
-- Policies for core and catalog.
--
-- Public catalogue data is readable by anon (the app must render the menu
-- before anyone logs in). Everything writable requires a permission.
-- Branch-scoped writes additionally require identity.can_manage_branch (D1).

-- ---------------------------------------------------------------------------
-- core.branches: public read of active branches. This is what the customer
-- picker reads to choose a branch.
-- ---------------------------------------------------------------------------
create policy branches_public_read on core.branches
  for select to anon, authenticated
  using (is_active);

create policy branches_staff_read on core.branches
  for select to authenticated
  using (identity.is_staff());

create policy branches_admin_write on core.branches
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

-- ---------------------------------------------------------------------------
create policy brands_public_read on core.brands
  for select to anon, authenticated
  using (true);

create policy brands_admin_write on core.brands
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

create policy zones_public_read on core.delivery_zones
  for select to anon, authenticated
  using (is_active);

create policy zones_admin_write on core.delivery_zones
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

create policy zone_branches_public_read on core.delivery_zone_branches
  for select to anon, authenticated
  using (true);

create policy zone_branches_admin_write on core.delivery_zone_branches
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

-- ---------------------------------------------------------------------------
-- app_settings: only is_public rows reach the client.
-- ---------------------------------------------------------------------------
create policy settings_public_read on core.app_settings
  for select to anon, authenticated
  using (is_public);

create policy settings_admin_write on core.app_settings
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

-- ---------------------------------------------------------------------------
-- Editorial content
-- ---------------------------------------------------------------------------
create policy legal_public_read on core.legal_documents
  for select to anon, authenticated
  using (is_published);

create policy legal_admin_write on core.legal_documents
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

create policy faq_public_read on core.faq_items
  for select to anon, authenticated
  using (is_active);

create policy faq_admin_write on core.faq_items
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

create policy onboarding_public_read on core.onboarding_slides
  for select to anon, authenticated
  using (is_active);

create policy onboarding_admin_write on core.onboarding_slides
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

-- ---------------------------------------------------------------------------
-- catalog: public read of live rows, permission-gated writes.
-- ---------------------------------------------------------------------------
create policy categories_public_read on catalog.categories
  for select to anon, authenticated
  using (is_active);

create policy categories_admin_write on catalog.categories
  for all to authenticated
  using (identity.has_permission('catalog.category.write'))
  with check (identity.has_permission('catalog.category.write'));

create policy products_public_read on catalog.products
  for select to anon, authenticated
  using (is_active and archived_at is null);

create policy products_staff_read_all on catalog.products
  for select to authenticated
  using (identity.has_permission('catalog.product.write'));

create policy products_admin_write on catalog.products
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create policy product_images_public_read on catalog.product_images
  for select to anon, authenticated
  using (true);

create policy product_images_admin_write on catalog.product_images
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create policy option_groups_public_read on catalog.option_groups
  for select to anon, authenticated
  using (is_active);

create policy option_groups_admin_write on catalog.option_groups
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create policy option_values_public_read on catalog.option_values
  for select to anon, authenticated
  using (is_active);

create policy option_values_admin_write on catalog.option_values
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create policy product_option_groups_public_read on catalog.product_option_groups
  for select to anon, authenticated
  using (true);

create policy product_option_groups_admin_write on catalog.product_option_groups
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create policy product_aliases_public_read on catalog.product_aliases
  for select to anon, authenticated
  using (true);

create policy product_aliases_admin_write on catalog.product_aliases
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create policy category_aliases_public_read on catalog.category_aliases
  for select to anon, authenticated
  using (true);

create policy category_aliases_admin_write on catalog.category_aliases
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

-- Search documents are internal projections of the rows above.
create policy product_search_read on catalog.product_search
  for select to anon, authenticated
  using (true);

create policy category_search_read on catalog.category_search
  for select to anon, authenticated
  using (true);

create policy bundles_public_read on catalog.bundles
  for select to anon, authenticated
  using (is_active);

create policy bundles_admin_write on catalog.bundles
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create policy bundle_items_public_read on catalog.bundle_items
  for select to anon, authenticated
  using (true);

create policy bundle_items_admin_write on catalog.bundle_items
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

-- ---------------------------------------------------------------------------
-- branch_product_pricing (D1): public read so the app can show branch prices,
-- but writes are restricted to staff who actually manage that branch.
-- ---------------------------------------------------------------------------
create policy bpp_public_read on catalog.branch_product_pricing
  for select to anon, authenticated
  using (true);

create policy bpp_admin_write on catalog.branch_product_pricing
  for all to authenticated
  using (identity.has_permission('catalog.product.write') and identity.can_manage_branch(branch_id))
  with check (identity.has_permission('catalog.product.write') and identity.can_manage_branch(branch_id));