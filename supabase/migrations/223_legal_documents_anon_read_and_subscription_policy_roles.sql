-- supabase/migrations/223_legal_documents_anon_read_and_subscription_policy_roles.sql
--
-- WHY THIS EXISTS
--
-- Two reads answered 42501 when probed against the live project as a real anon
-- client (the same probe that produced 033), measured 2026-11-03:
--
--   GET /rest/v1/legal_documents
--     -> permission denied for table legal_documents
--   GET /rest/v1/loyalty_rewards
--     -> permission denied for function has_permission
--
-- The customer app cannot degrade either one. The legal read is what the
-- Privacy/Terms pages show, and `LoyaltyPage` is not behind `AuthGuard` - the
-- notification deep link reaches it directly and its cubit treats guests as
-- customers - so a guest opening either surface gets an error state today.
--
-- ---------------------------------------------------------------------------
-- 1. `legal_documents` is the fourth bridge table 033 missed.
--
-- 033 added the base-table grants `public.faq_items`, `public.onboarding_slides`
-- and `public.app_settings` needed, because a `security_invoker` view runs as the
-- CALLING role (032). `core.legal_documents` was in the same family and was left
-- out: `023_grants_01.sql` lists it under `authenticated` only (line 36), and its
-- RLS policy `legal_public_read` (020:68) already says
-- `for select to anon, authenticated using (is_published)`. Only the table grant
-- is missing, so the policy is never reached.
--
-- This is a read-only grant on already-public text. The policy still filters to
-- `is_published`, so a draft document stays invisible to guests.
-- ---------------------------------------------------------------------------
grant select on core.legal_documents to anon;

-- ---------------------------------------------------------------------------
-- 2. Policies without a TO clause are granted to PUBLIC, anon included.
--
-- `create policy ... for all using (identity.has_permission(...))` with no `TO`
-- role means `TO PUBLIC`, and `anon` is a member of PUBLIC. The rest of the
-- schema is careful about this - every write policy in 020/022/023 says
-- `to authenticated` - and 074/075 are the only migrations that omit it.
--
-- `public.loyalty_rewards` (167:78) is a `security_invoker` view whose lateral
-- join reads `subscriptions.plans` as the calling role. For anon, Postgres
-- combines the SELECT policies on that table with OR:
--
--   plans_read   (is_active and is_for_sale)      -- no TO clause, applies
--   plans_write  (identity.has_permission(...))   -- no TO clause, applies
--
-- so a guest browsing reward tickets evaluates `identity.has_permission`, a
-- function deliberately closed to client roles, and the entire read dies with
-- 42501 rather than returning the rows the guest may see.
--
-- Scope the permission-gated policies to `authenticated`. Nothing is taken away
-- from a real customer: none of these tables is granted to anon at all
-- (074:664 grants plans/plan_branches/plan_products only; 076:7 grants
-- subscription_consumptions to authenticated), so before this change a guest was
-- denied by the grant and, one layer down, would have been denied by the
-- function. Staff keep `identity.has_permission` because `authenticated` is the
-- role they connect with.
--
-- The three plain public reads of 074 keep their exact behaviour and only gain
-- the roles they were already serving, spelled out so the next policy added
-- beside them cannot repeat the mistake.
-- ---------------------------------------------------------------------------

-- 2a. Public plan catalogue: same rows as before, roles now explicit.
drop policy if exists plans_read on subscriptions.plans;
create policy plans_read on subscriptions.plans
  for select to anon, authenticated
  using (is_active and is_for_sale);

drop policy if exists plan_branches_read on subscriptions.plan_branches;
create policy plan_branches_read on subscriptions.plan_branches
  for select to anon, authenticated
  using (true);

drop policy if exists plan_products_read on subscriptions.plan_products;
create policy plan_products_read on subscriptions.plan_products
  for select to anon, authenticated
  using (true);

-- 2b. Permission-gated writes: staff only.
drop policy if exists plans_write on subscriptions.plans;
create policy plans_write on subscriptions.plans
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

drop policy if exists plan_branches_write on subscriptions.plan_branches;
create policy plan_branches_write on subscriptions.plan_branches
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

drop policy if exists plan_products_write on subscriptions.plan_products;
create policy plan_products_write on subscriptions.plan_products
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

drop policy if exists subscriptions_write on subscriptions.subscriptions;
create policy subscriptions_write on subscriptions.subscriptions
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

-- 2c. Owner-or-staff reads. The owner half is unchanged (`user_id = auth.uid()`
-- and the EXISTS probes need `authenticated`); the staff half is what anon must
-- not be walked through.
drop policy if exists subscriptions_read on subscriptions.subscriptions;
create policy subscriptions_read on subscriptions.subscriptions
  for select to authenticated
  using (
    user_id = auth.uid() or identity.has_permission('subscriptions.consume') or identity.has_permission('subscriptions.manage')
  );

drop policy if exists usage_read on subscriptions.subscription_usage;
create policy usage_read on subscriptions.subscription_usage
  for select to authenticated
  using (
    exists (select 1 from subscriptions.subscriptions s where s.id = subscription_id and s.user_id = auth.uid())
    or identity.has_permission('subscriptions.consume')
    or identity.has_permission('subscriptions.manage')
  );

drop policy if exists events_read on subscriptions.subscription_events;
create policy events_read on subscriptions.subscription_events
  for select to authenticated
  using (
    user_id = auth.uid() or identity.has_permission('subscriptions.consume') or identity.has_permission('subscriptions.manage')
  );

drop policy if exists sub_consumptions_read on subscriptions.subscription_consumptions;
create policy sub_consumptions_read on subscriptions.subscription_consumptions
  for select to authenticated
  using (
    exists (select 1 from subscriptions.subscriptions s where s.id = subscription_id and s.user_id = auth.uid())
    or identity.has_permission('subscriptions.consume')
    or identity.has_permission('subscriptions.manage')
  );

-- `qr_tokens_read` / `qr_tokens_write` (074:177-181) are also unscoped, but their
-- predicates only call `auth.uid()`, which returns null for anon instead of
-- raising. Left alone: changing them is a cosmetic edit on a table anon has no
-- grant on.
