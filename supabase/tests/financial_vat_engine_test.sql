-- Behavioral coverage for migration 262's shared quote/order VAT calculation.
-- Run against an isolated local database after applying migrations. No fixtures
-- are inserted and the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

do $test$
declare
  v record;
begin
  select * into v from orders.calculate_vat_amounts(115, 0, 0, 15, true, false);
  if (v.taxable_base, v.vat_amount, v.tax_total, v.grand_total)
     is distinct from (100::numeric, 15::numeric, 0::numeric, 115::numeric) then
    raise exception 'inclusive VAT calculation mismatch: %', row_to_json(v);
  end if;

  select * into v from orders.calculate_vat_amounts(100, 0, 0, 15, false, false);
  if (v.taxable_base, v.vat_amount, v.tax_total, v.grand_total)
     is distinct from (100::numeric, 15::numeric, 15::numeric, 115::numeric) then
    raise exception 'exclusive VAT calculation mismatch: %', row_to_json(v);
  end if;

  select * into v from orders.calculate_vat_amounts(100, 10, 5, 0, true, false);
  if (v.taxable_base, v.vat_amount, v.tax_total, v.grand_total)
     is distinct from (90::numeric, 0::numeric, 0::numeric, 95::numeric) then
    raise exception 'zero-rate/not-registered calculation mismatch: %', row_to_json(v);
  end if;

  -- Coupon discount applies before tax; taxable delivery fee is included in
  -- the VAT base, while the customer still pays the inclusive gross amount.
  select * into v from orders.calculate_vat_amounts(115, 11.5, 11.5, 15, true, true);
  if (v.taxable_base, v.vat_amount, v.tax_total, v.grand_total)
     is distinct from (100::numeric, 15::numeric, 0::numeric, 115::numeric) then
    raise exception 'inclusive discount/fee calculation mismatch: %', row_to_json(v);
  end if;

  select * into v from orders.calculate_vat_amounts(100, 0, 10, 15, false, false);
  if (v.taxable_base, v.vat_amount, v.tax_total, v.grand_total)
     is distinct from (100::numeric, 15::numeric, 15::numeric, 125::numeric) then
    raise exception 'non-taxable delivery fee calculation mismatch: %', row_to_json(v);
  end if;

  select * into v from orders.calculate_vat_amounts(100, 0, 10, 15, false, true);
  if (v.taxable_base, v.vat_amount, v.tax_total, v.grand_total)
     is distinct from (110::numeric, 16.5::numeric, 16.5::numeric, 126.5::numeric) then
    raise exception 'taxable delivery fee calculation mismatch: %', row_to_json(v);
  end if;

  select * into v from orders.calculate_vat_amounts(0.05, 0, 0, 15, true, false);
  if (v.taxable_base, v.vat_amount, v.grand_total)
     is distinct from (0.04::numeric, 0.01::numeric, 0.05::numeric) then
    raise exception 'minor-unit rounding calculation mismatch: %', row_to_json(v);
  end if;
end;
$test$;

rollback;
