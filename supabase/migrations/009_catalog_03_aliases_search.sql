-- 009_catalog_03_aliases_search.sql
--
-- Search (decision D6): pg_trgm over core.normalize_ar() output.
--
-- Why these tables exist: today Arabic search works only because
-- SearchCubit borrows AssistantPhrases.productSynonyms (about 50 hard-coded
-- Arabic -> English pairs in assistant_phrases.dart:282-308). Search depends
-- on the assistant layer. These tables move that vocabulary into data, so
-- search stops depending on the chatbot.

create table if not exists catalog.product_aliases (
  id               uuid primary key default extensions.gen_random_uuid(),
  product_id       uuid not null references catalog.products(id) on delete cascade,
  alias            text not null check (length(btrim(alias)) > 0),
  locale           text not null default 'ar' check (locale in ('ar','en')),
  alias_normalized text not null,
  created_at       timestamptz not null default now(),
  unique (product_id, alias_normalized)
);

comment on table catalog.product_aliases is
  'Search aliases per product. alias_normalized is maintained by trigger.';

create index if not exists ix_product_aliases_trgm
  on catalog.product_aliases using gin (alias_normalized gin_trgm_ops);
create index if not exists ix_product_aliases_product
  on catalog.product_aliases (product_id);

create table if not exists catalog.category_aliases (
  id               uuid primary key default extensions.gen_random_uuid(),
  category_id      uuid not null references catalog.categories(id) on delete cascade,
  alias            text not null check (length(btrim(alias)) > 0),
  locale           text not null default 'ar' check (locale in ('ar','en')),
  alias_normalized text not null,
  created_at       timestamptz not null default now(),
  unique (category_id, alias_normalized)
);

comment on table catalog.category_aliases is
  'Search aliases per category. Replaces the categoryBoosts map.';

create index if not exists ix_category_aliases_trgm
  on catalog.category_aliases using gin (alias_normalized gin_trgm_ops);

-- Keep alias_normalized in sync no matter who writes.
create or replace function catalog.sync_alias_normalized()
returns trigger
language plpgsql
as $fn$
begin
  new.alias_normalized := core.normalize_ar(new.alias);
  return new;
end;
$fn$;

drop trigger if exists tr_product_aliases_norm on catalog.product_aliases;
create trigger tr_product_aliases_norm
  before insert or update of alias on catalog.product_aliases
  for each row execute function catalog.sync_alias_normalized();

drop trigger if exists tr_category_aliases_norm on catalog.category_aliases;
create trigger tr_category_aliases_norm
  before insert or update of alias on catalog.category_aliases
  for each row execute function catalog.sync_alias_normalized();

-- ---------------------------------------------------------------------------
-- Search documents. A trigger keeps these in sync; no scheduled rebuild and
-- no View, so the index stays usable for ILIKE and trigram matching.
-- ---------------------------------------------------------------------------
create table if not exists catalog.product_search (
  product_id    uuid primary key references catalog.products(id) on delete cascade,
  body_norm     text not null default '',
  keywords_norm text[] not null default '{}',
  updated_at    timestamptz not null default now()
);

comment on table catalog.product_search is
  'Denormalised search document per product. Maintained by trigger, read by search_products().';

create index if not exists ix_product_search_body_trgm
  on catalog.product_search using gin (body_norm gin_trgm_ops);
create index if not exists ix_product_search_keywords
  on catalog.product_search using gin (keywords_norm);

create table if not exists catalog.category_search (
  category_id   uuid primary key references catalog.categories(id) on delete cascade,
  body_norm     text not null default '',
  updated_at    timestamptz not null default now()
);

comment on table catalog.category_search is
  'Denormalised search document per category.';

create index if not exists ix_category_search_body_trgm
  on catalog.category_search using gin (body_norm gin_trgm_ops);

create or replace function catalog.rebuild_product_search(p_product uuid)
returns void
language sql
as $fn$
  insert into catalog.product_search (product_id, body_norm, keywords_norm, updated_at)
  select
    p.id,
    core.normalize_ar(
      coalesce(p.name_ar,'') || ' ' || coalesce(p.name_en,'') || ' ' ||
      coalesce(p.description_ar,'') || ' ' || coalesce(p.description_en,'') || ' ' ||
      coalesce(p.sku,'') || ' ' ||
      coalesce(c.name_ar,'') || ' ' || coalesce(c.name_en,'') || ' ' ||
      coalesce((select string_agg(a.alias, ' ')
                from catalog.product_aliases a where a.product_id = p.id), '')
    ),
    array_remove(array[
      core.normalize_ar(p.name_ar),
      core.normalize_ar(p.name_en),
      core.normalize_ar(c.name_ar),
      core.normalize_ar(c.name_en)
    ]::text[], ''),
    now()
  from catalog.products p
  join catalog.categories c on c.id = p.category_id
  where p.id = p_product
  on conflict (product_id) do update
    set body_norm = excluded.body_norm,
        keywords_norm = excluded.keywords_norm,
        updated_at = now();
$fn$;

comment on function catalog.rebuild_product_search(uuid) is
  'Rebuild one product search document. Called by triggers and after seed.';

create or replace function catalog.rebuild_category_search(p_category uuid)
returns void
language sql
as $fn$
  insert into catalog.category_search (category_id, body_norm, updated_at)
  select
    c.id,
    core.normalize_ar(
      coalesce(c.name_ar,'') || ' ' || coalesce(c.name_en,'') || ' ' ||
      coalesce(c.description_ar,'') || ' ' || coalesce(c.description_en,'') || ' ' ||
      coalesce((select string_agg(a.alias, ' ')
                from catalog.category_aliases a where a.category_id = c.id), '')
    ),
    now()
  from catalog.categories c
  where c.id = p_category
  on conflict (category_id) do update
    set body_norm = excluded.body_norm,
        updated_at = now();
$fn$;

create or replace function catalog.trg_product_search()
returns trigger
language plpgsql
as $fn$
begin
  perform catalog.rebuild_product_search(coalesce(new.id, old.id));
  return null;
end;
$fn$;

create or replace function catalog.trg_category_search()
returns trigger
language plpgsql
as $fn$
begin
  perform catalog.rebuild_category_search(coalesce(new.id, old.id));
  return null;
end;
$fn$;

-- Products: rebuild on insert/update, plus when the category name changes.
drop trigger if exists tr_products_search on catalog.products;
create trigger tr_products_search
  after insert or update on catalog.products
  for each row execute function catalog.trg_product_search();

drop trigger if exists tr_categories_search on catalog.categories;
create trigger tr_categories_search
  after insert or update on catalog.categories
  for each row execute function catalog.trg_category_search();

-- Alias changes must rebuild the affected document too.
drop trigger if exists tr_product_aliases_search on catalog.product_aliases;
create trigger tr_product_aliases_search
  after insert or update or delete on catalog.product_aliases
  for each row execute function catalog.trg_product_search();

drop trigger if exists tr_category_aliases_search on catalog.category_aliases;
create trigger tr_category_aliases_search
  after insert or update or delete on catalog.category_aliases
  for each row execute function catalog.trg_category_search();

-- One backfill for anything inserted before these triggers existed.
insert into catalog.product_search (product_id, body_norm, keywords_norm, updated_at)
select p.id, core.normalize_ar(
         coalesce(p.name_ar,'') || ' ' || coalesce(p.name_en,'') || ' ' ||
         coalesce(p.description_ar,'') || ' ' || coalesce(p.description_en,'') || ' ' ||
         coalesce(p.sku,'') || ' ' || coalesce(c.name_ar,'') || ' ' || coalesce(c.name_en,'')),
       array_remove(array[
                          core.normalize_ar(p.name_ar),
                          core.normalize_ar(p.name_en),
                          core.normalize_ar(c.name_ar),
                          core.normalize_ar(c.name_en)
                        ]::text[], ''),
       now()
  from catalog.products p
  join catalog.categories c on c.id = p.category_id
  on conflict (product_id) do nothing;

insert into catalog.category_search (category_id, body_norm, updated_at)
select c.id, core.normalize_ar(
         coalesce(c.name_ar,'') || ' ' || coalesce(c.name_en,'') || ' ' ||
         coalesce(c.description_ar,'') || ' ' || coalesce(c.description_en,'')), now()
  from catalog.categories c
  on conflict (category_id) do nothing;