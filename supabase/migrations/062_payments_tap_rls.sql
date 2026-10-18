-- 062_payments_tap_rls.sql
-- RLS for Tap-specific tables.

alter table payments.tap_customers enable row level security;
alter table payments.saved_cards enable row level security;
alter table payments.payment_events enable row level security;

-- tap_customers: owner read only; writes are service-role only.
create policy tap_customers_select_own on payments.tap_customers
  for select to authenticated
  using (user_id = auth.uid());

-- saved_cards: owner read only; writes/deletes are service-role only.
create policy saved_cards_select_own on payments.saved_cards
  for select to authenticated
  using (user_id = auth.uid() and is_active);

-- payment_events: no client access (service-role only).

-- Grants.
grant select on payments.tap_customers, payments.saved_cards to authenticated;
grant all on payments.tap_customers, payments.saved_cards, payments.payment_events to service_role;
