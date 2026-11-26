select exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='generate_subscription_qr') as qr_rpc_available,
exists(select 1 from cron.job where jobname='customer-product-subscription-run-schedule' and active) as recurring_scheduler_active;
