-- 096_assistant_rate_limit_fixed_window.sql
--
-- forward-only fix for the counter logic that migration 095 installed.
--
-- WHY A NEW MIGRATION
-- -------------------
-- 095 was already applied to this project's database, so the function body
-- that is live today is the one from 095: it increments the counter on every
-- request and never starts a fresh count, so a bucket that once reached its
-- limit stayed blocked. Changing the file of an applied migration would not
-- change the database and would rewrite the project's history, so the fixed
-- function is delivered here instead. Applying this migration is what puts
-- the fix in the database.
--
-- THE POLICY
-- ---------
-- A fixed window per bucket:
--   * The window starts with the first request of a bucket and lasts exactly
--     `p_window_seconds`.
--   * Inside the window the counter only grows.
--   * When the stored window has expired, the next request starts a new
--     window with a count of 1.
--   * A refused request never extends the window, so a customer who is over
--     the limit is released when the window ends and not a second later.
--
-- The limits themselves are unchanged: 15 requests per hour for a guest and
-- 60 requests per hour for a signed-in customer. They are passed in by the
-- Edge Function.
--
-- The statement stays atomic: one INSERT ... ON CONFLICT DO UPDATE reads the
-- row and writes it, so there is no gap between reading and writing for a
-- concurrent request to slip through.

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
    -- The window restarts only when the stored one has really ended.
    -- `window_start` does not move inside a window, and a refused request
    -- does not push the end of the window further away.
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
