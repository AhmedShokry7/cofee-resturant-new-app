-- supabase/tests/assistant_rate_limit_test.sql
--
-- Behaviour of the assistant rate limiter.
--
-- The file is written so it can be run against any disposable PostgreSQL:
--
--   psql -d <database> -v ON_ERROR_STOP=1 -f supabase/tests/assistant_rate_limit_test.sql
--
-- It expects migration 095 to have been applied to that database. Every check
-- raises an exception when the behaviour is not the expected one, so a failure
-- stops the script.

\set ON_ERROR_STOP on

\echo '--- 1. the first request in a window is allowed and counts as one'

do $$
declare
  r record;
begin
  delete from public.assistant_rate_limit_counters;
  select * into r
    from public.increment_assistant_rate_limit('guest:a', 15, 3600);
  if r.allowed is not true then
    raise exception 'expected the first request to be allowed';
  end if;
  if r.remaining <> 14 then
    raise exception 'expected 14 remaining, got %', r.remaining;
  end if;
  if r.reset_at is null or r.reset_at <= now() then
    raise exception 'expected a reset time in the future, got %', r.reset_at;
  end if;
  raise notice 'ok';
end $$;

\echo '--- 2. requests below the limit are allowed and the remainder falls'

do $$
declare
  r record;
  i int;
begin
  delete from public.assistant_rate_limit_counters;
  for i in 1..14 loop
    select * into r
      from public.increment_assistant_rate_limit('guest:b', 15, 3600);
    if r.allowed is not true then
      raise exception 'request % below the limit was refused', i;
    end if;
    if r.remaining <> 15 - i then
      raise exception 'expected % remaining, got %', 15 - i, r.remaining;
    end if;
  end loop;
  raise notice 'ok';
end $$;

\echo '--- 3. the request at the limit is allowed, the next one is refused'

do $$
declare
  r record;
  i int;
begin
  delete from public.assistant_rate_limit_counters;
  for i in 1..15 loop
    select * into r
      from public.increment_assistant_rate_limit('guest:c', 15, 3600);
  end loop;
  if r.allowed is not true then
    raise exception 'the fifteenth request must still be allowed';
  end if;
  if r.remaining <> 0 then
    raise exception 'expected 0 remaining at the limit, got %', r.remaining;
  end if;

  select * into r
    from public.increment_assistant_rate_limit('guest:c', 15, 3600);
  if r.allowed is not false then
    raise exception 'the sixteenth request must be refused';
  end if;
  if r.remaining <> 0 then
    raise exception 'expected 0 remaining after a refusal, got %', r.remaining;
  end if;
  raise notice 'ok';
end $$;

\echo '--- 4. a refused request does not extend the window'

do $$
declare
  r record;
  first_reset timestamptz;
  i int;
begin
  delete from public.assistant_rate_limit_counters;
  select * into r
    from public.increment_assistant_rate_limit('guest:d', 3, 3600);
  first_reset := r.reset_at;
  for i in 1..10 loop
    select * into r
      from public.increment_assistant_rate_limit('guest:d', 3, 3600);
    if r.reset_at <> first_reset then
      raise exception 'the window moved: % -> %', first_reset, r.reset_at;
    end if;
  end loop;
  raise notice 'ok';
end $$;

\echo '--- 5. a new window resets the counter'

do $$
declare
  r record;
begin
  delete from public.assistant_rate_limit_counters;
  perform public.increment_assistant_rate_limit('guest:e', 2, 3600);
  perform public.increment_assistant_rate_limit('guest:e', 2, 3600);
  select * into r
    from public.increment_assistant_rate_limit('guest:e', 2, 3600);
  if r.allowed is not false then
    raise exception 'the third request must be refused inside the window';
  end if;

  -- The window expires: the counter starts again from one.
  update public.assistant_rate_limit_counters
     set expires_at = now() - interval '1 second'
   where bucket_key = 'guest:e';

  select * into r
    from public.increment_assistant_rate_limit('guest:e', 2, 3600);
  if r.allowed is not true then
    raise exception 'the first request of a new window must be allowed';
  end if;
  if r.remaining <> 1 then
    raise exception 'the counter did not restart, remaining is %', r.remaining;
  end if;

  select count(*) into r.remaining
    from public.assistant_rate_limit_counters
   where bucket_key = 'guest:e';
  if r.remaining <> 1 then
    raise exception 'the stored counter is % after a reset, expected 1', r.remaining;
  end if;
  raise notice 'ok';
end $$;

\echo '--- 6. a guest and a signed-in customer are counted apart'

do $$
declare
  guest record;
  customer record;
begin
  delete from public.assistant_rate_limit_counters;
  select * into guest
    from public.increment_assistant_rate_limit('guest:f', 15, 3600);
  select * into customer     from public.increment_assistant_rate_limit('user:abc', 60, 3600);
  if guest.remaining <> 14 then
    raise exception 'the guest limit is not 15, remaining is %', guest.remaining;
  end if;
  if customer.remaining <> 59 then
    raise exception 'the customer limit is not 60, remaining is %', customer.remaining;
  end if;
  raise notice 'ok';
end $$;

\echo '--- 7. the arguments are checked'

do $$
declare
  caught boolean := false;
begin
  begin
    perform public.increment_assistant_rate_limit('', 15, 3600);
  exception when others then
    caught := true;
  end;
  if not caught then
    raise exception 'an empty bucket key was accepted';
  end if;

  caught := false;
  begin
    perform public.increment_assistant_rate_limit('x', 0, 3600);
  exception when others then
    caught := true;
  end;
  if not caught then
    raise exception 'a limit of zero was accepted';
  end if;

  caught := false;
  begin
    perform public.increment_assistant_rate_limit('x', 15, 0);
  exception when others then
    caught := true;
  end;
  if not caught then
    raise exception 'a window of zero seconds was accepted';
  end if;
  raise notice 'ok';
end $$;

\echo '--- 8. the table is closed to the client roles'

do $$
declare
  n bigint;
begin
  select count(*) into n
    from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name = 'assistant_rate_limit_counters'
     and grantee in ('anon', 'authenticated');
  if n <> 0 then
    raise exception 'a client role holds % grants on the counter table', n;
  end if;
  raise notice 'ok';
end $$;

\echo '--- all checks passed'

