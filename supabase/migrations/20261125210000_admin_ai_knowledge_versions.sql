-- Versioned, admin-only training content. It is deliberately kept out of
-- ai.knowledge_articles, which is the shared/customer retrieval corpus.
create table if not exists ai.admin_knowledge_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  knowledge_key text not null check (knowledge_key ~ '^[a-z0-9_]{2,80}$'),
  kind text not null check (kind in ('article', 'intent', 'example', 'synonym')),
  version integer not null check (version > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status text not null default 'draft'
    check (status in ('draft', 'pending_review', 'approved', 'published', 'archived')),
  previous_version_id uuid references ai.admin_knowledge_versions(id) on delete restrict,
  created_by uuid not null,
  submitted_by uuid,
  submitted_at timestamptz,
  reviewed_by uuid,
  reviewed_at timestamptz,
  published_by uuid,
  published_at timestamptz,
  archived_by uuid,
  archived_at timestamptz,
  archive_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (knowledge_key, version)
);

create index if not exists ix_admin_knowledge_versions_review
  on ai.admin_knowledge_versions(status, updated_at desc);
create index if not exists ix_admin_knowledge_versions_key
  on ai.admin_knowledge_versions(knowledge_key, version desc);
create unique index if not exists uq_admin_knowledge_one_published_version
  on ai.admin_knowledge_versions(knowledge_key)
  where status = 'published';
alter table ai.admin_knowledge_versions enable row level security;
revoke all on ai.admin_knowledge_versions from public, anon, authenticated, service_role;

create table if not exists ai.admin_knowledge_version_events (
  id uuid primary key default extensions.gen_random_uuid(),
  version_id uuid not null references ai.admin_knowledge_versions(id) on delete restrict,
  knowledge_key text not null,
  version integer not null,
  action text not null,
  from_status text,
  to_status text not null,
  actor_user_id uuid not null,
  reason text,
  happened_at timestamptz not null default now()
);
create index if not exists ix_admin_knowledge_version_events_history
  on ai.admin_knowledge_version_events(knowledge_key, version desc, happened_at);
alter table ai.admin_knowledge_version_events enable row level security;
revoke all on ai.admin_knowledge_version_events from public, anon, authenticated, service_role;

create or replace function public.admin_ai_knowledge_version_list(
  p_knowledge_key text default null,
  p_status text default null,
  p_limit integer default 100
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_key text := nullif(lower(btrim(coalesce(p_knowledge_key, ''))), '');
  v_status text := nullif(lower(btrim(coalesce(p_status, ''))), '');
begin
  if not identity.is_staff()
     or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if v_status is not null and v_status not in ('draft','pending_review','approved','published','archived') then
    raise exception 'invalid knowledge status' using errcode = '22023';
  end if;
  return query
  select jsonb_build_object(
    'id', v.id,
    'knowledge_key', v.knowledge_key,
    'kind', v.kind,
    'version', v.version,
    'payload', v.payload,
    'status', v.status,
    'previous_version_id', v.previous_version_id,
    'created_by', v.created_by,
    'submitted_by', v.submitted_by,
    'submitted_at', v.submitted_at,
    'reviewed_by', v.reviewed_by,
    'reviewed_at', v.reviewed_at,
    'published_by', v.published_by,
    'published_at', v.published_at,
    'archived_by', v.archived_by,
    'archived_at', v.archived_at,
    'archive_reason', v.archive_reason,
    'created_at', v.created_at,
    'updated_at', v.updated_at
  )
  from ai.admin_knowledge_versions v
  where (v_key is null or v.knowledge_key = v_key)
    and (v_status is null or v.status = v_status)
  order by v.updated_at desc, v.knowledge_key, v.version desc
  limit greatest(1, least(coalesce(p_limit, 100), 200));
end;
$fn$;

create or replace function public.admin_ai_knowledge_version_get(p_version_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id', v.id,
    'knowledge_key', v.knowledge_key,
    'kind', v.kind,
    'version', v.version,
    'payload', v.payload,
    'status', v.status,
    'previous_version_id', v.previous_version_id,
    'created_by', v.created_by,
    'submitted_by', v.submitted_by,
    'submitted_at', v.submitted_at,
    'reviewed_by', v.reviewed_by,
    'reviewed_at', v.reviewed_at,
    'published_by', v.published_by,
    'published_at', v.published_at,
    'archived_by', v.archived_by,
    'archived_at', v.archived_at,
    'archive_reason', v.archive_reason,
    'created_at', v.created_at,
    'updated_at', v.updated_at
  ) into v_result
  from ai.admin_knowledge_versions v where v.id = p_version_id;
  if v_result is null then raise exception 'knowledge version not found' using errcode = 'P0002'; end if;
  return v_result;
end;
$fn$;

create or replace function public.admin_ai_knowledge_version_save_draft(
  p_knowledge_key text,
  p_kind text,
  p_payload jsonb,
  p_version_id uuid default null,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_key text := lower(btrim(coalesce(p_knowledge_key, '')));
  v_kind text := lower(btrim(coalesce(p_kind, '')));
  v_version ai.admin_knowledge_versions%rowtype;
  v_number integer;
  v_previous uuid;
begin
  if not identity.is_staff()
     or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if v_key !~ '^[a-z0-9_]{2,80}$'
     or v_kind not in ('article', 'intent', 'example', 'synonym')
     or p_payload is null
     or jsonb_typeof(p_payload) <> 'object'
     or octet_length(p_payload::text) > 50000 then
    raise exception 'invalid knowledge draft' using errcode = '22023';
  end if;
  if v_kind = 'article' and (
    nullif(btrim(p_payload->>'title_ar'), '') is null
    or nullif(btrim(p_payload->>'title_en'), '') is null
    or nullif(btrim(p_payload->>'body_ar'), '') is null
    or nullif(btrim(p_payload->>'body_en'), '') is null
  ) then
    raise exception 'article needs Arabic and English title and body' using errcode = '22023';
  end if;
  if v_kind = 'intent' and (
    nullif(btrim(p_payload->>'intent'), '') is null
    or nullif(btrim(p_payload->>'description_ar'), '') is null
    or nullif(btrim(p_payload->>'description_en'), '') is null
  ) then
    raise exception 'intent needs a key and bilingual descriptions' using errcode = '22023';
  end if;
  if v_kind = 'example' and (
    nullif(btrim(p_payload->>'question_ar'), '') is null
    or nullif(btrim(p_payload->>'question_en'), '') is null
    or nullif(btrim(p_payload->>'intent'), '') is null
  ) then
    raise exception 'example needs bilingual questions and an intent' using errcode = '22023';
  end if;
  if v_kind = 'synonym' and (
    nullif(btrim(p_payload->>'intent'), '') is null
    or jsonb_typeof(p_payload->'terms_ar') is distinct from 'array'
    or jsonb_typeof(p_payload->'terms_en') is distinct from 'array'
  ) then
    raise exception 'synonyms need an intent and bilingual term arrays' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_key, 0));
  if p_version_id is null then
    select coalesce(max(v.version), 0) + 1, (array_agg(v.id order by v.version desc))[1]
      into v_number, v_previous
      from ai.admin_knowledge_versions v where v.knowledge_key = v_key;
    insert into ai.admin_knowledge_versions(
      knowledge_key, kind, version, payload, status, previous_version_id, created_by
    ) values (v_key, v_kind, v_number, p_payload, 'draft', v_previous, auth.uid())
    returning * into v_version;
    insert into ai.admin_knowledge_version_events(
      version_id, knowledge_key, version, action, from_status, to_status, actor_user_id
    ) values (v_version.id, v_key, v_number, 'draft_created', null, 'draft', auth.uid());
  else
    select * into v_version
      from ai.admin_knowledge_versions v
     where v.id = p_version_id
     for update;
    if not found or v_version.status <> 'draft' or v_version.created_by <> auth.uid()
       or v_version.knowledge_key <> v_key or v_version.kind <> v_kind then
      raise exception 'only your matching draft can be edited' using errcode = '42501';
    end if;
    if p_expected_updated_at is null or v_version.updated_at <> p_expected_updated_at then
      raise exception 'knowledge draft changed; reload before saving' using errcode = '40001';
    end if;
    update ai.admin_knowledge_versions
       set payload = p_payload, updated_at = now()
     where id = p_version_id returning * into v_version;
    insert into ai.admin_knowledge_version_events(
      version_id, knowledge_key, version, action, from_status, to_status, actor_user_id
    ) values (v_version.id, v_key, v_version.version, 'draft_updated', 'draft', 'draft', auth.uid());
  end if;
  return public.admin_ai_knowledge_version_get(v_version.id);
end;
$fn$;

create or replace function public.admin_ai_knowledge_version_transition(
  p_version_id uuid,
  p_action text,
  p_expected_updated_at timestamptz default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_version ai.admin_knowledge_versions%rowtype;
  v_new ai.admin_knowledge_versions%rowtype;
  v_archived ai.admin_knowledge_versions%rowtype;
  v_key text;
  v_number integer;
  v_previous uuid;
  v_reason text := left(btrim(coalesce(p_reason, '')), 500);
begin
  if not identity.is_staff()
     or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if v_action not in ('submit', 'approve', 'publish', 'archive', 'rollback') then
    raise exception 'invalid knowledge action' using errcode = '22023';
  end if;
  select knowledge_key into v_key
    from ai.admin_knowledge_versions where id = p_version_id;
  if not found then raise exception 'knowledge version not found' using errcode = 'P0002'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_key, 0));
  select * into v_version
    from ai.admin_knowledge_versions v
   where v.id = p_version_id
   for update;
  if p_expected_updated_at is null or v_version.updated_at <> p_expected_updated_at then
    raise exception 'knowledge version changed; reload before acting' using errcode = '40001';
  end if;

  if v_action = 'rollback' then
    if v_version.status not in ('published', 'archived') then
      raise exception 'only published history can be rolled back' using errcode = '22023';
    end if;
    select coalesce(max(v.version), 0) + 1 into v_number
      from ai.admin_knowledge_versions v where v.knowledge_key = v_version.knowledge_key;
    insert into ai.admin_knowledge_versions(
      knowledge_key, kind, version, payload, status, previous_version_id, created_by
    ) values (
      v_version.knowledge_key, v_version.kind, v_number, v_version.payload,
      'draft', v_version.id, auth.uid()
    ) returning * into v_new;
    insert into ai.admin_knowledge_version_events(
      version_id, knowledge_key, version, action, from_status, to_status,
      actor_user_id, reason
    ) values (
      v_new.id, v_new.knowledge_key, v_new.version, 'rollback_draft_created',
      v_version.status, 'draft', auth.uid(), v_reason
    );
    return public.admin_ai_knowledge_version_get(v_new.id);
  end if;

  if v_action = 'submit' and v_version.status = 'draft' then
    update ai.admin_knowledge_versions set status = 'pending_review',
      submitted_by = auth.uid(), submitted_at = now(), updated_at = now()
     where id = v_version.id returning * into v_version;
  elsif v_action = 'approve' and v_version.status = 'pending_review' then
    if v_version.created_by = auth.uid() then
      raise exception 'the author cannot approve their own knowledge version' using errcode = '42501';
    end if;
    update ai.admin_knowledge_versions set status = 'approved',
      reviewed_by = auth.uid(), reviewed_at = now(), updated_at = now()
     where id = v_version.id returning * into v_version;
  elsif v_action = 'publish' and v_version.status = 'approved' then
    if v_version.reviewed_by is null or v_version.reviewed_by = v_version.created_by then
      raise exception 'version needs a separate reviewer' using errcode = '42501';
    end if;
    for v_archived in
      update ai.admin_knowledge_versions
         set status = 'archived', archived_by = auth.uid(), archived_at = now(),
             archive_reason = 'superseded by a newer published version', updated_at = now()
       where knowledge_key = v_version.knowledge_key
         and status = 'published'
      returning *
    loop
      insert into ai.admin_knowledge_version_events(
        version_id, knowledge_key, version, action, from_status, to_status,
        actor_user_id, reason
      ) values (
        v_archived.id, v_archived.knowledge_key, v_archived.version,
        'superseded_by_publish', 'published', 'archived', auth.uid(),
        'superseded by a newer published version'
      );
    end loop;
    update ai.admin_knowledge_versions set status = 'published',
      published_by = auth.uid(), published_at = now(), updated_at = now()
     where id = v_version.id returning * into v_version;
  elsif v_action = 'archive' and v_version.status = 'published' then
    update ai.admin_knowledge_versions set status = 'archived',
      archived_by = auth.uid(), archived_at = now(), archive_reason = v_reason,
      updated_at = now()
     where id = v_version.id returning * into v_version;
  else
    raise exception 'action is not valid for the current knowledge status' using errcode = '22023';
  end if;

  insert into ai.admin_knowledge_version_events(
    version_id, knowledge_key, version, action, from_status, to_status,
    actor_user_id, reason
  ) values (
    v_version.id, v_version.knowledge_key, v_version.version, v_action,
    case v_action when 'submit' then 'draft'
                  when 'approve' then 'pending_review'
                  when 'publish' then 'approved'
                  else 'published' end,
    v_version.status, auth.uid(), v_reason
  );
  return public.admin_ai_knowledge_version_get(v_version.id);
end;
$fn$;

create or replace function public.admin_ai_knowledge_version_history(p_knowledge_key text)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff()
     or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  return query
  select jsonb_build_object(
    'id', e.id,
    'version_id', e.version_id,
    'knowledge_key', e.knowledge_key,
    'version', e.version,
    'action', e.action,
    'from_status', e.from_status,
    'to_status', e.to_status,
    'actor_user_id', e.actor_user_id,
    'reason', e.reason,
    'happened_at', e.happened_at
  )
    from ai.admin_knowledge_version_events e
   where e.knowledge_key = lower(btrim(coalesce(p_knowledge_key, '')))
   order by e.happened_at desc, e.id desc
   limit 500;
end;
$fn$;

create or replace function public.admin_ai_knowledge_search_published(
  p_query text,
  p_limit integer default 6
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_query text := lower(btrim(coalesce(p_query, '')));
begin
  if not identity.is_staff()
     or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if v_query = '' then return; end if;
  return query
  select jsonb_build_object(
    'knowledge_key', v.knowledge_key,
    'kind', v.kind,
    'version', v.version,
    'payload', v.payload
  )
    from ai.admin_knowledge_versions v
   where v.status = 'published'
     and strpos(lower(v.payload::text), v_query) > 0
   order by v.updated_at desc
   limit greatest(1, least(coalesce(p_limit, 6), 12));
end;
$fn$;

revoke all on function public.admin_ai_knowledge_version_list(text,text,integer) from public, anon;
revoke all on function public.admin_ai_knowledge_version_get(uuid) from public, anon;
revoke all on function public.admin_ai_knowledge_version_save_draft(text,text,jsonb,uuid,timestamptz) from public, anon;
revoke all on function public.admin_ai_knowledge_version_transition(uuid,text,timestamptz,text) from public, anon;
revoke all on function public.admin_ai_knowledge_version_history(text) from public, anon;
revoke all on function public.admin_ai_knowledge_search_published(text,integer) from public, anon;
grant execute on function public.admin_ai_knowledge_version_list(text,text,integer) to authenticated;
grant execute on function public.admin_ai_knowledge_version_get(uuid) to authenticated;
grant execute on function public.admin_ai_knowledge_version_save_draft(text,text,jsonb,uuid,timestamptz) to authenticated;
grant execute on function public.admin_ai_knowledge_version_transition(uuid,text,timestamptz,text) to authenticated;
grant execute on function public.admin_ai_knowledge_version_history(text) to authenticated;
grant execute on function public.admin_ai_knowledge_search_published(text,integer) to authenticated;

comment on table ai.admin_knowledge_versions is
  'Versioned admin-only assistant training data. Never included in shared/customer knowledge retrieval.';
comment on table ai.admin_knowledge_version_events is
  'Append-only reviewer and publication history for each admin knowledge version.';

notify pgrst, 'reload schema';
