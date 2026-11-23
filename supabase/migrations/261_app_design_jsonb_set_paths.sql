-- 261_app_design_jsonb_set_paths
--
-- APPROVED fix for two runtime defects in the applied 254 functions:
--
-- 1) jsonb_set() takes a text[] path, not text. Under `set search_path = ''`
--    a literal path ('{pages}') is coerced, but a CONCATENATED path stays text
--    and there is no implicit text -> text[] cast, so both 254 functions died
--    at the page-revision assignment with SQLSTATE 42883. The admin client
--    treats 42883 as "RPC missing" (it is listed in _isMissingRpcError),
--    silently disabled the atomic path for the whole session and fell back to
--    the weak read-merge-write path -- real compare-and-swap has never run.
--    Fix: explicit ::text[] casts; every other line is byte-identical to 254.
--
-- 2) The admin client (visual_editor_repository._atomicSavePages) calls
--    public.admin_save_app_design_pages (plural, batch of p_changes), while 254
--    only created the singular admin_save_app_design_page. The plural form only
--    existed in the superseded proposal file, so every atomic save answered
--    PGRST202 and the editor always fell back to the whole-document save.
--    Fix: add the plural batch wrapper over the singular CAS function, with the
--    request/response shape the client already sends and expects
--    ({p_changes:[{entry,expected_revision}], p_theme, p_update_theme, p_force}
--    -> {revisions:{page:rev}, saved_at}).
--
-- ROLLBACK (fully reversible):
--   recreate public.admin_save_app_design_page(text, jsonb, jsonb, integer, boolean)
--   and public.admin_publish_app_design_pages(jsonb, text, text) from 254 as
--   written there, then
--   DROP FUNCTION IF EXISTS public.admin_save_app_design_pages(jsonb, jsonb, boolean, boolean);

create or replace function public.admin_save_app_design_page(
  p_page              text,      -- page key (home, splash, ...)
  p_page_entry        jsonb,     -- the page entry `{page, root}` or NULL to remove the page explicitly
  p_theme             jsonb default null,
  p_expected_revision integer default null,
  p_force             boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_doc       jsonb;
  v_pages     jsonb;
  v_current   int;
  v_new_rev   int;
  v_bad       text;
  v_saved_at  timestamptz;
  v_had_draft boolean;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;
  if p_page is null or btrim(p_page) = '' then
    raise exception 'page key is required' using errcode = '22023';
  end if;

  -- قفل صف المسودة: الكاتب الثاني ينتظر الكاتب الأول ثم يقرأ قيمته —
  -- لا يمكن لعميل قديم أن يستبدل مراجعة أحدث لأن الفحص والكتابة ذريّان.
  select (s.value is not null) into v_had_draft
    from core.app_settings s
   where s.key = 'app_design_draft'
   for update;
  select s.value into v_doc
    from core.app_settings s
   where s.key = 'app_design_draft'
   for update;

  v_doc := coalesce(v_doc, jsonb_build_object('schema_version', 2, 'pages', '[]'::jsonb));
  v_current := coalesce(
    (v_doc -> 'meta' -> 'page_revisions' ->> p_page)::int,
    0
  );
  if not coalesce(p_force, false)
     and p_expected_revision is not null
     and v_current > p_expected_revision then
    raise exception 'page revision conflict: %',
      jsonb_build_object(
        'page', p_page,
        'server_revision', v_current,
        'expected_revision', p_expected_revision
      )
      using errcode = '40001';
  end if;

  -- دمج الصفحة الهدف فقط: احذف مدخلها ثم أعِد إدراجه إن لم يكن حذفًا
  -- صريحًا. ترتيب باقي الصفحات وقيمتها كما هي حرفيًا.
  v_pages := coalesce(v_doc -> 'pages', '[]'::jsonb);
  v_pages := (
    select coalesce(jsonb_agg(page order by ord), '[]'::jsonb)
      from jsonb_array_elements(v_pages) with ordinality as t(page, ord)
     where page ->> 'page' <> p_page
  );
  if p_page_entry is not null then
    if p_page_entry ->> 'page' <> p_page
       or p_page_entry -> 'root' is null then
      raise exception 'page entry does not match page key' using errcode = '22023';
    end if;
    v_pages := v_pages || jsonb_build_array(p_page_entry);
  end if;

  v_doc := jsonb_set(v_doc, '{pages}', v_pages, true);
  v_doc := jsonb_set(
    v_doc,
    '{schema_version}',
    to_jsonb(coalesce((v_doc ->> 'schema_version')::int, 2)),
    true
  );

  if p_theme is not null then
    if p_theme = 'null'::jsonb then
      v_doc := v_doc - 'theme';
    else
      v_doc := jsonb_set(v_doc, '{theme}', p_theme, true);
    end if;
  end if;

  v_bad := core.app_design_is_valid(v_doc);
  if v_bad is not null then
    raise exception 'design document is not editable: %', v_bad
      using errcode = '22023';
  end if;

  v_new_rev := v_current + 1;
  v_doc := jsonb_set(
    v_doc,
    ('{meta,page_revisions,' || p_page || '}')::text[],
    to_jsonb(v_new_rev),
    true
  );

  insert into core.app_settings (
    key, value, value_type, is_public, description, updated_at, updated_by
  )
  values (
    'app_design_draft',
    v_doc,
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
    jsonb_build_object('has_draft', v_had_draft),
    jsonb_build_object(
      'page_scope', jsonb_build_array(p_page),
      'page_revision', v_new_rev,
      'pages', jsonb_array_length(v_doc -> 'pages')
    ),
    null
  );

  return jsonb_build_object(
    'page', p_page,
    'revision', v_new_rev,
    'saved_at', v_saved_at,
    'document', v_doc
  );
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Batch save over the singular CAS function (the client contract, defect 2).
-- The theme is written with the first page of the batch exactly as the
-- singular function does it, so p_update_theme = false leaves it untouched.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_app_design_pages(
  p_changes      jsonb,     -- [{"entry":{"page":..,"root":..},"expected_revision":n}, ...]
  p_theme        jsonb default null,
  p_update_theme boolean default false,
  p_force        boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_change    jsonb;
  v_revisions jsonb := '{}'::jsonb;
  v_result    jsonb;
  v_page      text;
  v_rev       int;
begin
  if p_changes is null
     or jsonb_typeof(p_changes) <> 'array'
     or jsonb_array_length(p_changes) = 0 then
    raise exception 'p_changes must be a non-empty array' using errcode = '22023';
  end if;

  for v_change in select * from jsonb_array_elements(p_changes)
  loop
    v_page := v_change -> 'entry' ->> 'page';
    -- إن لم تكن هناك مسودة بعد، تعمل الدالة المفردة على مستند جديد فارغ.
    v_result := public.admin_save_app_design_page(
      v_page,
      v_change -> 'entry',
      case
        when coalesce(p_update_theme, false) and v_revisions = '{}'::jsonb
        then p_theme
        else null
      end,
      (v_change ->> 'expected_revision')::int,
      p_force
    );
    v_rev := (v_result ->> 'revision')::int;
    v_revisions := v_revisions || jsonb_build_object(v_page, v_rev);
  end loop;

  return jsonb_build_object(
    'revisions', v_revisions,
    'saved_at',  (v_result ->> 'saved_at')::timestamptz
  );
end;
$fn$;

revoke all on function public.admin_save_app_design_pages(jsonb, jsonb, boolean, boolean) from public, anon;
grant execute on function public.admin_save_app_design_pages(jsonb, jsonb, boolean, boolean) to authenticated;

comment on function public.admin_save_app_design_pages(jsonb, jsonb, boolean, boolean) is
  'Batch atomic page save (admin client contract) over admin_save_app_design_page CAS (261).';

create or replace function public.admin_publish_app_design_pages(
  p_pages jsonb,          -- [{"page":"home","expected_revision":5}, ...]
  p_name  text default null,
  p_note  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_draft       jsonb;
  v_published   jsonb;
  v_doc         jsonb;
  v_draft_pages jsonb;
  v_entry       jsonb;
  v_page        text;
  v_expected    int;
  v_server_rev  int;
  v_bad         text;
  v_version     core.app_design_versions;
  v_had_pub     boolean;
  v_approved    jsonb := '[]'::jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('design.publish') then
    raise exception 'missing permission: design.publish' using errcode = '42501';
  end if;
  if p_pages is null or jsonb_typeof(p_pages) <> 'array'
     or jsonb_array_length(p_pages) = 0 then
    raise exception 'p_pages must be a non-empty array' using errcode = '22023';
  end if;

  -- قفل المسودة ثم المنشور بترتيب ثابت: نشران متزامنان يصطفّان ولا
  -- يتعارضان (deadlock)، والقراءتان تحصلان على أحدث قيمتين فعليتين.
  select s.value into v_draft
    from core.app_settings s
   where s.key = 'app_design_draft'
   for update;
  select (s.value is not null) into v_had_pub
    from core.app_settings s
   where s.key = 'app_design_published'
   for update;
  select s.value into v_published
    from core.app_settings s
   where s.key = 'app_design_published'
   for update;

  if v_draft is null then
    raise exception 'no saved draft to publish' using errcode = '22023';
  end if;
  v_draft_pages := coalesce(v_draft -> 'pages', '[]'::jsonb);
  v_doc := coalesce(v_published, jsonb_build_object('schema_version', 2, 'pages', '[]'::jsonb));

  -- اعتماد الصفحات المطلوبة فقط من المسودة المقفلة: فحص تعارض المراجعة
  -- لكل صفحة قبل أي كتابة، ثم نسخ مدخلها كما هو إلى المنشور.
  for v_page, v_expected in
    select
      item ->> 'page',
      (item ->> 'expected_revision')::int
      from jsonb_array_elements(p_pages) as item
  loop
    if v_page is null or btrim(v_page) = '' then
      raise exception 'page key is required' using errcode = '22023';
    end if;
    select p into v_entry
      from jsonb_array_elements(v_draft_pages) as p
     where p ->> 'page' = v_page
     limit 1;
    if v_entry is null then
      raise exception 'page is not saved in the draft: %', v_page
        using errcode = '22023';
    end if;
    v_server_rev := coalesce(
      (v_draft -> 'meta' -> 'page_revisions' ->> v_page)::int,
      0
    );
    if v_expected is not null and v_server_rev > v_expected then
      raise exception 'page revision conflict: %',
        jsonb_build_object(
          'page', v_page,
          'server_revision', v_server_rev,
          'expected_revision', v_expected
        )
        using errcode = '40001';
    end if;

    -- استبدال مدخل الصفحة في المنشور بمدخل المسودة؛ كل ما عداها يبقى
    -- من أحدث مستند منشور حرفيًا.
    v_doc := jsonb_set(
      v_doc,
      '{pages}',
      (
        select coalesce(jsonb_agg(p order by ord), '[]'::jsonb)
          from jsonb_array_elements(coalesce(v_doc -> 'pages', '[]'::jsonb))
               with ordinality as t(p, ord)
         where p ->> 'page' <> v_page
      )
      || jsonb_build_array(v_entry),
      true
    );
    -- مراجعة الصفحة المعتمدة تُسجَّل من مراجعتها في المسودة.
    v_doc := jsonb_set(
      v_doc,
      ('{meta,page_revisions,' || v_page || '}')::text[],
      to_jsonb(v_server_rev),
      true
    );
    v_approved := v_approved || jsonb_build_array(v_page);
  end loop;

  -- طبقة الشكل تأتي من المسودة المعتمدة (المسودة هي مصدر الحقيقة للشكل).
  if v_draft -> 'theme' is not null then
    v_doc := jsonb_set(v_doc, '{theme}', v_draft -> 'theme', true);
  else
    v_doc := v_doc - 'theme';
  end if;
  v_doc := jsonb_set(
    v_doc,
    '{schema_version}',
    to_jsonb(coalesce((v_doc ->> 'schema_version')::int, 2)),
    true
  );

  v_bad := core.app_design_is_valid(v_doc);
  if v_bad is not null then
    raise exception 'design document cannot be published: %', v_bad
      using errcode = '22023';
  end if;

  -- صف الإصدار + المنشور في معاملة واحدة — نفس جسم 226/253 الناشر.
  insert into core.app_design_versions (
    schema_version, document, name, note, published_by
  )
  values (
    (v_doc ->> 'schema_version')::int,
    v_doc,
    nullif(btrim(coalesce(p_name, '')), ''),
    nullif(btrim(coalesce(p_note, '')), ''),
    auth.uid()
  )
  returning * into v_version;

  insert into core.app_settings (
    key, value, value_type, is_public, description, updated_at, updated_by
  )
  values (
    'app_design_published',
    v_doc,
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
    jsonb_build_object('has_published', v_had_pub),
    jsonb_build_object(
      'version_number', v_version.version_number,
      'schema_version', v_version.schema_version,
      'page_scope', v_approved,
      'pages', jsonb_array_length(v_doc -> 'pages')
    ),
    null
  );

  return jsonb_build_object(
    'id',             v_version.id,
    'version_number', v_version.version_number,
    'published_at',   v_version.published_at,
    'schema_version', v_version.schema_version,
    'name',           v_version.name,
    'note',           v_version.note
  );
end;
$fn$;

revoke all on function public.admin_publish_app_design_pages(jsonb, text, text) from public, anon;
grant execute on function public.admin_publish_app_design_pages(jsonb, text, text) to authenticated;

comment on function public.admin_publish_app_design_pages(jsonb, text, text) is
  'Atomic page-scoped publish: approved pages from the locked draft, everything else from the locked published document (254).';
