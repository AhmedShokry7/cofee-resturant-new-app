-- 076_subscriptions_grants_fix.sql
-- Ensure authenticated clients can use RLS-protected subscription tables.

grant select, insert, update on subscriptions.subscriptions to authenticated;
grant select on subscriptions.subscription_usage to authenticated;
grant select, insert, update on subscriptions.qr_tokens to authenticated;
grant select on subscriptions.subscription_consumptions to authenticated;
grant select on subscriptions.plans to anon, authenticated;
grant select on subscriptions.plan_branches to anon, authenticated;
grant select on subscriptions.plan_products to anon, authenticated;

grant usage on schema subscriptions to anon, authenticated;
