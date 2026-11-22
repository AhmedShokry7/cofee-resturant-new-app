254_app_design_page_transactions.SUPERSEDED_BY_254.sql
======================================================
This file (from a parallel session) was NEVER applied. The owner approved the
companion proposal 254_app_design_page_save_publish_atomic.PROPOSED.sql, which
defines `admin_save_app_design_page` (singular, per page) plus
`admin_publish_app_design_pages(jsonb,text,text)` with the SAME signature this
file used — applying both would raise "function is not unique". This file is
kept for reference only and must never be applied.
-- Serialize studio edits even before either settings row exists.
create or replace function public.admin_save_app_design_pages(
  p_changes jsonb, p_theme jsonb, p_update_theme boolean, p_force boolean
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  doc jsonb;
  change jsonb;
  page_id text;
  rev integer;
  revisions jsonb;
  saved jsonb := '{}';
  result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('design.edit') then
    raise exception 'missing permission: design.edit' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(226, 254);
  select value into doc from core.app_settings where key = 'app_design_draft' for update;
  if doc is null then
    select value into doc from core.app_settings where key = 'app_design_published';
  end if;
  doc := coalesce(doc, '{"schema_version":2,"pages":[]}');
  revisions := coalesce(doc #> '{meta,page_revisions}', '{}');
  for change in select * from jsonb_array_elements(p_changes) loop
    page_id := change -> 'entry' ->> 'page';
    if page_id is null then raise exception 'page is required'; end if;
    rev := coalesce((revisions ->> page_id)::integer, 0);
    if not p_force and rev <> (change ->> 'expected_revision')::integer then
      raise exception 'page revision conflict: %', jsonb_build_object(
        'page',page_id,'server_revision',rev,'expected_revision',change->'expected_revision'
      ) using errcode = '40001';
    end if;
    doc := jsonb_set(doc, '{pages}', coalesce((
      select jsonb_agg(x order by n) from jsonb_array_elements(doc->'pages')
      with ordinality a(x,n) where x->>'page' <> page_id
    ), '[]') || jsonb_build_array(change->'entry'));
    revisions := revisions || jsonb_build_object(page_id, rev+1);
    saved := saved || jsonb_build_object(page_id, rev+1);
  end loop;
  doc := jsonb_set(doc, '{meta}', coalesce(doc->'meta','{}') ||
    jsonb_build_object('page_revisions',revisions));
  if p_update_theme then
    doc := doc - 'theme';
    if p_theme is not null then doc := doc || jsonb_build_object('theme',p_theme); end if;
  end if;
  result := public.admin_save_app_design_draft(doc);
  return result || jsonb_build_object('revisions',saved);
end;
$$;

create or replace function public.admin_publish_app_design_pages(
  p_pages jsonb, p_name text, p_note text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  draft jsonb;
  doc jsonb;
  item jsonb;
  entry jsonb;
  page_id text;
  rev integer;
  revisions jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('design.publish') then
    raise exception 'missing permission: design.publish' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(226, 254);
  select value into draft from core.app_settings where key = 'app_design_draft' for update;
  if draft is null then raise exception 'no saved draft'; end if;
  select value into doc from core.app_settings where key = 'app_design_published' for update;
  doc := coalesce(doc, '{"schema_version":2,"pages":[]}');
  revisions := coalesce(doc #> '{meta,page_revisions}', '{}');
  for item in select * from jsonb_array_elements(p_pages) loop
    page_id := item->>'page';
    select x into entry from jsonb_array_elements(draft->'pages') x where x->>'page'=page_id;
    rev := coalesce((draft #>> array['meta','page_revisions',page_id])::integer,0);
    if rev <> (item->>'expected_revision')::integer then
      raise exception 'page revision conflict: %', jsonb_build_object(
        'page',page_id,'server_revision',rev,'expected_revision',item->'expected_revision'
      ) using errcode = '40001';
    end if;
    if entry is null and rev = 0 then raise exception 'page has no saved draft: %',page_id; end if;
    doc := jsonb_set(doc,'{pages}',coalesce((
      select jsonb_agg(x order by n) from jsonb_array_elements(doc->'pages')
      with ordinality a(x,n) where x->>'page' <> page_id
    ),'[]') || case when entry is null then '[]'::jsonb else jsonb_build_array(entry) end);
    revisions := revisions || jsonb_build_object(page_id,rev);
  end loop;
  doc := jsonb_set(doc,'{meta}',coalesce(doc->'meta','{}') ||
    jsonb_build_object('page_revisions',revisions)) - 'theme';
  if draft ? 'theme' then doc := doc || jsonb_build_object('theme',draft->'theme'); end if;
  return public.admin_publish_app_design(doc,p_name,p_note);
end;
$$;
revoke all on function public.admin_save_app_design_pages(jsonb,jsonb,boolean,boolean) from public, anon;
revoke all on function public.admin_publish_app_design_pages(jsonb,text,text) from public, anon;
grant execute on function public.admin_save_app_design_pages(jsonb,jsonb,boolean,boolean) to authenticated;
grant execute on function public.admin_publish_app_design_pages(jsonb,text,text) to authenticated;
