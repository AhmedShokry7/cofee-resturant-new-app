-- 231_ai_assistant_retrieval.sql
--
-- The assistant looks things up instead of being handed everything.
--
-- WHY
-- ---
-- The retrieval the assistant runs today is Dart code holding 26 hard-coded
-- articles plus a dump of the entire pre-loaded catalogue (up to 200 products,
-- every price, every order) pasted into the prompt of every model call. That
-- costs tokens on every question, it goes stale the moment the catalogue
-- changes, and the answer carries no pointer back to what it was built from.
--
-- This is the server-side half of retrieval: one function, ranked against the
-- actual question, that returns a handful of passages — each tagged with the
-- source it came from so the answer can cite it.
--
-- DESIGN
-- ------
-- * One owner per rule. Products are matched by `catalog.search_products`
--   (009/024/132) — the same ranked search the Menu tab uses, including the
--   effective price rule and branch availability. This function does not
--   re-implement product ranking; it reads from it and adds the ingredient
--   knowledge the model needs to answer "does this have nuts".
-- * Shop knowledge comes from `ai.knowledge_articles`, which 017 created to
--   replace the Dart arrays and which nothing has ever read.
-- * Trigram ranking, not embeddings: pg_trgm is installed, pgvector is not.
--   The threshold is deliberately loose because this only ranks; the caller
--   still refuses to answer from a weak match.
-- * Prices are only ever the effective price for the branch, never base_price.
-- * The function is SECURITY DEFINER so an `authenticated` caller can read the
--   closed `ai` schema through this one door. It exposes shop content only —
--   no customer data — so it grants to both roles.

-- The articles are matched as one document per language, indexed once per
-- language, so a query has to hit only one index.
create index if not exists ix_knowledge_articles_doc_ar
  on ai.knowledge_articles using gin ((title_ar || ' ' || body_ar) extensions.gin_trgm_ops);
create index if not exists ix_knowledge_articles_doc_en
  on ai.knowledge_articles using gin ((title_en || ' ' || body_en) extensions.gin_trgm_ops);

create or replace function public.assistant_search_knowledge(
  p_query text,
  p_branch_id uuid default null,
  p_locale text default 'ar',
  p_limit integer default 6
)
returns table (
  source_type text,
  source_id   text,
  title       text,
  body        text,
  score       real
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_limit integer := greatest(1, least(coalesce(p_limit, 6), 12));
  v_arabic boolean := left(coalesce(p_locale, 'ar'), 2) ilike 'ar';
begin
  if v_query = '' then
    return;
  end if;

  -- Shop articles first: hours, delivery, payment, coupons, brewing advice.
  return query
  with articles as (
    select
      'article'::text as source_type,
      a.slug::text as source_id,
      case when v_arabic then a.title_ar else a.title_en end as title,
      left(case when v_arabic then a.body_ar else a.body_en end, 600) as body,
      greatest(
        extensions.similarity(
          case when v_arabic then a.title_ar || ' ' || a.body_ar
               else a.title_en || ' ' || a.body_en end, v_query),
        case when a.keywords && string_to_array(lower(v_query), ' ')::text[]
             then 0.6 else 0 end::real
      )::real as score
    from ai.knowledge_articles a
    where a.is_active
  )
  select s.source_type, s.source_id, s.title, s.body, s.score
  from articles s
  where s.score > 0.15
  order by s.score desc
  limit v_limit;

  -- Then the menu, ranked by the shop's own search rule, with the ingredient
  -- knowledge that makes an allergen question answerable.
  return query
  with matched as (
    select
      p.id,
      case when v_arabic then p.name_ar else p.name_en end as name,
      case when v_arabic then p.description_ar else p.description_en end as blurb,
      p.effective_price,
      p.is_available,
      p.rank
    from public.search_products(v_query, p_branch_id, null, null, null, 'relevance', 1, v_limit) p
    where p.rank is not null
  )
  select
    'product'::text,
    m.id::text,
    m.name,
    concat(
      m.name,
      ' | ', coalesce(m.effective_price::text, 'price unknown'), ' SAR',
      ' | ', case when m.is_available then 'available' else 'not available' end,
      case when coalesce(m.blurb, '') = '' then '' else ' | ' || left(m.blurb, 200) end,
      case when k.ingredients is null or k.ingredients = '{}' then ''
           else ' | ingredients: ' || array_to_string(k.ingredients, ', ') end,
      case when k.allergens is null or k.allergens = '{}' then ''
           else ' | allergens: ' || array_to_string(k.allergens, ', ') end,
      case when k.tags is null or k.tags = '{}' then ''
           else ' | tags: ' || array_to_string(k.tags, ', ') end
    )::text as body,
    coalesce(m.rank, 0)::real
  from matched m
  left join ai.product_knowledge k on k.product_id = m.id
  order by coalesce(m.rank, 0) desc;
end;
$fn$;

comment on function public.assistant_search_knowledge(text, uuid, text, integer) is
  'Ranked passages for one question: the shop''s own articles and the menu as the search rule sees it, each tagged with its source id so an answer can cite where it came from.';

revoke all on function public.assistant_search_knowledge(text, uuid, text, integer)
  from public, anon;
grant execute on function public.assistant_search_knowledge(text, uuid, text, integer)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- A stale answer is worse than a slow one: what the assistant learned has to
-- expire, or the shop changes a price and the memory keeps serving the old one.
-- ---------------------------------------------------------------------------
create or replace function public.prune_stale_learned_answers(p_keep_days integer default 120)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  delete from ai.learned_answers l
   where l.pinned = false
     and l.hits = 0
     and l.updated_at < now() - make_interval(days => greatest(coalesce(p_keep_days, 120), 30));
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

revoke all on function public.prune_stale_learned_answers(integer) from public, anon, authenticated;
grant execute on function public.prune_stale_learned_answers(integer) to service_role;

do $do$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and not exists (select 1 from cron.job where jobname = 'prune-stale-learned-answers') then
    perform cron.schedule(
      'prune-stale-learned-answers',
      '45 3 * * *',
      $$select public.prune_stale_learned_answers(120);$$
    );
  end if;
end $do$;

notify pgrst, 'reload schema';
