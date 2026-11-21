-- Store the version name atomically with the publish and expose it in the
-- result. The existing two-argument publish RPC remains available to older
-- clients.
create or replace function public.admin_publish_app_design(
  p_document jsonb,
  p_name text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_bad text;
  v_version core.app_design_versions;
  v_old jsonb;
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.publish') then
    raise exception 'missing permission: design.publish' using errcode = '42501';
  end if;
  if v_name is null then
    raise exception 'version name is required' using errcode = '22023';
  end if;
  if char_length(v_name) > 120 then
    raise exception 'version name exceeds 120 characters' using errcode = '22023';
  end if;
  if char_length(coalesce(v_note, '')) > 500 then
    raise exception 'version note exceeds 500 characters' using errcode = '22023';
  end if;

  v_bad := core.app_design_is_valid(p_document);
  if v_bad is not null then
    raise exception 'design document cannot be published: %', v_bad
      using errcode = '22023';
  end if;

  select s.value into v_old
    from core.app_settings s
   where s.key = 'app_design_published';

  insert into core.app_design_versions (
    schema_version, document, name, note, published_by
  )
  values (
    (p_document ->> 'schema_version')::int,
    p_document,
    v_name,
    v_note,
    auth.uid()
  )
  returning * into v_version;

  insert into core.app_settings (
    key, value, value_type, is_public, description, updated_at, updated_by
  )
  values (
    'app_design_published',
    p_document,
    'json',
    true,
    'Published app design. Read by the customer app through public.app_settings.',
    now(),
    auth.uid()
  )
  on conflict (key) do update
    set value = excluded.value,
        value_type = excluded.value_type,
        is_public = excluded.is_public,
        description = excluded.description,
        updated_at = excluded.updated_at,
        updated_by = excluded.updated_by;

  perform identity.audit(
    'core.app_design.publish',
    'app_design_version',
    v_version.id,
    jsonb_build_object('has_published', v_old is not null),
    jsonb_build_object(
      'version_number', v_version.version_number,
      'name', v_version.name,
      'schema_version', v_version.schema_version,
      'pages', jsonb_array_length(p_document -> 'pages')
    ),
    null
  );

  return jsonb_build_object(
    'id', v_version.id,
    'version_number', v_version.version_number,
    'published_at', v_version.published_at,
    'schema_version', v_version.schema_version,
    'name', v_version.name,
    'note', v_version.note
  );
end;
$fn$;

revoke all on function public.admin_publish_app_design(jsonb, text, text)
  from public, anon;
grant execute on function public.admin_publish_app_design(jsonb, text, text)
  to authenticated;

comment on function public.admin_publish_app_design(jsonb, text, text) is
  'Publish the customer design and store its version name in one transaction.';

notify pgrst, 'reload schema';
