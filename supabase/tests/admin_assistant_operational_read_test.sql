-- Isolated branch-scope and privacy checks for the assistant aggregate reads.
begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('98e10000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'AI-OPS-READ-1', 'فرع تحليلات 1', 'Ops Branch 1', 'test', true, '{}'::jsonb),
  ('98e10000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'AI-OPS-READ-2', 'فرع تحليلات 2', 'Ops Branch 2', 'test', true, '{}'::jsonb);

insert into auth.users (id, email)
values ('98e20000-0000-4000-8000-000000000001', 'assistant-ops-reader@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values ('98e30000-0000-4000-8000-000000000001', '98e20000-0000-4000-8000-000000000001', 'active', 'Assistant Ops Reader', 'assistant-ops-reader@test.local');

insert into identity.roles (code, name_ar, name_en, is_system)
values ('assistant_ops_reader_test', 'قارئ عمليات اختبار', 'Assistant Ops Reader Test', false);

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '98e30000-0000-4000-8000-000000000001', id, '98e10000-0000-4000-8000-000000000001'
  from identity.roles where code = 'assistant_ops_reader_test';

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code in ('orders.read', 'payments.read')
 where r.code = 'assistant_ops_reader_test'
on conflict do nothing;

insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key, order_source,
  test_only
) values
  ('98e40000-0000-4000-8000-000000000001', 'AI-OPS-READ-ORDER-1', null, '98e10000-0000-4000-8000-000000000001', 'pickup', 'completed', 'paid', 25, 0, 0, 0, 25, 'SAR', '', now() - interval '1 day', 0, 'ai-ops-read-order-1', 'online', false),
  ('98e40000-0000-4000-8000-000000000002', 'AI-OPS-READ-ORDER-2', null, '98e10000-0000-4000-8000-000000000002', 'pickup', 'completed', 'paid', 90, 0, 0, 0, 90, 'SAR', '', now() - interval '1 day', 0, 'ai-ops-read-order-2', 'online', false);

insert into payments.payment_transactions (
  id, order_id, provider, amount, currency_code, status, created_at
) values
  ('98e50000-0000-4000-8000-000000000001', '98e40000-0000-4000-8000-000000000001', 'test', 25, 'SAR', 'captured', now() - interval '1 day'),
  ('98e50000-0000-4000-8000-000000000002', '98e40000-0000-4000-8000-000000000002', 'test', 90, 'SAR', 'captured', now() - interval '1 day');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"98e20000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare
  v_orders jsonb;
  v_payments jsonb;
begin
  v_orders := public.admin_assistant_order_metrics(now() - interval '7 days', now() + interval '1 minute', null);
  if v_orders->>'orders' <> '1'
     or jsonb_array_length(v_orders->'branch_comparison') <> 1
     or v_orders->'branch_comparison'->0->>'branch_name_en' <> 'Ops Branch 1'
     or v_orders::text ilike '%customer_phone%'
     or v_orders::text ilike '%customer_name%' then
    raise exception 'FAIL: order aggregates escaped branch scope or included customer data: %', v_orders;
  end if;

  v_payments := public.admin_assistant_payment_metrics(now() - interval '7 days', now() + interval '1 minute', null);
  if v_payments->>'transactions' <> '1'
     or (v_payments->'captured_by_currency'->0->>'captured_transaction_amount')::numeric <> 25
     or v_payments::text ilike '%card_last4%'
     or v_payments::text ilike '%provider_reference%'
     or v_payments::text ilike '%customer_name%' then
    raise exception 'FAIL: payment aggregates escaped branch scope or included sensitive data: %', v_payments;
  end if;

  begin
    perform public.admin_assistant_payment_metrics(
      now() - interval '7 days', now() + interval '1 minute',
      '98e10000-0000-4000-8000-000000000002'
    );
    raise exception 'FAIL: reader queried an out-of-scope branch';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

rollback;
