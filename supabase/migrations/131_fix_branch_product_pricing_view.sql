-- 131_fix_branch_product_pricing_view.sql
--
-- Migration 032 published the branch pricing table with "select *":
--
--   create or replace view public.branch_product_pricing ... as
--     select * from catalog.branch_product_pricing;
--
-- A PostgreSQL view freezes its column list when it is created: the star is
-- expanded once, at creation time. Migration 128 then added the four discount
-- columns to catalog.branch_product_pricing, but a view that is not recreated
-- keeps the column list it was created with, so the new columns never reached
-- the public view. The comment in 128 that said "already uses select *, so its
-- new columns are exposed" was wrong for exactly this reason.
--
-- The failure was live and total, not cosmetic:
--
--   GET /rest/v1/branch_product_pricing?select=discount_percentage&limit=1
--   -> 400 {"code":"42703",
--           "message":"column branch_product_pricing.discount_percentage does not exist"}
--
-- The customer app asks for those four columns by name
-- (lib/features/menu/data/repositories/supabase_product_repository.dart:68), so
-- every catalogue read failed with 42703 as soon as a branch was selected: the
-- menu, the categories and the home page could not load. The admin panel writes
-- the same four columns
-- (app/admin_app/lib/features/catalog/data/repositories/admin_product_repository.dart:221),
-- so a branch discount could not be saved either.
--
-- The view is republished with an explicit column list, so a column added to the
-- table later is never published by accident, and the grants are restated
-- because a recreated view carries no privileges of its own (see
-- REMAINING_ISSUES_REGISTER.md 2.10).

create or replace view public.branch_product_pricing with (security_invoker = true) as
  select branch_id,
         product_id,
         price_override,
         is_available,
         is_featured,
         unavailable_reason,
         updated_at,
         discount_percentage,
         discount_starts_at,
         discount_ends_at,
         use_general_discount
    from catalog.branch_product_pricing;

grant select on public.branch_product_pricing to anon, authenticated;
grant insert, update, delete on public.branch_product_pricing to authenticated;

comment on view public.branch_product_pricing is
  'Routing view over catalog.branch_product_pricing, including the branch discount columns.';

notify pgrst, 'reload schema';
