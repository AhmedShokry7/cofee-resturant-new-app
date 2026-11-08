-- Keep legacy conversation-training tables private to trusted server code.
-- Customer-facing access remains through the ownership-checking public RPCs.

alter table ai.conversation_patterns enable row level security;
alter table ai.conversations enable row level security;
alter table ai.conversation_feedback enable row level security;

revoke all on table ai.conversation_patterns,
  ai.conversations,
  ai.conversation_feedback
  from public, anon, authenticated;

grant usage on schema ai to service_role;
grant select on table ai.conversation_patterns to service_role;
grant select, insert, update, delete on table ai.conversations to service_role;
grant select, insert, update, delete on table ai.conversation_feedback to service_role;

drop policy if exists conversation_patterns_service_role
  on ai.conversation_patterns;
create policy conversation_patterns_service_role
  on ai.conversation_patterns
  for all to service_role
  using (true)
  with check (true);

drop policy if exists conversations_service_role on ai.conversations;
create policy conversations_service_role
  on ai.conversations
  for all to service_role
  using (true)
  with check (true);

drop policy if exists conversation_feedback_service_role
  on ai.conversation_feedback;
create policy conversation_feedback_service_role
  on ai.conversation_feedback
  for all to service_role
  using (true)
  with check (true);

comment on table ai.conversation_patterns is
  'Approved style examples; direct table access is restricted to service_role.';
comment on table ai.conversations is
  'Legacy conversation log; direct table access is restricted to service_role.';
comment on table ai.conversation_feedback is
  'Legacy conversation feedback; direct table access is restricted to service_role.';
