-- 016_engagement_01.sql
-- Reviews, in-app notifications, preferences and device tokens.

create table if not exists engagement.product_reviews (
  id           uuid primary key default extensions.gen_random_uuid(),
  product_id   uuid not null references catalog.products(id) on delete cascade,
  user_id      uuid not null references identity.profiles(id) on delete cascade,
  order_id     uuid references orders.orders(id) on delete set null,
  rating       integer not null check (rating between 1 and 5),
  title_ar     text,
  title_en     text,
  body_ar      text,
  body_en      text,
  is_published boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (product_id, user_id)
);

comment on table engagement.product_reviews is
  'One review per customer per product. order_id links a verified purchase.';

create index if not exists ix_reviews_product
  on engagement.product_reviews (product_id, created_at desc) where is_published;
create index if not exists ix_reviews_user
  on engagement.product_reviews (user_id, created_at desc);

create trigger tr_reviews_updated_at
  before update on engagement.product_reviews
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- In-app notifications. Push delivery is deferred; these rows are the
-- record that a future Edge Function would send from.
-- ---------------------------------------------------------------------------
create table if not exists engagement.notifications (
  id                 uuid primary key default extensions.gen_random_uuid(),
  user_id            uuid not null references identity.profiles(id) on delete cascade,
  type               text not null check (type in ('order_status','promo','system','loyalty')),
  title_ar           text not null,
  title_en           text not null,
  body_ar            text not null,
  body_en            text not null,
  payload            jsonb not null default '{}'::jsonb,
  related_entity_type text,
  related_entity_id   uuid,
  is_read            boolean not null default false,
  read_at            timestamptz,
  -- stops the same notification being generated twice
  dedupe_key         text,
  created_at         timestamptz not null default now(),
  constraint ck_notifications_read_at check (
    (not is_read) or read_at is not null
  )
);

comment on table engagement.notifications is
  'In-app notification log. Written server-side only. dedupe_key prevents duplicates.';

create index if not exists ix_notifications_user
  on engagement.notifications (user_id, is_read, created_at desc);
create unique index if not exists uq_notifications_dedupe
  on engagement.notifications (user_id, dedupe_key)
  where dedupe_key is not null;

-- ---------------------------------------------------------------------------
create table if not exists engagement.notification_preferences (
  user_id      uuid primary key references identity.profiles(id) on delete cascade,
  order_status boolean not null default true,
  promo        boolean not null default true,
  loyalty      boolean not null default true,
  system       boolean not null default true,
  push_enabled boolean not null default false,
  updated_at   timestamptz not null default now()
);

comment on table engagement.notification_preferences is
  'Per-user notification opt-ins. push_enabled is reserved for the deferred push phase.';

create trigger tr_notification_prefs_updated_at
  before update on engagement.notification_preferences
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists engagement.device_tokens (
  id           uuid primary key default extensions.gen_random_uuid(),
  user_id      uuid not null references identity.profiles(id) on delete cascade,
  platform     text not null check (platform in ('ios','android','web')),
  token        text not null,
  app_version  text,
  device_name  text,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (platform, token)
);

comment on table engagement.device_tokens is
  'Push device tokens, stored in advance. Sending requires a server-side Edge Function.';

create index if not exists ix_device_tokens_user
  on engagement.device_tokens (user_id);