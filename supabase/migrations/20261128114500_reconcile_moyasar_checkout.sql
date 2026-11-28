-- A webhook and a client verification can finish the same captured checkout
-- concurrently. Earlier edge code could overwrite finalized with captured
-- after the paid order and verified transaction had committed. Repair only
-- intents for which all three server records agree on the same payment.
update public.moyasar_checkout_intents as intent
   set status = 'finalized', updated_at = now()
 where intent.status = 'captured'
   and intent.order_id is not null
   and exists (
     select 1
       from payments.payment_transactions as tx
       join orders.orders as ord on ord.id = tx.order_id
      where tx.provider = 'moyasar'
        and tx.provider_reference = intent.payment_id::text
        and tx.status = 'captured'
        and tx.verified_by_server = true
        and ord.id = intent.order_id
        and ord.user_id = intent.user_id
        and ord.payment_status = 'paid'
   );
