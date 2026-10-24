-- 140_admin_customers.sql
create or replace function public.admin_customers()
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

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'email', p.email,
      'phone', p.phone,
      'avatar_url', p.avatar_url,
      'language', p.language,
      'last_seen_at', p.last_seen_at,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'orders_count', coalesce(o.cnt, 0),
      'total_spent', coalesce(o.spent, 0),
      'is_vip', p.is_vip,
      'is_blacklisted', p.is_blacklisted,
      'admin_notes', p.admin_notes
    ) order by p.created_at desc)
    from identity.profiles p
    left join lateral (
      select count(*)::int as cnt, coalesce(sum(grand_total), 0)::numeric as spent
      from orders.orders
      where user_id = p.id
    ) o on true
    where not exists (
      select 1 from identity.staff_members sm where sm.user_id = p.id
    )
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_customers() from public, anon;
grant execute on function public.admin_customers() to authenticated;
