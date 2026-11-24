-- Tighten the test-payment eligibility guard before any test identities exist.
-- A Phase 1.3 order must issue a simplified invoice with a complete seller
-- snapshot; SQL NULL must never weaken that requirement.
create or replace function payments.complete_phase13_test_payment(
  p_order_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
  v_payment payments.payment_transactions%rowtype;
  v_ref text;
begin
  if p_order_id is null or p_actor_user_id is null then
    raise exception 'order and authenticated test customer are required' using errcode = '22023';
  end if;
  if not exists (
    select 1 from payments.phase13_test_customers t
     where t.user_id = p_actor_user_id and t.expires_at > now()
  ) then
    raise exception 'test payment harness is not enabled for this identity' using errcode = '42501';
  end if;

  select * into v_order from orders.orders o
   where o.id = p_order_id and o.user_id = p_actor_user_id for update;
  if not found then
    raise exception 'test order not found for authenticated customer' using errcode = 'P0002';
  end if;

  v_ref := 'phase13-test:' || p_order_id::text;
  select * into v_payment from payments.payment_transactions pt
   where pt.provider = 'codex_phase13_test' and pt.order_id = p_order_id
   order by pt.created_at desc limit 1 for update;
  if found then
    if v_payment.status <> 'captured' or not v_payment.verified_by_server then
      raise exception 'test payment transaction is in an unexpected state' using errcode = '55000';
    end if;
    return jsonb_build_object(
      'order_id', p_order_id, 'payment_transaction_id', v_payment.id,
      'provider', 'codex_phase13_test', 'provider_reference', v_payment.provider_reference,
      'status', v_payment.status, 'verified_by_server', v_payment.verified_by_server,
      'simulated_test_payment', true, 'idempotent_replay', true
    );
  end if;

  if v_order.status = 'cancelled'
     or v_order.grand_total <= 0
     or v_order.payment_status not in ('unpaid', 'pending')
     or v_order.tax_registration_status_snapshot is distinct from 'registered'
     or v_order.seller_snapshot is null
     or nullif(btrim(v_order.seller_snapshot->>'legal_name'), '') is null
     or v_order.seller_snapshot->>'vat_number' !~ '^[0-9]{15}$'
     or coalesce(
       nullif(btrim(v_order.seller_snapshot->>'address_ar'), ''),
       nullif(btrim(v_order.seller_snapshot->>'address_en'), ''),
       nullif(btrim(v_order.seller_snapshot->>'address'), '')
     ) is null
     or not exists (select 1 from orders.order_items oi where oi.order_id=p_order_id) then
    raise exception 'order is not eligible for Phase 1.3 simplified invoice test' using errcode = '22023';
  end if;

  insert into payments.payment_transactions (
    order_id, provider, provider_reference, amount, currency_code,
    status, paid_at, verified_by_server
  ) values (
    p_order_id, 'codex_phase13_test', v_ref, v_order.grand_total,
    coalesce(v_order.currency_code, 'SAR'), 'pending', null, false
  ) returning * into v_payment;
  update payments.payment_transactions
     set status='captured', verified_by_server=true, paid_at=now(), updated_at=now()
   where id=v_payment.id returning * into v_payment;

  update orders.orders set payment_status='paid'
   where id=p_order_id and user_id=p_actor_user_id;

  insert into payments.payment_events(provider,event_id,charge_id,payload)
  values (
    'codex_phase13_test', v_ref || ':captured', v_ref,
    jsonb_build_object('provider','codex_phase13_test','test_only',true,
      'simulated_capture',true,'payment_transaction_id',v_payment.id,
      'order_id',p_order_id,'amount',v_payment.amount,'currency_code',v_payment.currency_code)
  ) on conflict (provider,event_id) do nothing;

  return jsonb_build_object(
    'order_id',p_order_id,'payment_transaction_id',v_payment.id,
    'provider','codex_phase13_test','provider_reference',v_payment.provider_reference,
    'status',v_payment.status,'verified_by_server',v_payment.verified_by_server,
    'simulated_test_payment',true,'idempotent_replay',false
  );
end;
$fn$;
revoke all on function payments.complete_phase13_test_payment(uuid,uuid) from public, anon, authenticated;
grant execute on function payments.complete_phase13_test_payment(uuid,uuid) to service_role;
