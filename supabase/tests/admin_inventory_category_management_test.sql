-- admin_inventory_category_management_test.sql
-- Run only against an isolated, non-production database after migration 266.
-- Run this full file only after migration 266 on an isolated, non-production DB.
-- It uses SET ROLE/JWT claims supported by Supabase SQL Editor and psql.
-- Every fixture and mutation is rolled back at the end.
begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('7a100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'ICAT-TEST', 'فرع اختبار التصنيفات', 'Category Test Branch', 'test', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('7a200000-0000-4000-8000-000000000001', 'inventory-category-owner@test.local'),
  ('7a200000-0000-4000-8000-000000000002', 'inventory-category-branch@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('7a300000-0000-4000-8000-000000000001', '7a200000-0000-4000-8000-000000000001', 'active', 'Inventory Test Owner', 'inventory-category-owner@test.local'),
  ('7a300000-0000-4000-8000-000000000002', '7a200000-0000-4000-8000-000000000002', 'active', 'Inventory Branch Manager', 'inventory-category-branch@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '7a300000-0000-4000-8000-000000000001', r.id, null
  from identity.roles r where r.code = 'owner';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '7a300000-0000-4000-8000-000000000002', r.id,
       '7a100000-0000-4000-8000-000000000001'::uuid
  from identity.roles r where r.code = 'branch_manager';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"7a200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_create_inventory_category('Test beans');
  if v->>'ok' <> 'true' then raise exception 'FAIL create category: %', v; end if;
  v := public.admin_create_inventory_category(' test beans ');
  if v->>'reason' <> 'duplicate_name' then raise exception 'FAIL duplicate category guard: %', v; end if;
  v := public.admin_create_inventory_category('   ');
  if v->>'reason' <> 'invalid_name' then raise exception 'FAIL blank category guard: %', v; end if;

  v := public.admin_create_inventory_category('Test dairy');
  if v->>'ok' <> 'true' then raise exception 'FAIL create reassignment category: %', v; end if;
  v := public.admin_create_inventory_category('Test empty');
  if v->>'ok' <> 'true' then raise exception 'FAIL create empty category: %', v; end if;
end $$;

reset role;

insert into inventory.raw_materials
  (id, name_ar, name_en, category, unit, unit_cost, reorder_level)
values
  ('7a400000-0000-4000-8000-000000000001', 'حبوب اختبار', 'Test beans material', 'Test beans', 'kg', 5, 1),
  ('7a400000-0000-4000-8000-000000000002', 'مادة اختبار فارغة', 'Empty category material', 'Test empty', 'piece', 1, 0);

insert into inventory.raw_material_stock (branch_id, material_id, quantity_on_hand)
values ('7a100000-0000-4000-8000-000000000001', '7a400000-0000-4000-8000-000000000001', 4);

insert into inventory.raw_material_movements
  (branch_id, material_id, movement_type, quantity_delta, balance_after, unit_cost)
values ('7a100000-0000-4000-8000-000000000001', '7a400000-0000-4000-8000-000000000001', 'receipt', 4, 4, 5);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"7a200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  -- Material rows and the stock/movement ledger remain intact through changes.
  v := public.admin_inventory_filters();
  if not exists (
    select 1 from jsonb_array_elements(v->'categories') c
     where c->>'value' = 'Test beans' and (c->>'count')::integer = 1
  ) then raise exception 'FAIL managed category filter/count: %', v; end if;
  v := public.admin_create_inventory_category(' ' || repeat('x', 81));
  if v->>'reason' <> 'invalid_name' then raise exception 'FAIL long category guard: %', v; end if;
  v := public.admin_rename_inventory_category('Test beans', 'Test dairy');
  if v->>'reason' <> 'duplicate_name' then raise exception 'FAIL rename duplicate guard: %', v; end if;
  v := public.admin_delete_inventory_category('Test beans', 'Missing target');
  if v->>'reason' <> 'invalid_target' then raise exception 'FAIL invalid reassignment guard: %', v; end if;

  v := public.admin_rename_inventory_category('Test beans', 'Renamed beans');
  if v->>'ok' <> 'true' then raise exception 'FAIL rename category: %', v; end if;
  if not exists (select 1 from inventory.raw_materials where id = '7a400000-0000-4000-8000-000000000001' and category = 'Renamed beans') then
    raise exception 'FAIL rename did not update the linked material';
  end if;
  if not exists (select 1 from inventory.raw_material_stock where material_id = '7a400000-0000-4000-8000-000000000001' and quantity_on_hand = 4)
     or not exists (select 1 from inventory.raw_material_movements where material_id = '7a400000-0000-4000-8000-000000000001') then
    raise exception 'FAIL rename changed stock or movement history';
  end if;

  v := public.admin_delete_inventory_category('Renamed beans', 'Test dairy');
  if v->>'ok' <> 'true' then raise exception 'FAIL delete/reassign category: %', v; end if;
  if not exists (select 1 from inventory.raw_materials where id = '7a400000-0000-4000-8000-000000000001' and category = 'Test dairy') then
    raise exception 'FAIL delete did not reassign the linked material';
  end if;
  if not exists (select 1 from inventory.raw_material_stock where material_id = '7a400000-0000-4000-8000-000000000001' and quantity_on_hand = 4)
     or not exists (select 1 from inventory.raw_material_movements where material_id = '7a400000-0000-4000-8000-000000000001') then
    raise exception 'FAIL delete/reassign changed stock or movement history';
  end if;

  v := public.admin_delete_inventory_category('Test empty', null);
  if v->>'ok' <> 'true' then raise exception 'FAIL delete to uncategorised: %', v; end if;
  if not exists (select 1 from inventory.raw_materials where id = '7a400000-0000-4000-8000-000000000002' and category = '') then
    raise exception 'FAIL null reassignment did not preserve material as uncategorised';
  end if;

end $$;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"7a200000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_create_inventory_category('Branch scope forbidden');
    raise exception 'FAIL branch manager changed global category catalogue';
  exception when sqlstate '42501' then
    null;
  end;
end $$;

reset role;

-- Invalid free-text categories cannot bypass the managed catalogue trigger.
do $$
begin
  begin
    insert into inventory.raw_materials
      (name_ar, name_en, category, unit, unit_cost, reorder_level)
    values ('تصنيف غير معروف', 'Unknown category', 'Not managed', 'piece', 0, 0);
    raise exception 'FAIL unknown raw-material category was accepted';
  exception when check_violation then
    null;
  end;
end $$;

rollback;
