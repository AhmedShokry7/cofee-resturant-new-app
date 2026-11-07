-- 230_ai_customer_memory.sql
--
-- The assistant remembers *the customer*, not just the question.
--
-- WHY
-- ---
-- Everything the assistant knew about a person lived in SharedPreferences on
-- one phone: the scores, the draft, the transcript. Clear the app data and the
-- assistant forgets who you are; change phones and it starts over. Worse, the
-- one thing that *was* server-side — `ai.learned_answers` — is shared by every
-- customer, so anything learned from a conversation with one person can be
-- served to another. That is the opposite of what a personal assistant has to
-- be, and it is a privacy problem, not a feature gap.
--
-- This migration moves memory to the database, one island per customer:
--
-- * `ai.customer_memory`      — what the assistant knows about this person,
--                               classified, with provenance and a supersede
--                               chain, so newer information wins instead of
--                               piling up.
-- * `ai.assistant_conversations` / `ai.assistant_messages`
--                             — the transcript, so "that thing I asked last
--                               week" is retrievable and a new chat can be
--                               linked to the old one.
-- * `ai.assistant_feedback`   — the corrections and ratings, which is the raw
--                               material the assistant learns from.
-- * `ai.assistant_memory_consent`
--                             — nothing is written about a person until they
--                               said yes, and the flag is the gate, not a
--                               comment in the docs.
--
-- DESIGN
-- ------
-- * Identity: `customer_id` is the auth user id (`identity.profiles.id`). It is
--   stable across devices and cannot be chosen by the client, which is what
--   makes it safe to key a personal store on. Guests keep their device memory;
--   there is no anonymous personal island by design, because an anonymous
--   bucket is one collision away from being someone else's.
-- * Leakage is closed twice over. Row Level Security gives each customer only
--   their own rows for direct reads, and every function re-checks ownership
--   with `assistant_may_touch()` before it does anything, so the service role
--   (the Edge Function, which acts *for* a customer) is the only other door.
--   A cross-customer read is not "denied by policy" — the functions refuse.
-- * Classification is stored, not guessed at read time: `fact` (the person
--   stated it), `preference` (they like/dislike something), `opinion` (their
--   judgement, never a claim about the menu), `assumption` (the assistant
--   inferred it and is unsure). `confidence` and `source` travel with the row,
--   so an assumption is never served as a fact.
-- * Selective saving: the app writes short typed statements, never whole
--   transcripts, and `is_secret` rows are stored pgp-encrypted with a key that
--   lives in the Edge Function's secrets and never in the database.
-- * Supersede: one active row per (customer, kind, memory_key). Writing a newer
--   value retires the older one to `superseded` and records the link, so the
--   history is auditable but the recall path only ever sees the current truth.
-- * Retention: transcripts age out on a schedule; a person's "delete my
--   memory" is one call and cascades.

-- ---------------------------------------------------------------------------
-- Consent — the gate every write goes through
-- ---------------------------------------------------------------------------
create table if not exists ai.assistant_memory_consent (
  customer_id uuid primary key references identity.profiles(id) on delete cascade,
  memory_enabled boolean not null default false,
  web_search_enabled boolean not null default false,
  version        text not null default '230',
  updated_at     timestamptz not null default now()
);

comment on table ai.assistant_memory_consent is
  'Whether this customer allows the assistant to keep memory about them, and to look things up outside the app.';

-- ---------------------------------------------------------------------------
-- Per-customer memory
-- ---------------------------------------------------------------------------
create table if not exists ai.customer_memory (
  id            uuid primary key default extensions.gen_random_uuid(),
  customer_id   uuid not null references identity.profiles(id) on delete cascade,
  kind          text not null check (kind in ('fact','preference','opinion','assumption')),
  memory_key    text not null,
  value         text,
  value_cipher  bytea,
  is_secret     boolean not null default false,
  confidence    real not null default 0.5,
  source        text not null default 'user_said'
                check (source in ('user_said','assistant_asked','order_history','feedback','imported')),
  status        text not null default 'active'
                check (status in ('active','superseded','deleted')),
  supersedes_id uuid references ai.customer_memory(id) on delete set null,
  evidence_count integer not null default 1,
  locale        text,
  conversation_id uuid,
  first_seen    timestamptz not null default now(),
  last_seen     timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table ai.customer_memory is
  'What the assistant remembers about one customer: classified, provenanced, and superseded by newer information.';

comment on column ai.customer_memory.memory_key is
  'Stable slug the assistant dedupes on, e.g. prefers:latte, allergy:nuts, name:first.';
comment on column ai.customer_memory.value_cipher is
  'pgp-encrypted copy of the value for is_secret rows; the plaintext column stays null for them.';

create unique index if not exists uq_customer_memory_active
  on ai.customer_memory (customer_id, kind, memory_key)
  where status = 'active';
create index if not exists ix_customer_memory_recall
  on ai.customer_memory (customer_id, last_seen desc)
  where status = 'active';
create index if not exists ix_customer_memory_key_trgm
  on ai.customer_memory using gin (memory_key extensions.gin_trgm_ops)
  where status = 'active';

drop trigger if exists tr_customer_memory_updated_at on ai.customer_memory;
create trigger tr_customer_memory_updated_at
  before update on ai.customer_memory
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Transcript
-- ---------------------------------------------------------------------------
create table if not exists ai.assistant_conversations (
  id              uuid primary key default extensions.gen_random_uuid(),
  customer_id     uuid not null references identity.profiles(id) on delete cascade,
  topic           text,
  subject         text,
  started_at      timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  message_count   integer not null default 0,
  archived        boolean not null default false
);

comment on table ai.assistant_conversations is
  'One chat the assistant had with one customer; the anchor a new conversation can be linked back to.';

create index if not exists ix_assistant_conversations_customer
  on ai.assistant_conversations (customer_id, last_message_at desc);

alter table ai.customer_memory
  drop constraint if exists customer_memory_conversation_id_fkey;
alter table ai.customer_memory
  add constraint customer_memory_conversation_id_fkey
  foreign key (conversation_id) references ai.assistant_conversations(id)
  on delete set null;

create table if not exists ai.assistant_messages (
  id              uuid primary key default extensions.gen_random_uuid(),
  conversation_id uuid not null references ai.assistant_conversations(id) on delete cascade,
  customer_id     uuid not null references identity.profiles(id) on delete cascade,
  role            text not null check (role in ('user','assistant','tool')),
  text            text not null,
  sources         jsonb,
  created_at      timestamptz not null default now()
);

comment on table ai.assistant_messages is
  'The retained turns of a conversation. `sources` carries the links an answer was built from.';

create index if not exists ix_assistant_messages_conversation
  on ai.assistant_messages (conversation_id, created_at);
create index if not exists ix_assistant_messages_customer_trgm
  on ai.assistant_messages using gin (text extensions.gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Feedback — the material learning runs on
-- ---------------------------------------------------------------------------
create table if not exists ai.assistant_feedback (
  id            uuid primary key default extensions.gen_random_uuid(),
  customer_id   uuid not null references identity.profiles(id) on delete cascade,
  message_id    uuid references ai.assistant_messages(id) on delete set null,
  conversation_id uuid references ai.assistant_conversations(id) on delete set null,
  rating        smallint check (rating in (-1, 1)),
  correction    text,
  created_at    timestamptz not null default now()
);

comment on table ai.assistant_feedback is
  'A customer saying an answer was wrong or useless, ideally with the right answer. This is what the assistant improves from.';

create index if not exists ix_assistant_feedback_customer
  on ai.assistant_feedback (customer_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Row Level Security — each customer sees their own island and nothing else
-- ---------------------------------------------------------------------------
alter table ai.assistant_memory_consent enable row level security;
alter table ai.customer_memory enable row level security;
alter table ai.assistant_conversations enable row level security;
alter table ai.assistant_messages enable row level security;
alter table ai.assistant_feedback enable row level security;

-- No `force row level security` here and no table grants to clients: the `ai`
-- schema is reachable by the service role only (092), so every client path is a
-- `public.*` function below, and those functions check ownership themselves.
-- The policies are the second lock, for the day this schema is ever exposed.
drop policy if exists memory_consent_self on ai.assistant_memory_consent;
create policy memory_consent_self on ai.assistant_memory_consent
  for all to authenticated
  using (customer_id = auth.uid())
  with check (customer_id = auth.uid());

drop policy if exists customer_memory_self on ai.customer_memory;
create policy customer_memory_self on ai.customer_memory
  for all to authenticated
  using (customer_id = auth.uid() and status <> 'deleted')
  with check (customer_id = auth.uid());

drop policy if exists assistant_conversations_self on ai.assistant_conversations;
create policy assistant_conversations_self on ai.assistant_conversations
  for select to authenticated
  using (customer_id = auth.uid());

drop policy if exists assistant_messages_self on ai.assistant_messages;
create policy assistant_messages_self on ai.assistant_messages
  for select to authenticated
  using (customer_id = auth.uid());

drop policy if exists assistant_feedback_self on ai.assistant_feedback;
create policy assistant_feedback_self on ai.assistant_feedback
  for all to authenticated
  using (customer_id = auth.uid())
  with check (customer_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Ownership rule — one owner, used by every function below
-- ---------------------------------------------------------------------------
create or replace function public.assistant_may_touch(p_customer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select p_customer is not null
     and (auth.role() = 'service_role' or auth.uid() = p_customer);
$fn$;

comment on function public.assistant_may_touch(uuid) is
  'True only for the customer themselves or the service role acting for them. Every assistant memory function refuses without it, so a wrong customer id can never read or write another person''s island.';

-- ---------------------------------------------------------------------------
-- Consent read/write
-- ---------------------------------------------------------------------------
-- Every assistant RPC takes p_customer last and optional. Postgres forbids a
-- required parameter after a defaulted one, so the caller cannot come first —
-- and a Flutter call that names no customer is the common case.
create or replace function public.assistant_get_consent(p_customer uuid default null)
returns table (memory_enabled boolean, web_search_enabled boolean, version text)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    return;
  end if;

  return query
    select c.memory_enabled, c.web_search_enabled, c.version
    from ai.assistant_memory_consent c
    where c.customer_id = p_customer;
end;
$fn$;

create or replace function public.assistant_set_consent(
  p_memory_enabled boolean,
  p_web_search_enabled boolean default false,
  p_customer uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    raise exception 'not your memory' using errcode = '42501';
  end if;

  insert into ai.assistant_memory_consent
    (customer_id, memory_enabled, web_search_enabled)
  values (p_customer, p_memory_enabled, p_web_search_enabled)
  on conflict (customer_id) do update
    set memory_enabled = excluded.memory_enabled,
        web_search_enabled = excluded.web_search_enabled,
        updated_at = now();
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Recall — the context the assistant is allowed to think with
-- ---------------------------------------------------------------------------
create or replace function public.assistant_recall_memory(
  p_query text default '',
  p_limit integer default 12,
  p_customer uuid default null
)
returns table (
  id uuid,
  kind text,
  memory_key text,
  value text,
  confidence real,
  source text,
  last_seen timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    return;
  end if;

  -- Without consent there is no memory to recall, whatever the rows say.
  if not coalesce(
    (select c.memory_enabled from ai.assistant_memory_consent c
      where c.customer_id = p_customer), false) then
    return;
  end if;

  return query
    select m.id, m.kind, m.memory_key,
           case when m.is_secret then null else m.value end as value,
           m.confidence, m.source, m.last_seen
    from ai.customer_memory m
    where m.customer_id = p_customer
      and m.status = 'active'
      and (
        btrim(coalesce(p_query, '')) = ''
        or extensions.similarity(m.memory_key, p_query) > 0.15
        or extensions.similarity(coalesce(m.value, ''), p_query) > 0.15
        or coalesce(m.value, '') ilike '%' || btrim(p_query) || '%'
      )
    order by
      case when btrim(coalesce(p_query, '')) = '' then 1
           else greatest(
             extensions.similarity(m.memory_key, p_query),
             extensions.similarity(coalesce(m.value, ''), p_query)
           ) end desc,
      -- Stated facts outrank guesses when the two are equally close.
      case m.kind when 'fact' then 4 when 'preference' then 3
                  when 'opinion' then 2 else 1 end desc,
      m.last_seen desc
    limit greatest(1, least(coalesce(p_limit, 12), 40));
end;
$fn$;

comment on function public.assistant_recall_memory(text, integer, uuid) is
  'The current, consented memory of one customer, ranked against the question. Secret values are never returned as plaintext.';

-- ---------------------------------------------------------------------------
-- Write — with the supersede rule
-- ---------------------------------------------------------------------------
create or replace function public.assistant_remember(
  p_kind text,
  p_memory_key text,
  p_value text,
  p_source text default 'user_said',
  p_confidence real default 0.8,
  p_is_secret boolean default false,
  p_encryption_key text default null,
  p_conversation_id uuid default null,
  p_locale text default null,
  p_customer uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_consent boolean;
  v_old_id uuid;
  v_id uuid;
  v_value text := btrim(coalesce(p_value, ''));
  v_cipher bytea;
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    raise exception 'not your memory' using errcode = '42501';
  end if;

  select c.memory_enabled into v_consent
  from ai.assistant_memory_consent c
  where c.customer_id = p_customer;

  if not coalesce(v_consent, false) then
    raise exception 'memory is not enabled for this customer' using errcode = '22023';
  end if;

  if p_kind not in ('fact','preference','opinion','assumption') then
    raise exception 'unknown memory kind' using errcode = '22023';
  end if;
  if btrim(coalesce(p_memory_key, '')) = '' or v_value = '' then
    raise exception 'memory key and value are required' using errcode = '22023';
  end if;

  -- A secret is stored in one of two ways, and never in the clear.
  --
  -- With a key — only the Edge Function can have one, it lives in the
  -- function secrets — the sentence is encrypted and the plaintext column is
  -- dropped. Without a key the caller is a device, and a device has no way to
  -- protect what it writes, so the sentence is dropped and only the key
  -- survives: "this customer must not have dairy" is the part the assistant
  -- needs to answer with, and it is not a copy of somebody's health message.
  if p_is_secret then
    if btrim(coalesce(p_encryption_key, '')) = '' then
      v_value := null;
    else
      v_cipher := extensions.pgp_sym_encrypt(v_value, p_encryption_key);
      v_value := null;
    end if;
  end if;

  -- Newest wins: the previous active row for the same (kind, key) retires.
  update ai.customer_memory old
     set status = 'superseded', last_seen = now()
   where old.customer_id = p_customer
     and old.kind = p_kind
     and old.memory_key = btrim(p_memory_key)
     and old.status = 'active'
   returning old.id into v_old_id;

  -- Re-stating the same thing is evidence, not a new memory.
  if v_old_id is null then
    insert into ai.customer_memory
      (customer_id, kind, memory_key, value, value_cipher, is_secret,
       confidence, source, conversation_id, locale)
    values
      (p_customer, p_kind, btrim(p_memory_key), v_value, v_cipher, p_is_secret,
       greatest(0, least(coalesce(p_confidence, 0.8), 1)),
       coalesce(p_source, 'user_said'), p_conversation_id, p_locale)
    on conflict (customer_id, kind, memory_key) where status = 'active'
    do update
      set value = coalesce(excluded.value, ai.customer_memory.value),
          value_cipher = coalesce(excluded.value_cipher, ai.customer_memory.value_cipher),
          evidence_count = ai.customer_memory.evidence_count + 1,
          confidence = greatest(ai.customer_memory.confidence, excluded.confidence),
          last_seen = now()
    returning id into v_id;
  else
    insert into ai.customer_memory
      (customer_id, kind, memory_key, value, value_cipher, is_secret,
       confidence, source, supersedes_id, conversation_id, locale)
    values
      (p_customer, p_kind, btrim(p_memory_key), v_value, v_cipher, p_is_secret,
       greatest(0, least(coalesce(p_confidence, 0.8), 1)),
       coalesce(p_source, 'user_said'), v_old_id, p_conversation_id, p_locale)
    returning id into v_id;
  end if;

  return v_id;
end;
$fn$;

comment on function public.assistant_remember(text, text, text, text, real, boolean, text, uuid, text, uuid) is
  'Stores one memory for one customer behind the consent gate, retiring the older value for the same key.';

-- ---------------------------------------------------------------------------
-- Forget — one key, or the whole island
-- ---------------------------------------------------------------------------
create or replace function public.assistant_forget(
  p_memory_id uuid default null,
  p_memory_key text default null,
  p_customer uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    raise exception 'not your memory' using errcode = '42501';
  end if;

  delete from ai.customer_memory m
   where m.customer_id = p_customer
     and (
       (p_memory_id is not null and m.id = p_memory_id)
       or (p_memory_id is null and btrim(coalesce(p_memory_key,'')) <> ''
           and m.memory_key = btrim(p_memory_key))
     );
  get diagnostics v_count = row_count;

  return v_count;
end;
$fn$;

create or replace function public.assistant_erase(p_customer uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    raise exception 'not your memory' using errcode = '42501';
  end if;

  delete from ai.customer_memory m where m.customer_id = p_customer;
  delete from ai.assistant_feedback f where f.customer_id = p_customer;
  delete from ai.assistant_messages msg where msg.customer_id = p_customer;
  delete from ai.assistant_conversations c where c.customer_id = p_customer;
end;
$fn$;

comment on function public.assistant_erase(uuid) is
  'The right-to-be-forgotten button: every memory, transcript and feedback row for one customer, and nothing else.';

-- ---------------------------------------------------------------------------
-- Transcript writing and retrieval
-- ---------------------------------------------------------------------------
create or replace function public.assistant_log_message(
  p_role text,
  p_text text,
  p_conversation_id uuid default null,
  p_sources jsonb default null,
  p_topic text default null,
  p_customer uuid default null
)
returns table (conversation_id uuid, message_id uuid)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_conversation uuid := p_conversation_id;
  v_message uuid;
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    return query select null::uuid, null::uuid;
    return;
  end if;
  if p_role not in ('user','assistant','tool') or btrim(coalesce(p_text,'')) = '' then
    return query select null::uuid, null::uuid;
    return;
  end if;

  if v_conversation is null then
    insert into ai.assistant_conversations (customer_id, topic)
      values (p_customer, left(btrim(p_text), 120))
    returning ai.assistant_conversations.id into v_conversation;
  end if;

  insert into ai.assistant_messages (conversation_id, customer_id, role, text, sources)
    values (v_conversation, p_customer, p_role, left(btrim(p_text), 4000), p_sources)
  returning id into v_message;

  update ai.assistant_conversations c
     set last_message_at = now(),
         message_count = c.message_count + 1,
         topic = coalesce(p_topic, c.topic)
   where c.id = v_conversation;

  return query select v_conversation, v_message;
end;
$fn$;

-- The tail of the conversation the customer was last having, oldest line
-- first after the client reverses it. One conversation rather than the last N
-- messages of several: a chat continued across app launches is the point, and
-- mixing two conversations into one prompt is how the model starts answering a
-- question the customer stopped asking a week ago.
create or replace function public.assistant_recent_messages(
  p_limit integer default 8,
  p_customer uuid default null
)
returns table (
  id uuid,
  conversation_id uuid,
  role text,
  text text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    return;
  end if;

  return query
    with latest as (
      select c.id
      from ai.assistant_conversations c
      where c.customer_id = p_customer
      order by c.last_message_at desc
      limit 1
    )
    select m.id, m.conversation_id, m.role, m.text, m.created_at
    from ai.assistant_messages m
    join latest l on l.id = m.conversation_id
    where m.customer_id = p_customer
    order by m.created_at desc
    limit greatest(1, least(coalesce(p_limit, 8), 40));
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Feedback capture
-- ---------------------------------------------------------------------------
create or replace function public.assistant_record_feedback(
  p_rating smallint,
  p_message_id uuid default null,
  p_conversation_id uuid default null,
  p_correction text default null,
  p_customer uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
begin
  -- An authenticated caller is always itself; only the service role (the Edge
  -- Function, which read the id from a validated JWT) may name a customer.
  p_customer := coalesce(p_customer, auth.uid());
  if not public.assistant_may_touch(p_customer) then
    raise exception 'not your feedback' using errcode = '42501';
  end if;

  insert into ai.assistant_feedback
    (customer_id, message_id, conversation_id, rating, correction)
  values
    (p_customer, p_message_id, p_conversation_id, p_rating,
     left(btrim(coalesce(p_correction, '')), 500))
  returning id into v_id;

  return v_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Shared learning must never carry a person's words
-- ---------------------------------------------------------------------------
-- `ai.learned_answers` (097) serves one customer's answer to the next. That is
-- fine for shop questions and wrong for anything personal, so the table gains a
-- scope and the recall path is narrowed to the shared half.
alter table ai.learned_answers
  drop constraint if exists learned_answers_scope_check;
alter table ai.learned_answers
  add column if not exists scope text not null default 'shared'
  check (scope in ('shared','personal'));
alter table ai.learned_answers
  add column if not exists customer_id uuid
  references identity.profiles(id) on delete cascade;

create index if not exists ix_learned_answers_personal
  on ai.learned_answers (customer_id, updated_at desc)
  where scope = 'personal';

-- Recall now only ever serves shared answers unless the caller is that customer.
create or replace function public.recall_learned_answer(
  p_question_key text,
  p_min_similarity real default 0.6,
  p_customer uuid default null
)
returns table (
  id uuid,
  answer text,
  provider text,
  topic text,
  hits integer,
  score real
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_id       uuid;
  v_answer   text;
  v_provider text;
  v_topic    text;
  v_hits     integer;
  v_score    real := 0;
begin
  if p_question_key is null or btrim(p_question_key) = '' then
    return;
  end if;

  select l.id, l.answer, l.provider, l.topic, l.hits
    into v_id, v_answer, v_provider, v_topic, v_hits
  from ai.learned_answers l
  where l.question_key = btrim(p_question_key)
    and (l.scope = 'shared' or (p_customer is not null and l.customer_id = p_customer));

  if v_id is not null then
    v_score := 1.0;
  else
    select l.id, l.answer, l.provider, l.topic, l.hits,
           extensions.similarity(l.question_key, p_question_key)
      into v_id, v_answer, v_provider, v_topic, v_hits, v_score
    from ai.learned_answers l
    where extensions.similarity(l.question_key, p_question_key) >= p_min_similarity
      and (l.scope = 'shared' or (p_customer is not null and l.customer_id = p_customer))
    order by extensions.similarity(l.question_key, p_question_key) desc
    limit 1;

    if v_id is null then
      return;
    end if;
  end if;

  update ai.learned_answers
     set hits = ai.learned_answers.hits + 1
   where ai.learned_answers.id = v_id;

  return query select v_id, v_answer, v_provider, v_topic, v_hits, v_score;
end;
$fn$;

create or replace function public.remember_answer(
  p_question_key text,
  p_question_text text,
  p_answer text,
  p_provider text default null,
  p_topic text default 'learned',
  p_scope text default 'shared',
  p_customer uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
begin
  if p_question_key is null or btrim(p_question_key) = '' then
    raise exception 'question key is required' using errcode = '22023';
  end if;
  if p_answer is null or btrim(p_answer) = '' then
    raise exception 'answer is required' using errcode = '22023';
  end if;
  if p_scope not in ('shared','personal') then
    raise exception 'unknown learning scope' using errcode = '22023';
  end if;
  -- A personal answer needs an owner, otherwise it would be shared by the back
  -- door of a missing field.
  if p_scope = 'personal' and p_customer is null then
    raise exception 'personal learning needs a customer' using errcode = '22023';
  end if;

  insert into ai.learned_answers
    (question_key, question_text, answer, provider, topic, scope, customer_id)
  values
    (btrim(p_question_key),
     left(coalesce(p_question_text, p_question_key), 500),
     left(btrim(p_answer), 2000),
     p_provider,
     coalesce(p_topic, 'learned'),
     p_scope,
     p_customer)
  on conflict (question_key) do update
    set answer = excluded.answer,
        question_text = excluded.question_text,
        provider = excluded.provider,
        topic = excluded.topic,
        scope = excluded.scope,
        customer_id = excluded.customer_id,
        updated_at = now()
    where ai.learned_answers.pinned = false
  returning id into v_id;

  if v_id is null then
    select l.id into v_id
    from ai.learned_answers l
    where l.question_key = btrim(p_question_key);
  end if;

  return v_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Retention
-- ---------------------------------------------------------------------------
create or replace function public.prune_assistant_transcripts(p_keep_days integer default 180)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  delete from ai.assistant_messages m
   where m.created_at < now() - make_interval(days => greatest(coalesce(p_keep_days, 180), 30));
  get diagnostics v_count = row_count;

  delete from ai.assistant_conversations c
   where c.last_message_at < now() - make_interval(days => greatest(coalesce(p_keep_days, 180), 30) * 2);

  return v_count;
end;
$fn$;

do $do$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and not exists (select 1 from cron.job where jobname = 'prune-assistant-transcripts') then
    perform cron.schedule(
      'prune-assistant-transcripts',
      '15 3 * * *',
      $$select public.prune_assistant_transcripts(180);$$
    );
  end if;
end $do$;

-- ---------------------------------------------------------------------------
-- Grants — clients reach their own island, the Edge Function reaches all of it
-- ---------------------------------------------------------------------------
revoke all on function public.assistant_may_touch(uuid) from public, anon;
grant execute on function public.assistant_may_touch(uuid) to authenticated, service_role;

revoke all on function public.assistant_get_consent(uuid) from public, anon;
grant execute on function public.assistant_get_consent(uuid) to authenticated, service_role;
revoke all on function public.assistant_set_consent(uuid, boolean, boolean) from public, anon;
grant execute on function public.assistant_set_consent(uuid, boolean, boolean) to authenticated, service_role;
revoke all on function public.assistant_recall_memory(uuid, text, integer) from public, anon;
grant execute on function public.assistant_recall_memory(uuid, text, integer) to authenticated, service_role;
revoke all on function public.assistant_remember(uuid, text, text, text, text, real, boolean, text, uuid, text) from public, anon;
grant execute on function public.assistant_remember(uuid, text, text, text, text, real, boolean, text, uuid, text) to authenticated, service_role;
revoke all on function public.assistant_forget(uuid, uuid, text) from public, anon;
grant execute on function public.assistant_forget(uuid, uuid, text) to authenticated, service_role;
revoke all on function public.assistant_erase(uuid) from public, anon;
grant execute on function public.assistant_erase(uuid) to authenticated, service_role;
revoke all on function public.assistant_log_message(uuid, uuid, text, text, jsonb, text) from public, anon;
grant execute on function public.assistant_log_message(uuid, uuid, text, text, jsonb, text) to authenticated, service_role;
revoke all on function public.assistant_recent_messages(uuid, integer) from public, anon;
grant execute on function public.assistant_recent_messages(uuid, integer) to authenticated, service_role;
revoke all on function public.assistant_record_feedback(uuid, uuid, uuid, smallint, text) from public, anon;
grant execute on function public.assistant_record_feedback(uuid, uuid, uuid, smallint, text) to authenticated, service_role;

-- The two learning functions stay service-role only, as 097 left them, but the
-- new signatures have to be granted or the Edge Function cannot call them.
revoke all on function public.recall_learned_answer(text, real, uuid) from public, anon, authenticated;
grant execute on function public.recall_learned_answer(text, real, uuid) to service_role;
revoke all on function public.remember_answer(text, text, text, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.remember_answer(text, text, text, text, text, text, uuid) to service_role;

revoke all on function public.prune_assistant_transcripts(integer) from public, anon, authenticated;
grant execute on function public.prune_assistant_transcripts(integer) to service_role;

notify pgrst, 'reload schema';
