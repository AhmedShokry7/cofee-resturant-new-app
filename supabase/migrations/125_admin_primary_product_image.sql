-- 125_admin_primary_product_image.sql
--
-- The picture of a product follows its primary picture.
--
-- The dashboard writes the pictures of a product in catalog.product_images and
-- keeps the picture of the product itself (catalog.products.image_url) in
-- step, because the cards, the lists and the details of the storefront read
-- that single column.
--
-- The dashboard cannot write that column itself: PostgREST exposes the
-- catalogue through public.products, and that view joins the products with
-- their category, so it is not automatically updatable
-- ("cannot update view products"). The write therefore belongs to the
-- database, where it is also atomic with the change of the primary picture.
--
-- Two pieces:
--   1. A trigger that keeps catalog.products.image_url in step with the
--      primary picture of the product, for every path (add, replace, set as
--      primary, delete).
--   2. public.admin_set_primary_product_image(), which moves the primary
--      picture in one transaction, so the product is never left with two
--      primary pictures or with none.
--
-- Idempotent: safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. The trigger that keeps the picture of the product in step.
-- ---------------------------------------------------------------------------
create or replace function catalog.sync_product_image_url()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_product uuid;
  v_url text;
begin
  if tg_op = 'DELETE' then
    v_product := old.product_id;
  else
    v_product := new.product_id;
  end if;

  select pi.image_url into v_url
    from catalog.product_images pi
   where pi.product_id = v_product
     and pi.is_primary
   order by pi.sort_order
   limit 1;

  update catalog.products p
     set image_url = v_url,
         updated_at = now()
   where p.id = v_product
     and p.image_url is distinct from v_url;

  return coalesce(new, old);
end;
$fn$;

comment on function catalog.sync_product_image_url() is
  'Keeps catalog.products.image_url in step with the primary picture of the product.';

drop trigger if exists tr_product_images_sync_product on catalog.product_images;
create trigger tr_product_images_sync_product
  after insert or update of is_primary or delete on catalog.product_images
  for each row
  execute function catalog.sync_product_image_url();

-- ---------------------------------------------------------------------------
-- 2. Moving the primary picture, in one transaction.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_primary_product_image(
  p_product_id uuid,
  p_image_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_url text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.product.write') then
    raise exception 'missing permission: catalog.product.write' using errcode = '42501';
  end if;

  select pi.image_url into v_url
    from catalog.product_images pi
   where pi.id = p_image_id
     and pi.product_id = p_product_id;

  if v_url is null then
    raise exception 'the picture % does not belong to the product %',
      p_image_id, p_product_id
      using errcode = '22023';
  end if;

  -- The old primary picture is released first, because the database allows
  -- only one primary picture per product.
  update catalog.product_images pi
     set is_primary = false
   where pi.product_id = p_product_id
     and pi.is_primary
     and pi.id <> p_image_id;

  update catalog.product_images pi
     set is_primary = true
   where pi.id = p_image_id
     and pi.product_id = p_product_id;

  -- The trigger above brings the picture of the product in step.
  return jsonb_build_object(
    'product_id', p_product_id,
    'image_id', p_image_id,
    'image_url', v_url
  );
end;
$fn$;

comment on function public.admin_set_primary_product_image(uuid, uuid) is
  'Makes a picture of a product the primary one and keeps the picture of the product in step.';

revoke all on function public.admin_set_primary_product_image(uuid, uuid) from public;
revoke execute on function public.admin_set_primary_product_image(uuid, uuid) from anon;
grant execute on function public.admin_set_primary_product_image(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
