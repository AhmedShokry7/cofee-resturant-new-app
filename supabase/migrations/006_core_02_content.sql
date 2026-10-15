-- 006_core_02_content.sql
-- Editorial content that currently lives as Dart constants:
--   privacy_policy_text.dart -> legal_documents
--   faqs_list.dart (5)       -> faq_items
--   on_boarding_list.dart(3) -> onboarding_slides

create table if not exists core.legal_documents (
  id           uuid primary key default extensions.gen_random_uuid(),
  slug         text not null unique check (slug ~ '^[a-z_]+$'),
  title_ar     text not null,
  title_en     text not null,
  content_ar   text not null,
  content_en   text not null,
  version      text not null default '1.0',
  is_published boolean not null default false,
  published_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table core.legal_documents is
  'Privacy policy, terms, and similar long-form bilingual documents.';

create index if not exists ix_legal_published
  on core.legal_documents (slug) where is_published;

create trigger tr_legal_updated_at
  before update on core.legal_documents
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists core.faq_items (
  id          uuid primary key default extensions.gen_random_uuid(),
  category    text not null default 'general',
  question_ar text not null,
  question_en text not null,
  answer_ar   text not null,
  answer_en   text not null,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table core.faq_items is
  'Help centre entries. Bilingual by construction (D4).';

create index if not exists ix_faq_sort on core.faq_items (sort_order) where is_active;

create trigger tr_faq_updated_at
  before update on core.faq_items
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists core.onboarding_slides (
  id         uuid primary key default extensions.gen_random_uuid(),
  image_url  text not null,
  title_ar   text not null,
  title_en   text not null,
  body_ar    text not null,
  body_en    text not null,
  sort_order integer not null,
  is_active  boolean not null default true
);

comment on table core.onboarding_slides is
  'Onboarding carousel. Order is explicit, not array position.';

create index if not exists ix_onboarding_sort
  on core.onboarding_slides (sort_order) where is_active;