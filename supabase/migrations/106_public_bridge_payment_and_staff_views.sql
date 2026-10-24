-- 106_public_bridge_payment_and_staff_views.sql
--
-- The payment path of the app could not reach its own tables.
--
-- What was wrong
-- --------------
-- The PostgREST of this project serves the `public` schema only.  The OpenAPI
-- document of the live project is titled "standard public schema" and its
-- schema cache holds the `public` views - not the tables of the internal
-- schemas.  The payment Edge Functions, however, talk to PostgREST through
-- `supabase/functions/_shared/tap.ts`, which builds a `/rest/v1/<table>`
-- path, and they read the tables of the `payments`, `orders`, `subscriptions`
-- and `identity` schemas:
--
--   tap-create-charge  /payment_attempts  /payment_transactions
--                      /tap_customers     /saved_cards
--   tap-verify-charge  /payment_transactions  /orders  /subscriptions
--                      /rpc/activate_subscription
--   tap-webhook        /payment_events  /payment_transactions  /orders
--                      /subscriptions   /rpc/activate_subscription
--   tap-refund         /staff_members  /staff_roles  /roles
--                      /role_permissions  /permissions
--                      /payment_transactions  /orders
--   tap-delete-card    /saved_cards
--
-- Every one of those calls answered:
--
--   PGRST205  Could not find the table 'public.payment_transactions'
--             in the schema cache
--
-- so no charge was ever recorded, no webhook ever reached the order and no
-- refund could be claimed.
--
-- Two more things were missing, and both are part of the same defect:
--
--   * the service role could not write the payment state.  It may read
--     `payments.payment_transactions` and `orders.orders`, but it had no
--     INSERT or UPDATE, so the charge and the order status could never be
--     written even when the table was reachable;
--   * the service role could not read `subscriptions.subscriptions` and
--     `subscriptions.plans` at all, so a subscription payment could never be
--     verified or activated.
--
-- What this migration does
-- ------------------------
-- 1. The bridge views the Edge Functions need, and nothing else:
--
--      public.payment_transactions   the charge of an order or a subscription
--      public.payment_attempts       the attempt of a charge
--      public.payment_events         the events the provider sent
--      public.tap_customers          the customer id of the provider
--      public.saved_card_provider    the provider ids of a stored card
--      public.subscriptions          a subscription with the price of its plan
--      public.staff_members          the back office staff
--      public.staff_roles            the roles of the staff
--      public.roles                  the roles
--      public.role_permissions       the permissions of a role
--      public.permissions            the permissions
--
--    Every view is `security_invoker`, so the privileges and the row level
--    security of the base table decide what the caller sees, and every view
--    is granted to `service_role` only: the Edge Functions authenticate with
--    the service key, and neither a customer nor an anonymous caller can
--    reach them.  The columns are written out one by one.  `select *` would
--    freeze the shape of the base table into the view and would publish the
--    provider columns of a card to whoever the view is granted to.
--
-- 2. `public.activate_subscription`, the wrapper of the RPC of the same name
--    in the `subscriptions` schema, so the webhook and the verification can
--    activate a paid subscription.  It is granted to `service_role` only, and
--    the function it calls checks the payment itself: a subscription is only
--    activated when a verified, captured transaction exists for it.
--
-- 3. The privileges the service role needs to write the payment state and to
--    read the subscriptions.  The service role is the credential of the
--    backend, it bypasses row level security, and the customers keep their
--    own access: nothing here is granted to `anon` or to `authenticated`.
--
-- The customer facing views are not touched: `public.saved_cards` still
-- shows the display columns of a card and never its provider ids, and the
-- new `public.saved_card_provider` is the only place where the provider
-- columns are readable.

begin;

-- ---------------------------------------------------------------------------
-- 1. The bridge views
-- ---------------------------------------------------------------------------
create or replace view public.payment_transactions with (security_invoker = true) as
select id,
       order_id,
       subscription_id,
       attempt_id,
       provider,
       provider_reference,
       amount,
       currency_code,
       status,
       paid_at,
       refunded_at,
       card_brand,
       card_last4,
       card_holder_name,
       verified_by_server,
       created_at,
       updated_at
  from payments.payment_transactions;

create or replace view public.payment_attempts with (security_invoker = true) as
select id,
       order_id,
       method_id,
       status,
       failure_code,
       failure_message,
       client_initiated,
       started_at,
       finished_at,
       idempotency_key
  from payments.payment_attempts;

create or replace view public.payment_events with (security_invoker = true) as
select id,
       provider,
       event_id,
       charge_id,
       payload,
       processed_at
  from payments.payment_events;

create or replace view public.tap_customers with (security_invoker = true) as
select user_id,
       tap_customer_id,
       created_at,
       updated_at
  from payments.tap_customers;

-- The provider ids of a stored card.  They are not in `public.saved_cards`,
-- which the customer reads: the ids of the card at the provider are not the
-- customer's business.
create or replace view public.saved_card_provider with (security_invoker = true) as
select id,
       user_id,
       tap_customer_id,
       tap_card_id,
       payment_agreement_id,
       brand,
       last4,
       expiry_month,
       expiry_year,
       holder_name,
       is_active,
       is_default,
       created_at,
       updated_at
  from payments.saved_cards;

-- The price of the plan travels with the subscription, so the webhook can
-- compare the amount of the charge with the amount that was promised.  It is
-- a column, not an embedded resource: a view carries no foreign key, so
-- PostgREST cannot resolve `plan:plans(...)` through it.
create or replace view public.subscriptions with (security_invoker = true) as
select s.id,
       s.user_id,
       s.plan_id,
       s.status,
       s.starts_at,
       s.ends_at,
       s.cups_entitled,
       s.cups_used,
       s.cups_carried_over,
       s.cups_reserved,
       s.bonus_balance,
       s.auto_renew,
       s.payment_reference,
       s.idempotency_key,
       s.created_at,
       jsonb_build_object(
         'id', p.id,
         'price', p.price,
         'currency_code', p.currency_code,
         'name_ar', p.name_ar,
         'name_en', p.name_en
       ) as plan
  from subscriptions.subscriptions s
  left join subscriptions.plans p on p.id = s.plan_id;

create or replace view public.staff_members with (security_invoker = true) as
select id,
       user_id,
       status,
       full_name,
       email,
       created_at
  from identity.staff_members;

create or replace view public.staff_roles with (security_invoker = true) as
select staff_id,
       role_id,
       branch_id,
       granted_by,
       created_at
  from identity.staff_roles;

create or replace view public.roles with (security_invoker = true) as
select id,
       code,
       name_ar,
       name_en,
       is_system
  from identity.roles;

create or replace view public.role_permissions with (security_invoker = true) as
select role_id,
       permission_id
  from identity.role_permissions;

create or replace view public.permissions with (security_invoker = true) as
select id,
       code,
       name_ar,
       name_en
  from identity.permissions;

-- ---------------------------------------------------------------------------
-- 2. The wrapper of the activation RPC
-- ---------------------------------------------------------------------------
create or replace function public.activate_subscription(
  p_subscription_id uuid,
  p_payment_reference text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  return subscriptions.activate_subscription(
    p_subscription_id,
    p_payment_reference
  );
end;
$fn$;

comment on function public.activate_subscription(uuid, text) is
  'Activates a subscription after a verified payment. The service role only; '
  'the function it calls checks that the payment exists and was verified.';

revoke all on function public.activate_subscription(uuid, text)
  from public, anon, authenticated;
grant execute on function public.activate_subscription(uuid, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- 3. The privileges the service role needs
-- ---------------------------------------------------------------------------
grant insert, update on table payments.payment_transactions to service_role;
grant insert, update on table payments.payment_attempts to service_role;
grant update on table orders.orders to service_role;
grant select on table subscriptions.subscriptions to service_role;
grant select on table subscriptions.plans to service_role;

-- ---------------------------------------------------------------------------
-- 4. The grants of the views: the service role, and nobody else
-- ---------------------------------------------------------------------------
grant select, insert, update on public.payment_transactions to service_role;
grant select, insert on public.payment_attempts to service_role;
grant select, insert on public.payment_events to service_role;
grant select, insert on public.tap_customers to service_role;
grant select, insert, update on public.saved_card_provider to service_role;
grant select on public.subscriptions to service_role;
grant select on public.staff_members to service_role;
grant select on public.staff_roles to service_role;
grant select on public.roles to service_role;
grant select on public.role_permissions to service_role;
grant select on public.permissions to service_role;

revoke all on public.payment_transactions from anon, authenticated;
revoke all on public.payment_attempts from anon, authenticated;
revoke all on public.payment_events from anon, authenticated;
revoke all on public.tap_customers from anon, authenticated;
revoke all on public.saved_card_provider from anon, authenticated;
revoke all on public.subscriptions from anon, authenticated;
revoke all on public.staff_members from anon, authenticated;
revoke all on public.staff_roles from anon, authenticated;
revoke all on public.roles from anon, authenticated;
revoke all on public.role_permissions from anon, authenticated;
revoke all on public.permissions from anon, authenticated;

notify pgrst, 'reload schema';
notify pgrst, 'reload config';

commit;

-- Verification
-- ------------
-- 1) The views the Edge Functions need exist:
--      select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
--       where n.nspname = 'public' and c.relkind = 'v'
--         and c.relname in ('payment_transactions','payment_attempts','payment_events',
--                           'tap_customers','saved_card_provider','subscriptions',
--                           'staff_members','staff_roles','roles','role_permissions',
--                           'permissions');
--    Expected: 11.
--
-- 2) None of them is reachable by a customer or by an anonymous caller:
--      select c.relname, has_table_privilege('anon', c.oid, 'SELECT') as anon,
--                        has_table_privilege('authenticated', c.oid, 'SELECT') as customer
--        from pg_class c join pg_namespace n on n.oid = c.relnamespace
--       where n.nspname = 'public' and c.relkind = 'v'
--         and c.relname in ('payment_transactions','payment_attempts','payment_events',
--                           'tap_customers','saved_card_provider','subscriptions',
--                           'staff_members','staff_roles','roles','role_permissions',
--                           'permissions');
--    Expected: anon = false and customer = false for every row.
--
-- 3) The service role may write the payment state:
--      select has_table_privilege('service_role','payments.payment_transactions','INSERT') as tx_insert,
--             has_table_privilege('service_role','payments.payment_transactions','UPDATE') as tx_update,
--             has_table_privilege('service_role','orders.orders','UPDATE') as order_update,
--             has_table_privilege('service_role','subscriptions.subscriptions','SELECT') as sub_select;
--    Expected: true, true, true, true.
--
-- 4) The customer facing saved cards still hide the provider ids:
--      select string_agg(column_name, ', ' order by ordinal_position) from information_schema.columns
--       where table_schema = 'public' and table_name = 'saved_cards';
--    Expected: no tap_customer_id and no tap_card_id.
--
-- 5) The activation RPC is not callable by a customer:
--      select has_function_privilege('authenticated','public.activate_subscription(uuid,text)','EXECUTE') as customer;
--    Expected: false.
--
-- Rollback
-- --------
-- begin;
-- revoke all on function public.activate_subscription(uuid, text) from service_role;
-- drop function if exists public.activate_subscription(uuid, text);
-- drop view if exists public.payment_transactions;
-- drop view if exists public.payment_attempts;
-- drop view if exists public.payment_events;
-- drop view if exists public.tap_customers;
-- drop view if exists public.saved_card_provider;
-- drop view if exists public.subscriptions;
-- drop view if exists public.staff_members;
-- drop view if exists public.staff_roles;
-- drop view if exists public.roles;
-- drop view if exists public.role_permissions;
-- drop view if exists public.permissions;
-- revoke insert, update on table payments.payment_transactions from service_role;
-- revoke insert, update on table payments.payment_attempts from service_role;
-- revoke update on table orders.orders from service_role;
-- revoke select on table subscriptions.subscriptions from service_role;
-- revoke select on table subscriptions.plans from service_role;
-- commit;
-- ---------------------------------------------------------------------------
