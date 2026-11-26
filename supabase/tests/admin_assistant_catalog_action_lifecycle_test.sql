-- Rollback-only end-to-end checks for assistant catalog/coupon approvals.
-- This test uses a dedicated staff identity and never sends messages or uses
-- customer data. It requires migration 276 to be applied to the test DB.
begin;

insert into auth.users (id, email)
values ('97f20000-0000-4000-8000-000000000016', 'assistant-action-lifecycle@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values ('97f30000-0000-4000-8000-000000000016', '97f20000-0000-4000-8000-000000000016', 'active', 'Assistant Action Test', 'assistant-action-lifecycle@test.local');

insert into identity.roles (code, name_ar, name_en, is_system)
values ('assistant_action_lifecycle_test', 'اختبار دورة إجراءات المساعد', 'Assistant Action Lifecycle Test', false);

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97f30000-0000-4000-8000-000000000016', id, null
from identity.roles where code = 'assistant_action_lifecycle_test';

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
from identity.roles r
join identity.permissions p on p.code in (
  'catalog.category.write', 'catalog.product.write', 'settings.write'
)
where r.code = 'assistant_action_lifecycle_test'
on conflict do nothing;

create temporary table assistant_action_test_expiry_token (preview_id uuid primary key) on commit drop;
grant select, insert on assistant_action_test_expiry_token to authenticated;

create function pg_temp.assistant_test_audit_exists(p_actor uuid, p_action text, p_entity uuid)
returns boolean language sql security definer set search_path = ''
as $$ select exists (
  select 1 from identity.audit_log
   where actor_user_id = p_actor and action = p_action and entity_id = p_entity
) $$;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000016","role":"authenticated","aud":"authenticated"}', true);

do $$
declare
  v_preview jsonb;
  v_result jsonb;
  v_replay jsonb;
  v_category_id uuid;
  v_product_id uuid;
  v_coupon_id uuid;
  v_preview_id uuid;
  v_count integer;
  v_price numeric;
  v_active boolean;
begin
  -- Create a category, verify the committed result/audit, then replay the
  -- same approval token and prove it did not create a duplicate row.
  v_preview := public.admin_assistant_prepare_category(null, jsonb_build_object(
    'name_ar', 'تصنيف اختبار المساعد 276',
    'name_en', 'Assistant Test Category 276',
    'description_ar', 'تصنيف مؤقت للاختبار',
    'description_en', 'Temporary test category'
  ));
  if v_preview->'old_values' is distinct from 'null'::jsonb then
    raise exception 'FAIL: create-category preview should have no old row: %', v_preview;
  end if;
  v_preview_id := (v_preview->>'preview_id')::uuid;
  v_result := public.admin_assistant_execute_catalog_action(v_preview_id);
  v_category_id := (v_result->>'id')::uuid;
  if v_category_id is null or v_result->>'action_type' <> 'catalog.category.save'
     or not exists (select 1 from catalog.categories where id = v_category_id and name_en = 'Assistant Test Category 276') then
    raise exception 'FAIL: category create did not persist the reviewed values: %', v_result;
  end if;
  if not pg_temp.assistant_test_audit_exists(auth.uid(), 'catalog.category.create', v_category_id) then
    raise exception 'FAIL: category creation was not audited';
  end if;
  v_replay := public.admin_assistant_execute_catalog_action(v_preview_id);
  if v_replay->>'id' <> v_category_id::text or v_replay->>'action_type' <> 'catalog.category.save' then
    raise exception 'FAIL: idempotent category replay returned a different result: %', v_replay;
  end if;
  select count(*) into v_count from catalog.categories where name_en = 'Assistant Test Category 276';
  if v_count <> 1 then raise exception 'FAIL: replay duplicated category rows: %', v_count; end if;

  -- Product creation delegates to the existing product RPC and records an
  -- assistant audit event. Then force a conflicting product price after a
  -- second preview and assert that the stale approval is rejected atomically.
  v_preview := public.admin_assistant_prepare_product(null, jsonb_build_object(
    'name_ar', 'منتج اختبار المساعد 276',
    'name_en', 'Assistant Test Product 276',
    'sku', 'AI-ACTION-276-PRODUCT',
    'slug', 'assistant-test-product-276',
    'base_price', 12.50,
    'category_id', v_category_id,
    'is_active', true,
    'is_featured', false,
    'allergens', jsonb_build_array()
  ));
  v_result := public.admin_assistant_execute_catalog_action((v_preview->>'preview_id')::uuid);
  v_product_id := (v_result->>'id')::uuid;
  if v_product_id is null or v_result->>'action_type' <> 'catalog.product.save'
     or not exists (select 1 from catalog.products where id = v_product_id and base_price = 12.50) then
    raise exception 'FAIL: product create did not persist the reviewed values: %', v_result;
  end if;
  if not pg_temp.assistant_test_audit_exists(auth.uid(), 'catalog.product.create', v_product_id) then
    raise exception 'FAIL: product creation was not audited';
  end if;

  v_preview := public.admin_assistant_prepare_product(v_product_id, jsonb_build_object(
    'name_ar', 'منتج اختبار المساعد 276',
    'name_en', 'Assistant Test Product 276',
    'sku', 'AI-ACTION-276-PRODUCT',
    'slug', 'assistant-test-product-276',
    'base_price', 13.00,
    'category_id', v_category_id,
    'is_active', true,
    'is_featured', false,
    'allergens', jsonb_build_array()
  ));
  -- Simulate a legitimate concurrent edit using the existing authorized RPC.
  perform public.admin_save_product(
    p_product_id => v_product_id,
    p_name_ar => 'منتج اختبار المساعد 276',
    p_name_en => 'Assistant Test Product 276',
    p_description_ar => null,
    p_description_en => null,
    p_sku => 'AI-ACTION-276-PRODUCT',
    p_slug => 'assistant-test-product-276',
    p_base_price => 14.00,
    p_compare_at_price => null,
    p_category_id => v_category_id,
    p_image_url => null,
    p_is_featured => false,
    p_is_active => true,
    p_prep_minutes => null,
    p_discount_percentage => null,
    p_discount_starts_at => null,
    p_discount_ends_at => null,
    p_calories => null,
    p_allergens => null,
    p_stock_quantity => null,
    p_branch_id => null
  );
  begin
    perform public.admin_assistant_execute_catalog_action((v_preview->>'preview_id')::uuid);
    raise exception 'FAIL: stale product preview executed';
  exception when sqlstate '40001' then
    null;
  end;
  select base_price into v_price from catalog.products where id = v_product_id;
  if v_price <> 14.00 then raise exception 'FAIL: stale approval overwrote concurrent price: %', v_price; end if;

  -- New coupons are forced to drafts. Activation has its own preview; changes
  -- made after that preview invalidate it, and an expired token cannot run.
  v_preview := public.admin_assistant_prepare_coupon(jsonb_build_object(
    'code', 'AI-ACTION-276',
    'title_ar', 'كوبون اختبار المساعد',
    'title_en', 'Assistant Test Coupon',
    'discount_type', 'percentage',
    'discount_value', 10,
    'max_discount', 20,
    'min_order_amount', 0,
    'applies_to', 'all',
    'category_ids', jsonb_build_array(),
    'product_ids', jsonb_build_array(),
    'per_user_limit', 1,
    'is_active', true
  ));
  v_result := public.admin_assistant_execute_catalog_action((v_preview->>'preview_id')::uuid);
  v_coupon_id := (v_result->>'id')::uuid;
  select is_active into v_active from marketing.coupons where id = v_coupon_id;
  if v_coupon_id is null or v_active is distinct from false then
    raise exception 'FAIL: assistant coupon create was not saved as an inactive draft: %', v_result;
  end if;
  if not pg_temp.assistant_test_audit_exists(auth.uid(), 'marketing.coupon.create', v_coupon_id) then
    raise exception 'FAIL: coupon creation was not audited';
  end if;

  v_preview := public.admin_assistant_prepare_coupon_activation(v_coupon_id, true);
  if (v_preview->'old_values'->'coupon'->>'is_active')::boolean is distinct from false then
    raise exception 'FAIL: coupon activation preview did not show the current inactive state: %', v_preview;
  end if;
  v_preview_id := (v_preview->>'preview_id')::uuid;
  update marketing.coupons set description_en = 'Concurrent edit' where id = v_coupon_id;
  begin
    perform public.admin_assistant_execute_catalog_action(v_preview_id);
    raise exception 'FAIL: stale coupon activation preview executed';
  exception when sqlstate '40001' then
    null;
  end;
  select is_active into v_active from marketing.coupons where id = v_coupon_id;
  if v_active is distinct from false then raise exception 'FAIL: stale coupon preview activated a coupon'; end if;

  v_preview := public.admin_assistant_prepare_coupon_activation(v_coupon_id, true);
  v_result := public.admin_assistant_execute_catalog_action((v_preview->>'preview_id')::uuid);
  select is_active into v_active from marketing.coupons where id = v_coupon_id;
  if v_active is distinct from true or v_result->>'action_type' <> 'marketing.coupon.activate' then
    raise exception 'FAIL: refreshed coupon activation did not run: %, active=%', v_result, v_active;
  end if;
  if not pg_temp.assistant_test_audit_exists(auth.uid(), 'marketing.coupon.activate', v_coupon_id) then
    raise exception 'FAIL: coupon activation was not audited';
  end if;

  v_preview := public.admin_assistant_prepare_coupon_activation(v_coupon_id, false);
  v_preview_id := (v_preview->>'preview_id')::uuid;
  insert into pg_temp.assistant_action_test_expiry_token values (v_preview_id);
end $$;

-- Expire the server-side token as the privileged test runner, then switch back
-- to the same authenticated identity before checking that execution is denied.
reset role;
update _ops.admin_assistant_action_previews
   set expires_at = now() - interval '1 second'
 where id = (select preview_id from pg_temp.assistant_action_test_expiry_token);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000016","role":"authenticated","aud":"authenticated"}', true);
do $$
declare v_active boolean; v_coupon_id uuid; v_preview_id uuid;
begin
  select preview_id into v_preview_id from pg_temp.assistant_action_test_expiry_token;
  select id into v_coupon_id from marketing.coupons where code = 'AI-ACTION-276';
  begin
    perform public.admin_assistant_execute_catalog_action(v_preview_id);
    raise exception 'FAIL: expired coupon approval executed';
  exception when sqlstate '40001' then
    null;
  end;
  select is_active into v_active from marketing.coupons where id = v_coupon_id;
  if v_active is distinct from true then raise exception 'FAIL: expired approval changed coupon state'; end if;
end $$;

rollback;
