-- supabase/migrations/228_app_design_templates.sql
--
-- WHY THIS EXISTS
--
-- The builder can move sections and recolour them, and every publish is one
-- whole document. What it could not do is keep a arrangement the owner liked:
-- the version history stores what customers saw, not what the owner was trying
-- out, so a design that was never published is gone as soon as the draft is
-- overwritten. The specification calls this the Templates system - templates are
-- data, not Dart files, because the owner makes them from the panel and expects
-- them to still be there next month and on the other manager's laptop.
--
-- WHAT IS A TEMPLATE HERE
--
-- A saved `DesignDocument`, validated by the same `core.app_design_is_valid`
-- that guards drafts and publishes. Nothing else: a template that could hold a
-- half-document would be a document the panel refuses to publish later, and the
-- owner would not know which of the two is broken.
--
-- The gallery's built-in looks (today's design, and the arrangements the
-- developer ships) are NOT rows. They are the registry's own documents, built
-- from `WidgetRegistry.node`, so they can not drift from the widgets they name.
-- A seed row would copy every widget's default properties into SQL; the first
-- property a later migration changes would leave a stale "built-in" template
-- that publishes a screen the phone no longer has.
--
-- WHY A SEPARATE TABLE AND NOT app_settings
--
-- Draft and published are single slots, so a key per document works. Templates
-- are a list the owner grows and shrinks, with a name each. Rows in
-- `core.app_settings` would need synthetic keys and a delete that hopes nobody
-- typed a different key - a table with a primary key is the smaller lie.
--
-- WHY brand_id IS HERE ALREADY
--
-- One brand runs this app today, so every row keeps it null and reads as
-- "shared". The column exists because a second brand's templates must not be
-- listed in the first one's panel, and adding the column after rows exist means
-- deciding, retroactively, who owned what. Nullable now costs nothing.
--
-- WHY NOTHING IS GRANTED ON THE TABLE
--
-- Same rule the version rows follow (226): PostgREST does not expose `core`, the
-- panel goes through the definer functions below, and Supabase hands new tables
-- to anon and authenticated by default - so the table is closed, not merely
-- unadvertised. A customer app that could read templates could apply one nobody
-- published.

-- ---------------------------------------------------------------------------
-- 1. Template rows.
-- ---------------------------------------------------------------------------
create table if not exists core.app_design_templates (
  id             uuid        not null default gen_random_uuid(),
  name           text        not null,
  schema_version integer     not null,
  document       jsonb       not null,
  brand_id       uuid        references core.brands(id) on delete restrict,
  created_by     uuid        references auth.users(id)   on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint pk_app_design_templates primary key (id),
  constraint ck_app_design_templates_name check (char_length(btrim(name)) between 1 and 60),
  constraint ck_app_design_templates_schema check (schema_version > 0),
  -- العقد نفسه الذي يوقّع عليه المسوّد والمنشور: لا شكل نصف مستند في القالب.
  constraint ck_app_design_templates_document check (
    core.app_design_is_valid(document) is null
  )
);

comment on table core.app_design_templates is
  'Design documents the owner saved from the panel, for reuse (228).';
comment on column core.app_design_templates.name is
  'As the owner typed it. One name, not a per-language pair: this is their label for their own work, and inventing a second field would ask the panel to translate it.';
comment on column core.app_design_templates.schema_version is
  'Copied from the document at save time so the list can say what a template is without sending the whole tree.';
comment on column core.app_design_templates.brand_id is
  'Null while one brand runs the app; the column exists so a second brand''s templates are never listed in the first one''s panel.';
comment on column core.app_design_templates.document is
  'A complete DesignDocument, checked by core.app_design_is_valid by table constraint.';

alter table core.app_design_templates enable row level security;

revoke all on core.app_design_templates from public, anon, authenticated;

create index if not exists ix_app_design_templates_created_at
  on core.app_design_templates (created_at desc);

-- ---------------------------------------------------------------------------
-- 2. List. No documents, on purpose: a gallery of forty templates fetching
--    forty trees is the slowest way to show forty names.
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_app_design_templates()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_rows jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'schema_version', t.schema_version,
        'created_at', t.created_at,
        'updated_at', t.updated_at
      )
      order by t.created_at desc
    ),
    '[]'::jsonb
  )
    into v_rows
    from core.app_design_templates t;

  return v_rows;
end;
$fn$;

revoke all on function public.admin_list_app_design_templates() from public, anon;
grant execute on function public.admin_list_app_design_templates() to authenticated;

comment on function public.admin_list_app_design_templates() is
  'Saved design templates, newest first, names and dates only (228).';

-- ---------------------------------------------------------------------------
-- 3. One template, with its document - the read that happens when the owner
--    actually applies it.
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_app_design_template(p_id uuid)
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

  select t.document
    into v_document
    from core.app_design_templates t
   where t.id = p_id;

  if v_document is null then
    raise exception 'template not found' using errcode = 'P0001';
  end if;

  return v_document;
end;
$fn$;

revoke all on function public.admin_get_app_design_template(uuid) from public, anon;
grant execute on function public.admin_get_app_design_template(uuid) to authenticated;

comment on function public.admin_get_app_design_template(uuid) is
  'One saved template document (228).';

-- ---------------------------------------------------------------------------
-- 4. Save. With p_id the row is updated, without it a template is created -
--    one function because both write the same contract and the panel can not
--    be trusted to pick the right one.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_app_design_template(
  p_id uuid,
  p_name text,
  p_document jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_name    text := btrim(coalesce(p_name, ''));
  v_bad     text;
  v_id      uuid;
  v_at      timestamptz;
  v_schema  integer := (p_document ->> 'schema_version')::integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;

  if v_name = '' or char_length(v_name) > 60 then
    raise exception 'template name must be 1-60 characters' using errcode = '22023';
  end if;

  v_bad := core.app_design_is_valid(p_document);
  if v_bad is not null then
    raise exception 'design document is not editable: %', v_bad
      using errcode = '22023';
  end if;

  if p_id is not null then
    perform 1 from core.app_design_templates where id = p_id;
    if not found then
      raise exception 'template not found' using errcode = 'P0001';
    end if;
  end if;

  insert into core.app_design_templates (
    id, name, schema_version, document, created_by
  )
  values (
    coalesce(p_id, gen_random_uuid()),
    v_name,
    (p_document ->> 'schema_version')::integer,
    p_document,
    auth.uid()
  )
  on conflict (id) do update
    set name           = excluded.name,
        schema_version = excluded.schema_version,
        document       = excluded.document,
        updated_at     = now()
  returning id, updated_at into v_id, v_at;

  perform identity.audit(
    'core.app_design.template.save',
    'app_design_template',
    v_id,
    jsonb_build_object('overwritten', p_id is not null),
    jsonb_build_object('name', v_name),
    null
  );

  return jsonb_build_object(
    'id', v_id,
    'name', v_name,
    'schema_version', v_schema,
    'updated_at', v_at
  );
end;
$fn$;

revoke all on function public.admin_save_app_design_template(uuid, text, jsonb)
  from public, anon;
grant execute on function public.admin_save_app_design_template(uuid, text, jsonb)
  to authenticated;

comment on function public.admin_save_app_design_template(uuid, text, jsonb) is
  'Create a template, or overwrite one by id, after the same document check publish uses (228).';

-- ---------------------------------------------------------------------------
-- 5. Delete. A template is the owner's own note: removing it never touches a
--    draft, a publish or a version row, so no confirmation dance on the server.
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_app_design_template(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_name text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;

  delete from core.app_design_templates t
   where t.id = p_id
   returning t.name into v_name;

  if v_name is null then
    raise exception 'template not found' using errcode = 'P0001';
  end if;

  perform identity.audit(
    'core.app_design.template.delete',
    'app_design_template',
    p_id,
    null,
    jsonb_build_object('name', v_name),
    null
  );

  return jsonb_build_object('deleted', true);
end;
$fn$;

revoke all on function public.admin_delete_app_design_template(uuid)
  from public, anon;
grant execute on function public.admin_delete_app_design_template(uuid)
  to authenticated;

comment on function public.admin_delete_app_design_template(uuid) is
  'Drop one saved template (228).';
