-- Reinstall the run-scoped simulated payment implementation from Phase 1.3.1.
-- The earlier schema must not apply production legal-seller eligibility to a
-- test-only seller snapshot.
create or replace function payments.complete_phase13_test_payment(p_order_id uuid,p_actor_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_order orders.orders%rowtype; v_payment payments.payment_transactions%rowtype;
  v_profile payments.phase13_test_seller_profiles%rowtype; v_amounts record;
  v_ref text;
begin
  if p_order_id is null or p_actor_user_id is null then
    raise exception 'order and authenticated test customer are required' using errcode='22023';
  end if;
  select * into v_order from orders.orders where id=p_order_id and user_id=p_actor_user_id for update;
  if not found or not v_order.test_only or v_order.test_run_id is null then
    raise exception 'test order not found for authenticated customer' using errcode='P0002';
  end if;
  select * into v_profile from payments.phase13_test_seller_profiles p
   where p.run_id=v_order.test_run_id and p.branch_id=v_order.branch_id and p.expires_at>now();
  if not found or not exists (select 1 from payments.phase13_test_customers c
       where c.user_id=p_actor_user_id and c.run_id=v_order.test_run_id and c.expires_at>now())
     or not exists (select 1 from payments.phase13_test_identities i
       where i.user_id=p_actor_user_id and i.run_id=v_order.test_run_id
         and i.identity_kind='customer' and i.expires_at>now()) then
    raise exception 'Phase 1.3 test identity or run is expired or unauthorized' using errcode='42501';
  end if;
  v_ref:='phase13-test:'||p_order_id::text;
  select * into v_payment from payments.payment_transactions
   where provider='codex_phase13_test' and order_id=p_order_id
   order by created_at desc limit 1 for update;
  if found then
    if v_payment.status<>'captured' or not v_payment.verified_by_server then
      raise exception 'test payment transaction is in an unexpected state' using errcode='55000';
    end if;
    return jsonb_build_object('order_id',p_order_id,'payment_transaction_id',v_payment.id,
      'provider','codex_phase13_test','provider_reference',v_payment.provider_reference,
      'status',v_payment.status,'verified_by_server',true,'simulated_test_payment',true,
      'idempotent_replay',true);
  end if;
  if v_order.status='cancelled' or v_order.grand_total<=0
     or v_order.payment_status not in ('unpaid','pending')
     or not exists(select 1 from orders.order_items where order_id=p_order_id) then
    raise exception 'test order is not eligible for simulated capture' using errcode='22023';
  end if;
  select * into v_amounts from orders.calculate_vat_amounts(
    v_order.subtotal,v_order.discount_total,v_order.delivery_fee,v_profile.tax_rate,
    v_profile.tax_included,v_profile.delivery_fee_taxable);
  update orders.orders set
    seller_snapshot=jsonb_build_object('test_only',true,'test_run_id',v_order.test_run_id,
      'seller_label',v_profile.seller_label,'address_label',v_profile.address_label,
      'tax_identity_status','not_a_legal_registration'),
    tax_rate_snapshot=v_profile.tax_rate,tax_included_snapshot=v_profile.tax_included,
    tax_registration_status_snapshot='test_only',tax_treatment_snapshot='test_only',
    tax_configuration_version_snapshot=0,delivery_fee_taxable_snapshot=v_profile.delivery_fee_taxable,
    taxable_base=v_amounts.taxable_base,vat_amount=v_amounts.vat_amount,
    tax_total=v_amounts.tax_total,grand_total=v_amounts.grand_total,tax_calculated_at=now()
   where id=p_order_id returning * into v_order;
  insert into payments.payment_transactions(order_id,provider,provider_reference,amount,currency_code,status,paid_at,verified_by_server)
   values(p_order_id,'codex_phase13_test',v_ref,v_order.grand_total,coalesce(v_order.currency_code,'SAR'),'captured',now(),true)
   returning * into v_payment;
  update orders.orders set payment_status='paid' where id=p_order_id;
  insert into payments.payment_events(provider,event_id,charge_id,payload)
   values('codex_phase13_test',v_ref||':captured',v_ref,
    jsonb_build_object('provider','codex_phase13_test','test_only',true,'simulated_capture',true,
      'payment_transaction_id',v_payment.id,'order_id',p_order_id,'amount',v_payment.amount,
      'currency_code',v_payment.currency_code)) on conflict(provider,event_id) do nothing;
  return jsonb_build_object('order_id',p_order_id,'payment_transaction_id',v_payment.id,
    'provider','codex_phase13_test','provider_reference',v_payment.provider_reference,
    'status',v_payment.status,'verified_by_server',true,'simulated_test_payment',true,
    'idempotent_replay',false);
end;
$fn$;
revoke all on function payments.complete_phase13_test_payment(uuid,uuid) from public,anon,authenticated;
grant execute on function payments.complete_phase13_test_payment(uuid,uuid) to service_role;
