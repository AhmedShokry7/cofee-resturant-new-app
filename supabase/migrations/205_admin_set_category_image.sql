-- 205_admin_set_category_image.sql
--
-- Closes the live failure the owner reported on 2026-10-28: uploading a picture
-- for a category answered `permission denied for function
-- rebuild_category_search (42501)`.
--
-- Why it happens, verified against webzzasosevzymftgszn:
--   * The admin app wrote the row directly:
--     `update public.categories set image_url = …` as the `authenticated` role.
--   * `catalog.categories` carries `tr_categories_search`, whose function
--     `catalog.trg_category_search()` is SECURITY INVOKER and performs
--     `catalog.rebuild_category_search(coalesce(new.id, old.id))`.
--   * Live ACL of that function is `{postgres=X/postgres, service_role=X/postgres}`:
--     `081_harden_function_and_view_grants.sql:31` revoked EXECUTE from
--     `authenticated`, and although `083_restore_client_function_execute_grants.sql:176`
--     granted it back (and 083 is in the ledger), the grant is not live — the
--     function was recreated after it. So the write reaches the trigger and dies
--     in the trigger, even though RLS let the row through.
--   * The product path does not fail for the same reason because its image trigger
--     `catalog.sync_product_image_url()` is SECURITY DEFINER, so the row write —
--     and therefore the search rebuild — already runs as the function owner.
--
-- The fix follows that same shape instead of reopening 081. Granting EXECUTE on
-- the rebuild functions back to `authenticated` would hand every signed-in
-- customer — customers are `authenticated` too — a security-definer write against
-- `catalog.category_search`/`catalog.product_search` for any uuid they choose,
-- which is exactly the surface 081 closed. So the write moves behind
-- `admin_set_category_image`, a security-definer entry point guarded by
-- `identity.is_staff()` and `catalog.category.write`, mirroring
-- `admin_set_category_active` (194) for the guards and `admin_set_branch_image`
-- (198) for the URL validation and the audit payload. Inside it the trigger runs
-- as the owner, so no client grant is needed and 081 stays honoured.

create or replace function public.admin_set_category_image(
  p_category_id uuid,
  p_image_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_url text := nullif(btrim(coalesce(p_image_url, '')), '');
  v_old text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.category.write') then
    raise exception 'missing permission: catalog.category.write' using errcode = '42501';
  end if;

  select c.image_url into v_old
    from catalog.categories c
   where c.id = p_category_id;
  if v_old is null and not exists (select 1 from catalog.categories c where c.id = p_category_id) then
    raise exception 'unknown category' using errcode = '22023';
  end if;

  if v_url is not null and v_url !~* '^https?://' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_url');
  end if;

  update catalog.categories
     set image_url = v_url,
         updated_at = now()
   where id = p_category_id;

  perform identity.audit(
    'catalog.category.image',
    'category',
    p_category_id,
    jsonb_build_object('image_url', v_old),
    jsonb_build_object('image_url', v_url)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_category_image(uuid, text) is
  'Record or clear the picture URL of a category for the admin dashboard. '
  'Security definer so the search rebuild trigger runs as the owner: the client '
  'needs no EXECUTE on catalog.rebuild_category_search. Audits the replaced URL.';

revoke all on function public.admin_set_category_image(uuid, text) from public, anon;
grant execute on function public.admin_set_category_image(uuid, text) to authenticated;
grant execute on function public.admin_set_category_image(uuid, text) to service_role;

notify pgrst, 'reload schema';
