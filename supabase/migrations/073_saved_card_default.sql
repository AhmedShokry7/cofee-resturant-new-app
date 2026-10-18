-- 073_saved_card_default.sql
--
-- A default saved card, so a customer with several cards can say which one to
-- pay with. There was no such concept: `payments.saved_cards` carried only
-- `is_active` (soft delete) and `created_at`, and nothing in the app could
-- choose a card at all — the checkout always opened the hosted card form and
-- the customer retyped a number they had already saved.
--
-- The shape follows the address book exactly (060 + 065), because it has the
-- same failure mode: a clear-then-set pair that two concurrent calls can
-- interleave, leaving the loser to trip the partial unique index with a raw
-- unique_violation on a perfectly legitimate request.

-- ---------------------------------------------------------------------------
-- Column + the at-most-one-default invariant
-- ---------------------------------------------------------------------------

alter table payments.saved_cards
  add column if not exists is_default boolean not null default false;

-- Partial, not a plain unique: a customer may have many non-default cards, and
-- soft-deleted rows must not count against the limit.
create unique index if not exists uq_saved_cards_one_default
  on payments.saved_cards (user_id)
  where is_default and is_active;

comment on column payments.saved_cards.is_default is
  'The card this customer pays with by default. At most one per customer, and '
  'never on a soft-deleted row.';

-- ---------------------------------------------------------------------------
-- Selection
-- ---------------------------------------------------------------------------

create or replace function payments.set_default_card(p_card_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_card_id is null then
    raise exception 'card required' using errcode = '22023';
  end if;

  -- One customer at a time. Without this, two overlapping calls both clear and
  -- then both set, and the second set loses to uq_saved_cards_one_default with
  -- a raw 23505 rather than a usable error.
  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':default-card', 0)
  );

  if not exists (
    select 1
      from payments.saved_cards sc
     where sc.id = p_card_id
       and sc.user_id = v_uid
       and sc.is_active
  ) then
    raise exception 'card not found' using errcode = 'P0002';
  end if;

  update payments.saved_cards
     set is_default = false
   where user_id = v_uid
     and is_active
     and id <> p_card_id;

  update payments.saved_cards
     set is_default = true
   where id = p_card_id
     and user_id = v_uid;
end;
$fn$;

revoke all on function payments.set_default_card(uuid) from public, anon;
grant execute on function payments.set_default_card(uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The client-facing view must expose the flag, or the app cannot show which
-- card is the default or offer to change it.
-- ---------------------------------------------------------------------------

drop view if exists public.saved_cards;
create view public.saved_cards with (security_invoker = true) as
  select
    id,
    user_id,
    brand,
    last4,
    holder_name,
    expiry_month,
    expiry_year,
    is_active,
    is_default,
    created_at,
    updated_at
  from payments.saved_cards;

comment on view public.saved_cards is
  'Saved cards for display. Provider tokens are never client-readable; this '
  'exposes only the fields a card row needs, plus is_default so the app can '
  'show and change the preferred card.';

notify pgrst, 'reload schema';