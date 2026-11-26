-- REVIEW DRAFT. This file is intentionally read-only when run as supplied.
-- Never change the final ROLLBACK to COMMIT until each affected customer,
-- pending run, captured payment and accounting treatment is signed off.
begin;

select 'package' as source, status, count(*) as cycles,
       sum(greatest(0,cups_entitled+cups_carried_over-cups_used-cups_reserved)) as unused_units,
       sum(cups_reserved) as reserved_units
  from subscriptions.subscriptions
 group by status
union all
select 'recurring_order',status,count(*),null,null
  from subscriptions.customer_product_subscriptions
 group by status;

select count(*) as pending_product_runs
  from subscriptions.customer_product_subscription_runs
 where status='pending';

select t.status,t.currency_code,count(*) as transactions,sum(t.amount) as amount
  from payments.payment_transactions t
 where t.subscription_id is not null
 group by t.status,t.currency_code;

-- AFTER REVIEW, a separate migration must snapshot impacted IDs/balances,
-- append one system_subscription_rebuild audit event per cycle, stop new
-- grants, resolve or preserve pending runs, and change each status once.
-- Never UPDATE balance counters to zero or DELETE payment/invoice/usage rows.

rollback;
