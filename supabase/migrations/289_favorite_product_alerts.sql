begin;

-- Notify a customer when a product they saved becomes available again or is
-- newly discounted. Notifications remain in-app even when push is disabled;
-- the existing notification trigger handles opted-in push delivery.
create or replace function engagement.notify_favorite_catalog_product_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_title_ar text;
  v_title_en text;
  v_body_ar text;
  v_body_en text;
  v_dedupe text;
  v_user record;
begin
  if tg_op <> 'UPDATE' then return new; end if;

  if old.is_active is distinct from true and new.is_active then
    v_reason := 'available';
    v_title_ar := 'منتجك المفضل عاد!';
    v_title_en := 'Your favorite is back!';
    v_body_ar := coalesce(new.name_ar, new.name_en, 'المنتج الذي حفظته') || ' أصبح متاحًا الآن.';
    v_body_en := coalesce(new.name_en, new.name_ar, 'A product you saved') || ' is available again.';
  elsif coalesce(new.discount_percentage, 0) > coalesce(old.discount_percentage, 0)
    and (new.discount_starts_at is null or new.discount_starts_at <= now())
    and (new.discount_ends_at is null or new.discount_ends_at > now()) then
    v_reason := 'discount';
    v_title_ar := 'خصم على منتجك المفضل';
    v_title_en := 'A discount on your favorite';
    v_body_ar := 'تم تخفيض سعر ' || coalesce(new.name_ar, new.name_en, 'منتج حفظته') || '.';
    v_body_en := coalesce(new.name_en, new.name_ar, 'A product you saved') || ' is now on sale.';
  else
    return new;
  end if;

  v_dedupe := 'favorite_product:' || v_reason || ':' || new.id::text || ':' || txid_current()::text;
  for v_user in
    select f.user_id
    from engagement.customer_favorites f
    where f.product_id = new.id
      and coalesce((select p.promo from engagement.notification_preferences p where p.user_id = f.user_id), true)
  loop
    insert into engagement.notifications (
      user_id, type, title_ar, title_en, body_ar, body_en, payload,
      related_entity_type, related_entity_id, dedupe_key
    ) values (
      v_user.user_id, 'promo', v_title_ar, v_title_en, v_body_ar, v_body_en,
      jsonb_build_object('destination', 'favorites', 'product_id', new.id, 'reason', v_reason),
      'product', new.id, v_dedupe
    ) on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  end loop;
  return new;
end;
$$;

drop trigger if exists tr_favorite_catalog_product_alert on catalog.products;
create trigger tr_favorite_catalog_product_alert
  after update of is_active, discount_percentage, discount_starts_at, discount_ends_at
  on catalog.products
  for each row execute function engagement.notify_favorite_catalog_product_change();

create or replace function engagement.notify_favorite_branch_product_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title_ar text;
  v_title_en text;
  v_body_ar text;
  v_body_en text;
  v_reason text;
  v_dedupe text;
  v_user record;
  v_name_ar text;
  v_name_en text;
begin
  if tg_op <> 'UPDATE' then return new; end if;
  if old.is_available is distinct from true and new.is_available then
    v_reason := 'available';
    v_title_ar := 'منتجك المفضل عاد في فرعك';
    v_title_en := 'Your favorite is back at your branch';
  elsif coalesce(new.discount_percentage, 0) > coalesce(old.discount_percentage, 0)
    and (new.discount_starts_at is null or new.discount_starts_at <= now())
    and (new.discount_ends_at is null or new.discount_ends_at > now()) then
    v_reason := 'discount';
    v_title_ar := 'خصم على منتجك المفضل في فرعك';
    v_title_en := 'A favorite is on sale at your branch';
  else
    return new;
  end if;

  select p.name_ar, p.name_en into v_name_ar, v_name_en
  from catalog.products p where p.id = new.product_id;
  if v_reason = 'available' then
    v_body_ar := coalesce(v_name_ar, v_name_en, 'المنتج الذي حفظته') || ' أصبح متاحًا الآن.';
    v_body_en := coalesce(v_name_en, v_name_ar, 'A product you saved') || ' is available again.';
  else
    v_body_ar := 'تم تخفيض سعر ' || coalesce(v_name_ar, v_name_en, 'منتج حفظته') || '.';
    v_body_en := coalesce(v_name_en, v_name_ar, 'A product you saved') || ' is now on sale.';
  end if;

  v_dedupe := 'favorite_branch_product:' || v_reason || ':' || new.branch_id::text || ':' || new.product_id::text || ':' || txid_current()::text;
  for v_user in
    select f.user_id
    from engagement.customer_favorites f
    join identity.profiles profile on profile.id = f.user_id and profile.branch_id = new.branch_id
    where f.product_id = new.product_id
      and coalesce((select p.promo from engagement.notification_preferences p where p.user_id = f.user_id), true)
  loop
    insert into engagement.notifications (
      user_id, type, title_ar, title_en, body_ar, body_en, payload,
      related_entity_type, related_entity_id, dedupe_key
    ) values (
      v_user.user_id, 'promo', v_title_ar, v_title_en, v_body_ar, v_body_en,
      jsonb_build_object('destination', 'favorites', 'product_id', new.product_id, 'branch_id', new.branch_id, 'reason', v_reason),
      'product', new.product_id, v_dedupe
    ) on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  end loop;
  return new;
end;
$$;

drop trigger if exists tr_favorite_branch_product_alert on catalog.branch_product_pricing;
create trigger tr_favorite_branch_product_alert
  after update of is_available, discount_percentage, discount_starts_at, discount_ends_at
  on catalog.branch_product_pricing
  for each row execute function engagement.notify_favorite_branch_product_change();

revoke all on function engagement.notify_favorite_catalog_product_change() from public, anon, authenticated;
revoke all on function engagement.notify_favorite_branch_product_change() from public, anon, authenticated;

commit;
