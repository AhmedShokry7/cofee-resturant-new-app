-- Rollback-only reviewer, version history, rollback-draft, and audience checks.
begin;

insert into auth.users (id, email) values
  ('98f20000-0000-4000-8000-000000000001', 'ai-knowledge-author@test.local'),
  ('98f20000-0000-4000-8000-000000000002', 'ai-knowledge-reviewer@test.local');
insert into identity.staff_members (id, user_id, status, full_name, email) values
  ('98f30000-0000-4000-8000-000000000001', '98f20000-0000-4000-8000-000000000001', 'active', 'Knowledge Author', 'ai-knowledge-author@test.local'),
  ('98f30000-0000-4000-8000-000000000002', '98f20000-0000-4000-8000-000000000002', 'active', 'Knowledge Reviewer', 'ai-knowledge-reviewer@test.local');
insert into identity.roles (code, name_ar, name_en, is_system)
values ('assistant_knowledge_test', 'مراجع معرفة اختبار', 'Assistant Knowledge Test', false);
insert into identity.staff_roles (staff_id, role_id, branch_id)
select staff_id, r.id, null
  from (values
    ('98f30000-0000-4000-8000-000000000001'::uuid),
    ('98f30000-0000-4000-8000-000000000002'::uuid)
  ) assigned(staff_id)
  cross join identity.roles r
 where r.code = 'assistant_knowledge_test';
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r
join identity.permissions p on p.code = 'settings.write'
where r.code = 'assistant_knowledge_test'
on conflict do nothing;

do $$ begin
  if has_table_privilege('authenticated', 'ai.admin_knowledge_versions', 'select') then
    raise exception 'FAIL: authenticated can read the training table directly';
  end if;
  if has_function_privilege('anon', 'public.admin_ai_knowledge_version_list(text,text,integer)', 'execute') then
    raise exception 'FAIL: anon can list admin training versions';
  end if;
end $$;

set local role authenticated;
do $$
declare
  v_id uuid;
  v_result jsonb;
  v_updated timestamptz;
  v_history jsonb;
  v_search jsonb;
  v_author_claims text := '{"sub":"98f20000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}';
  v_reviewer_claims text := '{"sub":"98f20000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}';
begin
  perform set_config('request.jwt.claims', v_author_claims, true);
  v_result := public.admin_ai_knowledge_version_save_draft(
    'assistant_training_test', 'article',
    '{"title_ar":"معلومة إدارية اختبار","title_en":"Test admin fact","body_ar":"إجابة إدارية فقط","body_en":"Admin-only answer","keywords":["training test"]}'::jsonb
  );
  v_id := (v_result->>'id')::uuid;
  if v_result->>'status' <> 'draft' or v_result->>'version' <> '1' then
    raise exception 'FAIL: initial version was not saved as draft: %', v_result;
  end if;

  v_result := public.admin_ai_knowledge_version_transition(
    v_id, 'submit', (v_result->>'updated_at')::timestamptz, null
  );
  if v_result->>'status' <> 'pending_review' then
    raise exception 'FAIL: draft did not enter pending review: %', v_result;
  end if;

  begin
    perform public.admin_ai_knowledge_version_transition(
      v_id, 'approve', (v_result->>'updated_at')::timestamptz, null
    );
    raise exception 'FAIL: author approved their own version';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;

  perform set_config('request.jwt.claims', v_reviewer_claims, true);
  v_result := public.admin_ai_knowledge_version_transition(
    v_id, 'approve', (v_result->>'updated_at')::timestamptz, null
  );
  if v_result->>'status' <> 'approved'
     or v_result->>'reviewed_by' <> '98f20000-0000-4000-8000-000000000002' then
    raise exception 'FAIL: explicit reviewer was not recorded: %', v_result;
  end if;

  perform set_config('request.jwt.claims', v_author_claims, true);
  v_result := public.admin_ai_knowledge_version_transition(
    v_id, 'publish', (v_result->>'updated_at')::timestamptz, null
  );
  if v_result->>'status' <> 'published' then
    raise exception 'FAIL: approved version did not publish: %', v_result;
  end if;

  select coalesce(jsonb_agg(s.value), '[]'::jsonb) into v_search
    from public.admin_ai_knowledge_search_published('Admin-only answer') as s(value);
  if jsonb_array_length(v_search) <> 1
     or v_search->0->>'knowledge_key' <> 'assistant_training_test' then
    raise exception 'FAIL: published admin-only version was not searchable to admins: %', v_search;
  end if;

  select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb) into v_search
    from public.assistant_search_knowledge('Admin-only answer', null, 'en', 6) as s
   where s.source_type = 'article';
  if jsonb_array_length(v_search) <> 0 then
    raise exception 'FAIL: admin training leaked into shared/customer retrieval: %', v_search;
  end if;

  v_result := public.admin_ai_knowledge_version_transition(
    v_id, 'rollback', (v_result->>'updated_at')::timestamptz, 'restore for review'
  );
  if v_result->>'status' <> 'draft'
     or v_result->>'version' <> '2'
     or v_result->>'previous_version_id' <> v_id::text then
    raise exception 'FAIL: rollback did not create a new reviewed draft: %', v_result;
  end if;

  select coalesce(jsonb_agg(row), '[]'::jsonb) into v_history
    from public.admin_ai_knowledge_version_history('assistant_training_test') row;
  if jsonb_array_length(v_history) <> 5 then
    raise exception 'FAIL: expected five version events, got %', v_history;
  end if;
end $$;

rollback;
