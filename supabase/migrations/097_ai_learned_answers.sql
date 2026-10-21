-- 097_ai_learned_answers.sql
--
-- The assistant remembers.
--
-- WHY
-- ---
-- The local engine answers most questions on its own, and the language model
-- takes the rest. Every question the model had to answer was a question the
-- shop had never heard, and the answer it gave was thrown away with the
-- session: the next customer asked the same thing and paid for the same
-- model call again.
--
-- This table is that memory. The Edge Function stores the answer next to the
-- question, and serves it the next time the question comes up — so the
-- assistant gets faster and cheaper with every conversation instead of
-- starting from the same place every day.
--
-- DESIGN
-- ------
-- * The answer is written by the FUNCTION, never by the client. The client
--   cannot be trusted to send the truth, and a poisoned answer would be served
--   to every customer afterwards.
-- * `question_key` is the normalized question. The app normalizes it (same
--   rules the search uses), so "الأسعار" and "الاسعار" are one key.
-- * The exact key is the fast path. A trigram match catches the same question
--   asked differently ("ايه رأيك في الطقس" / "رايك ايه في الجو"), and the
--   threshold is high on purpose: a wrong answer is worse than a slow one.
-- * `pinned` protects a curated answer. The shop can edit or pin a row and
--   the assistant stops learning over it.
-- * `hits` counts how often a learned answer was served, so the shop can see
--   which learned answers earn their keep.
--
-- Only the Edge Function reads and writes this table: the `ai` schema is
-- closed to every client role, exactly like the rest of the assistant
-- knowledge.

create table if not exists ai.learned_answers (
  id            uuid primary key default extensions.gen_random_uuid(),
  question_key  text not null unique,
  question_text text not null,
  answer        text not null,
  provider      text,
  topic         text not null default 'learned',
  hits          integer not null default 0,
  pinned        boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table ai.learned_answers is
  'Answers the assistant learned from the language model, served back to the next customer who asks the same thing.';

create index if not exists ix_learned_answers_key_trgm
  on ai.learned_answers using gin (question_key extensions.gin_trgm_ops);

create index if not exists ix_learned_answers_hits
  on ai.learned_answers (hits desc);

drop trigger if exists tr_learned_answers_updated_at on ai.learned_answers;
create trigger tr_learned_answers_updated_at
  before update on ai.learned_answers
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Recall
-- ---------------------------------------------------------------------------
-- The function lives in `public` because that is the only schema PostgREST
-- exposes, and the Edge Function reaches it with the service role. The data
-- stays in `ai`: the function is the only door, and the door is locked for
-- every client role (see the grants at the end).
--
-- `extensions.similarity` is qualified because the function pins search_path
-- to ''.
create or replace function public.recall_learned_answer(
  p_question_key text,
  p_min_similarity real default 0.6
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

  -- The same question, asked again.
  select l.id, l.answer, l.provider, l.topic, l.hits
    into v_id, v_answer, v_provider, v_topic, v_hits
  from ai.learned_answers l
  where l.question_key = p_question_key;

  if v_id is not null then
    v_score := 1.0;
  else
    -- The same question, asked differently.
    select l.id, l.answer, l.provider, l.topic, l.hits,
           extensions.similarity(l.question_key, p_question_key)
      into v_id, v_answer, v_provider, v_topic, v_hits, v_score
    from ai.learned_answers l
    where extensions.similarity(l.question_key, p_question_key) >= p_min_similarity
    order by extensions.similarity(l.question_key, p_question_key) desc
    limit 1;

    if v_id is null then
      return;
    end if;
  end if;

  -- The table columns are qualified: the OUT parameters of the function share
  -- their names with the columns, and plpgsql would read `hits` as the
  -- parameter.
  update ai.learned_answers
     set hits = ai.learned_answers.hits + 1
   where ai.learned_answers.id = v_id;

  return query select v_id, v_answer, v_provider, v_topic, v_hits, v_score;
end;
$fn$;

comment on function public.recall_learned_answer(text, real) is
  'The remembered answer for a question: the exact key, or the closest question above the similarity threshold.';

-- ---------------------------------------------------------------------------
-- Remember
-- ---------------------------------------------------------------------------
-- A pinned row is never overwritten: a curated answer stays curated.
create or replace function public.remember_answer(
  p_question_key text,
  p_question_text text,
  p_answer text,
  p_provider text default null,
  p_topic text default 'learned'
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

  insert into ai.learned_answers
    (question_key, question_text, answer, provider, topic)
  values
    (btrim(p_question_key),
     left(coalesce(p_question_text, p_question_key), 500),
     left(btrim(p_answer), 2000),
     p_provider,
     coalesce(p_topic, 'learned'))
  on conflict (question_key) do update
    set answer = excluded.answer,
        question_text = excluded.question_text,
        provider = excluded.provider,
        topic = excluded.topic,
        updated_at = now()
    where ai.learned_answers.pinned = false
  returning id into v_id;

  -- A pinned row keeps its answer; the id is returned so the caller knows the
  -- question is already curated.
  if v_id is null then
    select l.id into v_id
    from ai.learned_answers l
    where l.question_key = btrim(p_question_key);
  end if;

  return v_id;
end;
$fn$;

comment on function public.remember_answer(text, text, text, text, text) is
  'Stores the answer the model gave, unless the question is already pinned.';

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- The Edge Function reaches these with the service role. No client role may
-- call them or read the table.
drop function if exists ai.recall_learned_answer(text, real);
drop function if exists ai.remember_answer(text, text, text, text, text);

revoke all on function public.recall_learned_answer(text, real)
  from public, anon, authenticated;
revoke all on function public.remember_answer(text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.recall_learned_answer(text, real)
  to service_role;
grant execute on function public.remember_answer(text, text, text, text, text)
  to service_role;

notify pgrst, 'reload schema';
