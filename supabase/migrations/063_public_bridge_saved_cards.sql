-- 063_public_bridge_saved_cards.sql
-- Expose only non-sensitive display fields. Provider tokens (tap_customer_id,
-- tap_card_id, payment_agreement_id) stay behind the service role and are
-- never readable by the client, even though RLS already scopes rows to owner.
create or replace view public.saved_cards with (security_invoker = true) as
  select
    id,
    user_id,
    brand,
    last4,
    holder_name,
    expiry_month,
    expiry_year,
    is_active,
    created_at,
    updated_at
  from payments.saved_cards;

grant select on public.saved_cards to authenticated;
revoke all on public.saved_cards from anon;
