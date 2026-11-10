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
