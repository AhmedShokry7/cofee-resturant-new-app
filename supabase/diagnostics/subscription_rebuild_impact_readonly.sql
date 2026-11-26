select jsonb_build_object(
 'package_statuses',(select coalesce(jsonb_object_agg(status,n), '{}'::jsonb) from (select status,count(*) n from subscriptions.subscriptions group by status) x),
 'product_statuses',(select coalesce(jsonb_object_agg(status,n), '{}'::jsonb) from (select status,count(*) n from subscriptions.customer_product_subscriptions group by status) x),
 'active_package_customers',(select count(distinct user_id) from subscriptions.subscriptions where status='active'),
 'active_package_remaining_units',(select coalesce(sum(greatest(0,cups_entitled+cups_carried_over-cups_used-cups_reserved)),0) from subscriptions.subscriptions where status='active'),
 'active_package_reserved_units',(select coalesce(sum(cups_reserved),0) from subscriptions.subscriptions where status='active'),
 'open_consumptions',(select count(*) from subscriptions.subscription_consumptions where status='reserved'),
 'pending_package_payments',(select count(*) from subscriptions.subscriptions where status='pending_payment'),
 'active_product_customers',(select count(distinct user_id) from subscriptions.customer_product_subscriptions where status='active'),
 'pending_product_runs',(select count(*) from subscriptions.customer_product_subscription_runs where status='pending'),
 'package_payment_statuses',(select coalesce(jsonb_object_agg(status,n), '{}'::jsonb) from (select status,count(*) n from payments.payment_transactions where subscription_id is not null group by status) x)
) as impact;
