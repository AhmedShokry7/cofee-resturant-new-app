-- 232_ai_conversation_training.sql
--
-- Natural conversation training data for the AI assistant.
--
-- WHY
-- ---
-- The current assistant gives robotic, repeated answers. Customers expect
-- natural, varied conversations like they'd have at a real coffee shop.
--
-- This creates structured training data with:
-- * Conversation patterns (greeting → question → answer → follow-up)
-- * Personality tokens for each response type
-- * Few-shot examples that the LLM can learn from
-- * Arabic dialect variations (Egyptian + formal)
-- * Context-aware responses based on user type and time
--
-- DESIGN
-- ------
-- * One table per pattern category (greetings, product_qa, order_help, etc.)
-- * Each example has multiple response variants to encourage variation
-- * Metadata fields for context (time_of_day, user_type, complexity)
-- * Tags for categorizing response styles
-- * Pinned examples stay forever; unpinned ones age out

-- ---------------------------------------------------------------------------
-- 1. GREETING PATTERNS
-- ---------------------------------------------------------------------------
create table if not exists ai.conversation_patterns (
  id              uuid primary key default extensions.gen_random_uuid(),
  category        text not null,
  intent          text not null,
  
  -- The user's typical message that triggers this pattern
  user_message_ar text not null,
  user_message_en text not null,
  
  -- Multiple variant responses to encourage variation (at least 3)
  response_variants jsonb not null default '[]'::jsonb,
  
  -- When this pattern applies
  context_flags jsonb default '{}',
  
  -- Response style metadata
  tone            text not null default 'friendly',
  complexity      text not null default 'simple',
  tags            text[] not null default '{}',
  
  -- Training metadata
  is_pinned       boolean not null default false,
  weight          integer not null default 100,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table ai.conversation_patterns is
  'Natural conversation training examples with multiple response variants.';

comment on column ai.conversation_patterns.category is
  'Grouping: greetings, product_qa, order_help, loyalty, complaints, general';

comment on column ai.conversation_patterns.intent is
  'Specific purpose: welcome, hours_inquiry, menu_recommendation, etc.';

comment on column ai.conversation_patterns.response_variants is
  'Array of response objects, each with text and style markers. Use ≥3 variants.';

comment on column ai.conversation_patterns.context_flags is
  '{"time_of_day": "morning", "user_type": "returning", "branch_id": "..."}';

comment on column ai.conversation_patterns.tone is
  'friendly | professional | casual | enthusiastic | empathetic';

comment on column ai.conversation_patterns.complexity is
  'simple | detailed | concise | story-driven';

create index ix_conversation_patterns_category on ai.conversation_patterns (category);
create index ix_conversation_patterns_tags on ai.conversation_patterns using gin (tags);
create index ix_conversation_patterns_pinned on ai.conversation_patterns (is_pinned) where is_pinned = true;

create trigger tr_conversation_patterns_updated_at
  before update on ai.conversation_patterns
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. FEEDBACK LOOP TABLE
-- ---------------------------------------------------------------------------
-- This table is created before feedback because the feedback rows reference it.
create table if not exists ai.conversations (
  id              uuid primary key default extensions.gen_random_uuid(),
  user_id         uuid references auth.users(id),
  session_id      text not null,
  messages        jsonb not null default '[]'::jsonb,
  topic           text,
  source          text not null default 'app',
  language        text not null default 'ar',
  response_time_ms integer,
  retrieval_score numeric,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table if not exists ai.conversation_feedback (
  id              uuid primary key default extensions.gen_random_uuid(),
  conversation_id uuid not null references ai.conversations(id) on delete cascade,
  user_id         uuid references auth.users(id),
  
  -- Was the response helpful?
  helpful         boolean,
  
  -- What could be better?
  improvement_suggestions text[],
  
  -- Which variant was used? (for A/B learning)
  used_variant    integer,
  
  feedback_text   text,
  
  created_at      timestamptz not null default now()
);

create index ix_conversation_feedback_conversation on ai.conversation_feedback (conversation_id);
create index ix_conversation_feedback_user on ai.conversation_feedback (user_id);

-- ---------------------------------------------------------------------------
-- Conversation-derived learning is a review queue, never an automatic truth
-- ---------------------------------------------------------------------------
create table if not exists ai.assistant_knowledge_gaps (
  id                uuid primary key default extensions.gen_random_uuid(),
  question_hash     text not null unique,
  question          text not null check (char_length(question) between 3 and 300),
  locale            text not null default 'ar' check (locale in ('ar','en')),
  topic             text not null default 'cafe',
  occurrences       integer not null default 1 check (occurrences > 0),
  first_seen_at     timestamptz not null default now(),
  last_seen_at      timestamptz not null default now(),
  status            text not null default 'open'
                    check (status in ('open','addressed','dismissed')),
  knowledge_slug    text,
  created_at        timestamptz not null default now()
);

comment on table ai.assistant_knowledge_gaps is
  'Anonymous, deduplicated cafe questions that opted-in customers asked when the assistant had no grounded answer. Review and publish a knowledge article before resolving; the queue is not itself model training.';

create index if not exists ix_assistant_knowledge_gaps_review
  on ai.assistant_knowledge_gaps (status, occurrences desc, last_seen_at desc);
alter table ai.assistant_knowledge_gaps enable row level security;

create or replace function public.assistant_record_knowledge_gap(
  p_question text,
  p_locale text default 'ar',
  p_topic text default 'cafe'
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_question text := left(regexp_replace(btrim(coalesce(p_question, '')), '\s+', ' ', 'g'), 300);
  v_hash text;
begin
  if char_length(v_question) < 3 then return; end if;
  if p_locale not in ('ar','en') then p_locale := 'ar'; end if;
  v_hash := md5(lower(v_question));

  insert into ai.assistant_knowledge_gaps
    (question_hash, question, locale, topic)
  values
    (v_hash, v_question, p_locale, left(coalesce(p_topic, 'cafe'), 40))
  on conflict (question_hash) do update
    set occurrences = ai.assistant_knowledge_gaps.occurrences + 1,
        last_seen_at = now();
end;
$fn$;

revoke all on function public.assistant_record_knowledge_gap(text, text, text)
  from public, anon, authenticated;
grant execute on function public.assistant_record_knowledge_gap(text, text, text)
  to service_role;

create table if not exists ai.assistant_learning_candidates (
  id              uuid primary key default extensions.gen_random_uuid(),
  feedback_id     uuid not null unique references ai.assistant_feedback(id) on delete cascade,
  customer_id     uuid not null references identity.profiles(id) on delete cascade,
  conversation_id uuid references ai.assistant_conversations(id) on delete cascade,
  question        text not null,
  answer_rejected text not null,
  correction      text,
  sources         jsonb,
  status          text not null default 'pending_review'
                  check (status in ('pending_review','published','dismissed')),
  knowledge_slug  text,
  created_at      timestamptz not null default now(),
  reviewed_at     timestamptz
);

comment on table ai.assistant_learning_candidates is
  'A customer downvote and optional correction, linked to its owner and transcript. Review and redact before turning it into shared cafe knowledge.';

create index if not exists ix_assistant_learning_candidates_review
  on ai.assistant_learning_candidates (status, created_at desc);
alter table ai.assistant_learning_candidates enable row level security;

create or replace function ai.capture_assistant_learning_candidate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_question text;
  v_answer text;
  v_sources jsonb;
begin
  if new.rating <> -1 or new.message_id is null then return new; end if;

  select assistant.text, assistant.sources, customer.text
    into v_answer, v_sources, v_question
    from ai.assistant_messages assistant
    join lateral (
      select user_message.text
        from ai.assistant_messages user_message
       where user_message.conversation_id = assistant.conversation_id
         and user_message.customer_id = assistant.customer_id
         and user_message.role = 'user'
         and user_message.created_at < assistant.created_at
       order by user_message.created_at desc
       limit 1
    ) customer on true
   where assistant.id = new.message_id
     and assistant.customer_id = new.customer_id
     and assistant.role = 'assistant';

  if v_question is null or v_answer is null then return new; end if;
  insert into ai.assistant_learning_candidates
    (feedback_id, customer_id, conversation_id, question, answer_rejected,
     correction, sources)
  values
    (new.id, new.customer_id, new.conversation_id,
     left(v_question, 500), left(v_answer, 1500),
     nullif(left(btrim(coalesce(new.correction, '')), 500), ''), v_sources)
  on conflict (feedback_id) do nothing;
  return new;
end;
$fn$;

revoke all on function ai.capture_assistant_learning_candidate()
  from public, anon, authenticated;

drop trigger if exists tr_assistant_learning_candidate on ai.assistant_feedback;
create trigger tr_assistant_learning_candidate
  after insert on ai.assistant_feedback
  for each row execute function ai.capture_assistant_learning_candidate();

create or replace function public.assistant_record_learning_feedback(
  p_rating smallint,
  p_question text,
  p_answer text,
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
  v_feedback_id uuid;
  v_customer uuid := coalesce(p_customer, auth.uid());
  v_question text := left(btrim(coalesce(p_question, '')), 500);
  v_answer text := left(btrim(coalesce(p_answer, '')), 1500);
  v_correction text := nullif(left(btrim(coalesce(p_correction, '')), 500), '');
begin
  if p_rating is null or p_rating not in (-1, 1) then
    raise exception 'rating must be -1 or 1' using errcode = '22023';
  end if;
  if not public.assistant_may_touch(v_customer) then
    raise exception 'not your feedback' using errcode = '42501';
  end if;

  insert into ai.assistant_feedback
    (customer_id, message_id, conversation_id, rating, correction)
  values
    (v_customer, p_message_id, p_conversation_id, p_rating, v_correction)
  returning id into v_feedback_id;

  if p_rating = -1 and v_question <> '' and v_answer <> '' then
    insert into ai.assistant_learning_candidates
      (feedback_id, customer_id, conversation_id, question,
       answer_rejected, correction)
    values
      (v_feedback_id, v_customer, p_conversation_id, v_question,
       v_answer, v_correction)
    on conflict (feedback_id) do update
      set question = excluded.question,
          answer_rejected = excluded.answer_rejected,
          correction = coalesce(excluded.correction,
                                ai.assistant_learning_candidates.correction);
  end if;
  return v_feedback_id;
end;
$fn$;

revoke all on function public.assistant_record_learning_feedback(smallint, text, text, uuid, uuid, text, uuid)
  from public, anon;
grant execute on function public.assistant_record_learning_feedback(smallint, text, text, uuid, uuid, text, uuid)
  to authenticated, service_role;

-- Service-role-only publishing is the final review step. The Edge Function
-- never publishes user text directly into shared answers.
create or replace function public.assistant_publish_learning_candidate(
  p_candidate_id uuid,
  p_slug text,
  p_title_ar text,
  p_title_en text,
  p_body_ar text,
  p_body_en text,
  p_keywords text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_article_id uuid;
begin
  if p_slug !~ '^learned_[a-z0-9_]{1,50}$' then
    raise exception 'invalid learned article slug' using errcode = '22023';
  end if;
  if nullif(btrim(p_title_ar), '') is null
     or nullif(btrim(p_title_en), '') is null
     or nullif(btrim(p_body_ar), '') is null
     or nullif(btrim(p_body_en), '') is null then
    raise exception 'both languages need a reviewed title and answer' using errcode = '22023';
  end if;

  insert into ai.knowledge_articles
    (slug, category, title_ar, title_en, body_ar, body_en, keywords, is_active)
  values
    (p_slug, 'cafe_learning', left(btrim(p_title_ar), 160),
     left(btrim(p_title_en), 160), left(btrim(p_body_ar), 5000),
     left(btrim(p_body_en), 5000), coalesce(p_keywords, '{}'), true)
  on conflict (slug) do update
    set title_ar = excluded.title_ar,
        title_en = excluded.title_en,
        body_ar = excluded.body_ar,
        body_en = excluded.body_en,
        keywords = excluded.keywords,
        is_active = true
    where ai.knowledge_articles.category = 'cafe_learning'
  returning id into v_article_id;

  if v_article_id is null then
    raise exception 'learned slug may not replace curated knowledge' using errcode = '23505';
  end if;
  update ai.assistant_learning_candidates
     set status = 'published', knowledge_slug = p_slug, reviewed_at = now()
   where id = p_candidate_id and status = 'pending_review';
  if not found then
    raise exception 'candidate is not pending review' using errcode = 'P0002';
  end if;
  return v_article_id;
end;
$fn$;

revoke all on function public.assistant_publish_learning_candidate(uuid, text, text, text, text, text, text[])
  from public, anon, authenticated;
grant execute on function public.assistant_publish_learning_candidate(uuid, text, text, text, text, text, text[])
  to service_role;

-- ---------------------------------------------------------------------------
-- 3. CONVERSATION LOGS (for continuous learning)
-- ---------------------------------------------------------------------------
create table if not exists ai.conversations (
  id              uuid primary key default extensions.gen_random_uuid(),
  user_id         uuid references auth.users(id),
  session_id      text not null,
  
  messages        jsonb not null default '[]'::jsonb,
  
  -- Metadata about the conversation
  topic           text,
  source          text not null default 'app',
  language        text not null default 'ar',
  
  -- Performance metrics
  response_time_ms integer,
  retrieval_score numeric,
  
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index ix_conversations_user on ai.conversations (user_id);
create index ix_conversations_session on ai.conversations (session_id);
create index ix_conversations_created on ai.conversations (created_at desc);

-- Coffee education is stable knowledge. Menu facts, prices, ingredients and
-- branch availability continue to come from their live database records.
insert into ai.knowledge_articles
  (slug, category, title_ar, title_en, body_ar, body_en, keywords, is_active)
values
  (
    'coffee_basics', 'coffee_education',
    'أساسيات مشروبات القهوة', 'Coffee drink basics',
    'الإسبريسو قهوة مركزة تُحضّر بضغط الماء الساخن خلال بن ناعم. اللاتيه غالبًا يحتوي إسبريسو ولبنًا أكثر مع رغوة خفيفة، والكابتشينو رغوته أوضح ونسبة القهوة فيه عادةً أظهر. المقادير تختلف حسب وصفة كل كافيه، لذلك تفاصيل المنتج في المنيو هي المرجع للمكونات الفعلية.',
    'Espresso is concentrated coffee brewed by forcing hot water through finely ground coffee. A latte usually combines espresso with more steamed milk and a light foam; a cappuccino usually has a more noticeable foam and stronger coffee impression. Ratios vary by cafe recipe, so the current menu is the authority for actual product ingredients.',
    array['قهوة','اسبريسو','لاتيه','كابتشينو','الفرق بين اللاتيه والكابتشينو','espresso','latte','cappuccino','coffee drinks'], true
  ),
  (
    'cold_coffee_basics', 'coffee_education',
    'الفرق بين القهوة المثلجة والكولد برو', 'Iced coffee and cold brew',
    'القهوة المثلجة وصف عام لمشروب قهوة يُقدّم باردًا أو مع الثلج. الآيس لاتيه غالبًا إسبريسو ولبن بارد وثلج، أما الكولد برو فيُحضّر بنقع البن في ماء بارد مدة طويلة. وصفة الكافيه هي المرجع لتحديد مكونات أي صنف موجود في المنيو.',
    'Iced coffee is a general term for coffee served cold or over ice. An iced latte is commonly espresso, cold milk and ice; cold brew is made by steeping coffee grounds in cool water for an extended time. The cafe recipe is the source of truth for any menu item.',
    array['قهوة باردة','مثلجة','آيس لاتيه','كولد برو','cold brew','iced coffee','iced latte'], true
  ),
  (
    'caffeine_benefits', 'coffee_education',
    'تأثير الكافيين واليقظة', 'Caffeine and alertness',
    'الكافيين قد يزيد اليقظة مؤقتًا ويقلل النعاس، لكن تأثيره ومدته يختلفان بين الأشخاص. لا يعني ذلك أن القهوة تمنع مرضًا أو تعالجه. توضح FDA أن الحساسية تتأثر بعوامل مثل الحالة الصحية والأدوية والوزن. المصدر: https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much',
    'Caffeine may temporarily increase alertness and reduce sleepiness, but effects vary by person. This does not mean coffee prevents or treats disease. The FDA notes sensitivity can depend on health conditions, medicines and body weight. Source: https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much',
    array['فوائد القهوة','القهوة والتركيز','القهوة واليقظة','تأثير الكافيين','coffee benefits','alertness','caffeine effects'], true
  ),
  (
    'caffeine_risks', 'coffee_education',
    'الكافيين والآثار الجانبية', 'Caffeine limits and possible effects',
    'زيادة الكافيين قد تسبب اضطراب النوم أو التوتر والرعشة أو الخفقان، وتختلف الحساسية بين الأشخاص. تذكر FDA أن 400 مجم يوميًا لا ترتبط عادةً بآثار سلبية لمعظم البالغين الأصحاء، وليست هدفًا أو ضمانًا لكل شخص. توصي EFSA بألا يتجاوز إجمالي الكافيين 200 مجم يوميًا أثناء الحمل. كمية الكافيين في مشروب بعينه لا تُستنتج من اسمه فقط؛ نحتاج بيانات وصفته. المصادر: https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much https://www.efsa.europa.eu/en/topics/topic/caffeine',
    'Too much caffeine may cause sleep disruption, anxiety, jitters or palpitations, and sensitivity varies. FDA cites 400 mg/day as an amount not generally associated with negative effects for most healthy adults; it is not a target or guarantee for every person. EFSA advises a total of no more than 200 mg/day during pregnancy. The caffeine amount in a specific drink cannot be inferred from its name; the recipe data is needed. Sources: https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much https://www.efsa.europa.eu/en/topics/topic/caffeine',
    array['أضرار القهوة','اضرار الكافيين','القهوة والنوم','القهوة والحمل','الكافيين والقلق','coffee side effects','caffeine limit','sleep','pregnancy'], true
  )
on conflict (slug) do update
  set category = excluded.category,
      title_ar = excluded.title_ar,
      title_en = excluded.title_en,
      body_ar = excluded.body_ar,
      body_en = excluded.body_en,
      keywords = excluded.keywords,
      is_active = true;

-- ---------------------------------------------------------------------------
-- SAMPLE DATA: Natural Arabic Coffee Shop Conversations
-- ---------------------------------------------------------------------------

-- Category: greetings, Intent: welcome_new_user
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'greetings', 'welcome_new_user',
  'مرحباً', 'Hello',
  '[
    {
      "text_ar": "أهلاً بيك في [اسم الكافيه]! 👋 اشربي تحب تبدأ؟ عندي كوبس إسبريسو طازج، أو كابتشينو بناتي، أو حتى لاتيه بالكراميل اللي فاتح الهم",
      "text_en": "Welcome to [Coffee Shop Name]! 👋 What would you like to start with? We have fresh espresso, a nice cappuccino, or caramel latte that lifts your spirits.",
      "variant_id": "v1",
      "style_markers": ["emoji", "casual", "recommendation"]
    },
    {
      "text_ar": "مرحباً بك يا غالي! 🌟 [اسم الكافيه] عشانك. أنا مساعدك الذكي، لو عندك أي سؤال عن القائمة، الأسعار، أو غيري حاجة تفضل تسأل",
      "text_en": "Welcome dear! 🌟 [Coffee Shop Name] is here for you. I''m your smart assistant. Ask me anything about the menu, prices, or more.",
      "variant_id": "v2",
      "style_markers": ["warm", "helpful"]
    },
    {
      "text_ar": "صباح/مساكم نور! ☕[اسم الكافيه] جاهز يخدمك. إيه اللي دايماً بتطلعه لما جاي؟ أنا هنا عشان أسهل عليك الطلب",
      "text_en": "Good morning/evening! ☀️[Coffee Shop Name] is ready to serve you. What''s your usual go-to when you visit? I''m here to make ordering easier.",
      "variant_id": "v3",
      "style_markers": ["familiar", "engaging"]
    }
  ]'::jsonb,
  '{"branch_id": null}',
  'friendly', 'simple',
  '{"greeting", "new_user"}'
);

-- Category: greetings, Intent: returning_customer
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'greetings', 'returning_customer',
  'مرحباً', 'Hello',
  '[
    {
      "text_ar": "أهلاً بيك ثانية! 👋 اتقدرك باللي نورتينا مرة تانية. طلبك الحالي زي السابق ولا هنغير من النهاردة؟ 😊",
      "text_en": "Welcome back! 👋 So glad to see you again. Are you sticking with your usual or trying something new today? 😊",
      "variant_id": "v1",
      "style_markers": ["familiar", "personalized"]
    },
    {
      "text_ar": "يا هلا وغلا! 🌟 لقيتك مرة تانية. أنا متأكد إنك هتعجبك القهوة الجديدة اللي أوديناها الشهر ده",
      "text_en": "You''re back! 🌟 I''m sure you''ll love our new specialty coffees we just introduced this month",
      "variant_id": "v2",
      "style_markers": ["enthusiastic", "promotional"]
    },
    {
      "text_ar": "مرحباً! ❤️ الدوام عليكم. إحنا دائماً مستنيينك بقهوة مميزة وعلاقة حلوة",
      "text_en": "Welcome! ❤️ We always look forward to seeing you with a special coffee and warm connection",
      "variant_id": "v3",
      "style_markers": ["emotional", "loyal"]
    }
  ]'::jsonb,
  '{"user_type": "returning", "has_order_history": true}',
  'friendly', 'simple',
  '{"greeting", "returning_customer"}'
);

-- Category: product_qa, Intent: hours_inquiry
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'product_qa', 'hours_inquiry',
  'إنتوا فتيحين ازاي؟', 'What are your hours?',
  '[
    {
      "text_ar": "[اسم الكافيه] مفتوح من [8 ص - 11 م] يومين لحد خمسة، و[9 ص - 12 منتصف الليل] السبت والأحد. يوم الجمعة [9 ص - 5 عصر] فقط. لو عندك موعد خاص قولي وأنا أحجز لك طالع",
      "text_en": "[Coffee Shop Name] is open [8 AM - 11 PM] Mon-Fri, [9 AM - 12 AM] Sat-Sun, and [9 AM - 5 PM] Friday only. If you need special hours, let me know and I''ll arrange it.",
      "variant_id": "v1",
      "style_markers": ["informative", "helpful"]
    },
    {
      "text_ar": "في وقت طويل جداً! 🌞 من 8 صباح حتى 11 مساءً معظم الأيام. السبت الأحد نقدر نطمن نص الليل، وكلنا لك! 😄",
      "text_en": "We''ve got long hours! 🌞 From 8 AM until 11 PM most days. Saturday and Sunday we extend till midnight, all for you! 😄",
      "variant_id": "v2",
      "style_markers": ["casual", "friendly", "emoji"]
    }
  ]'::jsonb,
  '{"context": "information"}',
  'friendly', 'simple',
  '{"hours","information"}'
);

-- Category: product_qa, Intent: menu_recommendation
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'product_qa', 'menu_recommendation',
  'إيه اللي بتوصي به؟', 'What do you recommend?',
  '[
    {
      "text_ar": "أنا بنوصي بـ [اسم المنتج المفضل] 😊 طعمه مميز جداً وفي نوتات الشوكولاتة والقرفة. لو تحب حاجة خفيفة، الكرواسون بالجبن كريمي خيار رائع!",
      "text_en": "I highly recommend [Favorite Product] 😊 It has distinctive taste with chocolate and cinnamon notes. For something light, croissant with creamy cheese is a great choice!",
      "variant_id": "v1",
      "style_markers": ["personal", "enthusiastic"]
    },
    {
      "text_ar": "دي اختيارات العملاء الدايما: 🌟 لاتيه بالكرامول المملح، كابتشينو بالشوكولاتة البلجيكية، وخبز التوست بالحواواش. إيه ذوقك غالباً؟ حنقدر نضيقلك الخيارات",
      "text_en": "These are our regulars'' favorite choices: 🌟 Salted caramel latte, Belgian chocolate cappuccino, and havash toast. What''s your usual preference? We can narrow it down.",
      "variant_id": "v2",
      "style_markers": ["social_proof", "engaging"]
    },
    {
      "text_ar": "يعطيك العافية! ☕ أنا عندي ٣ اقتراحات حسب مزاجك اليوم:\n- صباح قوي: إسبريسو دبل شوت\n- استراحة ممتعة: كاراميل ماكياتو\n- خفيف وصحي: أمريكانو مع شيري\nإيه اللي يناسبك النهاردة؟",
      "text_en": "Bless you! ☕ I have 3 suggestions based on your mood today:\n- Strong morning: Double shot espresso\n- Pleasant break: Caramel macchiato\n- Light & healthy: Americano with cherry\nWhich suits you today?",
      "variant_id": "v3",
      "style_markers": ["structured", "helpful"]
    }
  ]'::jsonb,
  '{"context": "recommendation"}',
  'friendly', 'detailed',
  '{"recommendation", "popular_items"}'
);

-- Category: product_qa, Intent: dietary_inquiry
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'product_qa', 'dietary_inquiry',
  'إيه اللي محتواه قهوة؟ ولا فيه سكر؟', 'Is this coffee? Does it have sugar?',
  '[
    {
      "text_ar": "أهلاً! [اسم المنتج] فيه [المكونات الأساسية]. السكر موجود في [نسبة %] من المنتجات، وأنا هنا عشان أساعدك تختار اللي يناسب نظامك الغذائي. لو عندك حساسية أو قيود تانية، قولي بالتفصيل",
      "text_en": "Hello! [Product Name] contains [main ingredients]. Sugar is present in [X%] of products, and I''m here to help you choose what suits your diet. If you have allergies or restrictions, please tell me in detail.",
      "variant_id": "v1",
      "style_markers": ["informative", "careful"]
    },
    {
      "text_ar": "تمام يا فندم! 📋 ده تحليل دقيق للمنتج:\n🥛 مكونات أساسية: [قائمة]\n🍬 نسبة سكر: [منخفض/عالي/بدون سكر]\n⚠️ حساسيات محتملة: [قائمة]\n\nخليني أعرفك تفصيل أكثر لو حبيت!",
      "text_en": "Perfect, sir! 📋 Here''s a detailed breakdown:\n🥛 Main ingredients: [list]\n🍬 Sugar content: [low/high/none]\n⚠️ Possible allergens: [list]\n\nLet me know if you want more details!",
      "variant_id": "v2",
      "style_markers": ["detailed", "structured"]
    }
  ]'::jsonb,
  '{"context": "dietary", "requires_precision": true}',
  'professional', 'detailed',
  '{"ingredients", "allergens", "health"}'
);

-- Category: order_help, Intent: order_modification
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'order_help', 'order_modification',
  'عايز غير طلباتي', 'I want to modify my order',
  '[
    {
      "text_ar": "لا يهمك! 🔄 ممكن نعدل أي حاجة في الطلب قبل ما يبدأ التحضير. قولي إيه اللي تحب تغيره - حجم، مكونات، إضافة جانبية؟ هنساعدك في ثانية",
      "text_en": "No problem! 🔄 We can modify anything in your order before preparation starts. Tell me what you''d like to change - size, ingredients, add-ons? We''ll help you immediately.",
      "variant_id": "v1",
      "style_markers": ["reassuring", "quick"]
    },
    {
      "text_ar": "في نفس الوقت! ⚡ أنا هعدل لك الطلب فوراً. قولي بس الإيميل أو رقم الجوال للطلب، وأنا هخدها منك التعديلات المطلوبة",
      "text_en": "Right away! ⭐ I''ll modify your order immediately. Just give me the email or phone number for the order, and I''ll get those changes for you.",
      "variant_id": "v2",
      "style_markers": ["efficient", "action-oriented"]
    }
  ]'::jsonb,
  '{"context": "order_management"}',
  'friendly', 'concise',
  '{"order", "modification"}'
);

-- Category: loyalty, Intent: points_inquiry
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'loyalty', 'points_inquiry',
  'لدينا نقاط وفلتس؟', 'Do we have points and rewards?',
  '[
    {
      "text_ar": "يا سلام! 🎁 أنت جزء من برنامج الولاء الخاص بنا! كل [10] شربة = [1] مجاناً. دلوقتي عندك [X] نقطة، وبقرب [Y] نقاط عشان المكافأة التالية! 💫",
      "text_en": "Awesome! 🎁 You''re part of our loyalty program! Every [10] purchases = [1] free. Currently you have [X] points, and just [Y] points away from your next reward! 💫",
      "variant_id": "v1",
      "style_markers": ["exciting", "rewarding", "emoji"]
    },
    {
      "text_ar": "طبعاً! 🏆 برنامج الولاء بيجمع نقاط لكل طلب، والـ [100] نقطة = كوبس مجاني أو خصم [20%]. خلينا نشوف نقاطك الحالية...",
      "text_en": "Of course! 🏆 The loyalty program collects points for each order, and [100] points = free drink or [20%] discount. Let me check your current points...",
      "variant_id": "v2",
      "style_markers": ["formal", "rewarding"]
    }
  ]'::jsonb,
  '{"context": "loyalty_program"}',
  'enthusiastic', 'simple',
  '{"loyalty", "rewards", "points"}'
);

-- Category: general, Intent: apology_service_issue
insert into ai.conversation_patterns (
  category, intent, user_message_ar, user_message_en,
  response_variants, context_flags, tone, complexity, tags
) values (
  'general', 'apology_service_issue',
  'الخدمة مش زي ما كانت', 'Service is not as expected',
  '[
    {
      "text_ar": "يا غالي، أنا آسف جداً على التجربة دي 😔 ده مش المستوى اللي بنحاول نقفزه دائماً. قولي تفاصيل الموقف عشان نفهم ونحل المشكلة فوراً - هل المشكلة في الانتظار، الجودة، ولا غيري؟",
      "text_en": "Dear, I''m very sorry for this experience 😔 This isn''t the standard we always try to meet. Tell me the details so we can understand and fix the problem immediately - was it about waiting time, quality, or something else?",
      "variant_id": "v1",
      "style_markers": ["empathetic", "solution-oriented"]
    },
    {
      "text_ar": "آسف يا كبير! 🙏 ده مش طبيعي في [اسم الكافيه]. إحنا بنحب كل عميل وهداياكم معنا. قولي إيه حصل وأنا هتصرف مباشرة عشان تصحح",
      "text_en": "Sorry, dear! 🙏 This isn''t normal at [Coffee Shop Name]. We love every customer and care about you. Tell me what happened and I''ll act immediately to fix it.",
      "variant_id": "v2",
      "style_markers": ["apologetic", "caring"]
    },
    {
      "text_ar": "مرحباً، أنا فاهم إنك مستاء 😞 ده تماماً مش هدفنا. أنا هحول المشكلتك لمدير الفرع دلوقتي وهيرجع عليك في أقل من [30] دقيقة مع حل مناسب. شكراً إنك خبرتنا!",
      "text_en": "Hello, I understand you''re dissatisfied 😞 That''s exactly not our goal. I''ll escalate your issue to the branch manager now and they''ll get back to you within [30] minutes with a suitable solution. Thank you for letting us know!",
      "variant_id": "v3",
      "style_markers": ["professional", "escalating"]
    }
  ]'::jsonb,
  '{"context": "complaint", "urgent": true}',
  'empathetic', 'detailed',
  '{"apology", "complaint", "service_recovery"}'
);

-- ---------------------------------------------------------------------------
-- HELPER FUNCTIONS FOR NATURAL RESPONSE GENERATION
-- ---------------------------------------------------------------------------

-- Replace the draft examples above with reviewed, fact-neutral chat examples.
-- They teach tone only: every current product, price, schedule and promise must
-- come from the live menu or the shop's approved knowledge articles.
update ai.conversation_patterns
   set is_pinned = true,
       response_variants = case intent
         when 'welcome_new_user' then jsonb_build_array(
           jsonb_build_object('text_ar', 'أهلاً بيك! أنا مساعد الكافيه، اسألني عن المنيو أو القهوة.', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('warm','concise')),
           jsonb_build_object('text_ar', 'نورتنا 😊 قولي محتاج تعرف إيه عن مشروباتنا أو القهوة؟', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('friendly','concise'))
         )
         when 'returning_customer' then jsonb_build_array(
           jsonb_build_object('text_ar', 'أهلاً برجوعك! قولي أقدر أساعدك في إيه النهارده؟', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('warm','concise')),
           jsonb_build_object('text_ar', 'حمدلله على السلامة 😊 إيه اللي تحب تعرفه؟', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('friendly','concise'))
         )
         when 'hours_inquiry' then jsonb_build_array(
           jsonb_build_object('text_ar', 'أراجع لك مواعيد الفرع المحدد من بيانات الكافيه الحالية.', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('direct','grounded')),
           jsonb_build_object('text_ar', 'مواعيد الفروع ممكن تختلف، فهعتمد على بيانات الفرع اللي اخترته.', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('helpful','grounded'))
         )
         when 'menu_recommendation' then jsonb_build_array(
           jsonb_build_object('text_ar', 'أختار لك من الأصناف الموجودة فعلًا في المنيو، وبحسب ذوقك.', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('personalized','grounded')),
           jsonb_build_object('text_ar', 'خليني أبني الترشيح على مشروبات المنيو وتفضيلاتك.', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('helpful','grounded'))
         )
         when 'dietary_inquiry' then jsonb_build_array(
           jsonb_build_object('text_ar', 'هراجع المكونات المسجلة للمنتج، ولو المعلومة ناقصة هقولك بوضوح.', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('careful','grounded')),
           jsonb_build_object('text_ar', 'في أسئلة الحساسية، هعتمد على بيانات المكونات المؤكدة بس.', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('careful','concise'))
         )
         when 'order_modification' then jsonb_build_array(
           jsonb_build_object('text_ar', 'أراجع حالة طلبك الأول، وبعدها أوضح لك الخيارات المتاحة.', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('direct','grounded')),
           jsonb_build_object('text_ar', 'خليني أتأكد من حالة الطلب عشان أقولك الإجراء المناسب.', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('helpful','grounded'))
         )
         when 'points_inquiry' then jsonb_build_array(
           jsonb_build_object('text_ar', 'أراجع نقاطك الحالية وشروط برنامج الولاء المسجلة عندنا.', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('direct','grounded')),
           jsonb_build_object('text_ar', 'هعتمد على رصيدك الحالي وقواعد الولاء الموجودة في حسابك.', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('helpful','grounded'))
         )
         when 'apology_service_issue' then jsonb_build_array(
           jsonb_build_object('text_ar', 'آسف إن التجربة ما كانتش كويسة. احكيلي إيه اللي حصل عشان أساعدك.', 'variant_id', 'reviewed_1', 'style_markers', jsonb_build_array('empathetic','concise')),
           jsonb_build_object('text_ar', 'متفهم إن ده ضايقك، وهحاول أوضح لك الخطوة المتاحة لحل المشكلة.', 'variant_id', 'reviewed_2', 'style_markers', jsonb_build_array('empathetic','helpful'))
         )
         else response_variants
       end
 where intent in (
   'welcome_new_user','returning_customer','hours_inquiry',
   'menu_recommendation','dietary_inquiry','order_modification',
   'points_inquiry','apology_service_issue'
 );

-- Function to retrieve contextually relevant conversation patterns
create or replace function ai.get_conversation_patterns(
  p_intent text default null,
  p_category text default null,
  p_tone text default 'friendly',
  p_complexity text default 'simple',
  p_limit integer default 5
)
returns table (
  id uuid,
  category text,
  intent text,
  user_message_ar text,
  user_message_en text,
  response_variants jsonb,
  context_flags jsonb,
  tone text,
  complexity text,
  tags text[],
  is_pinned boolean,
  weight integer
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_query text := btrim(coalesce(p_intent, p_category, ''));
  v_limit integer := greatest(1, least(coalesce(p_limit, 5), 10));
begin
  return query
  select 
    cp.id, cp.category, cp.intent, cp.user_message_ar, cp.user_message_en,
    cp.response_variants, cp.context_flags, cp.tone, cp.complexity,
    cp.tags, cp.is_pinned, cp.weight
  from ai.conversation_patterns cp
  where
    -- Match by intent or category if specified
    ((p_intent is not null and cp.intent = p_intent) or
     (p_category is not null and cp.category = p_category) or
     (p_intent is null and p_category is null))
    -- Filter by tone if specified
    and (p_tone is null or cp.tone = p_tone)
    -- Filter by complexity if specified  
    and (p_complexity is null or cp.complexity = p_complexity)
  order by
    -- Prioritize pinned examples
    case when cp.is_pinned then 0 else 1 end,
    -- Weight-based sorting
    cp.weight desc,
    -- Randomize within same weight for variation
    random()
  limit v_limit;
end;
$fn$;

comment on function ai.get_conversation_patterns is
  'Retrieve contextually relevant conversation patterns with multiple response variants.';

-- The ai schema stays private. Only the Edge Function service role can fetch
-- approved examples; customer clients cannot read or write the training set.
create or replace function public.assistant_get_conversation_patterns(
  p_intent text default null,
  p_category text default null,
  p_limit integer default 3
)
returns table (
  id uuid,
  category text,
  intent text,
  user_message_ar text,
  response_variants jsonb,
  tone text,
  complexity text,
  tags text[]
)
language sql
volatile
security definer
set search_path = ''
as $fn$
  select p.id, p.category, p.intent, p.user_message_ar,
         p.response_variants, p.tone, p.complexity, p.tags
    from ai.get_conversation_patterns(
      p_intent, p_category, null, null, p_limit
    ) p
   where p.is_pinned;
$fn$;

revoke all on function public.assistant_get_conversation_patterns(text, text, integer)
  from public, anon, authenticated;
grant execute on function public.assistant_get_conversation_patterns(text, text, integer)
  to service_role;

-- Function to analyze message and suggest appropriate response style
create or replace function ai.analyze_message_sentiment(p_text text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_lower text := lower(p_text);
  sentiment text;
  urgency integer;
  intent_hint text;
begin
  -- Sentiment analysis
  if v_lower like '%آسف%' or v_lower like '%ستاء%' or v_lower like '%مش عجبني%' or v_lower like '%خطأ%' then
    sentiment := 'negative';
  elsif v_lower like '%جميل%' or v_lower like '%عظيم%' or v_lower like '%شكرا%' or v_lower like '%ما شاء الله%' then
    sentiment := 'positive';
  else
    sentiment := 'neutral';
  end if;
  
  -- Urgency detection
  urgency := 0;
  if v_lower like '%فوراً%' or v_lower like '%عاجل%' or v_lower like '%حاجة%مهم%' then
    urgency := 3; -- High
  elsif v_lower like '%لو سمحت%' or v_lower like '%من فضلك%' or v_lower like '%بكرمة%' then
    urgency := 2; -- Medium
  else
    urgency := 1; -- Low
  end if;
  
  -- Intent hints
  if v_lower like '%إيه%الجديد%' or v_lower like '%محدث%' then
    intent_hint := 'seasonal';
  elsif v_lower like '%نقاط%' or v_lower like '%ولاء%' or v_lower like '%مكافأة%' then
    intent_hint := 'loyalty';
  elsif v_lower like '%طلب%عدل%' or v_lower like '%غير%طلب%' then
    intent_hint := 'order_modification';
  elsif v_lower like '%وقت%' or v_lower like '%ساعة%' or v_lower like '%فتاح%' then
    intent_hint := 'hours_inquiry';
  elsif v_lower like '%يوصف%' or v_lower like '%بنوصي%' or v_lower like '%لي%بتوصي%' then
    intent_hint := 'menu_recommendation';
  else
    intent_hint := 'general';
  end if;
  
  return jsonb_build_object(
    'sentiment', sentiment,
    'urgency', urgency,
    'intent_hint', intent_hint,
    'requires_empathetic_response', sentiment = 'negative' or urgency > 2
  );
end;
$fn$;

-- Function to generate personalized greeting based on user type
create or replace function ai.generate_personalized_greeting(
  p_user_id uuid default null,
  p_time_of_day text default null,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_greeting jsonb;
  v_returning boolean;
  v_last_visit timestamptz;
begin
  -- Check if returning customer
  if p_user_id is not null then
    select max(updated_at) into v_last_visit
    from ai.conversations
    where user_id = p_user_id
    group by user_id;
    
    v_returning := v_last_visit is not null and v_last_visit > now() - interval '7 days';
  else
    v_returning := false;
  end if;
  
  -- Get greeting pattern based on user type
  if v_returning then
    select json_agg(row_to_json(cp)) into v_greeting
    from ai.get_conversation_patterns('greetings', 'returning_customer') cp
    order by random()
    limit 1;
  else
    select json_agg(row_to_json(cp)) into v_greeting
    from ai.get_conversation_patterns('greetings', 'welcome_new_user') cp
    order by random()
    limit 1;
  end if;
  
  return coalesce(v_greeting, '[]'::jsonb);
end;
$fn$;

comment on function ai.generate_personalized_greeting is
  'Generate appropriate greeting based on whether user is new or returning.';

-- Function to prune old conversations (data retention policy)
create or replace function ai.prune_old_conversations(p_keep_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  delete from ai.conversations
  where created_at < now() - make_interval(days => greatest(coalesce(p_keep_days, 90), 30));
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

comment on function ai.prune_old_conversations is
  'Delete old conversation history for data retention compliance.';

-- Auto-pruning cron job
do $do$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and not exists (select 1 from cron.job where jobname = 'prune-old-conversations') then
    perform cron.schedule(
      'prune-old-conversations',
      '0 4 * * *',
      $$select ai.prune_old_conversations(90);$$
    );
  end if;
end $do$;

-- ---------------------------------------------------------------------------
-- DYNAMIC DATA INTEGRATION FUNCTIONS (Layer 2)
-- These functions integrate real-time database information into responses
-- ---------------------------------------------------------------------------

-- Function to get product recommendations with live pricing and availability
create or replace function ai.get_dynamic_product_recommendations(
  p_user_preference text default null,
  p_branch_id uuid default null,
  p_limit integer default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_products jsonb;
  v_context text := coalesce(p_user_preference, 'popular');
begin
  -- Get products based on preference
  select json_agg(row_to_json(p))
  into v_products
  from (
    select
      id,
      name_ar,
      name_en,
      description_ar,
      description_en,
      effective_price,
      is_available,
      case 
        when v_context = 'recommended' then 
          jsonb_build_object(
            'recommendation_reason', 'الأكثر مبيعاً هذا الشهر 🌟',
            'variations', '[اسم المنتج] موجود بأحجام مختلفة تناسب كل الأذواق'
          )
        when v_context = 'available' then
          jsonb_build_object(
            'recommendation_reason', 'متوفر الآن وبسرعة ⚡',
            'variations', 'أسعار خاصة اليوم فقط!'
          )
        else
          jsonb_build_object(
            'recommendation_reason', 'اختيار العملاء الدائم 💫',
            'variations', 'طعم لا يُنسى وخدمة مميزة'
          )
      end as dynamic_content
    from catalog.products p
    where
      p.is_active = true
      and p.effective_price > 0
      and (p_branch_id is null or p.branch_id = p_branch_id)
      and (p_user_preference is null or 
           p.category_id in (select id from catalog.categories where slug = left(p_user_preference, 20)))
    order by
      case when v_context = 'available' then p.is_available end desc,
      p.sales_count desc nulls last,
      random()
    limit greatest(coalesce(p_limit, 5), 1)
  ) p;
  
  return coalesce(v_products, '[]'::jsonb);
end;
$fn$;

-- Function to inject dynamic pricing and offers into responses
create or replace function ai.inject_dynamic_pricing(
  p_response_text text,
  p_promotions jsonb default null
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_result text := p_response_text;
begin
  if p_promotions is not null and p_promotions::jsonb ? 'active_offers' then
    v_result := v_result || '\n\n🎁 عروض خاصة:\n';
    
    for i in 0 .. jsonb_array_length(p_promotions['active_offers']::jsonb) - 1
    loop
      declare
        v_offer record;
      begin
        select * into v_offer from jsonb_array_elements(p_promotions['active_offers']::jsonb) with ordinality as x(o, idx);
        v_result := v_result || '- ' || v_offer.title || ': ' || v_offer.description || '\n';
      end;
    end loop;
  end if;
  
  return v_result;
end;
$fn$;

-- Function to get branch-specific information for personalized responses
create or replace function ai.get_branch_context(
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_branch jsonb;
begin
  if p_branch_id is null then
    -- If no specific branch, get popular items across all branches
    v_branch := jsonb_build_object(
      'branches_count', (select count(*) from catalog.brands),
      'featured_products', (
        select json_agg(row_to_json(p))
        from (
          select id, name_ar, effective_price
          from catalog.products
          where is_active = true and is_available = true
          order by sales_count desc nulls last
          limit 3
        ) p
      ),
      'special_note', 'تختلف الخدمات المتاحة حسب الفرع'
    );
  else
    -- Get specific branch details
    select json_agg(row_to_json(b)) into v_branch
    from (
      select
        b.id,
        b.name_ar,
        b.name_en,
        b.is_open,
        b.current_status,
        current_timestamp - (b.created_at) as hours_opened,
        (select count(*) from catalog.products cp where cp.branch_id = b.id and cp.is_available = true) as available_products
      from catalog.brands b
      where b.id = p_branch_id
      limit 1
    ) b;
  end if;
  
  return coalesce(v_branch, '{}')::jsonb;
end;
$fn$;

-- Function to create personalized recommendation message
create or replace function ai.create_personalized_recommendation(
  p_product_ids uuid[],
  p_user_id uuid default null
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_response text;
  v_variant text;
begin
  if coalesce(array_length(p_product_ids, 1), 0) = 0 then
    return 'مفيش اختيارات متاحة حاليًا في البيانات اللي وصلتني. راجع المنيو وجرب تاني.';
  end if;
  -- Get base response pattern
  select response_variants->0->>'text_ar' into v_variant
  from ai.conversation_patterns
  where category = 'product_qa' and intent = 'menu_recommendation'
  order by weight desc, random()
  limit 1;
  
  -- Build dynamic response with actual product names
  v_response := format(
    '%s\n\nبناءً على ذوقك:\n',
    coalesce(v_variant, 'دي بعض الاختيارات المتاحة حاليًا في المنيو:')
  );
  
  for i in reverse array_upper(p_product_ids, 1)..1
  loop
    declare
      v_product record;
      v_suffix text;
    begin
      select id, name_ar, effective_price, tag into v_product
      from catalog.products
      where id = p_product_ids[i];
      
      -- Add variety to each suggestion
      v_suffix := case mod(i, 3)
        when 0 then ' - مثالي للاستمتاع به الآن ☕'
        when 1 then ' - خيار ممتاز يومياً 💪'
        when 2 then ' - جربه اليوم وتغير مزاجك! 🌟'
      end;
      
      v_response := v_response || format(
        '%d. %s (%s SAR)%s\n',
        i,
        v_product.name_ar,
        v_product.effective_price::text,
        v_suffix
      );
    end;
  end loop;
  
  return v_response || '\n\nإيه اللي يناسبك النهاردة؟';
end;
$fn$;

comment on function ai.create_personalized_recommendation is
  'Generate personalized product recommendations using actual database content.';

-- Trigger to update product knowledge when products change
create or replace function core.notify_product_knowledge_update()
returns trigger
language plpgsql
as $fn$
begin
  -- Notify assistant cache to refresh when products change
  perform pg_notify('assistant_cache_invalidation', 
    jsonb_build_object('type', 'products', 'ids', array[NEW.id::text])::text);
  return new;
end;
$fn$;

create trigger tr_products_knowledge_update
  after update or insert or delete on catalog.products
  for each row execute function core.notify_product_knowledge_update();

notify pgrst, 'reload schema';
