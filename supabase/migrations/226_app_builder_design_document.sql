-- supabase/migrations/226_app_builder_design_document.sql
--
-- WHY THIS EXISTS
--
-- The panel now has an app builder: one design document - a widget tree per
-- customer screen - that an employee edits on a canvas and publishes. Nothing
-- in the schema can hold it. `core.app_settings` (005) is a typed key/value
-- table whose `is_public` rows already reach the client through the
-- `public.app_settings` bridge view (032), so the two live documents, the draft
-- and what the customer sees, are two rows there rather than a new table. What
-- app_settings cannot do is keep history: one primary key holds one value per
-- key, and the builder needs a version list and a rollback. One new table,
-- `core.app_design_versions`, holds published documents as immutable rows.
--
-- WHAT CHANGES
--
--   * `core.app_design_versions` (version rows, one per publish or rollback)
--   * two `core.app_settings` keys written only through the RPCs below:
--     `app_design_draft` (is_public false) and `app_design_published`
--     (is_public true - the customer app reads the same row the panel reads)
--   * permissions `design.edit` and `design.publish`, granted to `manager`;
--     `owner` holds every permission implicitly (018)
--   * eight definer RPCs: read draft or published, save draft, discard draft,
--     list versions, read one version, publish, restore one version
--
-- WHY PUBLISHING NEEDS THE SERVER
--
-- `settings.write` is what every settings page in the panel already uses, but an
-- app builder puts a shape in front of the customer, so editing and publishing
-- get their own codes and every RPC checks them: `identity.is_staff()` first,
-- then `identity.has_permission(...)`, 42501 on either. Hiding the publish
-- button is not the guard - a malformed document is refused here too, in
-- `core.app_design_is_valid`, before a version row is written. Publish is one
-- transaction: version row inserted, published row upserted, audit written. A
-- failure at any step leaves the design the customer is looking at untouched,
-- which is why there is no half-published state to recover from. A rollback
-- re-publishes an old document under a NEW number, so the log keeps every fact
-- instead of rewriting one.
--
-- WHAT IS NOT VALIDATED HERE
--
-- The widget type list belongs to the developer-owned Dart registry; a copy in
-- SQL would be a second source of truth that drifts the first time a component
-- is added. The SQL therefore checks only the structure it can check alone -
-- known page ids, one page per id, node ids present and unique, scalar property
-- values, depth at most 12, at most 400 nodes, `schema_version = 1` - and the
-- panel's own validator is what refuses a type the registry does not draw. An
-- unknown type renders nothing rather than something wrong, and no document with
-- one can leave the panel.

-- ---------------------------------------------------------------------------
-- 1. Permissions. Two codes, because "let me rearrange my draft" and "let me
--    change what every customer sees" are different asks.
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('design.edit',    'تحرير تصميم التطبيق', 'Edit app design',
   'Save and discard the app builder draft and read its version history.'),
  ('design.publish', 'نشر تصميم التطبيق',  'Publish app design',
   'Publish the app builder design to the customer app and roll it back.')
on conflict (code) do update
  set name_ar     = excluded.name_ar,
      name_en     = excluded.name_en,
      description = excluded.description;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('design.edit', 'design.publish')
 where r.code = 'manager'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Version rows. Immutable: a publish writes one and never touches an old
--    one, so the list the panel shows is the list of what customers actually
--    saw, in order.
-- ---------------------------------------------------------------------------
create table if not exists core.app_design_versions (
  id             uuid        not null default gen_random_uuid(),
  version_number integer     not null generated always as identity,
  published_at   timestamptz not null default now(),
  schema_version integer     not null,
  document       jsonb       not null,
  note           text,
  published_by   uuid        references auth.users(id) on delete set null,
  constraint pk_app_design_versions primary key (id),
  constraint uq_app_design_versions_number unique (version_number),
  constraint ck_app_design_versions_schema check (schema_version > 0)
);

comment on table core.app_design_versions is
  'Every published design of the customer app, newest first by version_number (226).';
comment on column core.app_design_versions.version_number is
  'Displayed as "الإصدار N". An identity, not max+1: two concurrent publishes would read the same max and one would abort on the unique key, while an identity only leaves a gap on a rolled-back publish.';
comment on column core.app_design_versions.document is
  'The DesignDocument exactly as the panel serialized it, so a rollback republishes the shape rather than an approximation.';
comment on column core.app_design_versions.published_by is
  'Who published. Null when that account is deleted; the row itself is never deleted.';

alter table core.app_design_versions enable row level security;

-- No policy and no live grant: PostgREST does not expose `core`, the version
-- list is read through `admin_list_app_design_versions`, and the definer
-- function runs as the table owner. The REVOKE below is what makes that a fact
-- rather than a default — Supabase hands new tables to anon and authenticated,
-- so the table has to be closed, not merely unadvertised. A 032-style bridge
-- view would hand the whole document of every past version to anon for no
-- caller that exists.
revoke all on core.app_design_versions from public, anon, authenticated;

-- The unique key already serves the only read (`order by version_number desc`
-- over a handful of rows), so no second index is added.

-- ---------------------------------------------------------------------------
-- 3. Structure validation. Both helpers are immutable and schema-qualified:
--    they read nothing but their argument, so the caller can not steer them.
-- ---------------------------------------------------------------------------
create or replace function core.app_design_node_check(
  p_node jsonb,
  p_depth integer
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_child  jsonb;
  v_result jsonb;
  v_ids    jsonb := '[]'::jsonb;
begin
  -- 12 طبقات تكبر بها اللوحة، و400 عقدة في الصفحة كلها: سقفان يقفان عند
  -- مستند خرج من محرّر لا عند مستند كتبه إنسان.
  if p_depth > 12 then
    return jsonb_build_object('ok', false, 'reason', 'depth');
  end if;
  if jsonb_typeof(p_node) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'node');
  end if;
  if jsonb_typeof(p_node -> 'id') <> 'string' or coalesce(p_node ->> 'id', '') = '' then
    return jsonb_build_object('ok', false, 'reason', 'node_id');
  end if;
  if jsonb_typeof(p_node -> 'type') <> 'string' or coalesce(p_node ->> 'type', '') = '' then
    return jsonb_build_object('ok', false, 'reason', 'node_type');
  end if;
  if p_node ? 'visible' and jsonb_typeof(p_node -> 'visible') <> 'boolean' then
    return jsonb_build_object('ok', false, 'reason', 'visible');
  end if;
  if p_node ? 'properties' then
    if jsonb_typeof(p_node -> 'properties') <> 'object' then
      return jsonb_build_object('ok', false, 'reason', 'properties');
    end if;
    -- قيم أولية فقط: خاصية تحمل كائنًا أو مصفوفة لا يقرأها المحرّر، وهي الطريقة
    -- التي يتسرب بها نص خام إلى شاشة الزبون.
    if exists (
      select 1
        from jsonb_object_keys(p_node -> 'properties') k
       where jsonb_typeof(p_node -> 'properties' -> k)
               not in ('string', 'number', 'boolean')
    ) then
      return jsonb_build_object('ok', false, 'reason', 'property_value');
    end if;
  end if;

  if p_node ? 'children' then
    if jsonb_typeof(p_node -> 'children') <> 'array' then
      return jsonb_build_object('ok', false, 'reason', 'children');
    end if;
    for v_child in select jsonb_array_elements(p_node -> 'children') loop
      v_result := core.app_design_node_check(v_child, p_depth + 1);
      if not (v_result ->> 'ok')::boolean then
        return v_result;
      end if;
      v_ids := v_ids || (v_result -> 'ids');
    end loop;
  end if;

  v_ids := v_ids || jsonb_build_array(p_node ->> 'id');
  if jsonb_array_length(v_ids) > 400 then
    return jsonb_build_object('ok', false, 'reason', 'node_count');
  end if;
  return jsonb_build_object('ok', true, 'ids', v_ids);
end;
$fn$;

comment on function core.app_design_node_check(jsonb, integer) is
  'Walks one design subtree: shape, scalar properties, depth and node budget. Returns {ok, ids} or {ok:false, reason} (226).';

create or replace function core.app_design_is_valid(p_document jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_page  jsonb;
  v_check jsonb;
  v_ids   jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_document) <> 'object' then
    return 'document';
  end if;
  -- نسخة المخطط التي يعرفها المحرّر اليوم: مستند بنسخة أعلى يتركه الزبون على ما
  -- قبله، فلا معنى لقبوله من لوحة لا ترسمه.
  if jsonb_typeof(p_document -> 'schema_version') <> 'number' then
    return 'schema_version';
  end if;
  if (p_document ->> 'schema_version')::numeric <> 1 then
    return 'schema_version';
  end if;
  if jsonb_typeof(p_document -> 'pages') <> 'array'
     or jsonb_array_length(p_document -> 'pages') = 0 then
    return 'pages';
  end if;
  if jsonb_array_length(p_document -> 'pages') > 7 then
    return 'page_count';
  end if;
  -- الشاشات التي يفتحها الهاتف لا تزيد. قائمة ثابتة لا سجل تحرير: صفحة لا
  -- يعرفها التطبيق لا تُعرض ولا تُحرَّر.
  if exists (
    select 1
      from jsonb_array_elements(p_document -> 'pages') p
     where coalesce(p ->> 'page', '') not in
       ('home', 'categories', 'search', 'product_details', 'cart',
        'favourites', 'settings')
  ) then
    return 'page_key';
  end if;
  if (
    select count(distinct p ->> 'page')
      from jsonb_array_elements(p_document -> 'pages') p
  ) <> jsonb_array_length(p_document -> 'pages') then
    return 'page_duplicate';
  end if;

  for v_page in select jsonb_array_elements(p_document -> 'pages') loop
    if jsonb_typeof(v_page) <> 'object' then
      return 'page_entry';
    end if;
    v_check := core.app_design_node_check(v_page -> 'root', 1);
    if not (v_check ->> 'ok')::boolean then
      return coalesce(v_check ->> 'reason', 'root');
    end if;
    v_ids := v_ids || (v_check -> 'ids');
  end loop;

  if jsonb_array_length(v_ids) > 400 then
    return 'node_count';
  end if;
  if (
    select count(distinct i) from jsonb_array_elements_text(v_ids) i
  ) <> jsonb_array_length(v_ids) then
    return 'node_duplicate';
  end if;
  return null;
end;
$fn$;

comment on function core.app_design_is_valid(jsonb) is
  'Null when a design document is structurally publishable, else the first broken part as a code the panel prints (226).';

-- ---------------------------------------------------------------------------
-- 4. Reads. Draft and published share one function because they are the same
--    row shape in the same table; the slot is what stops a caller from naming
--    any setting key it likes.
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_app_design(p_slot text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_key   text;
  v_value jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_slot = 'draft' then
    if not identity.has_permission('design.edit') then
      raise exception 'missing permission: design.edit' using errcode = '42501';
    end if;
    v_key := 'app_design_draft';
  elsif p_slot = 'published' then
    -- القراءة كلها للمحرّر: اللوحة تفتح المسودة والمنشور والإصدارات في جولة
    -- واحدة، فمن يُسمح له بالتحرير ولا يرى ما يراه الزبون يقف على شاشة خطأ.
    -- النشر نفسه يبقى منفردًا في admin_publish_app_design.
    if not identity.has_permission('design.edit') then
      raise exception 'missing permission: design.edit' using errcode = '42501';
    end if;
    v_key := 'app_design_published';
  else
    raise exception 'unknown design slot' using errcode = '22023';
  end if;

  select s.value
    into v_value
    from core.app_settings s
   where s.key = v_key;
  return v_value;
end;
$fn$;

revoke all on function public.admin_get_app_design(text) from public, anon;
grant execute on function public.admin_get_app_design(text) to authenticated;

comment on function public.admin_get_app_design(text) is
  'Draft or published design document as saved, or null when nothing was saved (226).';

-- ---------------------------------------------------------------------------
-- 5. Draft. Never public, so nothing here reaches the customer app.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_app_design_draft(p_document jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old       jsonb;
  v_bad       text;
  v_saved_at  timestamptz;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;

  v_bad := core.app_design_is_valid(p_document);
  if v_bad is not null then
    raise exception 'design document is not editable: %', v_bad
      using errcode = '22023';
  end if;

  select s.value into v_old from core.app_settings s where s.key = 'app_design_draft';

  insert into core.app_settings (
    key, value, value_type, is_public, description, updated_at, updated_by
  )
  values (
    'app_design_draft',
    p_document,
    'json',
    false,
    'Unpublished app builder design. Never read by the customer app.',
    now(),
    auth.uid()
  )
  on conflict (key) do update
    set value       = excluded.value,
        value_type  = excluded.value_type,
        is_public   = excluded.is_public,
        description = excluded.description,
        updated_at  = excluded.updated_at,
        updated_by  = excluded.updated_by
  returning updated_at into v_saved_at;

  perform identity.audit(
    'core.app_design.draft.save',
    'app_setting',
    null,
    jsonb_build_object('has_draft', v_old is not null),
    jsonb_build_object(
      'schema_version', p_document -> 'schema_version',
      'pages', jsonb_array_length(p_document -> 'pages')
    ),
    null
  );

  return jsonb_build_object('saved_at', v_saved_at);
end;
$fn$;

revoke all on function public.admin_save_app_design_draft(jsonb) from public, anon;
grant execute on function public.admin_save_app_design_draft(jsonb) to authenticated;

comment on function public.admin_save_app_design_draft(jsonb) is
  'Store the builder draft in core.app_settings without touching what the customer sees (226).';

create or replace function public.admin_discard_app_design_draft()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;

  delete from core.app_settings where key = 'app_design_draft';

  perform identity.audit(
    'core.app_design.draft.discard',
    'app_setting',
    null,
    null,
    null,
    null
  );
  return jsonb_build_object('discarded', true);
end;
$fn$;

revoke all on function public.admin_discard_app_design_draft() from public, anon;
grant execute on function public.admin_discard_app_design_draft() to authenticated;

comment on function public.admin_discard_app_design_draft() is
  'Drop the draft row so the panel opens on the published design again (226).';

-- ---------------------------------------------------------------------------
-- 6. Version history. The list carries no documents on purpose: a panel that
--    shows thirty version rows fetching thirty trees is the slowest way to
--    render a number and a date.
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_app_design_versions(p_limit integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_limit integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;

  v_limit := coalesce(p_limit, 30);
  if v_limit < 1 or v_limit > 100 then
    raise exception 'version limit out of range' using errcode = '22003';
  end if;

  return (
    select coalesce(
      jsonb_agg(jsonb_build_object(
        'id',             v.id,
        'version_number', v.version_number,
        'published_at',   v.published_at,
        'schema_version', v.schema_version,
        'note',           v.note
      ) order by v.version_number desc),
      '[]'::jsonb
    )
    from (
      select v2.id, v2.version_number, v2.published_at, v2.schema_version, v2.note
        from core.app_design_versions v2
       order by v2.version_number desc
       limit v_limit
    ) v
  );
end;
$fn$;

revoke all on function public.admin_list_app_design_versions(integer) from public, anon;
grant execute on function public.admin_list_app_design_versions(integer) to authenticated;

comment on function public.admin_list_app_design_versions(integer) is
  'Version metadata, newest first, without the stored documents (226).';

create or replace function public.admin_get_app_design_version(p_version_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_document jsonb;
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

  select v.document
    into v_document
    from core.app_design_versions v
   where v.id = p_version_id;
  return v_document;
end;
$fn$;

revoke all on function public.admin_get_app_design_version(uuid) from public, anon;
grant execute on function public.admin_get_app_design_version(uuid) to authenticated;

comment on function public.admin_get_app_design_version(uuid) is
  'One stored version document, for the preview before a rollback (226).';

-- ---------------------------------------------------------------------------
-- 7. Publish and rollback. Both end in the same two writes, so both live in
--    one body: a version row and the published settings row, in one
--    transaction, or nothing at all.
-- ---------------------------------------------------------------------------
create or replace function public.admin_publish_app_design(
  p_document jsonb,
  p_note     text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_bad      text;
  v_version  core.app_design_versions;
  v_old      jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.publish') then
    raise exception 'missing permission: design.publish' using errcode = '42501';
  end if;

  v_bad := core.app_design_is_valid(p_document);
  if v_bad is not null then
    raise exception 'design document cannot be published: %', v_bad
      using errcode = '22023';
  end if;

  select s.value into v_old from core.app_settings s where s.key = 'app_design_published';

  insert into core.app_design_versions (
    schema_version, document, note, published_by
  )
  values (
    (p_document ->> 'schema_version')::int,
    p_document,
    nullif(btrim(coalesce(p_note, '')), ''),
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
    set value       = excluded.value,
        value_type  = excluded.value_type,
        is_public   = excluded.is_public,
        description = excluded.description,
        updated_at  = excluded.updated_at,
        updated_by  = excluded.updated_by;

  perform identity.audit(
    'core.app_design.publish',
    'app_design_version',
    v_version.id,
    jsonb_build_object('has_published', v_old is not null),
    jsonb_build_object(
      'version_number', v_version.version_number,
      'schema_version', v_version.schema_version,
      'pages', jsonb_array_length(p_document -> 'pages')
    ),
    null
  );

  return jsonb_build_object(
    'id',             v_version.id,
    'version_number', v_version.version_number,
    'published_at',   v_version.published_at,
    'schema_version', v_version.schema_version,
    'note',           v_version.note
  );
end;
$fn$;

revoke all on function public.admin_publish_app_design(jsonb, text) from public, anon;
grant execute on function public.admin_publish_app_design(jsonb, text) to authenticated;

comment on function public.admin_publish_app_design(jsonb, text) is
  'Atomically write a version row and the published design the customer app reads (226).';

create or replace function public.admin_restore_app_design_version(p_version_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_document jsonb;
  v_note     text;
  v_number   integer;
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

  select v.document, v.version_number
    into v_document, v_number
    from core.app_design_versions v
   where v.id = p_version_id;
  if v_document is null then
    raise exception 'design version not found' using errcode = 'P0002';
  end if;

  -- السجل لا يُمحى ولا يُعاد كتابته: الرجوع إصدارٌ جديدٌ يحمل ملفّ الإصدار
  -- القديم، ولهذا يُفحص مرة أخرى ولو كان نُشر من قبل.
  if core.app_design_is_valid(v_document) is not null then
    raise exception 'stored version is no longer publishable' using errcode = '22023';
  end if;

  v_note := 'restored from version ' || v_number::text;
  return public.admin_publish_app_design(v_document, v_note);
end;
$fn$;

revoke all on function public.admin_restore_app_design_version(uuid) from public, anon;
grant execute on function public.admin_restore_app_design_version(uuid) to authenticated;

comment on function public.admin_restore_app_design_version(uuid) is
  'Republish a stored version under a new number, keeping the log honest (226).';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
