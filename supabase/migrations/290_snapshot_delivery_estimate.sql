begin;

-- Freeze the branch-configured estimate on the order at placement time, so a
-- later edit to a delivery zone never rewrites the customer's order history.
create or replace function orders.snapshot_delivery_estimate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estimated_minutes integer;
begin
  if new.fulfillment_type <> 'delivery' or new.delivery_zone_id is null then
    return new;
  end if;

  select z.estimated_minutes into v_estimated_minutes
  from core.delivery_zones z
  where z.id = new.delivery_zone_id;

  new.delivery_address_snapshot :=
    coalesce(new.delivery_address_snapshot, '{}'::jsonb)
    || jsonb_strip_nulls(jsonb_build_object(
      'estimated_delivery_minutes', v_estimated_minutes
    ));
  return new;
end;
$$;

drop trigger if exists tr_snapshot_delivery_estimate on orders.orders;
create trigger tr_snapshot_delivery_estimate
  before insert on orders.orders
  for each row execute function orders.snapshot_delivery_estimate();

revoke all on function orders.snapshot_delivery_estimate() from public, anon, authenticated;

commit;
