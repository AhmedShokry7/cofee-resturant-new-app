-- 163_subscription_demo_data.sql
-- Development demo data for the subscriptions screens.
--
-- The database is still under development, so the subscriptions page needs
-- representative rows to review: four plans, eight customers and their
-- subscriptions, with a usage log whose quantities add up to the cups every
-- subscription consumed.
--
-- Every statement is idempotent and keyed on a fixed id, code or idempotency
-- key, so applying the migration twice changes nothing. Usage rows point at
-- the first branch of the database and the first product when one exists, so
-- the seed never creates catalogue content.

-- ---------------------------------------------------------------------------
-- Plans.
-- ---------------------------------------------------------------------------
insert into subscriptions.plans (
  id, code, name_ar, name_en, description_ar, description_en,
  price, currency_code, duration_days, cups_per_cycle,
  bonus_type, bonus_value, bonus_expires_with_cycle,
  rollover_cap_cups, renewal_policy, auto_renew_supported,
  all_branches, product_scope, is_active, is_for_sale
)
values
  (
    '16300000-0000-4000-8000-0000000000a1', 'DEMO_WEEKLY',
    'الباقة الأسبوعية', 'Weekly plan',
    'سبعة أكواب من القهوة المختارة على مدار أسبوع كامل.',
    'Seven specialty coffee cups across a full week.',
    45, 'SAR', 7, 7,
    'none', 0, true,
    0, 'manual', false,
    true, 'all', true, true
  ),
  (
    '16300000-0000-4000-8000-0000000000a2', 'DEMO_BRONZE',
    'الباقة البرونزية', 'Bronze plan',
    'ثمانية أكواب شهريًا من القائمة الأساسية.',
    'Eight cups per month from the core menu.',
    99, 'SAR', 30, 8,
    'none', 0, true,
    0, 'manual', false,
    true, 'all', true, true
  ),
  (
    '16300000-0000-4000-8000-0000000000a3', 'DEMO_SILVER',
    'الباقة الفضية', 'Silver plan',
    'اثنا عشر كوبًا شهريًا مع ترحيل كوبين ومكافأة 5% على قيمة الباقة.',
    'Twelve cups per month with a two-cup rollover and a 5% bonus.',
    149, 'SAR', 30, 12,
    'percent', 5, true,
    2, 'auto', true,
    true, 'all', true, true
  ),
  (
    '16300000-0000-4000-8000-0000000000a4', 'DEMO_GOLD',
    'الباقة الذهبية', 'Gold plan',
    'عشرون كوبًا شهريًا مع ترحيل خمسة أكواب ومكافأة 25 ريالًا.',
    'Twenty cups per month with a five-cup rollover and a 25 SAR bonus.',
    249, 'SAR', 30, 20,
    'fixed', 25, true,
    5, 'auto', true,
    true, 'all', true, true
  )
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Demo customers. Only the columns the auth schema always has are written, so
-- the rows apply on a live project and on the migration replay alike. The
-- profile trigger creates the linked profile from the metadata.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data, created_at)
values
  ('16300000-0000-4000-8000-0000000000b1', 'sara.ali@demo.coffee',
   jsonb_build_object('full_name', 'سارة علي'), now() - interval '90 days'),
  ('16300000-0000-4000-8000-0000000000b2', 'ahmed.shokry@demo.coffee',
   jsonb_build_object('full_name', 'أحمد شكري'), now() - interval '75 days'),
  ('16300000-0000-4000-8000-0000000000b3', 'mona.adel@demo.coffee',
   jsonb_build_object('full_name', 'منى عادل'), now() - interval '40 days'),
  ('16300000-0000-4000-8000-0000000000b4', 'khaled.hassan@demo.coffee',
   jsonb_build_object('full_name', 'خالد حسن'), now() - interval '120 days'),
  ('16300000-0000-4000-8000-0000000000b5', 'nour.ibrahim@demo.coffee',
   jsonb_build_object('full_name', 'نور إبراهيم'), now() - interval '60 days'),
  ('16300000-0000-4000-8000-0000000000b6', 'omar.fathy@demo.coffee',
   jsonb_build_object('full_name', 'عمر فتحي'), now() - interval '30 days'),
  ('16300000-0000-4000-8000-0000000000b7', 'heba.mostafa@demo.coffee',
   jsonb_build_object('full_name', 'هبة مصطفى'), now() - interval '20 days'),
  ('16300000-0000-4000-8000-0000000000b8', 'youssef.kamal@demo.coffee',
   jsonb_build_object('full_name', 'يوسف كمال'), now() - interval '50 days')
on conflict do nothing;

insert into identity.profiles (id, full_name, email, phone, language)
values
  ('16300000-0000-4000-8000-0000000000b1', 'سارة علي', 'sara.ali@demo.coffee', '+966500000001', 'ar'),
  ('16300000-0000-4000-8000-0000000000b2', 'أحمد شكري', 'ahmed.shokry@demo.coffee', '+966500000002', 'ar'),
  ('16300000-0000-4000-8000-0000000000b3', 'منى عادل', 'mona.adel@demo.coffee', '+966500000003', 'ar'),
  ('16300000-0000-4000-8000-0000000000b4', 'خالد حسن', 'khaled.hassan@demo.coffee', '+966500000004', 'ar'),
  ('16300000-0000-4000-8000-0000000000b5', 'نور إبراهيم', 'nour.ibrahim@demo.coffee', '+966500000005', 'ar'),
  ('16300000-0000-4000-8000-0000000000b6', 'عمر فتحي', 'omar.fathy@demo.coffee', '+966500000006', 'ar'),
  ('16300000-0000-4000-8000-0000000000b7', 'هبة مصطفى', 'heba.mostafa@demo.coffee', '+966500000007', 'ar'),
  ('16300000-0000-4000-8000-0000000000b8', 'يوسف كمال', 'youssef.kamal@demo.coffee', '+966500000008', 'ar')
on conflict (id) do update set
  full_name = excluded.full_name,
  phone = excluded.phone,
  language = excluded.language;

-- ---------------------------------------------------------------------------
-- Subscriptions and their usage log. The cup counts are the source of truth:
-- every usage quantity adds up to the subscription's cups_used, and no active
-- subscription ends in the past.
-- ---------------------------------------------------------------------------
do $$
declare
  v_branch uuid;
  v_product uuid;
begin
  select id into v_branch
    from core.branches
   where is_active
   order by created_at
   limit 1;
  if v_branch is null then
    select id into v_branch from core.branches order by created_at limit 1;
  end if;
  if v_branch is null then
    if not exists (select 1 from core.brands) then
      insert into core.brands (id, name_ar, name_en)
      values ('16300000-0000-4000-8000-0000000000e0', 'كوفي هاوس', 'Coffee House')
      on conflict do nothing;
    end if;
    insert into core.branches (
      id, brand_id, code, name_ar, name_en, address, address_ar, address_en,
      is_active
    )
    values (
      '16300000-0000-4000-8000-0000000000e1',
      (select id from core.brands order by created_at limit 1),
      'DEMO', 'الفرع التجريبي', 'Demo branch',
      'Demo branch address', 'عنوان الفرع التجريبي', 'Demo branch address',
      true
    )
    on conflict do nothing;
    select id into v_branch from core.branches where code = 'DEMO';
  end if;

  select id into v_product
    from catalog.products
   where archived_at is null
   order by created_at
   limit 1;

  -- Active customers ------------------------------------------------------
  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c1',
    '16300000-0000-4000-8000-0000000000b1', p.id, 'active',
    now() - interval '12 days', now() + interval '18 days',
    20, 7, 0, 0,
    25, now() + interval '18 days', true,
    'DEMO-PAY-SARA', 'demo-sub-sara-gold', false,
    now() - interval '12 days'
  from subscriptions.plans p where p.code = 'DEMO_GOLD'
  on conflict do nothing;

  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c2',
    '16300000-0000-4000-8000-0000000000b2', p.id, 'active',
    now() - interval '26 days', now() + interval '4 days',
    12, 5, 2, 0,
    5, now() + interval '4 days', true,
    'DEMO-PAY-AHMED', 'demo-sub-ahmed-silver', false,
    now() - interval '26 days'
  from subscriptions.plans p where p.code = 'DEMO_SILVER'
  on conflict do nothing;

  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c6',
    '16300000-0000-4000-8000-0000000000b6', p.id, 'active',
    now() - interval '5 days', now() + interval '2 days',
    7, 2, 0, 0,
    0, now() + interval '2 days', false,
    'DEMO-PAY-OMAR', 'demo-sub-omar-weekly', false,
    now() - interval '5 days'
  from subscriptions.plans p where p.code = 'DEMO_WEEKLY'
  on conflict do nothing;

  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c7',
    '16300000-0000-4000-8000-0000000000b7', p.id, 'active',
    now() - interval '3 days', now() + interval '27 days',
    8, 0, 0, 0,
    0, now() + interval '27 days', false,
    'DEMO-PAY-HEBA', 'demo-sub-heba-bronze', false,
    now() - interval '3 days'
  from subscriptions.plans p where p.code = 'DEMO_BRONZE'
  on conflict do nothing;

  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c8',
    '16300000-0000-4000-8000-0000000000b8', p.id, 'active',
    now() - interval '9 days', now() + interval '21 days',
    20, 12, 0, 0,
    25, now() + interval '21 days', true,
    'DEMO-PAY-YOUSSEF', 'demo-sub-youssef-gold', false,
    now() - interval '9 days'
  from subscriptions.plans p where p.code = 'DEMO_GOLD'
  on conflict do nothing;

  -- Pending payment: the plan is reserved, no cups were issued yet. --------
  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, auto_renew, idempotency_key, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c3',
    '16300000-0000-4000-8000-0000000000b3', p.id, 'pending_payment',
    null, null,
    0, 0, 0, 0,
    0, false, 'demo-sub-mona-bronze', now() - interval '1 day'
  from subscriptions.plans p where p.code = 'DEMO_BRONZE'
  on conflict do nothing;

  -- Expired: the whole cycle was redeemed. ---------------------------------
  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c4',
    '16300000-0000-4000-8000-0000000000b4', p.id, 'expired',
    now() - interval '45 days', now() - interval '15 days',
    20, 20, 0, 0,
    0, now() - interval '15 days', false,
    'DEMO-PAY-KHALED', 'demo-sub-khaled-gold', true,
    now() - interval '45 days'
  from subscriptions.plans p where p.code = 'DEMO_GOLD'
  on conflict do nothing;

  -- Cancelled by the customer after three cups. ----------------------------
  insert into subscriptions.subscriptions (
    id, user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over, cups_reserved,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied, created_at
  )
  select
    '16300000-0000-4000-8000-0000000000c5',
    '16300000-0000-4000-8000-0000000000b5', p.id, 'cancelled',
    now() - interval '20 days', now() - interval '3 days',
    12, 3, 0, 0,
    0, now() - interval '3 days', false,
    'DEMO-PAY-NOUR', 'demo-sub-nour-silver', false,
    now() - interval '20 days'
  from subscriptions.plans p where p.code = 'DEMO_SILVER'
  on conflict do nothing;

  -- Usage log. Each row is a real redemption; the sums below match the
  -- cups_used of the subscription above it.
  insert into subscriptions.subscription_usage (
    id, subscription_id, branch_id, product_id, quantity, method,
    idempotency_key, created_at
  )
  values
    -- Sara: 2 + 3 + 2 = 7 of 20
    ('16300000-0000-4000-8000-d00000000001', '16300000-0000-4000-8000-0000000000c1', v_branch, v_product, 2, 'qr', 'demo-usage-sara-1', now() - interval '9 days'),
    ('16300000-0000-4000-8000-d00000000002', '16300000-0000-4000-8000-0000000000c1', v_branch, v_product, 3, 'app_order', 'demo-usage-sara-2', now() - interval '5 days'),
    ('16300000-0000-4000-8000-d00000000003', '16300000-0000-4000-8000-0000000000c1', v_branch, v_product, 2, 'qr', 'demo-usage-sara-3', now() - interval '1 day'),
    -- Ahmed: 3 + 2 = 5 of 14 (12 + 2 carried over)
    ('16300000-0000-4000-8000-d00000000004', '16300000-0000-4000-8000-0000000000c2', v_branch, v_product, 3, 'qr', 'demo-usage-ahmed-1', now() - interval '18 days'),
    ('16300000-0000-4000-8000-d00000000005', '16300000-0000-4000-8000-0000000000c2', v_branch, v_product, 2, 'qr', 'demo-usage-ahmed-2', now() - interval '6 days'),
    -- Omar: 1 + 1 = 2 of 7
    ('16300000-0000-4000-8000-d00000000006', '16300000-0000-4000-8000-0000000000c6', v_branch, v_product, 1, 'qr', 'demo-usage-omar-1', now() - interval '4 days'),
    ('16300000-0000-4000-8000-d00000000007', '16300000-0000-4000-8000-0000000000c6', v_branch, v_product, 1, 'app_order', 'demo-usage-omar-2', now() - interval '1 day'),
    -- Youssef: 4 + 4 + 4 = 12 of 20
    ('16300000-0000-4000-8000-d00000000008', '16300000-0000-4000-8000-0000000000c8', v_branch, v_product, 4, 'app_order', 'demo-usage-youssef-1', now() - interval '7 days'),
    ('16300000-0000-4000-8000-d00000000009', '16300000-0000-4000-8000-0000000000c8', v_branch, v_product, 4, 'qr', 'demo-usage-youssef-2', now() - interval '3 days'),
    ('16300000-0000-4000-8000-d00000000010', '16300000-0000-4000-8000-0000000000c8', v_branch, v_product, 4, 'qr', 'demo-usage-youssef-3', now() - interval '1 day'),
    -- Khaled: 8 + 6 + 6 = 20 of 20
    ('16300000-0000-4000-8000-d00000000011', '16300000-0000-4000-8000-0000000000c4', v_branch, v_product, 8, 'app_order', 'demo-usage-khaled-1', now() - interval '40 days'),
    ('16300000-0000-4000-8000-d00000000012', '16300000-0000-4000-8000-0000000000c4', v_branch, v_product, 6, 'qr', 'demo-usage-khaled-2', now() - interval '30 days'),
    ('16300000-0000-4000-8000-d00000000013', '16300000-0000-4000-8000-0000000000c4', v_branch, v_product, 6, 'manual', 'demo-usage-khaled-3', now() - interval '20 days'),
    -- Nour: 3 of 12 before cancelling
    ('16300000-0000-4000-8000-d00000000014', '16300000-0000-4000-8000-0000000000c5', v_branch, v_product, 3, 'qr', 'demo-usage-nour-1', now() - interval '10 days')
  on conflict do nothing;
end $$;
