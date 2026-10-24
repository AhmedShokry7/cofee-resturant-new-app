-- 141_customer_enhancements.sql
alter table identity.profiles
  add column if not exists is_vip boolean not null default false,
  add column if not exists is_blacklisted boolean not null default false,
  add column if not exists admin_notes text;

insert into identity.permissions (code, name_ar, name_en)
values ('customers.write', 'كتابة العملاء', 'Write customers')
on conflict (code) do nothing;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  cross join identity.permissions p
 where r.code = 'manager'
   and p.code = 'customers.write'
on conflict do nothing;

create or replace function public.admin_customer_details(p_customer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'profile', jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'email', p.email,
        'phone', p.phone,
        'avatar_url', p.avatar_url,
        'language', p.language,
        'last_seen_at', p.last_seen_at,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_vip', p.is_vip,
        'is_blacklisted', p.is_blacklisted,
        'admin_notes', p.admin_notes
      ),
      'addresses', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'label', a.label,
          'details', a.details,
          'is_default', a.is_default
        ) order by a.created_at)
        from identity.customer_addresses a
        where a.user_id = p.id and a.archived_at is null
      ), '[]'::jsonb),
      'orders', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', o.id,
          'branch_id', o.branch_id,
          'status', o.status,
          'grand_total', o.grand_total,
          'placed_at', o.placed_at,
          'items', coalesce((
            select jsonb_agg(jsonb_build_object(
              'product_name_ar', pr.name_ar,
              'product_name_en', pr.name_en,
              'quantity', oi.quantity,
              'unit_price', oi.unit_price,
              'line_total', oi.line_total
            ) order by oi.id)
            from orders.order_items oi
            left join catalog.products pr on pr.id = oi.product_id
            where oi.order_id = o.id
          ), '[]'::jsonb)
        ) order by o.placed_at desc)
        from orders.orders o
        where o.user_id = p.id
      ), '[]'::jsonb)
    )
    from identity.profiles p
    where p.id = p_customer_id
  );
end;
$fn$;

create or replace function public.admin_update_customer(
  p_customer_id uuid,
  p_is_vip boolean default null,
  p_is_blacklisted boolean default null,
  p_admin_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  update identity.profiles
     set is_vip = coalesce(p_is_vip, is_vip),
         is_blacklisted = coalesce(p_is_blacklisted, is_blacklisted),
         admin_notes = coalesce(p_admin_notes, admin_notes),
         updated_at = now()
   where id = p_customer_id;
end;
$fn$;

revoke all on function public.admin_customer_details(uuid) from public, anon;
grant execute on function public.admin_customer_details(uuid) to authenticated;

revoke all on function public.admin_update_customer(uuid, boolean, boolean, text) from public, anon;
grant execute on function public.admin_update_customer(uuid, boolean, boolean, text) to authenticated;
