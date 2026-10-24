-- 124_product_images_storage.sql
--
-- The bucket that holds the pictures of the products.
--
-- The dashboard writes the pictures of a product to storage and keeps the
-- public url of every picture in catalog.product_images. The url is public
-- because the storefront shows the picture of a product to every visitor,
-- but only the staff that may write products can upload, replace or remove
-- a file.
--
-- The pictures live under their own folder:
--     products/<product_id>/<file name>
-- so the policies of the bucket can be scoped to the pictures of the
-- catalogue and never reach the avatars of the customers.
--
-- Idempotent: safe to re-run.

-- ---------------------------------------------------------------------------
-- Bucket
-- ---------------------------------------------------------------------------
-- 5 MiB and three formats are the same limits the avatars bucket uses.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

update storage.buckets
   set public = true,
       file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'product-images';

-- ---------------------------------------------------------------------------
-- Object policies.
--
-- Reading is public: the picture of a product is shown to every visitor of
-- the storefront, exactly like the url that catalog.product_images holds.
--
-- Writing needs the same permission the dashboard needs to write a product,
-- and it only reaches the folders of the catalogue.
-- ---------------------------------------------------------------------------
drop policy if exists "product_images_public_read" on storage.objects;
create policy "product_images_public_read"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'product-images');

drop policy if exists "product_images_staff_insert" on storage.objects;
create policy "product_images_staff_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_update" on storage.objects;
create policy "product_images_staff_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and identity.has_permission('catalog.product.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_delete" on storage.objects;
create policy "product_images_staff_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and identity.has_permission('catalog.product.write')
  );

notify pgrst, 'reload schema';
