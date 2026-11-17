-- Subscription plan images are customer-facing content, separate from app
-- design images. Reads and writes stay behind the subscriptions permission.
-- Apply 247_catalog_image_storage_permissions.sql after this migration; it
-- reasserts the generic product policy with category/banner/branch exclusions
-- and adds their dedicated writers.

create or replace function public.admin_subscription_plan_images()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'image_url', p.image_url))
      from subscriptions.plans p
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscription_plan_images() from public, anon;
grant execute on function public.admin_subscription_plan_images() to authenticated;

create or replace function public.admin_set_subscription_plan_image(
  p_plan_id uuid,
  p_image_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  update subscriptions.plans
     set image_url = nullif(btrim(coalesce(p_image_url, '')), '')
   where id = p_plan_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'id', p_plan_id);
end;
$fn$;

revoke all on function public.admin_set_subscription_plan_image(uuid, text) from public, anon;
grant execute on function public.admin_set_subscription_plan_image(uuid, text) to authenticated;

-- Replace the broad products-folder policies before adding feature-scoped
-- rules; PostgreSQL combines permissive storage policies with OR semantics.
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

drop policy if exists subscription_plan_images_staff_insert on storage.objects;
create policy subscription_plan_images_staff_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  );

drop policy if exists subscription_plan_images_staff_update on storage.objects;
create policy subscription_plan_images_staff_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  );

drop policy if exists subscription_plan_images_staff_delete on storage.objects;
create policy subscription_plan_images_staff_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  );
