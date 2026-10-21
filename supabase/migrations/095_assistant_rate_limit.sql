-- 095_assistant_rate_limit.sql
--
-- حماية حصة الـ LLM المجانية من الاستنزاف.
--
-- دالة `ai-assistant` متاحة للزائرين (guest) بدون تسجيل دخول، حتى يرد المساعد
-- على أي عميل. بدون حدّ لكل عنوان IP، أي شخص يقدر يستهلك حصة المزوّد المجاني
-- كلها في دقائق.
--
-- العدّاد هنا بمفتاح نصّي (مستخدم مسجّل أو بصمة عنوان IP للزائر)، على عكس
-- `rate_limit_counters` الذي يعتمد على `uuid` مرتبط بـ auth.users.
--
-- نافذة زمنية ثابتة (fixed window):
--   * النافذة تبدأ عند أول طلب وتستمر ساعة بالضبط (أو `p_window_seconds`).
--   * العدّاد يُصفَّر تلقائيًا عندما تنتهي النافذة، فيبدأ العدّاد الجديد من 1.
--   * الطلبات داخل النافذة نفسها تزيد العدّاد ولا تُمدّد النافذة: طلبٌ مرفوض
--     لا يجوز أن يُبقي المستخدم محجوبًا إلى ما بعد نهاية نافذته.
--
-- التنفيذ ذرّي: جملة واحدة (INSERT ... ON CONFLICT DO UPDATE) تقرأ الصف
-- وتكتبه، فلا توجد فجوة بين القراءة والكتابة يمرّ منها طلبٌ متزامن.

create table if not exists public.assistant_rate_limit_counters (
  bucket_key   text primary key,
  count        bigint not null default 1,
  window_start timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '1 hour')
);

-- فهرس لتنظيف المنتهية الصلاحية بسرعة.
create index if not exists ix_assistant_rate_limit_expires
  on public.assistant_rate_limit_counters (expires_at);

-- RLS مفعّل بدون سياسات: الوصول مسموح فقط لـ service_role.
alter table public.assistant_rate_limit_counters enable row level security;

-- زيادة ذرّية للعدّاد ضمن نافذة ثابتة: إما Allowed مع المتبقي، أو الرفض عند
-- تجاوز الحد. `reset_at` هو نهاية النافذة الفعلية.
create or replace function public.increment_assistant_rate_limit(
  p_bucket_key text,
  p_limit bigint,
  p_window_seconds bigint default 3600
)
returns table (
  allowed boolean,
  remaining bigint,
  reset_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_now        timestamptz := now();
  v_window     interval  := p_window_seconds * interval '1 second';
  v_count      bigint;
  v_reset_at   timestamptz;
begin
  if p_bucket_key is null or btrim(p_bucket_key) = '' then
    raise exception 'bucket key is required' using errcode = '22023';
  end if;
  if p_limit is null or p_limit <= 0 then
    raise exception 'limit must be positive' using errcode = '22023';
  end if;
  if p_window_seconds is null or p_window_seconds <= 0 then
    raise exception 'window seconds must be positive' using errcode = '22023';
  end if;

  insert into public.assistant_rate_limit_counters
    (bucket_key, count, window_start, expires_at)
  values (p_bucket_key, 1, v_now, v_now + v_window)
  on conflict (bucket_key)
  do update set
    -- النافذة تُصفَّر فقط عندما تكون منتهية فعلًا..window_start لا يتحرك
    -- والعداد يبقى كما هو داخل النافذة نفسها.
    count = case
              when public.assistant_rate_limit_counters.expires_at <= v_now
              then 1
              else public.assistant_rate_limit_counters.count + 1
            end,
    window_start = case
                     when public.assistant_rate_limit_counters.expires_at <= v_now
                     then v_now
                     else public.assistant_rate_limit_counters.window_start
                   end,
    expires_at = case
                   when public.assistant_rate_limit_counters.expires_at <= v_now
                   then v_now + v_window
                   else public.assistant_rate_limit_counters.expires_at
                 end
  returning count, expires_at into v_count, v_reset_at;

  if v_count > p_limit then
    return query
      select false::boolean as allowed,
             0::bigint as remaining,
             v_reset_at as reset_at;
    return;
  end if;

  return query
    select true::boolean as allowed,
           (p_limit - v_count)::bigint as remaining,
           v_reset_at as reset_at;
end;
$fn$;

comment on function public.increment_assistant_rate_limit(text, bigint, bigint) is
  'Fixed-window counter for the assistant. The window restarts only when the '
  'stored window has expired, so a rejected request cannot extend the block.';

-- التنفيذ لـ service_role فقط؛ التطبيق لا يناديها مباشرة.
revoke all on function public.increment_assistant_rate_limit(text, bigint, bigint)
  from public, anon, authenticated;
grant execute on function public.increment_assistant_rate_limit(text, bigint, bigint)
  to service_role;

notify pgrst, 'reload schema';
