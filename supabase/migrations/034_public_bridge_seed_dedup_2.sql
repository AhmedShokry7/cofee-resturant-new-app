-- 034_public_bridge_seed_dedup_2.sql
--
-- Second pass of the seed idempotency fix.
--
-- 033 handled bundles, bundle_items and banners. Probing the bridge afterwards
-- showed the same defect in two more tables that seed_03 inserts without a
-- natural key:
--     core.faq_items          10 rows instead of 5
--     core.onboarding_slides   6 rows instead of 3
--
-- Deduplicate them, give them real keys, and correct seed_03 so a fresh run
-- can never reintroduce the problem.

delete from core.faq_items f
 where f.id in (
   select id from (
     select id, row_number() over (
       partition by question_en order by id::text) rn
     from core.faq_items
   ) t where rn > 1
 );

delete from core.onboarding_slides s
 where s.id in (
   select id from (
     select id, row_number() over (
       partition by sort_order order by id::text) rn
     from core.onboarding_slides
   ) t where rn > 1
 );

do $$
begin
  if not exists (select 1 from pg_constraint
                 where conname = 'faq_items_question_en_key'
                   and conrelid = 'core.faq_items'::regclass) then
    alter table core.faq_items
      add constraint faq_items_question_en_key unique (question_en);
  end if;
  if not exists (select 1 from pg_constraint
                 where conname = 'onboarding_slides_sort_order_key'
                   and conrelid = 'core.onboarding_slides'::regclass) then
    alter table core.onboarding_slides
      add constraint onboarding_slides_sort_order_key unique (sort_order);
  end if;
end $$;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';