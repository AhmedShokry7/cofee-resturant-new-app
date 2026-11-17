-- Category and banner image paths have feature-specific permissions. The
-- product-images bucket's generic catalogue policy must not let product
-- writers bypass those owners' checks, nor block those owners from uploading.
-- This migration is prepared for deployment, not applied here.

drop policy if exists "product_images_staff_insert" on storage.objects;
create policy "product_images_staff_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_update" on storage.objects;
create policy "product_images_staff_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_delete" on storage.objects;
create policy "product_images_staff_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists category_images_staff_insert on storage.objects;
create policy category_images_staff_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  );

drop policy if exists category_images_staff_update on storage.objects;
create policy category_images_staff_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  );

drop policy if exists category_images_staff_delete on storage.objects;
create policy category_images_staff_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  );

drop policy if exists banner_images_staff_insert on storage.objects;
create policy banner_images_staff_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  );

drop policy if exists banner_images_staff_update on storage.objects;
create policy banner_images_staff_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  );

drop policy if exists banner_images_staff_delete on storage.objects;
create policy banner_images_staff_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  );
