-- 218_admin_subscriptions_and_loyalty_avatars.sql
-- بلاطة الصورة في الاشتراكات وسجل حركة الولاء كانتا تطبعان الحروف الأولى دائمًا:
-- الدالتان لم تكونا ترجعان `avatar_url` أصلًا، فلا شيء يصل إلى الـ Widget ليُعرض.
--
-- WHY THIS IS THE ONLY BACKEND PIECE THE FIX NEEDS
--   `identity.profiles.avatar_url` stores a PATH inside the private `avatars`
--   bucket (084:18-20), and the admin app converts paths to short-lived signed
--   urls at read time in `AdminAvatarLinks.signTree` (TTL 3600, storage policy
--   measured on the staff role by 208:42-52). Every other customer feed already
--   returns the column — 140/141/160 for customers, 153/186 for orders,
--   169 for reviews, 170 for notifications, 165:296 for loyalty members,
--   176 for POS — so the picture renders there.
--   Two feeds predate that convention and never carried it:
--     * public.admin_subscriptions()        (150, rewritten by 161) — its row
--       builder already reads `p.full_name / p.email / p.phone` off
--       `left join identity.profiles p`, and the UI has an avatar tile for that
--       customer (SubscriptionAvatar, used by the table, the cards and the
--       details dialog). The tile could only ever draw initials.
--     * public.admin_loyalty_transactions() (165, rewritten by 167) — its row
--       builder already reads `p.full_name / p.email` off
--       `join identity.profiles p`, and the activity table and activity cards
--       both draw an avatar tile for that member. Same dead tile.
--   Both already hold the join and the permission gate, so the repair is one
--   projected column per function. No table, no column on a table, no
--   constraint, no index, no policy, no new function.
--
-- SECURITY IS UNCHANGED, NOT RELAXED
--   Both functions stay SECURITY DEFINER with `set search_path = ''` and the
--   same two gates (identity.is_staff() plus subscriptions.manage /
--   loyalty.read). The value added is the path string only. The client cannot
--   read the object with it: `avatars` is private (084:42-50) and the SELECT
--   policy is what decides the signed url, so a staff account without
--   customers.read gets a failed signature and the tile prints its initials
--   exactly as it does today (admin_avatar_links.dart:53-62 keeps the path on
--   failure; AdminAvatarImage only fetches http(s) values).
--
-- WHAT BREAKS IF THIS IS WRONG
--   Nothing reads the new key except the two entities it is added to, and a
--   missing key parses as null there, so the pre-218 client and the post-218
--   server are each fine with the other. The blast radius of a wrong body is
--   the feed itself: a syntax error aborts the migration and the old definition
--   stays in force.
--
-- VERIFY LIVE STATE BEFORE APPLYING (chain-vs-live drift is the known hazard on
-- this project): read the two definitions as they run now, and compare with the
-- bodies below, which are copied verbatim from 161:5-65 and 167:353-411 with
-- only the marked line added.
--   select pg_get_functiondef('public.admin_subscriptions()'::regprocedure),
--          pg_get_functiondef('public.admin_loyalty_transactions(integer)'::regprocedure);
-- Apply through the migration ledger (`supabase migration repair` for any
-- version this folder records), never `db push`.
-- -----------------------------------------------------------------------------

create or replace function public.admin_subscriptions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id,
      'user_id', s.user_id,
      'customer_name', p.full_name,
      'customer_email', p.email,
      'customer_phone', p.phone,
      -- 218: the path, not a link. The app signs it per read.
      'avatar_url', p.avatar_url,
      'plan_id', s.plan_id,
      'plan_code', pl.code,
      'plan_name_ar', pl.name_ar,
      'plan_name_en', pl.name_en,
      'plan_price', pl.price,
      'currency_code', pl.currency_code,
      'plan_duration_days', pl.duration_days,
      'status', case
        when s.status = 'active'
          and s.ends_at is not null
          and s.ends_at <= now() then 'expired'
        else s.status
      end,
      'starts_at', s.starts_at,
      'ends_at', s.ends_at,
      'bonus_expires_at', s.bonus_expires_at,
      'cups_entitled', s.cups_entitled,
      'cups_used', s.cups_used,
      'cups_carried_over', s.cups_carried_over,
      'cups_reserved', s.cups_reserved,
      'bonus_balance', s.bonus_balance,
      'auto_renew', s.auto_renew,
      'payment_reference', s.payment_reference,
      'created_at', s.created_at,
      'usage_count', coalesce(u.usage_count, 0),
      'last_used_at', u.last_used_at
    ) order by s.created_at desc)
    from subscriptions.subscriptions s
    left join identity.profiles p on p.id = s.user_id
    left join subscriptions.plans pl on pl.id = s.plan_id
    left join lateral (
      select
        count(*)::int as usage_count,
        max(usage.created_at) as last_used_at
      from subscriptions.subscription_usage usage
      where usage.subscription_id = s.id
    ) u on true
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscriptions() from public, anon;
grant execute on function public.admin_subscriptions() to authenticated;

-- ---------------------------------------------------------------------------
create or replace function public.admin_loyalty_transactions(p_limit integer default 300)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 300), 1), 1000);
  v_rows  jsonb;
  v_total bigint;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.read') then
    raise exception 'missing permission: loyalty.read' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(entry), '[]'::jsonb)
    into v_rows
    from (
      select jsonb_build_object(
        'id', t.id,
        'user_id', t.user_id,
        'customer_name', p.full_name,
        'customer_email', p.email,
        -- 218: the path, not a link. The app signs it per read.
        'avatar_url', p.avatar_url,
        'points', t.points,
        'balance_after', t.balance_after,
        'reason', t.reason,
        'reference_type', t.reference_type,
        'reference_id', t.reference_id,
        'order_number', o.order_number,
        'reward_type', r.reward_type,
        'reward_product_name_ar', coalesce(rp.name_ar, rb.name_ar, rpl.name_ar),
        'reward_product_name_en', coalesce(rp.name_en, rb.name_en, rpl.name_en),
        'note', t.note,
        'created_at', t.created_at
      ) as entry
        from loyalty.loyalty_transactions t
        join identity.profiles p on p.id = t.user_id
        left join orders.orders o
          on t.reference_type = 'order' and o.id = t.reference_id
        left join loyalty.loyalty_rewards r
          on t.reference_type = 'reward' and r.id = t.reference_id
        left join catalog.products rp
          on r.reward_type = 'product' and rp.id = r.product_id
        left join catalog.bundles rb
          on r.reward_type = 'bundle' and rb.id = r.bundle_id
        left join subscriptions.plans rpl
          on r.reward_type = 'plan' and rpl.id = r.plan_id
       order by t.created_at desc
       limit v_limit
    ) rows;

  select count(*) into v_total from loyalty.loyalty_transactions;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$fn$;

comment on function public.admin_loyalty_transactions is
  'Newest points-ledger entries, with the order or reward each one refers to, '
  'and the member''s avatar path in the private avatars bucket (218).';

revoke all on function public.admin_loyalty_transactions(integer) from public, anon;
grant execute on function public.admin_loyalty_transactions(integer) to authenticated;

notify pgrst, 'reload schema';
