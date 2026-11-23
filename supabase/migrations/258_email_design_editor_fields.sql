-- Expand the editable customer email design while keeping an uploaded logo
-- override separate from the app logo used when the override is empty.
create or replace function public.admin_email_design_get()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_config jsonb;
  v_app_logo text;
  v_app_name_ar text;
  v_app_name_en text;
begin
  if not identity.is_staff()
     or not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage'
      using errcode = '42501';
  end if;

  select config into v_config
    from public.email_design_settings
   where id = 'default';

  select s.value #>> '{theme,brand,logo_url}',
         s.value #>> '{theme,brand,name_ar}',
         s.value #>> '{theme,brand,name_en}'
    into v_app_logo, v_app_name_ar, v_app_name_en
    from core.app_settings s
   where s.key = 'app_design_published';

  return coalesce(v_config, '{}'::jsonb)
    || jsonb_build_object(
      'logoUrl', coalesce(nullif(v_config->>'logoUrl', ''), v_app_logo, ''),
      'appNameAr', coalesce(nullif(v_config->>'appNameAr', ''), v_app_name_ar, 'New Coffee'),
      'appNameEn', coalesce(nullif(v_config->>'appNameEn', ''), v_app_name_en, 'New Coffee')
    );
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
    'appNameAr', 'appNameEn', 'logoUrl', 'logoWidth', 'cardRadius',
    'layoutStyle', 'showLogo', 'primaryColor', 'backgroundColor',
    'surfaceColor', 'textColor', 'buttonColor', 'otpCodeColor',
    'footerAr', 'footerEn', 'signupSubjectAr', 'signupSubjectEn',
    'signupTitleAr', 'signupTitleEn', 'signupBodyAr', 'signupBodyEn',
    'otpLabelAr', 'otpLabelEn'
  ] loop
    v_value := coalesce(p_config->>v_key, '');
    if char_length(v_value) > (case
      when v_key in ('signupBodyAr', 'signupBodyEn', 'footerAr', 'footerEn') then 1200
      when v_key = 'logoUrl' then 2048
      else 180
    end) then
      raise exception 'email design field % is too long', v_key
        using errcode = '22023';
    end if;
  end loop;

  foreach v_key in array array['appNameAr', 'appNameEn'] loop
    if coalesce(btrim(p_config->>v_key), '') = '' then
      raise exception 'email app name is required for %', v_key
        using errcode = '22023';
    end if;
  end loop;

  foreach v_key in array array[
    'primaryColor', 'backgroundColor', 'surfaceColor', 'textColor',
    'buttonColor', 'otpCodeColor'
  ] loop
    if coalesce(p_config->>v_key, '') !~ '^#[0-9A-Fa-f]{6}$' then
      raise exception 'invalid color for %', v_key using errcode = '22023';
    end if;
  end loop;

  v_value := nullif(btrim(coalesce(p_config->>'logoUrl', '')), '');
  if v_value is not null and v_value !~ '^https://[^[:space:]]+$' then
    raise exception 'logo URL must use HTTPS' using errcode = '22023';
  end if;
  if coalesce(p_config->>'logoWidth', '') !~ '^(48|[5-9][0-9]|[12][0-9]{2}|3[01][0-9]|320)$' then
    raise exception 'logo width must be between 48 and 320' using errcode = '22023';
  end if;
  if coalesce(p_config->>'cardRadius', '') !~ '^([0-9]|[12][0-9]|3[0-2])$' then
    raise exception 'card radius must be between 0 and 32' using errcode = '22023';
  end if;
  if coalesce(p_config->>'layoutStyle', '') not in ('centered', 'simple') then
    raise exception 'invalid email layout style' using errcode = '22023';
  end if;
  if coalesce(p_config->>'showLogo', '') not in ('true', 'false') then
    raise exception 'invalid showLogo value' using errcode = '22023';
  end if;

  v_config := jsonb_build_object(
    'appNameAr', btrim(p_config->>'appNameAr'),
    'appNameEn', btrim(p_config->>'appNameEn'),
    'logoUrl', coalesce(v_value, ''),
    'logoWidth', p_config->>'logoWidth',
    'cardRadius', p_config->>'cardRadius',
    'layoutStyle', p_config->>'layoutStyle',
    'showLogo', p_config->>'showLogo',
    'primaryColor', upper(p_config->>'primaryColor'),
    'backgroundColor', upper(p_config->>'backgroundColor'),
    'surfaceColor', upper(p_config->>'surfaceColor'),
    'textColor', upper(p_config->>'textColor'),
    'buttonColor', upper(p_config->>'buttonColor'),
    'otpCodeColor', upper(p_config->>'otpCodeColor'),
    'footerAr', btrim(coalesce(p_config->>'footerAr', '')),
    'footerEn', btrim(coalesce(p_config->>'footerEn', '')),
    'signupSubjectAr', btrim(coalesce(p_config->>'signupSubjectAr', '')),
    'signupSubjectEn', btrim(coalesce(p_config->>'signupSubjectEn', '')),
    'signupTitleAr', btrim(coalesce(p_config->>'signupTitleAr', '')),
    'signupTitleEn', btrim(coalesce(p_config->>'signupTitleEn', '')),
    'signupBodyAr', btrim(coalesce(p_config->>'signupBodyAr', '')),
    'signupBodyEn', btrim(coalesce(p_config->>'signupBodyEn', '')),
    'otpLabelAr', btrim(coalesce(p_config->>'otpLabelAr', '')),
    'otpLabelEn', btrim(coalesce(p_config->>'otpLabelEn', ''))
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

update public.email_design_settings s
   set config = s.config || jsonb_build_object(
     'appNameAr', coalesce(nullif(s.config->>'appNameAr', ''), a.value #>> '{theme,brand,name_ar}', 'New Coffee'),
     'appNameEn', coalesce(nullif(s.config->>'appNameEn', ''), a.value #>> '{theme,brand,name_en}', 'New Coffee'),
     'logoWidth', coalesce(s.config->>'logoWidth', '160'),
     'cardRadius', coalesce(s.config->>'cardRadius', '18'),
     'layoutStyle', coalesce(s.config->>'layoutStyle', 'centered'),
     'showLogo', coalesce(s.config->>'showLogo', 'true'),
     'buttonColor', coalesce(s.config->>'buttonColor', '#078A75'),
     'otpCodeColor', coalesce(s.config->>'otpCodeColor', '#078A75'),
     'otpLabelAr', coalesce(s.config->>'otpLabelAr', U&'\0631\0645\0632\0020\0627\0644\062a\062d\0642\0642'),
     'otpLabelEn', coalesce(s.config->>'otpLabelEn', 'Verification code')
   )
  from core.app_settings a
 where s.id = 'default'
   and a.key = 'app_design_published';

