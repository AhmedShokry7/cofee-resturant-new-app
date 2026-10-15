-- 017_ai_01.sql
-- Local assistant knowledge. NOT exposed to PostgREST by design
-- (DATABASE_SPEC.md section 4): read only through an Edge Function.
--
-- Carries the content of product_knowledge.dart, coffee_knowledge.dart and
-- faq_knowledge.dart out of Dart constants into data.

create table if not exists ai.product_knowledge (
  product_id      uuid primary key references catalog.products(id) on delete cascade,
  ingredients     text[] not null default '{}',
  tags            text[] not null default '{}',
  allergens       text[] not null default '{}',
  flavor_notes_ar text,
  flavor_notes_en text,
  prep_notes_ar   text,
  prep_notes_en   text,
  updated_at      timestamptz not null default now()
);

comment on table ai.product_knowledge is
  'Assistant ingredient/tag knowledge per product. No LLM data is stored here.';

create index if not exists ix_ai_knowledge_ingredients
  on ai.product_knowledge using gin (ingredients);
create index if not exists ix_ai_knowledge_tags
  on ai.product_knowledge using gin (tags);

create trigger tr_ai_knowledge_updated_at
  before update on ai.product_knowledge
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists ai.knowledge_articles (
  id         uuid primary key default extensions.gen_random_uuid(),
  slug       text not null unique check (slug ~ '^[a-z0-9_]+$'),
  category   text not null default 'faq',
  title_ar   text not null,
  title_en   text not null,
  body_ar    text not null,
  body_en    text not null,
  keywords   text[] not null default '{}',
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table ai.knowledge_articles is
  'Help articles the local assistant can rank. Replaces the coffee/faq knowledge arrays.';

create index if not exists ix_knowledge_articles_category
  on ai.knowledge_articles (category, sort_order) where is_active;
create index if not exists ix_knowledge_articles_keywords
  on ai.knowledge_articles using gin (keywords);

create trigger tr_knowledge_articles_updated_at
  before update on ai.knowledge_articles
  for each row execute function core.set_updated_at();