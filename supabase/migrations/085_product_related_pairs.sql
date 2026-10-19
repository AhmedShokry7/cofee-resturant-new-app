alter table catalog.products add column if not exists related_product_ids uuid[] not null default '{}';
comment on column catalog.products.related_product_ids is 'Admin-defined companion products shown as Goes well with.';
