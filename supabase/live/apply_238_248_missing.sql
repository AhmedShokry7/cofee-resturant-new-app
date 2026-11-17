-- Apply the migrations missing from the live database: 238, 239, 244, 245,
-- 246, 247 and 248.
--
-- HOW TO APPLY: paste this whole file into the Supabase SQL Editor and run it
-- once. Safe to re-run: every statement is create or replace / drop if exists /
-- create if not exists.
--
-- WHY (verified 2025 against the live project webzzasosevzymftgszn):
--   * public.admin_image_assets_*() missing          -> visual editor's
--     "مكتبة صور التطبيق" shows "تعذر تحميل الصور" (PGRST202 on every call).
--   * storage.objects policies for design/, category-%/, banners/ and
--     subscription-plans/ missing (245 + 247 + 246)  -> uploading any image
--     from the visual editor fails with StorageException 403
--     "new row violates row-level security policy".
--   * public.admin_ai_assistant_config() / admin_ai_reply_examples() missing
--     (238 + 239)                                    -> AI assistant settings
--     pages in the dashboard fail.
--   * core.app_design_is_valid lacks schema v2 brand validation (244).

begin;

-- ===== 238_admin_ai_assistant_control.sql =====
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

-- ===== 239_admin_ai_reply_examples.sql =====
-- Admin-safe CRUD for reviewed response examples. The customer assistant already
-- reads this table; edits here immediately influence its few-shot guidance.

create or replace function public.admin_ai_reply_examples()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  return query
  select jsonb_build_object(
    'id', p.id,
    'category', p.category,
    'intent', p.intent,
    'user_message_ar', p.user_message_ar,
    'user_message_en', p.user_message_en,
    'response_variants', p.response_variants,
    'tone', p.tone,
    'complexity', p.complexity,
    'is_pinned', p.is_pinned,
    'weight', p.weight
  )
  from ai.conversation_patterns p
  order by p.is_pinned desc, p.weight desc, p.updated_at desc;
end;
$fn$;

create or replace function public.admin_ai_reply_example_save(p_example jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
  v_variants jsonb;
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  if coalesce(btrim(p_example->>'intent'), '') = '' or
     coalesce(btrim(p_example->>'user_message_ar'), '') = '' or
     coalesce(btrim(p_example->>'response_ar'), '') = '' then
    raise exception 'invalid assistant reply example' using errcode = '22023';
  end if;
  v_variants := jsonb_build_array(jsonb_build_object(
    'text_ar', btrim(p_example->>'response_ar'),
    'text_en', btrim(coalesce(p_example->>'response_en', '')),
    'variant_id', 'admin',
    'style_markers', jsonb_build_array('reviewed')
  ));

  if nullif(p_example->>'id', '') is not null then
    v_id := (p_example->>'id')::uuid;
    update ai.conversation_patterns set
      category = coalesce(nullif(btrim(p_example->>'category'), ''), 'general'),
      intent = btrim(p_example->>'intent'),
      user_message_ar = btrim(p_example->>'user_message_ar'),
      user_message_en = btrim(coalesce(p_example->>'user_message_en', '')),
      response_variants = v_variants,
      tone = coalesce(nullif(p_example->>'tone', ''), 'friendly'),
      complexity = 'simple',
      is_pinned = coalesce((p_example->>'is_pinned')::boolean, false),
      weight = 100
    where id = v_id;
    if not found then raise exception 'assistant reply example not found' using errcode = 'P0002'; end if;
  else
    insert into ai.conversation_patterns(
      category, intent, user_message_ar, user_message_en, response_variants,
      tone, complexity, tags, is_pinned, weight
    ) values (
      coalesce(nullif(btrim(p_example->>'category'), ''), 'general'),
      btrim(p_example->>'intent'),
      btrim(p_example->>'user_message_ar'),
      btrim(coalesce(p_example->>'user_message_en', '')),
      v_variants,
      coalesce(nullif(p_example->>'tone', ''), 'friendly'),
      'simple', array['admin_managed']::text[],
      coalesce((p_example->>'is_pinned')::boolean, false), 100
    ) returning id into v_id;
  end if;
  return v_id;
end;
$fn$;

create or replace function public.admin_ai_reply_example_delete(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.has_permission('settings.write') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  delete from ai.conversation_patterns where id = p_id;
end;
$fn$;

revoke all on function public.admin_ai_reply_examples() from public, anon;
revoke all on function public.admin_ai_reply_example_save(jsonb) from public, anon;
revoke all on function public.admin_ai_reply_example_delete(uuid) from public, anon;
grant execute on function public.admin_ai_reply_examples() to authenticated;
grant execute on function public.admin_ai_reply_example_save(jsonb) to authenticated;
grant execute on function public.admin_ai_reply_example_delete(uuid) to authenticated;

notify pgrst, 'reload schema';

-- ===== 244_app_design_all_pages.sql =====
-- 244_app_design_brand.sql
--
-- WHY THIS EXISTS
--
-- The Theme Studio carried colours and scales only. The shop owner asked to
-- edit the store's identity — name and logo — in the same place, with the
-- same publish/rollback pipeline, so the customer app can never drift from
-- what the dashboard shows.
--
-- The brand lives inside the theme object (`theme.brand`) because it is
-- shipped with the layout it decorates and rolls back with it. An absent
-- brand means the shipped identity (code constants and bundled logo); a brand
-- with fields means those fields win. The old documents stay valid untouched:
-- they simply read as "no brand" in the customer.
--
-- WHAT CHANGES (function only, no table/column/RPC)
--
--   * `core.app_design_is_valid` accepts `brand` inside a version-2 `theme`
--     and validates it: an object with only `name_ar`, `name_en`, `logo_url`
--     string values, names 1..80 characters, logo an http(s) URL <= 2048.
--     Unknown keys inside brand are rejected the same way unknown theme keys
--     are, so a future field cannot slip in silently.
--   * Everything else (roles, hex, scales, pages, nodes) is unchanged.

create or replace function core.app_design_is_valid(p_document jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_page        jsonb;
  v_check       jsonb;
  v_ids         jsonb := '[]'::jsonb;
  v_version     numeric;
  v_theme       jsonb;
  v_brand       jsonb;
begin
  if jsonb_typeof(p_document) <> 'object' then
    return 'document';
  end if;
  if jsonb_typeof(p_document -> 'schema_version') <> 'number' then
    return 'schema_version';
  end if;
  v_version := (p_document ->> 'schema_version')::numeric;
  if v_version not in (1, 2) then
    return 'schema_version';
  end if;
  if jsonb_typeof(p_document -> 'pages') <> 'array'
     or jsonb_array_length(p_document -> 'pages') = 0 then
    return 'pages';
  end if;
  if jsonb_array_length(p_document -> 'pages') > 40 then
    return 'page_count';
  end if;
  if exists (
    select 1
      from jsonb_array_elements(p_document -> 'pages') p
     where coalesce(p ->> 'page', '') not in
       ('splash', 'welcome', 'onboarding', 'auth', 'sign_up', 'forget_password', 'reset_password', 'phone_auth', 'email_auth', 'home', 'categories', 'search', 'product_details', 'cart', 'favourites', 'settings', 'checkout', 'shipping_addresses', 'add_address', 'payment_method', 'add_card', 'payment_success', 'e_receipt', 'coupon', 'orders', 'edit_profile', 'saved_cards', 'addresses', 'address_form', 'loyalty', 'subscription_plans', 'subscription_details', 'cashier_subscription', 'notifications', 'notification_settings', 'help', 'privacy', 'assistant_memory')
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

  ---------------------------------------------------------------------------
  -- The theme block, including the brand identity (244).
  ---------------------------------------------------------------------------
  v_theme := p_document -> 'theme';
  if v_theme is not null then
    if v_version <> 2 then
      return 'theme_version';
    end if;
    if jsonb_typeof(v_theme) <> 'object' then
      return 'theme';
    end if;
    if exists (
      select 1
        from jsonb_object_keys(v_theme) k
       where k not in ('colors', 'text_scale', 'radius_scale', 'brand')
    ) then
      return 'theme_key';
    end if;

    if v_theme ? 'colors' then
      if jsonb_typeof(v_theme -> 'colors') <> 'object' then
        return 'theme_colors';
      end if;
      if exists (
        select 1
          from jsonb_object_keys(v_theme -> 'colors') r
         where r not in (
           'primary', 'secondary', 'background', 'surface',
           'text_primary', 'text_secondary', 'border',
           'success', 'error', 'disabled')
      ) then
        return 'theme_color_role';
      end if;
      if exists (
        select 1
          from jsonb_each(v_theme -> 'colors') c
         where jsonb_typeof(c.value) <> 'string'
            or c.value #>> '{}' !~ '^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$'
      ) then
        return 'theme_color_value';
      end if;
    end if;

    if v_theme ? 'text_scale' and (
      jsonb_typeof(v_theme -> 'text_scale') <> 'string'
      or v_theme ->> 'text_scale' not in
         ('default', 'compact', 'comfortable', 'large')
    ) then
      return 'theme_text_scale';
    end if;
    if v_theme ? 'radius_scale' and (
      jsonb_typeof(v_theme -> 'radius_scale') <> 'string'
      or v_theme ->> 'radius_scale' not in
         ('default', 'sharp', 'soft', 'round', 'pill')
    ) then
      return 'theme_radius_scale';
    end if;

    -------------------------------------------------------------------------
    -- The brand identity: name in both languages and a logo URL.
    -- A field that is present must read as a usable value; the empty brand
    -- (no keys) is allowed and means the shipped identity, the same rule the
    -- theme block uses for colours.
    -------------------------------------------------------------------------
    if v_theme ? 'brand' then
      v_brand := v_theme -> 'brand';
      if jsonb_typeof(v_brand) <> 'object' then
        return 'brand';
      end if;
      if exists (
        select 1
          from jsonb_object_keys(v_brand) k
         where k not in ('name_ar', 'name_en', 'logo_url')
      ) then
        return 'brand_key';
      end if;
      if exists (
        select 1 from jsonb_each(v_brand) b
         where jsonb_typeof(b.value) <> 'string'
      ) then
        return 'brand_value';
      end if;
      if (v_brand ? 'name_ar' and char_length(v_brand ->> 'name_ar') > 80)
         or (v_brand ? 'name_en' and char_length(v_brand ->> 'name_en') > 80)
      then
        return 'brand_name';
      end if;
      if v_brand ? 'logo_url' then
        if char_length(v_brand ->> 'logo_url') > 2048
           or v_brand ->> 'logo_url' !~ '^https?://'
        then
          return 'brand_logo_url';
        end if;
      end if;
    end if;
  end if;

  return null;
end;
$fn$;

comment on function core.app_design_is_valid(jsonb) is
  'Null when a design document is structurally publishable, else the first broken part as a code the panel prints. Accepts schema_version 1 (no theme) and 2 (optional theme); validates colour roles, hex values, scale names and the brand identity (244).';

notify pgrst, 'reload config';

-- ===== 245_app_design_image_storage.sql =====
-- Images uploaded by the visual editor live in product-images/design/.
-- Keep this namespace separate from catalogue assets: editing app design has
-- its own permission and must not implicitly grant product write access.
-- Idempotent; this migration is prepared for deployment, not applied here.

drop policy if exists "app_design_images_staff_insert" on storage.objects;
create policy "app_design_images_staff_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  );

drop policy if exists "app_design_images_staff_update" on storage.objects;
create policy "app_design_images_staff_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  );

drop policy if exists "app_design_images_staff_delete" on storage.objects;
create policy "app_design_images_staff_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'design'
    and identity.has_permission('design.edit')
  );

-- ===== 246_subscription_plan_image_storage.sql =====
-- Subscription plan images are customer-facing content, separate from app
-- design images. Reads and writes stay behind the subscriptions permission.
-- Apply 247_catalog_image_storage_permissions.sql after this migration; it
-- reasserts the generic product policy with category/banner/branch exclusions
-- and adds their dedicated writers.

create or replace function public.admin_subscription_plan_images()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'image_url', p.image_url))
      from subscriptions.plans p
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscription_plan_images() from public, anon;
grant execute on function public.admin_subscription_plan_images() to authenticated;

create or replace function public.admin_set_subscription_plan_image(
  p_plan_id uuid,
  p_image_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  update subscriptions.plans
     set image_url = nullif(btrim(coalesce(p_image_url, '')), '')
   where id = p_plan_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'id', p_plan_id);
end;
$fn$;

revoke all on function public.admin_set_subscription_plan_image(uuid, text) from public, anon;
grant execute on function public.admin_set_subscription_plan_image(uuid, text) to authenticated;

-- Replace the broad products-folder policies before adding feature-scoped
-- rules; PostgreSQL combines permissive storage policies with OR semantics.
drop policy if exists "product_images_staff_insert" on storage.objects;
create policy "product_images_staff_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_update" on storage.objects;
create policy "product_images_staff_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_delete" on storage.objects;
create policy "product_images_staff_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists subscription_plan_images_staff_insert on storage.objects;
create policy subscription_plan_images_staff_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  );

drop policy if exists subscription_plan_images_staff_update on storage.objects;
create policy subscription_plan_images_staff_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  );

drop policy if exists subscription_plan_images_staff_delete on storage.objects;
create policy subscription_plan_images_staff_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'subscription-plans'
    and identity.has_permission('subscriptions.manage')
  );

-- ===== 247_catalog_image_storage_permissions.sql =====
-- Category and banner image paths have feature-specific permissions. The
-- product-images bucket's generic catalogue policy must not let product
-- writers bypass those owners' checks, nor block those owners from uploading.
-- This migration is prepared for deployment, not applied here.

drop policy if exists "product_images_staff_insert" on storage.objects;
create policy "product_images_staff_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_update" on storage.objects;
create policy "product_images_staff_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists "product_images_staff_delete" on storage.objects;
create policy "product_images_staff_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] not in ('subscription-plans', 'banners')
    and (storage.foldername(name))[2] not like 'category-%'
    and (storage.foldername(name))[2] not like 'branch-%'
    and identity.has_permission('catalog.product.write')
  );

drop policy if exists category_images_staff_insert on storage.objects;
create policy category_images_staff_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  );

drop policy if exists category_images_staff_update on storage.objects;
create policy category_images_staff_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  );

drop policy if exists category_images_staff_delete on storage.objects;
create policy category_images_staff_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] like 'category-%'
    and identity.has_permission('catalog.category.write')
  );

drop policy if exists banner_images_staff_insert on storage.objects;
create policy banner_images_staff_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  );

drop policy if exists banner_images_staff_update on storage.objects;
create policy banner_images_staff_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  );

drop policy if exists banner_images_staff_delete on storage.objects;
create policy banner_images_staff_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = 'products'
    and (storage.foldername(name))[2] = 'banners'
    and identity.has_permission('settings.write')
  );

-- ===== 248_admin_visual_editor_image_assets.sql =====
-- Read the complete customer-facing image library for staff members who can
-- manage each owning feature. The visual editor never writes catalogue rows
-- itself; replacement/removal still use their feature-specific repositories.

create or replace function public.admin_image_assets_catalog()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(asset order by asset->>'asset_kind', asset->>'name_en')
      from (
        select jsonb_build_object(
          'asset_kind', 'product', 'id', p.id,
          'name_ar', p.name_ar, 'name_en', p.name_en, 'image_url', p.image_url
        ) as asset
          from catalog.products p
         where identity.has_permission('catalog.product.write')
        union all
        select jsonb_build_object(
          'asset_kind', 'category', 'id', c.id,
          'name_ar', c.name_ar, 'name_en', c.name_en, 'image_url', c.image_url
        ) as asset
          from catalog.categories c
         where identity.has_permission('catalog.category.write')
      ) assets
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_catalog() from public, anon;
grant execute on function public.admin_image_assets_catalog() to authenticated;

create or replace function public.admin_image_assets_product_images()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('catalog.product.write') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', pi.id, 'product_id', pi.product_id, 'image_url', pi.image_url,
      'alt_ar', pi.alt_ar, 'alt_en', pi.alt_en, 'sort_order', pi.sort_order,
      'is_primary', pi.is_primary
    ) order by pi.product_id, pi.sort_order)
      from catalog.product_images pi
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_product_images() from public, anon;
grant execute on function public.admin_image_assets_product_images() to authenticated;

create or replace function public.admin_image_assets_banners()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'title_ar', b.title_ar, 'title_en', b.title_en,
      'image_url', b.image_url
    ) order by b.sort_order)
      from marketing.banners b
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_banners() from public, anon;
grant execute on function public.admin_image_assets_banners() to authenticated;

create or replace function public.admin_image_assets_bundles()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('catalog.product.write') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name_ar', b.name_ar, 'name_en', b.name_en,
      'image_url', b.image_url
    ) order by b.sort_order)
      from catalog.bundles b
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_image_assets_bundles() from public, anon;
grant execute on function public.admin_image_assets_bundles() to authenticated;

commit;
notify pgrst, 'reload schema';
