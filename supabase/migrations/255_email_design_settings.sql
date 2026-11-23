-- Editable email appearance shared by Auth OTP and customer notification mail.
create table if not exists public.email_design_settings (
  id text primary key check (id = 'default'),
  config jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

insert into public.email_design_settings (id, config)
values (
  'default',
  '{
    "brandName":"New Coffee",
    "logoUrl":"",
    "primaryColor":"#078A75",
    "backgroundColor":"#F3F6F5",
    "surfaceColor":"#FFFFFF",
    "textColor":"#172522",
    "footerAr":"\u0647\u0630\u0647\u0020\u0631\u0633\u0627\u0644\u0629\u0020\u0622\u0644\u064a\u0629\u0020\u0645\u0646\u0020New\u0020Coffee.",
    "footerEn":"This is an automated message from New Coffee.",
    "signupSubjectAr":"\u062a\u0623\u0643\u064a\u062f\u0020\u0627\u0644\u0628\u0631\u064a\u062f\u0020\u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a\u0020|\u0020New\u0020Coffee",
    "signupSubjectEn":"New Coffee | Confirm your email",
    "signupTitleAr":"\u062a\u0623\u0643\u064a\u062f\u0020\u0628\u0631\u064a\u062f\u0643\u0020\u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a",
    "signupTitleEn":"Confirm your email",
    "signupBodyAr":"\u0623\u062f\u062e\u0644\u0020\u0631\u0645\u0632\u0020\u0627\u0644\u062a\u062d\u0642\u0642\u0020\u0627\u0644\u062a\u0627\u0644\u064a\u0020\u0641\u064a\u0020\u0627\u0644\u062a\u0637\u0628\u064a\u0642\u0020\u0644\u0625\u0643\u0645\u0627\u0644\u0020\u0625\u0646\u0634\u0627\u0621\u0020\u062d\u0633\u0627\u0628\u0643.",
    "signupBodyEn":"Enter the code below to finish creating your account."
  }'::jsonb
)
on conflict (id) do nothing;

alter table public.email_design_settings enable row level security;
revoke all on table public.email_design_settings from anon, authenticated;
grant all on table public.email_design_settings to service_role;

create or replace function public.admin_email_design_get()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_config jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage'
      using errcode = '42501';
  end if;

  select config into v_config
    from public.email_design_settings
   where id = 'default';
  return coalesce(v_config, '{}'::jsonb);
end;
$fn$;

create or replace function public.admin_email_design_save(p_config jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_config jsonb;
  v_key text;
  v_value text;
begin
  if not identity.is_staff()
     or not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage'
      using errcode = '42501';
  end if;
  if p_config is null or jsonb_typeof(p_config) <> 'object' then
    raise exception 'email design config must be an object'
      using errcode = '22023';
  end if;

  foreach v_key in array array[
    'brandName', 'logoUrl', 'primaryColor', 'backgroundColor',
    'surfaceColor', 'textColor', 'footerAr', 'footerEn',
    'signupSubjectAr', 'signupSubjectEn', 'signupTitleAr', 'signupTitleEn',
    'signupBodyAr', 'signupBodyEn'
  ] loop
    v_value := coalesce(p_config->>v_key, '');
    if char_length(v_value) > (case
      when v_key in ('signupBodyAr', 'signupBodyEn', 'footerAr', 'footerEn')
        then 1200
      when v_key = 'logoUrl' then 500
      else 180
    end) then
      raise exception 'email design field % is too long', v_key
        using errcode = '22023';
    end if;
  end loop;

  if coalesce(p_config->>'brandName', '') = '' then
    raise exception 'brand name is required' using errcode = '22023';
  end if;
  foreach v_key in array array[
    'primaryColor', 'backgroundColor', 'surfaceColor', 'textColor'
  ] loop
    if coalesce(p_config->>v_key, '') !~ '^#[0-9A-Fa-f]{6}$' then
      raise exception 'invalid color for %', v_key using errcode = '22023';
    end if;
  end loop;
  v_value := nullif(btrim(coalesce(p_config->>'logoUrl', '')), '');
  if v_value is not null and v_value !~ '^https://[^[:space:]]+$' then
    raise exception 'logo URL must use HTTPS' using errcode = '22023';
  end if;

  v_config := jsonb_build_object(
    'brandName', btrim(p_config->>'brandName'),
    'logoUrl', coalesce(v_value, ''),
    'primaryColor', upper(p_config->>'primaryColor'),
    'backgroundColor', upper(p_config->>'backgroundColor'),
    'surfaceColor', upper(p_config->>'surfaceColor'),
    'textColor', upper(p_config->>'textColor'),
    'footerAr', btrim(coalesce(p_config->>'footerAr', '')),
    'footerEn', btrim(coalesce(p_config->>'footerEn', '')),
    'signupSubjectAr', btrim(coalesce(p_config->>'signupSubjectAr', '')),
    'signupSubjectEn', btrim(coalesce(p_config->>'signupSubjectEn', '')),
    'signupTitleAr', btrim(coalesce(p_config->>'signupTitleAr', '')),
    'signupTitleEn', btrim(coalesce(p_config->>'signupTitleEn', '')),
    'signupBodyAr', btrim(coalesce(p_config->>'signupBodyAr', '')),
    'signupBodyEn', btrim(coalesce(p_config->>'signupBodyEn', ''))
  );

  insert into public.email_design_settings (id, config, updated_at, updated_by)
  values ('default', v_config, now(), auth.uid())
  on conflict (id) do update
    set config = excluded.config,
        updated_at = excluded.updated_at,
        updated_by = excluded.updated_by;
  return v_config;
end;
$fn$;

revoke all on function public.admin_email_design_get() from public, anon;
revoke all on function public.admin_email_design_save(jsonb) from public, anon;
grant execute on function public.admin_email_design_get() to authenticated;
grant execute on function public.admin_email_design_save(jsonb) to authenticated;

comment on table public.email_design_settings is
  'Admin-editable shared look and signup OTP copy for customer e-mails.';
