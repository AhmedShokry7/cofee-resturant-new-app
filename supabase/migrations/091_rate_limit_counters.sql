-- 091_rate_limit_counters.sql
--
-- جداول ودالة لتقليل المعدل (Rate Limiting) لحماية نقاط النهاية الحساسة
-- (إرسال الطلبات، استبدال السلة، البحث) من الإغراق عند ازدياد عدد المستخدمين.
--
-- العدادات تُخزّن per user per endpoint مع وقت انتهاء تلقائي، وتُستخدم من
-- Edge Function `rate-limit` قبل تنفيذ المنطق التجاري.

create table if not exists public.rate_limit_counters (
  id            bigserial primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  endpoint      text not null,
  count         bigint not null default 1,
  window_start  timestamptz not null default now(),
  expires_at    timestamptz not null default (now() + interval '1 hour'),
  unique (user_id, endpoint)
);

-- فهرس لتنظيف المنتهية الصلاحية بسرعة.
create index if not exists ix_rate_limit_expires
  on public.rate_limit_counters (expires_at);

-- RLS: فقط النظام (service_role) يمكنه الكتابة والقراءة؛ التطبيق لا يلمس هذا الجدول مباشرة.
alter table public.rate_limit_counters enable row level security;

create policy "rate_limit_system_only"
  on public.rate_limit_counters
  for all
  to authenticated
  using (false)
  with check (false);

-- دالة زيادة العداد بشكل ذري (Atomic) لمنع ظروف السباق (race conditions).
create or replace function public.increment_rate_limit(
  p_user_id uuid,
  p_endpoint text,
  p_limit bigint,
  p_cost bigint default 1,
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
  v_window_start timestamptz := date_trunc('second', now());
  v_expires_at   timestamptz := now() + (p_window_seconds * interval '1 second');
  v_current      bigint;
begin
  -- upsert: إذا كان العداد موجوداً في النافذة الحالية، زيدّه؛ وإلا أنشئ جديداً.
  insert into public.rate_limit_counters (user_id, endpoint, count, window_start, expires_at)
  values (p_user_id, p_endpoint, p_cost, v_window_start, v_expires_at)
  on conflict (user_id, endpoint)
  do update set
    count = public.rate_limit_counters.count + p_cost,
    window_start = case
      when public.rate_limit_counters.window_start < v_window_start - interval '1 hour'
        then v_window_start
      else public.rate_limit_counters.window_start
    end,
    expires_at = v_expires_at
  returning count into v_current;

  -- إذا لم يرجع upsert صفاً (بسبب تعارض)، اقرأ القيمة الحالية.
  if v_current is null then
    select count into v_current
      from public.rate_limit_counters
     where user_id = p_user_id
       and endpoint = p_endpoint;
  end if;

  -- إذا كان العداد超过 الحد، رفض الطلب.
  if v_current > p_limit then
    return query
      select false::boolean as allowed,
             0::bigint as remaining,
             (select expires_at from public.rate_limit_counters
              where user_id = p_user_id and endpoint = p_endpoint
              limit 1) as reset_at;
    return;
  end if;

  return query
    select true::boolean as allowed,
           (p_limit - v_current)::bigint as remaining,
           (select expires_at from public.rate_limit_counters
            where user_id = p_user_id and endpoint = p_endpoint
            limit 1) as reset_at;
end;
$fn$;

-- منح 실행 فقط للمصادقة (المستخدمين المسجلين) و service_role.
revoke all on function public.increment_rate_limit(uuid, text, bigint, bigint, bigint)
  from public, anon;
grant execute on function public.increment_rate_limit(uuid, text, bigint, bigint, bigint)
  to authenticated, service_role;

notify pgrst, 'reload schema';
