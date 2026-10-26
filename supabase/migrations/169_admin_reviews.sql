-- 169_admin_reviews.sql
-- Admin-side review moderation on top of engagement.product_reviews.
--
-- Customers write, edit and delete their own reviews, and the public read
-- policy only exposes published rows. Staff RLS can update a review but can
-- neither read a hidden one nor delete one, so moderation needs dedicated
-- security-definer functions:
--   * a directory that joins the product, the customer and the verified
--     purchase order;
--   * headline metrics and a 1..5 rating distribution;
--   * publish/hide and delete with an audit row for each change.
--
-- Every function requires reviews.moderate, the same permission the RLS
-- update policy uses, so the dashboard can never widen a staff member's
-- access.

-- ---------------------------------------------------------------------------
-- 1. Indexes for the moderation queries.
-- ---------------------------------------------------------------------------
create index if not exists ix_reviews_moderation
  on engagement.product_reviews (is_published, created_at desc);
create index if not exists ix_reviews_rating
  on engagement.product_reviews (rating, created_at desc);

-- ---------------------------------------------------------------------------
-- 2. Review directory with product, customer and verified purchase.
-- ---------------------------------------------------------------------------
create or replace function public.admin_reviews()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('reviews.moderate') then
    raise exception 'missing permission: reviews.moderate' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'rating', r.rating,
      'title_ar', r.title_ar,
      'title_en', r.title_en,
      'body_ar', r.body_ar,
      'body_en', r.body_en,
      'is_published', r.is_published,
      'created_at', r.created_at,
      'updated_at', r.updated_at,
      'order_id', r.order_id,
      'order_number', o.order_number,
      'product', jsonb_build_object(
        'id', p.id,
        'name_ar', p.name_ar,
        'name_en', p.name_en,
        'sku', p.sku,
        'image_url', p.image_url,
        'category_name_ar', cat.name_ar,
        'category_name_en', cat.name_en
      ),
      'customer', jsonb_build_object(
        'id', pr.id,
        'full_name', pr.full_name,
        'email', pr.email,
        'phone', pr.phone,
        'avatar_url', pr.avatar_url
      )
    ) order by r.created_at desc)
    from engagement.product_reviews r
    join catalog.products p on p.id = r.product_id
    left join catalog.categories cat on cat.id = p.category_id
    join identity.profiles pr on pr.id = r.user_id
    left join orders.orders o on o.id = r.order_id
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_reviews is
  'Every review, published or hidden, with the product, customer and verified order for moderation.';

revoke all on function public.admin_reviews() from public, anon;
grant execute on function public.admin_reviews() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Headline metrics and the 1..5 rating distribution.
-- ---------------------------------------------------------------------------
create or replace function public.admin_review_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('reviews.moderate') then
    raise exception 'missing permission: reviews.moderate' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'total', count(*),
      'published', count(*) filter (where r.is_published),
      'hidden', count(*) filter (where not r.is_published),
      'average_rating', coalesce(round(avg(r.rating)::numeric, 2), 0),
      'low_ratings', count(*) filter (where r.rating <= 2),
      'verified', count(*) filter (where r.order_id is not null),
      'this_month', count(*) filter (
        where r.created_at >= date_trunc('month', now())
      ),
      'distribution', jsonb_build_object(
        '1', count(*) filter (where r.rating = 1),
        '2', count(*) filter (where r.rating = 2),
        '3', count(*) filter (where r.rating = 3),
        '4', count(*) filter (where r.rating = 4),
        '5', count(*) filter (where r.rating = 5)
      )
    )
    from engagement.product_reviews r
  );
end;
$fn$;

comment on function public.admin_review_metrics is
  'Review totals, average rating and the 1..5 distribution shown on the admin reviews page.';

revoke all on function public.admin_review_metrics() from public, anon;
grant execute on function public.admin_review_metrics() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Publish or hide a review.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_review_published(
  p_review_id uuid,
  p_published boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old      jsonb;
  v_publish  boolean := coalesce(p_published, false);
  v_changed  boolean := false;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('reviews.moderate') then
    raise exception 'missing permission: reviews.moderate' using errcode = '42501';
  end if;

  select to_jsonb(r) into v_old
    from engagement.product_reviews r
   where r.id = p_review_id;

  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  update engagement.product_reviews
     set is_published = v_publish
   where id = p_review_id
     and is_published <> v_publish;

  v_changed := found;

  if v_changed then
    perform identity.audit(
      case when v_publish
        then 'engagement.review.publish'
        else 'engagement.review.hide'
      end,
      'product_review',
      p_review_id,
      v_old,
      jsonb_build_object('is_published', v_publish)
    );
  end if;

  return jsonb_build_object('ok', true, 'changed', v_changed);
end;
$fn$;

comment on function public.admin_set_review_published is
  'Publish or hide a review and record the previous row in the audit log.';

revoke all on function public.admin_set_review_published(uuid, boolean) from public, anon;
grant execute on function public.admin_set_review_published(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Delete a review permanently.
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_review(p_review_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('reviews.moderate') then
    raise exception 'missing permission: reviews.moderate' using errcode = '42501';
  end if;

  select to_jsonb(r) into v_old
    from engagement.product_reviews r
   where r.id = p_review_id;

  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  delete from engagement.product_reviews where id = p_review_id;

  perform identity.audit(
    'engagement.review.delete',
    'product_review',
    p_review_id,
    v_old,
    null
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_delete_review is
  'Delete a review permanently; the previous row is kept in the audit log.';

revoke all on function public.admin_delete_review(uuid) from public, anon;
grant execute on function public.admin_delete_review(uuid) to authenticated;

notify pgrst, 'reload schema';
