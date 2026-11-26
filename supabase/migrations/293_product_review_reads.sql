-- 293_product_review_reads.sql
-- Read side of product reviews for the customer product page.
--
-- engagement.product_reviews is only readable through RLS, and a customer can
-- not read other customers' profiles or orders. These two functions expose just
-- what the product page needs:
--   * published reviews only (the same rule as reviews_public_read),
--   * the reviewer as "First L." (never an email or account id),
--   * a verified-purchase flag computed here. The client writes order_id on
--     upsert and nothing checks it, so the flag only counts an order that
--     belongs to the reviewer, contains this product, and is completed.

create or replace function public.product_review_summary(p_product_id uuid)
returns table (
  review_count   int,
  average_rating numeric,
  star_1         int,
  star_2         int,
  star_3         int,
  star_4         int,
  star_5         int
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    count(*)::int,
    coalesce(round(avg(r.rating)::numeric, 2), 0),
    count(*) filter (where r.rating = 1)::int,
    count(*) filter (where r.rating = 2)::int,
    count(*) filter (where r.rating = 3)::int,
    count(*) filter (where r.rating = 4)::int,
    count(*) filter (where r.rating = 5)::int
  from engagement.product_reviews r
  where r.product_id = p_product_id
    and r.is_published;
$$;

create or replace function public.product_review_list(
  p_product_id uuid,
  p_limit      int default 10,
  p_offset     int default 0
)
returns table (
  review_id         uuid,
  rating            int,
  title_ar          text,
  title_en          text,
  body_ar           text,
  body_en           text,
  created_at        timestamptz,
  reviewer_name     text,
  verified_purchase boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.rating,
    r.title_ar,
    r.title_en,
    r.body_ar,
    r.body_en,
    r.created_at,
    case
      when nullif(btrim(p.full_name), '') is null then null
      when position(' ' in btrim(p.full_name)) = 0 then btrim(p.full_name)
      else split_part(btrim(p.full_name), ' ', 1) || ' '
        || left(regexp_replace(btrim(p.full_name), '^.*\s', ''), 1) || '.'
    end,
    exists (
      select 1
      from orders.orders o
      join orders.order_items oi on oi.order_id = o.id
      where o.id = r.order_id
        and o.user_id = r.user_id
        and oi.product_id = r.product_id
        and o.status = 'completed'
    )
  from engagement.product_reviews r
  join identity.profiles p on p.id = r.user_id
  where r.product_id = p_product_id
    and r.is_published
  order by r.created_at desc, r.id desc
  limit least(greatest(coalesce(p_limit, 10), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.product_review_summary(uuid) from public;
grant execute on function public.product_review_summary(uuid) to anon, authenticated;

revoke all on function public.product_review_list(uuid, int, int) from public;
grant execute on function public.product_review_list(uuid, int, int) to anon, authenticated;

comment on function public.product_review_summary(uuid) is
  'Published review count, average and star distribution for one product.';
comment on function public.product_review_list(uuid, int, int) is
  'Published reviews for one product, newest first, with a privacy-safe reviewer name and a server-verified purchase flag.';
