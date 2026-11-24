-- 266_admin_inventory_category_management.sql
-- Managed raw-material categories for Admin Inventory.
--
-- This is a migration candidate. Apply only after confirming the project ref,
-- reviewing the full SQL, and approving the rollout/rollback plan.

begin;

-- A staff principal may write the global material/category catalogue only
-- when its active roles include the all-branch inventory.adjust scope.
-- Branch managers can adjust stock in their assigned branches but cannot
-- change this global catalogue.
--
-- Category management is permission-checked through inventory.adjust plus
-- all-branch scope, matching admin_save_inventory_material(). No permission
-- assignment is widened by this migration. Historical category spellings are
-- consolidated by case and outer whitespace during backfill; see the rollout
-- risk note in DATABASE_SPEC.md.

create table if not exists inventory.raw_material_categories (
  category_name text primary key,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_raw_material_category_name_nonempty
    check (btrim(category_name) <> '')
);

create unique index if not exists uq_raw_material_categories_normalized
  on inventory.raw_material_categories (lower(btrim(category_name)));

create or replace function inventory.touch_raw_material_category()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

revoke all on function inventory.touch_raw_material_category()
  from public, anon, authenticated;

drop trigger if exists trg_touch_raw_material_category
  on inventory.raw_material_categories;
create trigger trg_touch_raw_material_category
before update on inventory.raw_material_categories
for each row execute function inventory.touch_raw_material_category();

comment on table inventory.raw_material_categories is
  'Managed names used by inventory.raw_materials.category. Category changes preserve material rows and inventory history.';

alter table inventory.raw_material_categories enable row level security;
revoke all on table inventory.raw_material_categories from anon, authenticated;

-- Preserve existing free-text categories while consolidating case/outer-space
-- variants to a deterministic spelling. This normalizes category labels only;
-- it does not delete materials or alter stock/movement records.
insert into inventory.raw_material_categories (category_name)
select min(btrim(m.category) collate "C")
  from inventory.raw_materials m
 where btrim(m.category) <> ''
 group by lower(btrim(m.category))
on conflict do nothing;

with canonical as (
  select min(btrim(m.category) collate "C") as category_name,
         lower(btrim(m.category)) as category_key
    from inventory.raw_materials m
   where btrim(m.category) <> ''
   group by lower(btrim(m.category))
)
update inventory.raw_materials m
   set category = c.category_name
  from canonical c
 where lower(btrim(m.category)) = c.category_key
   and m.category is distinct from c.category_name;

create or replace function inventory.validate_raw_material_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_name text;
begin
  new.category := btrim(coalesce(new.category, ''));
  if new.category = '' then
    return new;
  end if;

  select c.category_name
    into v_name
    from inventory.raw_material_categories c
   where lower(btrim(c.category_name)) = lower(new.category)
   for key share;
  if v_name is null then
    raise exception 'unknown raw material category'
      using errcode = '23514',
            constraint = 'ck_raw_material_category_exists';
  end if;
  new.category := v_name;
  return new;
end;
$fn$;

revoke all on function inventory.validate_raw_material_category()
  from public, anon, authenticated;

drop trigger if exists trg_validate_raw_material_category
  on inventory.raw_materials;
create trigger trg_validate_raw_material_category
before insert or update of category on inventory.raw_materials
for each row execute function inventory.validate_raw_material_category();

create or replace function public.admin_create_inventory_category(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_name text := btrim(coalesce(p_name, ''));
begin
  perform inventory.require_permission('inventory.adjust');
  if not identity.manages_all_branches() then
    raise exception 'inventory categories require all-branch access'
      using errcode = '42501';
  end if;
  if v_name = '' or char_length(v_name) > 80 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if exists (
    select 1 from inventory.raw_material_categories c
     where lower(btrim(c.category_name)) = lower(v_name)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_name');
  end if;

  insert into inventory.raw_material_categories (category_name, created_by)
  values (v_name, auth.uid());

  perform identity.audit(
    'stock.category.create', 'raw_material_category', null, null,
    jsonb_build_object('category_name', v_name)
  );
  return jsonb_build_object('ok', true);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_name');
end;
$fn$;

revoke all on function public.admin_create_inventory_category(text)
  from public, anon;
grant execute on function public.admin_create_inventory_category(text)
  to authenticated;

create or replace function public.admin_rename_inventory_category(
  p_current_name text,
  p_new_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old text := btrim(coalesce(p_current_name, ''));
  v_new text := btrim(coalesce(p_new_name, ''));
  v_count integer;
begin
  perform inventory.require_permission('inventory.adjust');
  if not identity.manages_all_branches() then
    raise exception 'inventory categories require all-branch access'
      using errcode = '42501';
  end if;
  if v_new = '' or char_length(v_new) > 80 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;

  select c.category_name into v_old
    from inventory.raw_material_categories c
   where lower(btrim(c.category_name)) = lower(v_old)
   for update;
  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if lower(v_old) = lower(v_new) and v_old = v_new then
    return jsonb_build_object('ok', true);
  end if;
  if v_old is distinct from v_new and exists (
    select 1 from inventory.raw_material_categories c
     where lower(btrim(c.category_name)) = lower(v_new)
       and c.category_name <> v_old
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_name');
  end if;

  select count(*)::integer into v_count
    from inventory.raw_materials m
   where m.category = v_old;

  update inventory.raw_material_categories
     set category_name = v_new, updated_at = now()
   where category_name = v_old;
  update inventory.raw_materials
     set category = v_new, updated_at = now()
   where category = v_old;

  perform identity.audit(
    'stock.category.rename', 'raw_material_category', null,
    jsonb_build_object('category_name', v_old, 'materials', v_count),
    jsonb_build_object('category_name', v_new, 'materials', v_count)
  );
  return jsonb_build_object('ok', true);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_name');
end;
$fn$;

revoke all on function public.admin_rename_inventory_category(text, text)
  from public, anon;
grant execute on function public.admin_rename_inventory_category(text, text)
  to authenticated;

create or replace function public.admin_delete_inventory_category(
  p_name text,
  p_reassign_to text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old text := btrim(coalesce(p_name, ''));
  v_target text := nullif(btrim(coalesce(p_reassign_to, '')), '');
  v_count integer;
begin
  perform inventory.require_permission('inventory.adjust');
  if not identity.manages_all_branches() then
    raise exception 'inventory categories require all-branch access'
      using errcode = '42501';
  end if;

  select c.category_name into v_old
    from inventory.raw_material_categories c
   where lower(btrim(c.category_name)) = lower(v_old)
   for update;
  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_target is not null then
    select c.category_name into v_target
      from inventory.raw_material_categories c
     where lower(btrim(c.category_name)) = lower(v_target);
    if v_target is null or v_target = v_old then
      return jsonb_build_object('ok', false, 'reason', 'invalid_target');
    end if;
  end if;

  select count(*)::integer into v_count
    from inventory.raw_materials m
   where m.category = v_old;

  -- Existing material records and their stock/movement history are retained.
  -- A null target deliberately moves the materials to the legacy uncategorised
  -- state; the UI requires the operator to choose that option explicitly.
  update inventory.raw_materials
     set category = coalesce(v_target, ''), updated_at = now()
   where category = v_old;
  delete from inventory.raw_material_categories
   where category_name = v_old;

  perform identity.audit(
    'stock.category.delete', 'raw_material_category', null,
    jsonb_build_object('category_name', v_old, 'materials', v_count),
    jsonb_build_object('reassigned_to', v_target, 'materials', v_count)
  );
  return jsonb_build_object('ok', true);
end;
$fn$;

revoke all on function public.admin_delete_inventory_category(text, text)
  from public, anon;
grant execute on function public.admin_delete_inventory_category(text, text)
  to authenticated;

-- Keep the existing filters response contract while sourcing categories from
-- the managed catalogue and counting currently assigned materials.
create or replace function public.admin_inventory_filters()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform inventory.require_permission('inventory.read');

  return jsonb_build_object(
    'branches', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', b.id,
                 'code', b.code,
                 'name_ar', b.name_ar,
                 'name_en', b.name_en,
                 'is_active', b.is_active
               )
               order by b.is_active desc, b.name_ar
             )
        from core.branches b
       where identity.can_manage_branch(b.id)
    ), '[]'::jsonb),
    'categories', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'value', c.category_name,
                 'count', coalesce(m.material_count, 0)
               ) order by c.category_name
             )
        from inventory.raw_material_categories c
        left join lateral (
          select count(*)::integer as material_count
            from inventory.raw_materials rm
           where rm.category = c.category_name
        ) m on true
    ), '[]'::jsonb)
  );
end;
$fn$;

revoke all on function public.admin_inventory_filters() from public, anon;
grant execute on function public.admin_inventory_filters() to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';

commit;
