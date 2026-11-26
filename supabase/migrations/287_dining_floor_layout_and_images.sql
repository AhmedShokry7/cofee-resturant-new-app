alter table floor.tables
  add column if not exists layout_x double precision,
  add column if not exists layout_y double precision;

alter table floor.tables
  drop constraint if exists ck_floor_table_layout_x,
  add constraint ck_floor_table_layout_x
    check (layout_x is null or layout_x between 0 and 1),
  drop constraint if exists ck_floor_table_layout_y,
  add constraint ck_floor_table_layout_y
    check (layout_y is null or layout_y between 0 and 1);

with ranked as (
  select id,
         row_number() over (partition by branch_id order by sort_order, name, id) as row_no,
         count(*) over (partition by branch_id) as total
    from floor.tables
), positions as (
  select id,
         0.08 + (((row_no - 1)::integer % 4) * 0.28) as x,
         0.22 + floor((row_no - 1) / 4)::double precision
           * 0.68 / greatest(ceil(total::double precision / 4) - 1, 1) as y
    from ranked
)
update floor.tables t set layout_x=p.x,layout_y=p.y
  from positions p where p.id=t.id and (t.layout_x is null or t.layout_y is null);

create or replace function public.admin_list_dining_table_layout(p_branch_id uuid)
returns table(id uuid, layout_x double precision, layout_y double precision)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() or not identity.has_permission('tables.read') then
    raise exception 'missing permission: tables.read' using errcode='42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode='42501';
  end if;
  return query select t.id,t.layout_x,t.layout_y from floor.tables t where t.branch_id=p_branch_id;
end;
$fn$;
revoke all on function public.admin_list_dining_table_layout(uuid) from public,anon;
grant execute on function public.admin_list_dining_table_layout(uuid) to authenticated;

create or replace function public.admin_set_dining_table_layout_position(
  p_table_id uuid,p_layout_x double precision,p_layout_y double precision
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_branch uuid;
begin
  if not identity.is_staff() or not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode='42501';
  end if;
  if p_layout_x is null or p_layout_y is null
     or p_layout_x not between 0 and 1 or p_layout_y not between 0 and 1 then
    return jsonb_build_object('ok',false,'reason','invalid_position');
  end if;
  select branch_id into v_branch from floor.tables where id=p_table_id for update;
  if not found then return jsonb_build_object('ok',false,'reason','not_found'); end if;
  if not identity.can_manage_branch(v_branch) then
    raise exception 'branch out of scope' using errcode='42501';
  end if;
  update floor.tables set layout_x=p_layout_x,layout_y=p_layout_y,updated_at=now() where id=p_table_id;
  return jsonb_build_object('ok',true);
end;
$fn$;
revoke all on function public.admin_set_dining_table_layout_position(uuid,double precision,double precision) from public,anon;
grant execute on function public.admin_set_dining_table_layout_position(uuid,double precision,double precision) to authenticated;

drop policy if exists dining_table_images_staff_insert on storage.objects;
create policy dining_table_images_staff_insert on storage.objects
  for insert to authenticated with check (
    bucket_id='product-images'
    and name like 'dining/tables/%'
    and identity.has_permission('tables.manage')
  );

notify pgrst,'reload schema';
