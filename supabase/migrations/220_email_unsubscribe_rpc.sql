-- supabase/migrations/220_email_unsubscribe_rpc.sql
--
-- WHAT THIS FIXES
--
-- 219 put the unsubscribe write in `engagement`, which is where the rest of the
-- notifications schema lives. It is correct SQL and it is safe, but the
-- send-email Edge Function reaches it with `rpc('unsubscribe_email')`, and the
-- REST layer only publishes functions of the `public` schema: the call answers
-- PGRST202 and a signed one-click link reports "account not found" instead of
-- turning the mail off. Verified against production, not inferred.
--
-- WHAT THIS ADDS
--
-- A thin `public` facade over the function 219 already created. The rules stay
-- where they were written: one column, one row, and only through a definer
-- function. The facade changes reachability, not authority, and it stays closed
-- to every role but the one the Edge Function signs with.
--
-- Every other function an Edge Function calls by name is already in `public`
-- (increment_rate_limit, remember_answer, set_push_preferences, ...), so this is
-- the project's own convention rather than a new rule.

-- A facade the caller can actually step through: `service_role` has DML on the
-- `public` bridge views but no USAGE on the `engagement` schema at all, so an
-- invoker facade dies with 42501 before it reaches the rule. Definer is what
-- makes the second hop possible, and the rules stay in 219's function, which is
-- itself a definer. Only the service role holding the webhook secret gets here,
-- and it gets exactly one column of one row.
create or replace function public.unsubscribe_email(p_user_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $fn$
  select engagement.unsubscribe_email(p_user_id);
$fn$;

comment on function public.unsubscribe_email(uuid) is
  'REST-visible facade over engagement.unsubscribe_email: the PostgREST schema only publishes public.';

revoke all on function public.unsubscribe_email(uuid) from public, anon, authenticated;
grant execute on function public.unsubscribe_email(uuid) to service_role;

-- The API caches its schema, so a function that appears after boot is invisible
-- until the cache is reloaded. Without this the facade keeps 404ing.
select pg_notify('pgrst', 'reload schema');
