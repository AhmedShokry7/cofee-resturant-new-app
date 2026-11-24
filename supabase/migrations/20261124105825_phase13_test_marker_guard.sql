-- Prevent ordinary callers from injecting the system-managed test marker,
-- and keep test/report classification immutable after order creation.
begin;

create or replace function orders.guard_phase13_test_order_markers()
returns trigger language plpgsql security definer set search_path = '' as $fn$
declare v_run uuid;
begin
  if tg_op='UPDATE' then
    if new.test_only is distinct from old.test_only
       or new.test_run_id is distinct from old.test_run_id then
      raise exception 'test order classification is immutable' using errcode='55000';
    end if;
    return new;
  end if;

  select nullif(b.settings->>'phase13_test_run_id','')::uuid into v_run
    from core.branches b where b.id=new.branch_id;
  if v_run is null and (new.test_only or new.test_run_id is not null) then
    raise exception 'test order markers are assigned only by the dedicated test branch' using errcode='42501';
  end if;
  return new;
end;
$fn$;
revoke all on function orders.guard_phase13_test_order_markers() from public, anon, authenticated;
drop trigger if exists tr_orders_guard_phase13_test_markers on orders.orders;
create trigger tr_orders_guard_phase13_test_markers
before insert or update of test_only,test_run_id on orders.orders
for each row execute function orders.guard_phase13_test_order_markers();

commit;
