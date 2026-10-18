-- 067_coupon_availability.sql
--
-- The coupon list only filtered `is_active`, so a customer who had already
-- spent their per-user allowance still saw every coupon offered, and only
-- discovered the truth when the checkout refused the code with a raw English
-- message. It read as the coupon having vanished for them alone, which is
-- exactly what it looked like.
--
-- Fix: expose, per coupon, how many times *this* signed-in customer has
-- already used it and how many they have left, so the list can say so instead
-- of failing silently. Reading-only: applying a coupon still records nothing,
-- and a redemption is still written only when an order completes.
--
-- Rows are keyed by coupon id so a left join keeps an uncategorised/unmatched
-- coupon visible rather than dropping it.

create or replace function public.coupon_availability()
returns table (
  coupon_id      uuid,
  used_count     bigint,
  per_user_limit integer,
  usage_limit    integer,
  total_used     bigint
)
language sql
stable
security definer
set search_path to ''
as $fn$
  select c.id,
         (select count(*)
            from marketing.coupon_redemptions r
           where r.coupon_id = c.id
             and r.user_id = auth.uid()) as used_count,
         c.per_user_limit,
         c.usage_limit,
         (select count(*)
            from marketing.coupon_redemptions r
           where r.coupon_id = c.id) as total_used
    from marketing.coupons c;
$fn$;

comment on function public.coupon_availability() is
  'Per-coupon usage for the signed-in customer. Read-only; never records a '
  'redemption. Used to explain why a coupon is unavailable instead of '
  'letting it fail at checkout.';

grant execute on function public.coupon_availability()
  to authenticated, service_role;