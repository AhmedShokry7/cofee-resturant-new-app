-- Include keyword similarity in article ranking. Token overlap alone misses
-- Arabic phrases when prefixes/conjunctions differ from the stored keywords.
create or replace function public.assistant_search_knowledge(
  p_query text,
  p_branch_id uuid default null,
  p_locale text default 'ar',
  p_limit integer default 6
)
returns table (
  source_type text,
  source_id text,
  title text,
  body text,
  score real
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

  return query
  with articles as (
    select
      'article'::text as source_type,
      a.slug::text as source_id,
      case when v_arabic then a.title_ar else a.title_en end as title,
      left(case when v_arabic then a.body_ar else a.body_en end, 600) as body,
      greatest(
        extensions.similarity(
          lower(case when v_arabic then a.title_ar || ' ' || a.body_ar
                     else a.title_en || ' ' || a.body_en end),
          lower(v_query)
        ),
        extensions.similarity(
          lower(array_to_string(coalesce(a.keywords, '{}'::text[]), ' ')),
          lower(v_query)
        ),
        case when exists (
          select 1
          from unnest(coalesce(a.keywords, '{}'::text[])) keyword
          where char_length(keyword) >= 4
            and lower(v_query) like '%' || lower(keyword) || '%'
        ) then 0.7::real else 0::real end
      )::real as score
    from ai.knowledge_articles a
    where a.is_active
  )
  select s.source_type, s.source_id, s.title, s.body, s.score
  from articles s
  where s.score > 0.15
  order by s.score desc
  limit v_limit;

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

revoke all on function public.assistant_search_knowledge(text, uuid, text, integer)
  from public, anon;
grant execute on function public.assistant_search_knowledge(text, uuid, text, integer)
  to authenticated, service_role;

notify pgrst, 'reload schema';
