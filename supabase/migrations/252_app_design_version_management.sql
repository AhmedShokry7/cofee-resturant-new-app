-- Show the complete version history and let authorized admins maintain its
-- notes and remove history entries without changing the currently published
-- customer design.

alter table core.app_design_versions
  add column if not exists name text;

create or replace function public.admin_list_app_design_versions(
  p_limit integer default 1000000
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_limit integer := coalesce(p_limit, 1000000);
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;
  if v_limit < 1 or v_limit > 1000000 then
    raise exception 'version limit out of range' using errcode = '22003';
  end if;

  return (
    select coalesce(
      jsonb_agg(jsonb_build_object(
        'id', v.id,
        'version_number', v.version_number,
        'published_at', v.published_at,
        'schema_version', v.schema_version,
        'name', v.name,
        'note', v.note
      ) order by v.version_number desc),
      '[]'::jsonb
    )
    from (
      select v2.id, v2.version_number, v2.published_at,
             v2.schema_version, v2.name, v2.note
        from core.app_design_versions v2
       order by v2.version_number desc
       limit v_limit
    ) v
  );
end;
$fn$;

revoke all on function public.admin_list_app_design_versions(integer)
  from public, anon;
grant execute on function public.admin_list_app_design_versions(integer)
  to authenticated;

create or replace function public.admin_update_app_design_version_details(
  p_version_id uuid,
  p_name text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_number integer;
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;
  if p_version_id is null then
    raise exception 'version id required' using errcode = '22023';
  end if;
  if char_length(coalesce(v_name, '')) > 120 then
    raise exception 'version name exceeds 120 characters' using errcode = '22023';
  end if;
  if char_length(coalesce(v_note, '')) > 500 then
    raise exception 'version note exceeds 500 characters' using errcode = '22023';
  end if;

  update core.app_design_versions
     set name = v_name,
         note = v_note
   where id = p_version_id
   returning version_number into v_number;
  if not found then
    raise exception 'design version not found' using errcode = 'P0002';
  end if;

  perform identity.audit(
    'core.app_design.version.details',
    'app_design_version',
    p_version_id,
    null,
    jsonb_build_object(
      'version_number', v_number,
      'name', v_name,
      'note', v_note
    ),
    null
  );
  return jsonb_build_object('id', p_version_id, 'version_number', v_number,
                            'name', v_name, 'note', v_note);
end;
$fn$;

revoke all on function public.admin_update_app_design_version_details(uuid, text, text)
  from public, anon;
grant execute on function public.admin_update_app_design_version_details(uuid, text, text)
  to authenticated;

create or replace function public.admin_delete_app_design_version(
  p_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_number integer;
  v_name text;
  v_note text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.publish') then
    raise exception 'missing permission: design.publish' using errcode = '42501';
  end if;
  if p_version_id is null then
    raise exception 'version id required' using errcode = '22023';
  end if;

  delete from core.app_design_versions
   where id = p_version_id
   returning version_number, name, note into v_number, v_name, v_note;
  if not found then
    raise exception 'design version not found' using errcode = 'P0002';
  end if;

  perform identity.audit(
    'core.app_design.version.delete',
    'app_design_version',
    p_version_id,
    jsonb_build_object(
      'version_number', v_number,
      'name', v_name,
      'note', v_note
    ),
    null,
    null
  );
  return jsonb_build_object('deleted', true, 'version_number', v_number);
end;
$fn$;

revoke all on function public.admin_delete_app_design_version(uuid)
  from public, anon;
grant execute on function public.admin_delete_app_design_version(uuid)
  to authenticated;

notify pgrst, 'reload schema';
