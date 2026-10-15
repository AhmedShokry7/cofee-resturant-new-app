-- 015_marketing_01.sql
-- Banners and coupons.
--
-- CouponModel stored the discount as display text ("Get 50% OFF") and
-- CheckoutCubit scraped the percentage out of it with a regex
-- (checkout_cubit.dart:68). discount_value is a real number here.

create table if not exists marketing.banners (
  id             uuid primary key default extensions.gen_random_uuid(),
  title_ar       text not null,
  title_en       text not null,
  subtitle_ar    text,
  subtitle_en    text,
  description_ar text,
  description_en text,
  image_url      text not null,
  cta_label_ar   text,
  cta_label_en   text,
  -- replaces BannerModel.targetCategory, which was a raw English string
  target_type    text not null default 'category'
                   check (target_type in ('category','product','bundle','url','none')),
  target_id      uuid,
  target_url     text,
  sort_order     integer not null default 0,
  starts_at      timestamptz,
  ends_at        timestamptz,
  is_published   boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint ck_banners_window check (
    ends_at is null or starts_at is null or ends_at > starts_at
  ),
  constraint ck_banners_target check (
    (target_type in ('none','url') and target_id is null)
    or (target_type in ('category','product','bundle') and target_id is not null)
  ),
  constraint ck_banners_url check (
    target_type <> 'url' or target_url is not null
  )
);

comment on table marketing.banners is
  'Home banners with ordering, publishing window and a typed target.';

-- Partial index on the immutable predicate only. now() is STABLE, not
-- IMMUTABLE, so the publish window (starts_at/ends_at) is filtered at query
-- time by catalog's banner reader rather than baked into the index.
create index if not exists ix_banners_published
  on marketing.banners (sort_order)
  where is_published;

create index if not exists ix_banners_window
  on marketing.banners (starts_at, ends_at)
  where is_published;

create trigger tr_banners_updated_at
  before update on marketing.banners
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists marketing.coupons (
  id               uuid primary key default extensions.gen_random_uuid(),
  code             text not null unique check (code = upper(code)),
  title_ar         text not null,
  title_en         text not null,
  description_ar   text,
  description_en   text,
  discount_type    text not null check (discount_type in ('percentage','fixed_amount')),
  discount_value   numeric(12,2) not null check (discount_value > 0),
  max_discount     numeric(12,2) check (max_discount > 0),
  min_order_amount numeric(12,2) not null default 0 check (min_order_amount >= 0),
  applies_to       text not null default 'all'
                     check (applies_to in ('all','category','product')),
  usage_limit      integer check (usage_limit > 0),
  per_user_limit   integer not null default 1 check (per_user_limit > 0),
  starts_at        timestamptz,
  ends_at          timestamptz,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint ck_coupons_pct_range check (
    discount_type <> 'percentage' or discount_value <= 100
  ),
  constraint ck_coupons_window check (
    ends_at is null or starts_at is null or ends_at > starts_at
  )
);

comment on table marketing.coupons is
  'Coupons with a real numeric discount. min_order_amount is actually enforced by validate_coupon().';

create index if not exists ix_coupons_active
  on marketing.coupons (code) where is_active;

create trigger tr_coupons_updated_at
  before update on marketing.coupons
  for each row execute function core.set_updated_at();

create table if not exists marketing.coupons_categories (
  coupon_id   uuid not null references marketing.coupons(id) on delete cascade,
  category_id uuid not null references catalog.categories(id) on delete cascade,
  primary key (coupon_id, category_id)
);

comment on table marketing.coupons_categories is
  'Restricts a category-scoped coupon to specific categories.';

-- ---------------------------------------------------------------------------
create table if not exists marketing.coupon_redemptions (
  id         uuid primary key default extensions.gen_random_uuid(),
  coupon_id  uuid not null references marketing.coupons(id) on delete restrict,
  user_id    uuid not null references identity.profiles(id) on delete cascade,
  order_id   uuid not null references orders.orders(id) on delete cascade,
  amount     numeric(12,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique (coupon_id, order_id)
);

comment on table marketing.coupon_redemptions is
  'A coupon may be applied once per order, and per_user_limit times per user.';

create index if not exists ix_coupon_redemptions_coupon_user
  on marketing.coupon_redemptions (coupon_id, user_id);
create index if not exists ix_coupon_redemptions_order
  on marketing.coupon_redemptions (order_id);