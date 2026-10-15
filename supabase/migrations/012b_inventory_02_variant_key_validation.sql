-- 012b_inventory_02_variant_key_validation.sql
--
-- Problem: inventory.branch_stock used a foreign key
--   variant_key -> catalog.option_values(id)
-- but decision D8 makes variant_key NOT NULL with the sentinel
-- 00000000-0000-0000-0000-000000000000 to mean "the product itself, no
-- variant". That sentinel has no row in option_values, so the FK rejects it
-- and stock rows cannot be created at all.
--
-- A conditional FK is not expressible, and option_values cannot hold a
-- sentinel row without polluting the real option list.
--
-- Fix: drop the FK and enforce the same invariant with a trigger. Either the
-- key is the sentinel, or it must be a genuine option_values row that belongs
-- to an option group actually offered by the product.

alter table inventory.branch_stock
  drop constraint if exists fk_branch_stock_variant;

create or replace function inventory.validate_stock_variant()
returns trigger
language plpgsql
as $fn$
declare
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
begin
  if new.variant_key = v_sentinel then
    return new;
  end if;

  if not exists (
    select 1
    from catalog.option_values ov
    join catalog.product_option_groups pog on pog.group_id = ov.group_id
    where ov.id = new.variant_key
      and pog.product_id = new.product_id
  ) then
    raise exception
      'variant_key % is not an option offered by product %', new.variant_key, new.product_id
      using errcode = '23503';
  end if;

  return new;
end;
$fn$;

comment on function inventory.validate_stock_variant() is
  'Enforces that variant_key is either the sentinel or a real option bound to the product.';

drop trigger if exists tr_branch_stock_variant on inventory.branch_stock;
create constraint trigger tr_branch_stock_variant
  after insert or update of variant_key, product_id on inventory.branch_stock
  deferrable initially deferred
  for each row execute function inventory.validate_stock_variant();

-- stock_movements carries the same column; validate it the same way.
alter table inventory.stock_movements
  drop constraint if exists fk_movements_variant;

create or replace function inventory.validate_movement_variant()
returns trigger
language plpgsql
as $fn$
declare
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
begin
  if new.variant_key = v_sentinel then
    return new;
  end if;
  if not exists (select 1 from catalog.option_values ov where ov.id = new.variant_key) then
    raise exception 'unknown variant_key %', new.variant_key using errcode = '23503';
  end if;
  return new;
end;
$fn$;

drop trigger if exists tr_movements_variant on inventory.stock_movements;
create constraint trigger tr_movements_variant
  after insert on inventory.stock_movements
  deferrable initially deferred
  for each row execute function inventory.validate_movement_variant();