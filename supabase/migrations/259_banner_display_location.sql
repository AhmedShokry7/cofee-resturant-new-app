-- Keep the home carousel and the in-page promotion slot independent.
alter table marketing.banners
  add column if not exists display_location text not null default 'hero';

alter table marketing.banners
  drop constraint if exists ck_banners_display_location;

alter table marketing.banners
  add constraint ck_banners_display_location
  check (display_location in ('hero', 'inline'));

create index if not exists ix_banners_location_order_published
  on marketing.banners (display_location, sort_order)
  where is_published;

-- Refresh the public bridge so clients can read/write the new column.
create or replace view public.banners with (security_invoker = true) as
  select * from marketing.banners;
