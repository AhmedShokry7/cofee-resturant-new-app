-- 254_app_design_page_save_publish_atomic.PROPOSED.sql
--
-- APPROVED by the owner and applied. Rationale and rollback plan live in
-- supabase/proposals/254_app_design_page_save_publish_atomic.PROPOSED.sql.
-- WHY (the race the Dart-side check cannot close)
--   The editor keeps its own merge-on-read save path (read fresh draft,
--   compare revisions in Dart, then write). That is a compare-then-swap
--   done by the CLIENT: two sessions that read the same revision can both
--   pass the Dart check and interleave their writes at the database.
--   This proposal moves the compare-and-swap INSIDE one transaction with a
--   row lock (`SELECT ... FOR UPDATE`), so a stale client physically cannot
--   replace a newer revision — the database refuses it.
--
-- WHAT IT ADDS (additive only — no tables, no columns, no policies, no
-- view changes; 226/244/252/253 behavior untouched):
--   1) admin_save_app_design_page  — atomic per-page draft save (CAS).
--   2) admin_publish_app_design_pages — atomic page-scoped publish
--      (assembles: approved pages from the LOCKED draft + everything else
--      from the LOCKED published document; one transaction).
--
-- MERGE CONTRACT (mirrors lib/features/visual_editor/domain/design_document_merge.dart):
--   * Saving page P touches ONLY P's entry and P's meta revision. Other
--     pages, their order and their revisions are preserved verbatim.
--   * p_page_entry = SQL NULL means an EXPLICIT removal of the page from
--     the draft. A client never removes a page implicitly — removing a
--     page is always a signed, audited action.
--   * p_theme: pass the theme jsonb to update the layer, or the jsonb
--     literal 'null' to clear it, or SQL NULL to leave it untouched.
--   * Publishing page P copies P's entry (and P's draft revision into the
--     published meta) from the draft; every other page keeps its latest
--     PUBLISHED content. Drafts of other pages are never auto-published.
--   * Both functions validate the resulting WHOLE document with
--     core.app_design_is_valid (226/244) before writing.
--
-- REVISION LOCKING
--   The core.app_settings row is locked FOR UPDATE inside the transaction:
--   two concurrent writers serialize; the second one re-reads the value
--   the first one wrote, sees its own expected_revision is stale, and
--   raises `page revision conflict` (errcode 40001 — retryable class).
--   Publishes lock draft-then-published in a fixed order, so two
--   concurrent publishes cannot deadlock each other.
--
-- CLIENT COMPATIBILITY
--   The admin client (repository) probes for these functions on first
--   write and uses them when present; when absent it falls back to the
--   existing whole-document RPCs with merge-on-read. No client redeploy is
--   required before applying this migration, and no rollback breaks the
--   old clients.
--
-- ROLLBACK PLAN (fully reversible; run as one script if ever needed):
--   REVOKE ALL ON FUNCTION public.admin_save_app_design_page(text, jsonb, jsonb, integer, boolean) FROM authenticated;
--   REVOKE ALL ON FUNCTION public.admin_publish_app_design_pages(jsonb, text, text) FROM authenticated;
--   DROP FUNCTION IF EXISTS public.admin_save_app_design_page(text, jsonb, jsonb, integer, boolean);
--   DROP FUNCTION IF EXISTS public.admin_publish_app_design_pages(jsonb, text, text);
--   Nothing else changes: no table, no column, no policy, no view. The old
--   whole-document RPCs (226/253) keep working.

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
    '{meta,page_revisions,' || p_page || '}',
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

revoke all on function public.admin_save_app_design_page(text, jsonb, jsonb, integer, boolean) from public, anon;
grant execute on function public.admin_save_app_design_page(text, jsonb, jsonb, integer, boolean) to authenticated;

comment on function public.admin_save_app_design_page(text, jsonb, jsonb, integer, boolean) is
  'Atomic per-page draft save: compare-and-swap on the page revision under a row lock (254).';

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
      '{meta,page_revisions,' || v_page || '}',
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
