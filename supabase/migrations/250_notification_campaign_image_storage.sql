-- Campaign images belong to notifications, not the catalogue. Keep their
-- storage permissions separate so a notification sender can upload a campaign
-- image without gaining permission to write products.

drop policy if exists "product_images_staff_insert" on storage.objects;
create policy "product_images_staff_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in (
      'subscription-plans', 'banners', 'notifications'
    )
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
    and (storage.foldername(name))[2] not in (
      'subscription-plans', 'banners', 'notifications'
    )
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in (
      'subscription-plans', 'banners', 'notifications'
    )
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
    and (storage.foldername(name))[2] not in (
      'subscription-plans', 'banners', 'notifications'
    )
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists notification_campaign_images_insert on storage.objects;
create policy notification_campaign_images_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'notifications'
    and identity.has_permission('notifications.send')
  );

drop policy if exists notification_campaign_images_update on storage.objects;
create policy notification_campaign_images_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'notifications'
    and identity.has_permission('notifications.send')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'notifications'
    and identity.has_permission('notifications.send')
  );

drop policy if exists notification_campaign_images_delete on storage.objects;
create policy notification_campaign_images_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'notifications'
    and identity.has_permission('notifications.send')
  );
