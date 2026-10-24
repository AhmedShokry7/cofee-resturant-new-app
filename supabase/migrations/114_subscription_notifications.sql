-- The app already sends p_locale with token registration. The earlier RPC did
-- not accept it, so PostgREST rejected every registration and the device locale
-- remained empty. This overload stores the locale while retaining the old RPC.
create or replace function public.register_device_token(
  p_platform text,
  p_token text,
  p_app_version text default null,
  p_device_name text default null,
  p_locale text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_user uuid := auth.uid();
  v_id uuid;
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
    (v_user, p_platform, p_token, p_app_version, p_device_name,
     case when lower(coalesce(p_locale, '')) like 'ar%' then 'ar'
          when lower(coalesce(p_locale, '')) like 'en%' then 'en'
          else null end,
     now())
  on conflict (platform, token) do update
    set user_id = excluded.user_id,
        app_version = excluded.app_version,
        device_name = excluded.device_name,
        locale = excluded.locale,
        last_seen_at = now()
  returning id into v_id;
  return v_id;
end;
$fn$;

grant execute on function public.register_device_token(text, text, text, text, text) to authenticated;
revoke execute on function public.register_device_token(text, text, text, text, text) from public, anon;

-- Subscription lifecycle and expiry reminders are stored in the same in-app inbox
-- as order updates, then dispatched through the existing push trigger.

alter table engagement.notifications
  drop constraint if exists notifications_type_check;
alter table engagement.notifications
  add constraint notifications_type_check
  check (type in ('order_status','promo','system','loyalty','subscription'));

create or replace function engagement.notify_subscription_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_title_ar text;
  v_title_en text;
  v_body_ar text;
  v_body_en text;
  v_key text;
begin
  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;
  if new.status not in ('active','expired','cancelled') then
    return new;
  end if;

  if new.status = 'active' then
    v_title_ar := 'تم تفعيل اشتراكك';
    v_title_en := 'Your subscription is active';
    v_body_ar := 'يمكنك الآن استخدام أكواب اشتراكك حتى تاريخ الانتهاء.';
    v_body_en := 'You can now use your subscription cups until the end date.';
  elsif new.status = 'expired' then
    v_title_ar := 'انتهى اشتراكك';
    v_title_en := 'Your subscription has expired';
    v_body_ar := 'انتهت صلاحية اشتراكك. تصفح الباقات لتجديده.';
    v_body_en := 'Your subscription has ended. Browse plans to renew it.';
  else
    v_title_ar := 'تم إلغاء اشتراكك';
    v_title_en := 'Your subscription was cancelled';
    v_body_ar := 'تم إلغاء اشتراكك بنجاح.';
    v_body_en := 'Your subscription was cancelled successfully.';
  end if;
  v_key := 'subscription:' || new.id::text || ':' || new.status || ':' || new.ends_at::date::text;

  insert into engagement.notifications
    (user_id, type, title_ar, title_en, body_ar, body_en,
     related_entity_type, related_entity_id, dedupe_key)
  values
    (new.user_id, 'subscription', v_title_ar, v_title_en, v_body_ar, v_body_en,
     'subscription', new.id, v_key)
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  return new;
end;
$fn$;

drop trigger if exists tr_subscription_status_notification on subscriptions.subscriptions;
create trigger tr_subscription_status_notification
  after insert or update of status on subscriptions.subscriptions
  for each row execute function engagement.notify_subscription_status();

create or replace function engagement.process_subscription_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer := 0;
  v_row record;
begin
  -- Expiry status change raises the lifecycle notification trigger above.
  update subscriptions.subscriptions
     set status = 'expired', auto_renew = false
   where status = 'active' and ends_at <= now();

  for v_row in
    select id, user_id, ends_at,
           case when ends_at <= now() + interval '1 day' then '1d' else '3d' end as reminder
      from subscriptions.subscriptions
     where status = 'active'
       and ((ends_at > now() + interval '2 days' and ends_at <= now() + interval '3 days')
         or (ends_at > now() and ends_at <= now() + interval '1 day'))
  loop
    insert into engagement.notifications
      (user_id, type, title_ar, title_en, body_ar, body_en,
       related_entity_type, related_entity_id, dedupe_key)
    values
      (v_row.user_id, 'subscription',
       'اشتراكك على وشك الانتهاء', 'Your subscription is ending soon',
       case when v_row.reminder = '1d' then 'يتبقى يوم واحد على انتهاء اشتراكك.' else 'يتبقى 3 أيام على انتهاء اشتراكك.' end,
       case when v_row.reminder = '1d' then 'Your subscription expires in one day.' else 'Your subscription expires in 3 days.' end,
       'subscription', v_row.id,
       'subscription:' || v_row.id::text || ':reminder_' || v_row.reminder || ':' || v_row.ends_at::date::text)
    on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
    if found then v_count := v_count + 1; end if;
  end loop;
  return v_count;
end;
$fn$;

-- Refresh this hourly; each reminder has a per-subscription dedupe key.
do $$
declare j record;
begin
  for j in select jobid from cron.job where jobname = 'subscription-notification-schedule' loop
    perform cron.unschedule(j.jobid);
  end loop;
end $$;
select cron.schedule(
  'subscription-notification-schedule',
  '0 * * * *',
  $job$select engagement.process_subscription_notifications();$job$
);

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
