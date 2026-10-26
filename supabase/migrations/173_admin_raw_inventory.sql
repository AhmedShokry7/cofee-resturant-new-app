-- 173_admin_raw_inventory.sql
-- Raw-material inventory for the café / restaurant back office.
--
-- 012 modelled the stock of sellable menu products (inventory.branch_stock and
-- inventory.stock_movements keyed by product_id). A kitchen is stocked with
-- ingredients: coffee beans, milk, cups, syrups. Those have their own unit of
-- measure, cost and reorder point, and they are not sellable products, so they
-- cannot live in the product stock tables without polluting catalogue counts.
--
-- This migration adds:
--   1. inventory.raw_materials        — the material master (name, SKU, unit,
--      unit cost, reorder level, category);
--   2. inventory.raw_material_stock   — quantity on hand per branch;
--   3. inventory.raw_material_movements — append-only ledger with the balance
--      after each movement, so the history can always be read back;
--   4. RPCs used by the admin app: directory, metrics, filters, material
--      options, save/delete material, record movement, movement directory and
--      movement metrics.
--
-- The material catalogue is global; stock and movements are per branch. Only
-- an all-branch manager may edit the catalogue, while a branch manager may
-- record movements for the branches they manage.
--
-- The tables are not granted to anon/authenticated: every read and write goes
-- through the SECURITY DEFINER functions below. RLS and read policies are still
-- defined as a second line of defence.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------
create table if not exists inventory.raw_materials (
  id             uuid primary key default extensions.gen_random_uuid(),
  sku            text,
  name_ar        text not null,
  name_en        text,
  category       text not null default '',
  unit           text not null default 'piece',
  unit_cost      numeric(12,2) not null default 0,
  reorder_level  numeric(12,3) not null default 0,
  notes          text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint ck_raw_material_name check (btrim(name_ar) <> ''),
  constraint ck_raw_material_unit check (unit in
    ('kg','g','l','ml','piece','pack','box','bag','bottle','can')),
  constraint ck_raw_material_cost check (unit_cost >= 0),
  constraint ck_raw_material_reorder check (reorder_level >= 0)
);

comment on table inventory.raw_materials is
  'Master list of kitchen / café raw materials with their unit, unit cost and reorder level.';

comment on column inventory.raw_materials.unit_cost is
  'Latest purchase cost per unit, used to value the stock and to price movements.';

create unique index if not exists uq_raw_materials_sku
  on inventory.raw_materials (lower(btrim(sku)))
  where sku is not null and btrim(sku) <> '';

create index if not exists ix_raw_materials_category
  on inventory.raw_materials (category);

create table if not exists inventory.raw_material_stock (
  branch_id         uuid not null references core.branches(id) on delete cascade,
  material_id       uuid not null references inventory.raw_materials(id) on delete cascade,
  quantity_on_hand  numeric(12,3) not null default 0,
  updated_at        timestamptz not null default now(),
  primary key (branch_id, material_id),
  constraint ck_raw_stock_nonnegative check (quantity_on_hand >= 0)
);

comment on table inventory.raw_material_stock is
  'Raw-material quantity on hand per branch. Written only by admin_record_inventory_movement().';

create index if not exists ix_raw_stock_material
  on inventory.raw_material_stock (material_id);

create table if not exists inventory.raw_material_movements (
  id              bigserial primary key,
  branch_id       uuid not null references core.branches(id) on delete restrict,
  material_id     uuid not null references inventory.raw_materials(id) on delete restrict,
  movement_type   text not null check (movement_type in
                    ('receipt','issue','waste','count')),
  quantity_delta  numeric(12,3) not null,
  balance_after   numeric(12,3) not null,
  unit_cost       numeric(12,2) not null default 0,
  reference       text,
  note            text,
  actor_user_id   uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  constraint ck_raw_movement_delta check (quantity_delta <> 0),
  constraint ck_raw_movement_balance check (balance_after >= 0),
  constraint ck_raw_movement_cost check (unit_cost >= 0)
);

comment on table inventory.raw_material_movements is
  'Append-only raw-material ledger. balance_after is the stock after applying quantity_delta.';

create index if not exists ix_raw_movements_created
  on inventory.raw_material_movements (created_at desc);
create index if not exists ix_raw_movements_branch
  on inventory.raw_material_movements (branch_id, created_at desc);
create index if not exists ix_raw_movements_material
  on inventory.raw_material_movements (material_id, created_at desc);
create index if not exists ix_raw_movements_type
  on inventory.raw_material_movements (movement_type, created_at desc);

-- ---------------------------------------------------------------------------
-- 2. RLS and read policies. No client writes: every mutation is an RPC.
-- ---------------------------------------------------------------------------
alter table inventory.raw_materials enable row level security;
alter table inventory.raw_material_stock enable row level security;
alter table inventory.raw_material_movements enable row level security;

drop policy if exists raw_materials_staff_read on inventory.raw_materials;
create policy raw_materials_staff_read on inventory.raw_materials
  for select to authenticated
  using (identity.has_permission('inventory.read'));

drop policy if exists raw_material_stock_staff_read on inventory.raw_material_stock;
create policy raw_material_stock_staff_read on inventory.raw_material_stock
  for select to authenticated
  using (
    identity.has_permission('inventory.read')
    and identity.can_manage_branch(branch_id)
  );

drop policy if exists raw_material_movements_staff_read on inventory.raw_material_movements;
create policy raw_material_movements_staff_read on inventory.raw_material_movements
  for select to authenticated
  using (
    identity.has_permission('inventory.read')
    and identity.can_manage_branch(branch_id)
  );

revoke all on table inventory.raw_materials from anon, authenticated;
revoke all on table inventory.raw_material_stock from anon, authenticated;
revoke all on table inventory.raw_material_movements from anon, authenticated;

-- Movements use bigserial; authenticated never inserts, but keep the sequence
-- unreachable as well.
revoke all on sequence inventory.raw_material_movements_id_seq from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Internal guards
-- ---------------------------------------------------------------------------
create or replace function inventory.require_permission(p_code text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission(p_code) then
    raise exception 'missing permission: %', p_code using errcode = '42501';
  end if;
end;
$fn$;

comment on function inventory.require_permission(text) is
  'Raise 42501 unless the caller is active staff holding p_code. Internal helper.';

revoke all on function inventory.require_permission(text) from public, anon, authenticated;

create or replace function inventory.require_branch(p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if p_branch_id is null
     or not exists (select 1 from core.branches b where b.id = p_branch_id) then
    raise exception 'branch not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
end;
$fn$;

comment on function inventory.require_branch(uuid) is
  'Raise when the branch does not exist or is outside the caller scope. Internal helper.';

revoke all on function inventory.require_branch(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Inventory directory: server-side search, category/status/branch filters
--    and paging. Quantities are aggregated over the branches the caller can
--    manage, or over one branch when p_branch_id is given.
-- ---------------------------------------------------------------------------
create or replace function public.admin_inventory_directory(
  p_search text default null,
  p_category text default null,
  p_status text default null,
  p_branch_id uuid default null,
  p_limit int default 20,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_term     text := nullif(btrim(left(coalesce(p_search, ''), 120)), '');
  v_category text := nullif(btrim(p_category), '');
  v_status   text := nullif(lower(btrim(p_status)), '');
  v_limit    int  := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset   int  := greatest(0, coalesce(p_offset, 0));
begin
  perform inventory.require_permission('inventory.read');
  if p_branch_id is not null then
    perform inventory.require_branch(p_branch_id);
  end if;
  if v_status is not null and v_status not in ('ok', 'low', 'out') then
    v_status := null;
  end if;

  return (
    with scoped as (
      select b.id
        from core.branches b
       where (p_branch_id is null or b.id = p_branch_id)
         and identity.can_manage_branch(b.id)
    )
    select jsonb_build_object(
      'rows', coalesce(
        jsonb_agg(
          to_jsonb(page_row) - 'total_count' - 'sort_rank'
          order by page_row.sort_rank, page_row.name_ar, page_row.id
        ),
        '[]'::jsonb
      ),
      'total', coalesce(max(page_row.total_count), 0)
    )
    from (
      select
        e.*,
        count(*) over() as total_count
      from (
        select
          m.id,
          m.sku,
          m.name_ar,
          m.name_en,
          m.category,
          m.unit,
          m.unit_cost,
          m.reorder_level,
          m.notes,
          m.created_at,
          m.updated_at,
          coalesce(st.quantity, 0) as quantity_on_hand,
          round(coalesce(st.quantity, 0) * m.unit_cost, 2) as stock_value,
          lm.last_movement_at,
          case
            when coalesce(st.quantity, 0) <= 0 then 'out'
            when coalesce(st.quantity, 0) <= m.reorder_level then 'low'
            else 'ok'
          end as status,
          case
            when coalesce(st.quantity, 0) <= 0 then 0
            when coalesce(st.quantity, 0) <= m.reorder_level then 1
            else 2
          end as sort_rank
        from inventory.raw_materials m
        left join lateral (
          select sum(s.quantity_on_hand) as quantity
            from inventory.raw_material_stock s
           where s.material_id = m.id
             and s.branch_id in (select id from scoped)
        ) st on true
        left join lateral (
          select max(mv.created_at) as last_movement_at
            from inventory.raw_material_movements mv
           where mv.material_id = m.id
             and mv.branch_id in (select id from scoped)
        ) lm on true
        where (v_term is null or (
                m.name_ar ilike '%' || v_term || '%'
                or coalesce(m.name_en, '') ilike '%' || v_term || '%'
                or coalesce(m.sku, '') ilike '%' || v_term || '%'
                or m.category ilike '%' || v_term || '%'
                or coalesce(m.notes, '') ilike '%' || v_term || '%'
              ))
          and (v_category is null or m.category = v_category)
      ) e
      where v_status is null or e.status = v_status
      order by e.sort_rank, e.name_ar, e.id
      limit v_limit
      offset v_offset
    ) page_row
  );
end;
$fn$;

comment on function public.admin_inventory_directory(text, text, text, uuid, int, int) is
  'Raw materials with branch-scoped on-hand quantity, stock value, health status and paging.';

revoke all on function public.admin_inventory_directory(text, text, text, uuid, int, int)
  from public, anon;
grant execute on function public.admin_inventory_directory(text, text, text, uuid, int, int)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Headline metrics for the page cards.
-- ---------------------------------------------------------------------------
create or replace function public.admin_inventory_metrics(p_branch_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform inventory.require_permission('inventory.read');
  if p_branch_id is not null then
    perform inventory.require_branch(p_branch_id);
  end if;

  return (
    with scoped as (
      select b.id
        from core.branches b
       where (p_branch_id is null or b.id = p_branch_id)
         and identity.can_manage_branch(b.id)
    ),
    stats as (
      select
        m.unit_cost,
        m.reorder_level,
        coalesce(st.quantity, 0) as quantity
      from inventory.raw_materials m
      left join lateral (
        select sum(s.quantity_on_hand) as quantity
          from inventory.raw_material_stock s
         where s.material_id = m.id
           and s.branch_id in (select id from scoped)
      ) st on true
    )
    select jsonb_build_object(
      'total', count(*),
      'out', count(*) filter (where quantity <= 0),
      'low', count(*) filter (
        where quantity > 0 and quantity <= reorder_level
      ),
      'stock_value', coalesce(round(sum(quantity * unit_cost), 2), 0),
      'categories', (
        select count(distinct m.category)
          from inventory.raw_materials m
         where btrim(m.category) <> ''
      ),
      'branches', (select count(*) from scoped),
      'latest_movement_at', (
        select max(mv.created_at)
          from inventory.raw_material_movements mv
         where mv.branch_id in (select id from scoped)
      )
    )
    from stats
  );
end;
$fn$;

comment on function public.admin_inventory_metrics(uuid) is
  'Raw-material totals, out/low counts, stock value and the latest movement time.';

revoke all on function public.admin_inventory_metrics(uuid) from public, anon;
grant execute on function public.admin_inventory_metrics(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Filter options: branches in scope and the categories in use.
-- ---------------------------------------------------------------------------
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
               jsonb_build_object('value', c.category, 'count', c.material_count)
               order by c.category
             )
        from (
          select m.category, count(*)::integer as material_count
            from inventory.raw_materials m
           where btrim(m.category) <> ''
           group by m.category
        ) c
    ), '[]'::jsonb)
  );
end;
$fn$;

comment on function public.admin_inventory_filters() is
  'Branches the caller manages and the raw-material categories in use.';

revoke all on function public.admin_inventory_filters() from public, anon;
grant execute on function public.admin_inventory_filters() to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Material options for the movement dialog.
-- ---------------------------------------------------------------------------
create or replace function public.admin_inventory_material_options(
  p_search text default null,
  p_branch_id uuid default null,
  p_limit int default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_term  text := nullif(btrim(left(coalesce(p_search, ''), 120)), '');
  v_limit int  := greatest(1, least(coalesce(p_limit, 30), 50));
begin
  perform inventory.require_permission('inventory.read');
  if p_branch_id is not null then
    perform inventory.require_branch(p_branch_id);
  end if;

  return (
    with scoped as (
      select b.id
        from core.branches b
       where (p_branch_id is null or b.id = p_branch_id)
         and identity.can_manage_branch(b.id)
    )
    select coalesce(jsonb_agg(
             jsonb_build_object(
               'id', m.id,
               'sku', m.sku,
               'name_ar', m.name_ar,
               'name_en', m.name_en,
               'unit', m.unit,
               'unit_cost', m.unit_cost,
               'reorder_level', m.reorder_level,
               'quantity_on_hand', coalesce(st.quantity, 0)
             )
             order by m.name_ar
           ), '[]'::jsonb)
    from (
      select *
        from inventory.raw_materials m
       where v_term is null or (
               m.name_ar ilike '%' || v_term || '%'
               or coalesce(m.name_en, '') ilike '%' || v_term || '%'
               or coalesce(m.sku, '') ilike '%' || v_term || '%'
             )
       order by m.name_ar
       limit v_limit
    ) m
    left join lateral (
      select sum(s.quantity_on_hand) as quantity
        from inventory.raw_material_stock s
       where s.material_id = m.id
         and s.branch_id in (select id from scoped)
    ) st on true
  );
end;
$fn$;

comment on function public.admin_inventory_material_options(text, uuid, int) is
  'Searchable raw-material options with unit, cost and current on-hand quantity.';

revoke all on function public.admin_inventory_material_options(text, uuid, int)
  from public, anon;
grant execute on function public.admin_inventory_material_options(text, uuid, int)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Create / update one material. The catalogue is global, so only a staff
--    member who manages every branch may change it.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_inventory_material(p_material jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id           uuid;
  v_sku          text;
  v_name_ar      text;
  v_name_en      text;
  v_category     text;
  v_unit         text;
  v_unit_cost    numeric;
  v_reorder      numeric;
  v_notes        text;
  v_old          jsonb;
  v_snapshot     jsonb;
begin
  perform inventory.require_permission('inventory.adjust');
  if not identity.manages_all_branches() then
    raise exception 'catalogue requires all-branch access' using errcode = '42501';
  end if;
  if p_material is null or jsonb_typeof(p_material) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    v_id := nullif(btrim(coalesce(p_material->>'id', '')), '')::uuid;
    v_unit_cost := nullif(btrim(coalesce(p_material->>'unit_cost', '')), '')::numeric;
    v_reorder := nullif(btrim(coalesce(p_material->>'reorder_level', '')), '')::numeric;
  exception
    when data_exception then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  v_name_ar := btrim(coalesce(p_material->>'name_ar', ''));
  v_name_en := btrim(coalesce(p_material->>'name_en', ''));
  v_category := btrim(coalesce(p_material->>'category', ''));
  v_unit := lower(btrim(coalesce(p_material->>'unit', 'piece')));
  v_notes := nullif(btrim(coalesce(p_material->>'notes', '')), '');
  v_sku := nullif(upper(btrim(coalesce(p_material->>'sku', ''))), '');
  v_unit_cost := coalesce(v_unit_cost, 0);
  v_reorder := coalesce(v_reorder, 0);

  if v_name_ar = '' or char_length(v_name_ar) > 120 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if char_length(v_name_en) > 120 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if v_name_en = '' then
    v_name_en := v_name_ar;
  end if;
  if v_sku is not null and v_sku !~ '^[A-Z0-9][A-Z0-9._-]{0,39}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_sku');
  end if;
  if char_length(v_category) > 80 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_category');
  end if;
  if v_unit not in ('kg','g','l','ml','piece','pack','box','bag','bottle','can') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_unit');
  end if;
  if v_unit_cost < 0 or v_unit_cost > 9999999.99 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_cost');
  end if;
  if v_reorder < 0 or v_reorder > 999999999.999 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_reorder');
  end if;
  if v_notes is not null and char_length(v_notes) > 500 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_notes');
  end if;

  if v_id is not null then
    select jsonb_build_object(
             'sku', m.sku,
             'name_ar', m.name_ar,
             'name_en', m.name_en,
             'category', m.category,
             'unit', m.unit,
             'unit_cost', m.unit_cost,
             'reorder_level', m.reorder_level,
             'notes', m.notes
           )
      into v_old
      from inventory.raw_materials m
     where m.id = v_id;
    if v_old is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    -- The ledger stores quantities in the material unit. Re-interpreting the
    -- unit of a material that already has history would silently corrupt it.
    if v_unit <> (v_old->>'unit')
       and exists (
         select 1 from inventory.raw_material_movements mv
          where mv.material_id = v_id
       ) then
      return jsonb_build_object('ok', false, 'reason', 'unit_locked');
    end if;
  end if;

  if v_sku is not null and exists (
    select 1
      from inventory.raw_materials m
     where lower(btrim(m.sku)) = lower(v_sku)
       and (v_id is null or m.id <> v_id)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_sku');
  end if;

  begin
    if v_id is null then
      insert into inventory.raw_materials (
        sku, name_ar, name_en, category, unit,
        unit_cost, reorder_level, notes, created_by
      ) values (
        v_sku, v_name_ar, v_name_en, v_category, v_unit,
        v_unit_cost, v_reorder, v_notes, auth.uid()
      ) returning id into v_id;
    else
      update inventory.raw_materials
         set sku = v_sku,
             name_ar = v_name_ar,
             name_en = v_name_en,
             category = v_category,
             unit = v_unit,
             unit_cost = v_unit_cost,
             reorder_level = v_reorder,
             notes = v_notes,
             updated_at = now()
       where id = v_id;
    end if;
  exception
    when unique_violation then
      return jsonb_build_object('ok', false, 'reason', 'duplicate_sku');
  end;

  select jsonb_build_object(
           'sku', m.sku,
           'name_ar', m.name_ar,
           'name_en', m.name_en,
           'category', m.category,
           'unit', m.unit,
           'unit_cost', m.unit_cost,
           'reorder_level', m.reorder_level,
           'notes', m.notes
         )
    into v_snapshot
    from inventory.raw_materials m
   where m.id = v_id;

  perform identity.audit(
    case when v_old is null
         then 'stock.material.create'
         else 'stock.material.update'
    end,
    'raw_material',
    v_id,
    v_old,
    v_snapshot
  );

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$fn$;

comment on function public.admin_save_inventory_material(jsonb) is
  'Create or update a global raw material. Requires inventory.adjust and all-branch scope.';

revoke all on function public.admin_save_inventory_material(jsonb) from public, anon;
grant execute on function public.admin_save_inventory_material(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Delete a material that has no stock and no history.
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_inventory_material(p_material_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  perform inventory.require_permission('inventory.adjust');
  if not identity.manages_all_branches() then
    raise exception 'catalogue requires all-branch access' using errcode = '42501';
  end if;
  if p_material_id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  select jsonb_build_object(
           'sku', m.sku,
           'name_ar', m.name_ar,
           'name_en', m.name_en,
           'unit', m.unit,
           'unit_cost', m.unit_cost
         )
    into v_old
    from inventory.raw_materials m
   where m.id = p_material_id;
  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if exists (
    select 1 from inventory.raw_material_movements mv
     where mv.material_id = p_material_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'has_movements');
  end if;
  if exists (
    select 1 from inventory.raw_material_stock s
     where s.material_id = p_material_id
       and s.quantity_on_hand <> 0
  ) then
    return jsonb_build_object('ok', false, 'reason', 'has_stock');
  end if;

  begin
    delete from inventory.raw_materials where id = p_material_id;
  exception
    when foreign_key_violation then
      return jsonb_build_object('ok', false, 'reason', 'in_use');
  end;

  perform identity.audit(
    'stock.material.delete',
    'raw_material',
    p_material_id,
    v_old,
    null
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_delete_inventory_material(uuid) is
  'Delete a raw material only when no branch holds stock and no movement references it.';

revoke all on function public.admin_delete_inventory_material(uuid) from public, anon;
grant execute on function public.admin_delete_inventory_material(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Record one movement and update the branch balance atomically.
--     receipt: stock in, positive delta
--     issue:   consumption, negative delta, cannot take the stock below zero
--     waste:   spoilage / breakage, negative delta
--     count:   the counted quantity replaces the recorded quantity
-- ---------------------------------------------------------------------------
create or replace function public.admin_record_inventory_movement(p_movement jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_material_id  uuid;
  v_branch_id    uuid;
  v_type         text;
  v_quantity     numeric;
  v_input_cost   numeric;
  v_reference    text;
  v_note         text;
  v_unit         text;
  v_material     text;
  v_on_hand      numeric;
  v_delta        numeric;
  v_balance      numeric;
  v_unit_cost    numeric;
  v_movement_id  bigint;
begin
  perform inventory.require_permission('inventory.adjust');
  if p_movement is null or jsonb_typeof(p_movement) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    v_material_id := nullif(btrim(coalesce(p_movement->>'material_id', '')), '')::uuid;
    v_branch_id := nullif(btrim(coalesce(p_movement->>'branch_id', '')), '')::uuid;
    v_quantity := nullif(btrim(coalesce(p_movement->>'quantity', '')), '')::numeric;
    v_input_cost := nullif(btrim(coalesce(p_movement->>'unit_cost', '')), '')::numeric;
  exception
    when data_exception then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  v_type := lower(btrim(coalesce(p_movement->>'type', '')));
  v_reference := nullif(btrim(coalesce(p_movement->>'reference', '')), '');
  v_note := nullif(btrim(coalesce(p_movement->>'note', '')), '');

  if v_branch_id is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_branch');
  end if;
  perform inventory.require_branch(v_branch_id);

  select m.unit
    into v_unit
    from inventory.raw_materials m
   where m.id = v_material_id;
  if v_unit is null then
    return jsonb_build_object('ok', false, 'reason', 'material_not_found');
  end if;

  if v_type not in ('receipt','issue','waste','count') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_type');
  end if;
  if v_quantity is null
     or v_quantity < 0
     or v_quantity > 999999999.999
     or (v_type <> 'count' and v_quantity = 0) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_quantity');
  end if;
  if v_input_cost is not null and (v_input_cost < 0 or v_input_cost > 9999999.99) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_cost');
  end if;
  if v_reference is not null and char_length(v_reference) > 80 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_reference');
  end if;
  if v_note is not null and char_length(v_note) > 300 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_note');
  end if;

  -- The balance row may not exist yet. Create it first so the row lock below
  -- always has something to lock, then read the current balance.
  insert into inventory.raw_material_stock (branch_id, material_id)
  values (v_branch_id, v_material_id)
  on conflict (branch_id, material_id) do nothing;

  select s.quantity_on_hand
    into v_on_hand
    from inventory.raw_material_stock s
   where s.branch_id = v_branch_id
     and s.material_id = v_material_id
   for update;

  if v_type = 'count' then
    v_delta := round(v_quantity, 3) - v_on_hand;
  elsif v_type = 'receipt' then
    v_delta := round(v_quantity, 3);
  else
    v_delta := -round(v_quantity, 3);
  end if;

  if v_delta = 0 then
    return jsonb_build_object('ok', false, 'reason', 'no_change');
  end if;

  v_balance := v_on_hand + v_delta;
  if v_balance < 0 then
    return jsonb_build_object('ok', false, 'reason', 'insufficient_stock');
  end if;

  select m.unit_cost
    into v_unit_cost
    from inventory.raw_materials m
   where m.id = v_material_id;

  if v_type = 'receipt' and v_input_cost is not null then
    v_unit_cost := v_input_cost;
    update inventory.raw_materials
       set unit_cost = v_input_cost,
           updated_at = now()
     where id = v_material_id;
  end if;

  update inventory.raw_material_stock
     set quantity_on_hand = v_balance,
         updated_at = now()
   where branch_id = v_branch_id
     and material_id = v_material_id;

  insert into inventory.raw_material_movements (
    branch_id, material_id, movement_type, quantity_delta,
    balance_after, unit_cost, reference, note, actor_user_id
  ) values (
    v_branch_id, v_material_id, v_type, v_delta,
    v_balance, v_unit_cost, v_reference, v_note, auth.uid()
  ) returning id into v_movement_id;

  select m.name_ar
    into v_material
    from inventory.raw_materials m
   where m.id = v_material_id;

  perform identity.audit(
    'stock.adjust',
    'raw_material',
    v_material_id,
    jsonb_build_object('result', v_on_hand),
    jsonb_build_object(
      'material', v_material,
      'delta', v_delta,
      'reason', v_type,
      'result', v_balance,
      'unit', v_unit,
      'reference', v_reference
    ),
    v_branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_movement_id,
    'balance_after', v_balance
  );
end;
$fn$;

comment on function public.admin_record_inventory_movement(jsonb) is
  'Record a receipt, issue, waste or count for one material at one branch, atomically updating the balance.';

revoke all on function public.admin_record_inventory_movement(jsonb) from public, anon;
grant execute on function public.admin_record_inventory_movement(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Movement ledger with server-side search, type/period/branch filters and
--     paging.
-- ---------------------------------------------------------------------------
create or replace function public.admin_stock_movement_directory(
  p_search text default null,
  p_type text default null,
  p_period text default null,
  p_branch_id uuid default null,
  p_limit int default 20,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_term   text := nullif(btrim(left(coalesce(p_search, ''), 120)), '');
  v_type   text := nullif(lower(btrim(p_type)), '');
  v_period text := nullif(lower(btrim(p_period)), '');
  v_since  timestamptz;
  v_limit  int := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  perform inventory.require_permission('inventory.read');
  if p_branch_id is not null then
    perform inventory.require_branch(p_branch_id);
  end if;
  if v_type is not null and v_type not in ('receipt', 'issue', 'waste', 'count') then
    v_type := null;
  end if;

  v_since := case v_period
    when 'today' then date_trunc('day', now())
    when 'week' then now() - interval '7 days'
    when 'month' then now() - interval '30 days'
    else null
  end;

  return (
    with scoped as (
      select b.id
        from core.branches b
       where (p_branch_id is null or b.id = p_branch_id)
         and identity.can_manage_branch(b.id)
    )
    select jsonb_build_object(
      'rows', coalesce(
        jsonb_agg(
          to_jsonb(page_row) - 'total_count'
          order by page_row.created_at desc, page_row.id desc
        ),
        '[]'::jsonb
      ),
      'total', coalesce(max(page_row.total_count), 0)
    )
    from (
      select
        mv.id,
        mv.created_at,
        mv.movement_type,
        mv.quantity_delta,
        mv.balance_after,
        mv.unit_cost,
        round(abs(mv.quantity_delta) * mv.unit_cost, 2) as movement_value,
        mv.reference,
        mv.note,
        m.id as material_id,
        m.sku as material_sku,
        m.name_ar as material_name_ar,
        m.name_en as material_name_en,
        m.unit,
        b.id as branch_id,
        b.code as branch_code,
        b.name_ar as branch_name_ar,
        b.name_en as branch_name_en,
        coalesce(sm.full_name, p.full_name) as actor_name,
        coalesce(sm.email, p.email) as actor_email,
        count(*) over() as total_count
      from inventory.raw_material_movements mv
      join inventory.raw_materials m on m.id = mv.material_id
      join core.branches b on b.id = mv.branch_id
      left join identity.staff_members sm on sm.user_id = mv.actor_user_id
      left join identity.profiles p on p.id = mv.actor_user_id
      where mv.branch_id in (select id from scoped)
        and (v_type is null or mv.movement_type = v_type)
        and (v_since is null or mv.created_at >= v_since)
        and (v_term is null or (
              m.name_ar ilike '%' || v_term || '%'
              or coalesce(m.name_en, '') ilike '%' || v_term || '%'
              or coalesce(m.sku, '') ilike '%' || v_term || '%'
              or coalesce(mv.reference, '') ilike '%' || v_term || '%'
              or coalesce(mv.note, '') ilike '%' || v_term || '%'
              or coalesce(sm.full_name, '') ilike '%' || v_term || '%'
              or coalesce(sm.email, '') ilike '%' || v_term || '%'
              or b.name_ar ilike '%' || v_term || '%'
              or coalesce(b.name_en, '') ilike '%' || v_term || '%'
            ))
      order by mv.created_at desc, mv.id desc
      limit v_limit
      offset v_offset
    ) page_row
  );
end;
$fn$;

comment on function public.admin_stock_movement_directory(text, text, text, uuid, int, int) is
  'Raw-material movement history with material, branch, actor, signed quantity and balance.';

revoke all on function public.admin_stock_movement_directory(text, text, text, uuid, int, int)
  from public, anon;
grant execute on function public.admin_stock_movement_directory(text, text, text, uuid, int, int)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 12. Movement metrics for the page cards.
-- ---------------------------------------------------------------------------
create or replace function public.admin_stock_movement_metrics(
  p_branch_id uuid default null,
  p_period text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_period text := nullif(lower(btrim(p_period)), '');
  v_since  timestamptz;
begin
  perform inventory.require_permission('inventory.read');
  if p_branch_id is not null then
    perform inventory.require_branch(p_branch_id);
  end if;

  v_since := case v_period
    when 'today' then date_trunc('day', now())
    when 'week' then now() - interval '7 days'
    when 'month' then now() - interval '30 days'
    else null
  end;

  return (
    with scoped as (
      select b.id
        from core.branches b
       where (p_branch_id is null or b.id = p_branch_id)
         and identity.can_manage_branch(b.id)
    )
    select jsonb_build_object(
      'total', count(*),
      'receipts', count(*) filter (where mv.movement_type = 'receipt'),
      'issues', count(*) filter (where mv.movement_type = 'issue'),
      'waste', count(*) filter (where mv.movement_type = 'waste'),
      'counts', count(*) filter (where mv.movement_type = 'count'),
      'received_value', coalesce(round(sum(
        case when mv.movement_type = 'receipt'
             then mv.quantity_delta * mv.unit_cost else 0 end
      ), 2), 0),
      'issued_value', coalesce(round(sum(
        case when mv.movement_type = 'issue'
             then abs(mv.quantity_delta) * mv.unit_cost else 0 end
      ), 2), 0),
      'waste_value', coalesce(round(sum(
        case when mv.movement_type = 'waste'
             then abs(mv.quantity_delta) * mv.unit_cost else 0 end
      ), 2), 0),
      'actors', count(distinct mv.actor_user_id),
      'latest_at', max(mv.created_at)
    )
    from inventory.raw_material_movements mv
    where mv.branch_id in (select id from scoped)
      and (v_since is null or mv.created_at >= v_since)
  );
end;
$fn$;

comment on function public.admin_stock_movement_metrics(uuid, text) is
  'Movement counts by type, received/issued/waste values and the latest movement time.';

revoke all on function public.admin_stock_movement_metrics(uuid, text) from public, anon;
grant execute on function public.admin_stock_movement_metrics(uuid, text) to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
