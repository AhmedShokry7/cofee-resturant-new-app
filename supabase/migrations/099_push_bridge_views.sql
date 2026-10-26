-- 099_push_bridge_views.sql
--
-- The Edge Function reads and writes through the public schema, because that
-- is what PostgREST serves on this project: a path like
-- /rest/v1/engagement.device_tokens is not resolved here, the unqualified
-- name of the public view is.
--
-- Two things are missing for that:
--
--   1. public.device_tokens was created with `select *` before the locale
--      column existed, and a view freezes its column list at creation time.
--      The view is therefore rebuilt with the column list written out, so the
--      Edge Function can read the language of the device. A view cannot be
--      replaced when a column is added in the middle, so it is dropped and
--      created again; the grants are restored right after.
--
--   2. public.push_deliveries does not exist yet. The delivery log is
--      written by the Edge Function, so it needs the same bridge as the other
--      engagement tables.

drop view if exists public.device_tokens;

create view public.device_tokens with (security_invoker = true) as
  select id,
         user_id,
         platform,
         token,
         app_version,
         device_name,
         locale,
         last_seen_at,
         created_at
    from engagement.device_tokens;

comment on view public.device_tokens is
  'Bridge to engagement.device_tokens. The column list is written out because '
  'a view cannot gain a column in the middle.';

grant select, insert, update, delete on public.device_tokens to authenticated;
grant select, insert, update, delete on public.device_tokens to service_role;
revoke all on public.device_tokens from anon;

-- On a fresh replay the delivery log is created by 104 (the renamed push
-- migration) after this file, so the view can only be created when the table
-- already exists. 104 repeats both statements at the end.
do $$
begin
  if to_regclass('engagement.push_deliveries') is not null then
    execute $sql$
      create or replace view public.push_deliveries
        with (security_invoker = true) as
        select * from engagement.push_deliveries
    $sql$;
    execute $sql$
      comment on view public.push_deliveries is
        'Bridge to engagement.push_deliveries. Written by the send-push Edge Function.'
    $sql$;
    execute 'grant select on public.push_deliveries to service_role';
    execute 'revoke all on public.push_deliveries from anon, authenticated';
  end if;
end;
$$;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
