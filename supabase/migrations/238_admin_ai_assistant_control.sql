-- Secure, editable settings for the customer-facing AI assistant.
-- API credentials are write-only from the admin UI and remain in Supabase Vault.

create table if not exists ai.assistant_admin_config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default true,
  provider text not null default 'gemini'
    check (provider in ('gemini', 'groq', 'openrouter', 'openai', 'custom')),
  model text not null default 'gemini-3.8-flash',
  base_url text not null default 'https://generativelanguage.googleapis.com/v1beta/openai',
  system_prompt text not null default '',
  tone text not null default 'friendly'
    check (tone in ('friendly', 'professional', 'casual')),
  max_reply_chars integer not null default 700
    check (max_reply_chars between 200 and 2000),
  fallback_reply text not null default '',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

insert into ai.assistant_admin_config(singleton)
values (true)
on conflict (singleton) do nothing;

alter table ai.assistant_admin_config enable row level security;
revoke all on ai.assistant_admin_config from public, anon, authenticated, service_role;

create or replace function public.admin_ai_assistant_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_config ai.assistant_admin_config%rowtype;
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  select * into v_config from ai.assistant_admin_config where singleton = true;
  return jsonb_build_object(
    'enabled', coalesce(v_config.enabled, true),
    'provider', coalesce(v_config.provider, 'gemini'),
    'model', coalesce(v_config.model, 'gemini-3.8-flash'),
    'base_url', coalesce(v_config.base_url, ''),
    'system_prompt', coalesce(v_config.system_prompt, ''),
    'tone', coalesce(v_config.tone, 'friendly'),
    'max_reply_chars', coalesce(v_config.max_reply_chars, 700),
    'fallback_reply', coalesce(v_config.fallback_reply, ''),
    'has_api_key', exists (
      select 1 from vault.decrypted_secrets
      where name = 'assistant_provider_key' and decrypted_secret <> ''
    ),
    'updated_at', v_config.updated_at
  );
end;
$fn$;

create or replace function public.admin_ai_assistant_save_config(
  p_provider text,
  p_model text,
  p_base_url text,
  p_system_prompt text,
  p_tone text,
  p_max_reply_chars integer,
  p_fallback_reply text,
  p_enabled boolean,
  p_api_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_secret_id uuid;
  v_provider text := lower(btrim(coalesce(p_provider, '')));
  v_model text := btrim(coalesce(p_model, ''));
  v_base_url text := btrim(coalesce(p_base_url, ''));
  v_tone text := lower(btrim(coalesce(p_tone, 'friendly')));
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  if v_provider not in ('gemini', 'groq', 'openrouter', 'openai', 'custom') then
    raise exception 'invalid assistant provider' using errcode = '22023';
  end if;
  if v_tone not in ('friendly', 'professional', 'casual') then
    raise exception 'invalid assistant tone' using errcode = '22023';
  end if;
  if v_model = '' or char_length(v_model) > 160 then
    raise exception 'assistant model is required' using errcode = '22023';
  end if;
  if v_provider in ('custom', 'openai') and
     (v_base_url = '' or v_base_url !~ '^https://') then
    raise exception 'provider base URL must use HTTPS' using errcode = '22023';
  end if;
  if char_length(coalesce(p_system_prompt, '')) > 8000 or
     char_length(coalesce(p_fallback_reply, '')) > 1000 then
    raise exception 'assistant text is too long' using errcode = '22023';
  end if;

  insert into ai.assistant_admin_config(
    singleton, enabled, provider, model, base_url, system_prompt, tone,
    max_reply_chars, fallback_reply, updated_at, updated_by
  ) values (
    true, coalesce(p_enabled, true), v_provider, v_model, v_base_url,
    btrim(coalesce(p_system_prompt, '')), v_tone,
    greatest(200, least(coalesce(p_max_reply_chars, 700), 2000)),
    btrim(coalesce(p_fallback_reply, '')), now(), auth.uid()
  )
  on conflict (singleton) do update set
    enabled = excluded.enabled,
    provider = excluded.provider,
    model = excluded.model,
    base_url = excluded.base_url,
    system_prompt = excluded.system_prompt,
    tone = excluded.tone,
    max_reply_chars = excluded.max_reply_chars,
    fallback_reply = excluded.fallback_reply,
    updated_at = now(),
    updated_by = auth.uid();

  if nullif(btrim(coalesce(p_api_key, '')), '') is not null then
    select id into v_secret_id
      from vault.secrets
     where name = 'assistant_provider_key'
     order by created_at desc
     limit 1;
    if v_secret_id is null then
      perform vault.create_secret(
        btrim(p_api_key), 'assistant_provider_key',
        'Provider key managed by the admin assistant settings'
      );
    else
      perform vault.update_secret(
        v_secret_id, btrim(p_api_key), 'assistant_provider_key',
        'Provider key managed by the admin assistant settings'
      );
    end if;
  end if;

  return public.admin_ai_assistant_config();
end;
$fn$;

create or replace function public.admin_ai_knowledge_articles(
  p_search text default null,
  p_limit integer default 200
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare v_query text := lower(btrim(coalesce(p_search, '')));
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  return query
  select jsonb_build_object(
    'id', a.id, 'slug', a.slug, 'category', a.category,
    'title_ar', a.title_ar, 'title_en', a.title_en,
    'body_ar', a.body_ar, 'body_en', a.body_en,
    'keywords', a.keywords, 'sort_order', a.sort_order,
    'is_active', a.is_active, 'updated_at', a.updated_at
  )
  from ai.knowledge_articles a
  where v_query = '' or
    lower(a.title_ar || ' ' || a.title_en || ' ' || a.body_ar || ' ' ||
          a.body_en || ' ' || array_to_string(a.keywords, ' ')) like '%' || v_query || '%'
  order by a.sort_order, a.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 200), 500));
end;
$fn$;

create or replace function public.admin_ai_knowledge_save_article(p_article jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
  v_slug text := lower(btrim(coalesce(p_article->>'slug', '')));
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  if v_slug !~ '^[a-z0-9_]+$' or
     coalesce(btrim(p_article->>'title_ar'), '') = '' or
     coalesce(btrim(p_article->>'title_en'), '') = '' or
     coalesce(btrim(p_article->>'body_ar'), '') = '' or
     coalesce(btrim(p_article->>'body_en'), '') = '' then
    raise exception 'invalid assistant knowledge article' using errcode = '22023';
  end if;

  if nullif(p_article->>'id', '') is not null then
    v_id := (p_article->>'id')::uuid;
    update ai.knowledge_articles set
      slug = v_slug,
      category = coalesce(nullif(btrim(p_article->>'category'), ''), 'faq'),
      title_ar = btrim(p_article->>'title_ar'),
      title_en = btrim(p_article->>'title_en'),
      body_ar = btrim(p_article->>'body_ar'),
      body_en = btrim(p_article->>'body_en'),
      keywords = case when jsonb_typeof(p_article->'keywords') = 'array'
        then array(select jsonb_array_elements_text(p_article->'keywords')) else '{}'::text[] end,
      is_active = coalesce((p_article->>'is_active')::boolean, true)
    where id = v_id;
    if not found then raise exception 'assistant article not found' using errcode = 'P0002'; end if;
  else
    insert into ai.knowledge_articles(
      slug, category, title_ar, title_en, body_ar, body_en, keywords,
      is_active, sort_order
    ) values (
      v_slug,
      coalesce(nullif(btrim(p_article->>'category'), ''), 'faq'),
      btrim(p_article->>'title_ar'), btrim(p_article->>'title_en'),
      btrim(p_article->>'body_ar'), btrim(p_article->>'body_en'),
      case when jsonb_typeof(p_article->'keywords') = 'array'
        then array(select jsonb_array_elements_text(p_article->'keywords')) else '{}'::text[] end,
      coalesce((p_article->>'is_active')::boolean, true),
      coalesce((p_article->>'sort_order')::integer, 0)
    ) returning id into v_id;
  end if;
  return v_id;
end;
$fn$;

create or replace function public.admin_ai_knowledge_delete_article(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  delete from ai.knowledge_articles where id = p_id;
end;
$fn$;

-- This function is the only path by which the Edge Function receives a key.
-- It is not callable by anon or authenticated clients.
create or replace function public.assistant_runtime_config()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select jsonb_build_object(
    'enabled', c.enabled,
    'provider', c.provider,
    'model', c.model,
    'base_url', c.base_url,
    'system_prompt', c.system_prompt,
    'tone', c.tone,
    'max_reply_chars', c.max_reply_chars,
    'fallback_reply', c.fallback_reply,
    'api_key', coalesce((
      select d.decrypted_secret from vault.decrypted_secrets d
       where d.name = 'assistant_provider_key'
       order by d.created_at desc limit 1
    ), '')
  )
  from ai.assistant_admin_config c
  where c.singleton = true
$fn$;

revoke all on function public.admin_ai_assistant_config() from public, anon;
revoke all on function public.admin_ai_assistant_save_config(text, text, text, text, text, integer, text, boolean, text) from public, anon;
revoke all on function public.admin_ai_knowledge_articles(text, integer) from public, anon;
revoke all on function public.admin_ai_knowledge_save_article(jsonb) from public, anon;
revoke all on function public.admin_ai_knowledge_delete_article(uuid) from public, anon;
revoke all on function public.assistant_runtime_config() from public, anon, authenticated;
grant execute on function public.admin_ai_assistant_config() to authenticated;
grant execute on function public.admin_ai_assistant_save_config(text, text, text, text, text, integer, text, boolean, text) to authenticated;
grant execute on function public.admin_ai_knowledge_articles(text, integer) to authenticated;
grant execute on function public.admin_ai_knowledge_save_article(jsonb) to authenticated;
grant execute on function public.admin_ai_knowledge_delete_article(uuid) to authenticated;
grant execute on function public.assistant_runtime_config() to service_role;

notify pgrst, 'reload schema';
