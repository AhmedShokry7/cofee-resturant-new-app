-- Rollback-only permission split regression for assistant product, category,
-- and coupon previews. This user can read coupon reports but has no write
-- permissions and receives no branch or product fixtures.
begin;

insert into auth.users (id, email)
values ('97f20000-0000-4000-8000-000000000006', 'assistant-catalog-reader@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values ('97f30000-0000-4000-8000-000000000006', '97f20000-0000-4000-8000-000000000006', 'active', 'Assistant Catalog Reader', 'assistant-catalog-reader@test.local');

insert into identity.roles (code, name_ar, name_en, is_system)
values ('assistant_catalog_reader_test', 'قارئ كتالوج مساعد', 'Assistant Catalog Reader', false);

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97f30000-0000-4000-8000-000000000006', id, null
from identity.roles where code = 'assistant_catalog_reader_test';

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
from identity.roles r
join identity.permissions p on p.code = 'coupons.read'
where r.code = 'assistant_catalog_reader_test'
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$ begin
  if not identity.has_permission('coupons.read') then
    raise exception 'FAIL: read-only test permission was not assigned';
  end if;
  if identity.has_permission('settings.write')
     or identity.has_permission('catalog.product.write')
     or identity.has_permission('catalog.category.write') then
    raise exception 'FAIL: read-only user unexpectedly received a write permission';
  end if;
  begin
    perform public.admin_assistant_prepare_coupon('{}'::jsonb);
    raise exception 'FAIL: coupons.read could prepare coupon changes';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
  begin
    perform public.admin_assistant_prepare_product(null, '{"name_ar":"اختبار","base_price":1}'::jsonb, null);
    raise exception 'FAIL: read-only user could prepare product changes';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
  begin
    perform public.admin_assistant_prepare_category(null, '{"name_ar":"اختبار","name_en":"Test"}'::jsonb);
    raise exception 'FAIL: read-only user could prepare category changes';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

rollback;
