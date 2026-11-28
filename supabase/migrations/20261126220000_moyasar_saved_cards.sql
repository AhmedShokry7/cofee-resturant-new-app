-- Store Moyasar token references alongside legacy Tap cards without exposing
-- provider credentials or card numbers to the client.
alter table payments.saved_cards
  add column if not exists provider text not null default 'tap',
  add column if not exists moyasar_token_id text;

alter table payments.saved_cards
  alter column tap_customer_id drop not null,
  alter column tap_card_id drop not null;

do $migration$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'saved_cards_provider_check'
       and conrelid = 'payments.saved_cards'::regclass
  ) then
    alter table payments.saved_cards
      add constraint saved_cards_provider_check check (
        (provider = 'tap' and tap_customer_id is not null
          and tap_card_id is not null and moyasar_token_id is null)
        or
        (provider = 'moyasar' and tap_customer_id is null
          and tap_card_id is null and moyasar_token_id is not null)
      );
  end if;
end
$migration$;

create unique index if not exists uq_saved_moyasar_token
  on payments.saved_cards (user_id, moyasar_token_id)
  where provider = 'moyasar' and moyasar_token_id is not null;

create or replace view public.saved_cards with (security_invoker = true) as
  select id, user_id, brand, last4, holder_name, expiry_month, expiry_year,
         is_active, is_default, created_at, updated_at, provider
    from payments.saved_cards;

create or replace view public.saved_card_provider with (security_invoker = true) as
  select id, user_id, tap_customer_id, tap_card_id, payment_agreement_id,
         brand, last4, expiry_month, expiry_year, holder_name, is_active,
         is_default, created_at, updated_at, provider, moyasar_token_id
    from payments.saved_cards;

notify pgrst, 'reload schema';
