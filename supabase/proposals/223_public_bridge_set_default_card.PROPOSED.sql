-- 223_public_bridge_set_default_card.PROPOSED.sql
-- STATUS: NOT APPLIED. This file is a decision draft; applying it is an owner
-- action in the SQL Editor (see README.md in this folder).
--
-- ## Why
--
-- `SupabaseSavedCardsRepository.setDefaultCard()` asks for an Edge Function
-- named `set_default_card`. No such function exists in `supabase/functions/`
-- (the Tap family is `tap-create-charge`, `tap-tokenize-card`,
-- `tap-verify-charge`, `tap-refund`, `tap-delete-card`, `tap-webhook`), so the
-- call answers 404 and "make this card my default" can never work.
--
-- There is no fallback path either:
--   * `public.saved_cards` is SELECT-only for `authenticated` (063 + 105) and
--     `anon` is revoked, so a client-side `update` is a permission error;
--   * `payments.saved_cards` has one policy, `saved_cards_select_own` (062), so
--     even the base table is read-only for the customer role;
--   * the rule is already written and correct —
--     `payments.set_default_card(p_card_id uuid)` (073) takes a per-customer
--     advisory lock, re-checks ownership, clears the previous default and sets
--     the new one. It is only unreachable, because it lives in a schema
--     PostgREST does not expose.
--
-- ## Change
--
-- The same bridge wrapper this repo already uses for every other domain RPC
-- (035, 063, 074, 078). Behaviour stays 100% inside 073: ownership, the lock
-- and the one-default invariant are untouched. `security invoker` is required
-- so `auth.uid()` inside 073 still sees the customer, exactly as the
-- subscriptions bridge does; 023 already grants `usage on schema payments`.
--
-- ## Read-only rehearsal (run before pasting)
--
--   select p.proname, n.nspname, pg_get_function_identity_arguments(p.oid),
--          has_function_privilege('authenticated', p.oid, 'execute')
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname in ('public', 'payments')
--      and p.proname = 'set_default_card';
--
-- Expect exactly one row from `payments` with execute = true, and no row from
-- `public`. If `public.set_default_card` already exists, do not paste this
-- file — reconcile the body with `pg_get_functiondef` first.
--
-- ## What breaks if this is wrong?
--
-- Nothing that works today. Before it, the button fails; after a bad paste the
-- same button still fails, because the wrapper only forwards to a function that
-- already refuses any card the caller does not own (`card not found`, P0002).
-- The exposure surface does not grow: execute is granted to `authenticated`
-- only, and `anon` is revoked explicitly.

create or replace function public.set_default_card(p_card_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select payments.set_default_card(p_card_id); $fn$;

comment on function public.set_default_card(uuid) is
  'Bridge to payments.set_default_card (073): makes the caller''s own card the '
  'default and clears the others. The customer app cannot write saved_cards '
  'directly - the view is SELECT-only.';

revoke all on function public.set_default_card(uuid) from public, anon;
grant execute on function public.set_default_card(uuid) to authenticated;
