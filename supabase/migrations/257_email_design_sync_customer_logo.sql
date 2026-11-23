-- The customer app's published brand is the only source of the e-mail logo.
-- Admins still edit mail colors and copy, while the logo follows the app.
create or replace function public.admin_email_design_get()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_config jsonb;
  v_logo_url text;
begin
  if not identity.is_staff()
     or not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage'
      using errcode = '42501';
  end if;

  select config into v_config
    from public.email_design_settings
   where id = 'default';

  select s.value #>> '{theme,brand,logo_url}' into v_logo_url
    from core.app_settings s
   where s.key = 'app_design_published';

  return coalesce(v_config, '{}'::jsonb)
    || jsonb_build_object('logoUrl', coalesce(v_logo_url, ''));
end;
$fn$;

revoke all on function public.admin_email_design_get() from public, anon;
grant execute on function public.admin_email_design_get() to authenticated;
