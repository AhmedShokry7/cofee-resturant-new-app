-- Images uploaded by the visual editor live in product-images/design/.
-- Keep this namespace separate from catalogue assets: editing app design has
-- its own permission and must not implicitly grant product write access.
-- Idempotent; this migration is prepared for deployment, not applied here.

drop policy if exists "app_design_images_staff_insert" on storage.objects;
create policy "app_design_images_staff_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  );

drop policy if exists "app_design_images_staff_update" on storage.objects;
create policy "app_design_images_staff_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  );

drop policy if exists "app_design_images_staff_delete" on storage.objects;
create policy "app_design_images_staff_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  );
