begin;

create or replace function engagement.notify_started_favorite_discounts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_row record;
begin
  -- Future catalog discounts are announced when their start time is reached,
  -- not when a manager schedules them.
  for v_row in
    select distinct f.user_id, p.id as product_id, p.name_ar, p.name_en,
           p.discount_starts_at as starts_at
    from catalog.products p
    join engagement.customer_favorites f on f.product_id = p.id
    where p.is_active and p.discount_percentage > 0
      and p.discount_starts_at > p.updated_at + interval '5 seconds'
      and p.discount_starts_at <= now()
      and p.discount_starts_at > now() - interval '6 minutes'
      and (p.discount_ends_at is null or p.discount_ends_at > now())
      and coalesce((select np.promo from engagement.notification_preferences np where np.user_id=f.user_id),true)
  loop
    insert into engagement.notifications(
      user_id,type,title_ar,title_en,body_ar,body_en,payload,
      related_entity_type,related_entity_id,dedupe_key
    ) values (
      v_row.user_id,'promo','بدأ الخصم على منتجك المفضل','A favorite product is now on sale',
      'بدأ الخصم على ' || coalesce(v_row.name_ar,v_row.name_en,'منتج حفظته') || '.',
      'The discount has started on ' || coalesce(v_row.name_en,v_row.name_ar,'a product you saved') || '.',
      jsonb_build_object('destination','favorites','product_id',v_row.product_id,'reason','discount'),
      'product',v_row.product_id,
      'favorite_scheduled_discount:' || v_row.product_id::text || ':' || v_row.starts_at::text
    ) on conflict (user_id,dedupe_key) where dedupe_key is not null do nothing;
    if found then v_count := v_count + 1; end if;
  end loop;

  for v_row in
    select distinct f.user_id, p.id as product_id, p.name_ar, p.name_en,
           b.branch_id, b.discount_starts_at as starts_at
    from catalog.branch_product_pricing b
    join catalog.products p on p.id=b.product_id and p.is_active
    join engagement.customer_favorites f on f.product_id=p.id
    join identity.profiles profile on profile.id=f.user_id and profile.branch_id=b.branch_id
    where b.discount_percentage > 0
      and b.discount_starts_at > b.updated_at + interval '5 seconds'
      and b.discount_starts_at <= now()
      and b.discount_starts_at > now() - interval '6 minutes'
      and (b.discount_ends_at is null or b.discount_ends_at > now())
      and coalesce((select np.promo from engagement.notification_preferences np where np.user_id=f.user_id),true)
  loop
    insert into engagement.notifications(
      user_id,type,title_ar,title_en,body_ar,body_en,payload,
      related_entity_type,related_entity_id,dedupe_key
    ) values (
      v_row.user_id,'promo','بدأ الخصم على منتجك المفضل في فرعك','A favorite product is now on sale at your branch',
      'بدأ الخصم على ' || coalesce(v_row.name_ar,v_row.name_en,'منتج حفظته') || '.',
      'The discount has started on ' || coalesce(v_row.name_en,v_row.name_ar,'a product you saved') || '.',
      jsonb_build_object('destination','favorites','product_id',v_row.product_id,'branch_id',v_row.branch_id,'reason','discount'),
      'product',v_row.product_id,
      'favorite_branch_scheduled_discount:' || v_row.branch_id::text || ':' || v_row.product_id::text || ':' || v_row.starts_at::text
    ) on conflict (user_id,dedupe_key) where dedupe_key is not null do nothing;
    if found then v_count := v_count + 1; end if;
  end loop;
  return v_count;
end;
$$;

revoke all on function engagement.notify_started_favorite_discounts() from public,anon,authenticated;

do $$
declare v_job bigint;
begin
  select jobid into v_job from cron.job where jobname='favorite-discount-notifications' limit 1;
  if v_job is not null then perform cron.unschedule(v_job); end if;
  perform cron.schedule(
    'favorite-discount-notifications',
    '*/5 * * * *',
    'select engagement.notify_started_favorite_discounts();'
  );
end;
$$;

commit;

