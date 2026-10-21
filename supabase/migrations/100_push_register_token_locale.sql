-- 100_push_register_token_locale.sql
--
-- The device language is needed to write the push in the language the phone
-- reads: the notification that Android shows in the tray is written by the
-- server, and the server does not know the language of the device. The app
-- does, so it sends it with the token.
--
-- The parameter is added to the existing function instead of a new one: the
-- app registers the token with one call, and a second function with the same
-- job would only give the two a reason to disagree.

create or replace function public.register_device_token(
  p_platform    text,
  p_token       text,
  p_app_version text default null,
  p_device_name text default null,
  p_locale      text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_user uuid := auth.uid();
  v_id   uuid;
begin
  if v_user is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;

  if p_platform is null or p_platform not in ('android','ios','web') then
    raise exception 'Unsupported platform.' using errcode = '22023';
  end if;

  if p_token is null or length(trim(p_token)) < 8 then
    raise exception 'Invalid token.' using errcode = '22023';
  end if;

  insert into engagement.device_tokens
    (user_id, platform, token, app_version, device_name, locale, last_seen_at)
  values
    (v_user, p_platform, p_token, p_app_version, p_device_name, p_locale, now())
  on conflict (platform, token) do update
    set user_id       = excluded.user_id,
        app_version   = excluded.app_version,
        device_name   = excluded.device_name,
        locale        = excluded.locale,
        last_seen_at  = now()
  returning id into v_id;

  return v_id;
end;
$fn$;

comment on function public.register_device_token(text, text, text, text, text) is
  'Stores the FCM token of the signed-in customer and moves it to that '
  'customer when the device changed accounts.';

grant execute on function public.register_device_token(text, text, text, text, text)
  to authenticated;

revoke execute on function public.register_device_token(text, text, text, text, text)
  from public, anon;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
