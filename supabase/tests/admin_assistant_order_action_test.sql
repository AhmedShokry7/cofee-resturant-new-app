-- Rollback-only verification of the assistant's status/cancel approval flow.
begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('97f10000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'AI-ORDER-275-A', 'فرع اختبار أ', 'Assistant Test A', 'test', true, '{}'::jsonb),
  ('97f10000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'AI-ORDER-275-B', 'فرع اختبار ب', 'Assistant Test B', 'test', true, '{}'::jsonb);

insert into auth.users (id, email) values
  ('97f20000-0000-4000-8000-000000000001', 'assistant-order-admin-275@test.local'),
  ('97f20000-0000-4000-8000-000000000002', 'assistant-order-reader-275@test.local'),
  ('97f20000-0000-4000-8000-000000000003', 'assistant-order-customer-275@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email) values
  ('97f30000-0000-4000-8000-000000000001', '97f20000-0000-4000-8000-000000000001', 'active', 'Order Admin', 'assistant-order-admin-275@test.local'),
  ('97f30000-0000-4000-8000-000000000002', '97f20000-0000-4000-8000-000000000002', 'active', 'Order Reader', 'assistant-order-reader-275@test.local');

insert into identity.roles (code, name_ar, name_en, is_system)
values
  ('assistant_order_admin', 'مسؤول طلبات اختبار', 'Assistant Order Admin 275', false),
  ('assistant_order_reader', 'قارئ طلبات اختبار', 'Assistant Order Reader 275', false);

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97f30000-0000-4000-8000-000000000001', id, '97f10000-0000-4000-8000-000000000001'
from identity.roles where code = 'assistant_order_admin';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97f30000-0000-4000-8000-000000000002', id, '97f10000-0000-4000-8000-000000000001'
from identity.roles where code = 'assistant_order_reader';

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
from identity.roles r cross join identity.permissions p
where (r.code = 'assistant_order_admin' and p.code in ('orders.read','orders.status.update','orders.cancel'))
   or (r.code = 'assistant_order_reader' and p.code = 'orders.read')
on conflict do nothing;

insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key, order_source,
  test_only
) values
  ('97f40000-0000-4000-8000-000000000001', 'AI-ORDER-275-STATUS', '97f20000-0000-4000-8000-000000000003', '97f10000-0000-4000-8000-000000000001', 'pickup', 'confirmed', 'unpaid', 20, 0, 0, 0, 20, 'SAR', '', now(), 0, 'ai-order-275-status', 'online', false),
  ('97f40000-0000-4000-8000-000000000002', 'AI-ORDER-275-CANCEL', '97f20000-0000-4000-8000-000000000003', '97f10000-0000-4000-8000-000000000001', 'pickup', 'preparing', 'unpaid', 20, 0, 0, 0, 20, 'SAR', '', now(), 0, 'ai-order-275-cancel', 'online', false),
  ('97f40000-0000-4000-8000-000000000003', 'AI-ORDER-275-PAID', '97f20000-0000-4000-8000-000000000003', '97f10000-0000-4000-8000-000000000001', 'pickup', 'confirmed', 'paid', 20, 0, 0, 0, 20, 'SAR', '', now(), 0, 'ai-order-275-paid', 'online', false),
  ('97f40000-0000-4000-8000-000000000004', 'AI-ORDER-275-OTHER-BRANCH', '97f20000-0000-4000-8000-000000000003', '97f10000-0000-4000-8000-000000000002', 'pickup', 'confirmed', 'unpaid', 20, 0, 0, 0, 20, 'SAR', '', now(), 0, 'ai-order-275-other-branch', 'online', false);

create function pg_temp.assistant_order_event_count(p_order uuid, p_event text)
returns integer language sql security definer set search_path = ''
as $$ select count(*)::integer from orders.order_events where order_id = p_order and event_type = p_event $$;
create function pg_temp.assistant_order_audit_count(p_order uuid, p_action text)
returns integer language sql security definer set search_path = ''
as $$ select count(*)::integer from identity.audit_log where entity_id = p_order and action = p_action $$;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare
  v_preview jsonb;
  v_result jsonb;
  v_token text;
  v_events_before integer;
  v_audits_before integer;
  v_events_after integer;
  v_audits_after integer;
begin
  v_preview := public.admin_assistant_order_action_preview('AI-ORDER-275-STATUS', 'status', 'preparing', null);
  if v_preview->>'old_status' <> 'confirmed' or v_preview->>'new_status' <> 'preparing' then
    raise exception 'FAIL: status preview did not include the expected before/after values: %', v_preview;
  end if;
  v_token := v_preview->>'approval_token';
  perform set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated","session_id":"different-session"}', true);
  begin
    perform public.admin_assistant_order_action_execute(v_token);
    raise exception 'FAIL: approval was accepted from a different auth session';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
  perform set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
  v_result := public.admin_assistant_order_action_execute(v_token);
  if v_result->>'new_status' <> 'preparing' or not (v_result->>'ok')::boolean then
    raise exception 'FAIL: approved status update did not complete: %', v_result;
  end if;
  v_events_before := pg_temp.assistant_order_event_count('97f40000-0000-4000-8000-000000000001', 'assistant.order.status');
  v_audits_before := pg_temp.assistant_order_audit_count('97f40000-0000-4000-8000-000000000001', 'order.status.update');
  if v_events_before <> 1 or v_audits_before <> 1 then
    raise exception 'FAIL: first status execution should write one assistant event and one lifecycle audit';
  end if;
  v_result := public.admin_assistant_order_action_execute(v_token);
  if v_result->>'new_status' <> 'preparing' or not (v_result->>'ok')::boolean then
    raise exception 'FAIL: replay returned an unexpected result: %', v_result;
  end if;
  v_events_after := pg_temp.assistant_order_event_count('97f40000-0000-4000-8000-000000000001', 'assistant.order.status');
  v_audits_after := pg_temp.assistant_order_audit_count('97f40000-0000-4000-8000-000000000001', 'order.status.update');
  if v_events_after <> v_events_before or v_audits_after <> v_audits_before then
    raise exception 'FAIL: replay duplicated an event or audit record';
  end if;

  v_preview := public.admin_assistant_order_action_preview('AI-ORDER-275-STATUS', 'status', 'ready', null);
  v_token := v_preview->>'approval_token';
  perform orders.update_order_status('97f40000-0000-4000-8000-000000000001', 'ready', 'test changed after preview');
  begin
    perform public.admin_assistant_order_action_execute(v_token);
    raise exception 'FAIL: stale preview was executed';
  exception when others then
    if sqlstate <> '40001' then raise; end if;
  end;

  v_preview := public.admin_assistant_order_action_preview('AI-ORDER-275-STATUS', 'status', 'completed', null);
  perform set_config('test.assistant_order_expiry_token', v_preview->>'approval_token', true);

  v_preview := public.admin_assistant_order_action_preview('AI-ORDER-275-CANCEL', 'cancel', null, 'customer requested');
  v_token := v_preview->>'approval_token';
  v_result := public.admin_assistant_order_action_execute(v_token);
  if v_result->>'new_status' <> 'cancelled' then
    raise exception 'FAIL: cancellation did not complete: %', v_result;
  end if;

  begin
    perform public.admin_assistant_order_action_preview('AI-ORDER-275-PAID', 'cancel', null, 'customer requested');
    raise exception 'FAIL: paid order cancellation preview was allowed';
  exception when others then
    if sqlstate <> '23514' then raise; end if;
  end;

  begin
    perform public.admin_assistant_order_action_preview('AI-ORDER-275-OTHER-BRANCH', 'status', 'preparing', null);
    raise exception 'FAIL: branch-scoped user previewed an order in another branch';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

-- Expire a fresh approval as the test owner, then confirm the authenticated
-- caller cannot execute it. The real client never receives table access.
reset role;
update orders.admin_assistant_order_action_previews
   set expires_at = now() - interval '1 second'
 where token_hash = encode(
   extensions.digest(
     convert_to(current_setting('test.assistant_order_expiry_token'), 'UTF8'),
     'sha256'
   ),
   'hex'
 );
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
do $$ begin
  begin
    perform public.admin_assistant_order_action_execute(current_setting('test.assistant_order_expiry_token'));
    raise exception 'FAIL: expired approval was executed';
  exception when others then
    if sqlstate <> '40001' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims', '{"sub":"97f20000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
do $$ begin
  begin
    perform public.admin_assistant_order_action_preview('AI-ORDER-275-STATUS', 'status', 'preparing', null);
    raise exception 'FAIL: read-only role created a status preview';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

rollback;
