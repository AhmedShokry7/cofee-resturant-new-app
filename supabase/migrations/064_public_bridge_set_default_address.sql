-- 064_public_bridge_set_default_address.sql
-- Expose identity.set_default_address to PostgREST through the public schema.
--
-- PostgREST serves only public on this project, so the owner-only default
-- address RPC must have a public bridge like the other customer operations.
-- This file does not reimplement the logic: it forwards to the existing
-- SECURITY DEFINER function, which still resolves auth.uid() and checks
-- ownership itself.

create or replace function public.set_default_address(p_address_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $fn$
  select identity.set_default_address(p_address_id);
$fn$;

revoke all on function public.set_default_address(uuid) from public, anon;
grant execute on function public.set_default_address(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';
