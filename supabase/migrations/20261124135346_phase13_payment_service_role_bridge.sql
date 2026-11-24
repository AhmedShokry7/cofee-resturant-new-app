-- Provide a narrow PostgREST entry point without granting schema usage on the
-- private payments schema. Only a signed service_role JWT can execute it.
create or replace function public.complete_phase13_test_payment(
  p_order_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service-role authorization required for Phase 1.3 test payment'
      using errcode='42501';
  end if;
  return payments.complete_phase13_test_payment(p_order_id,p_actor_user_id);
end;
$fn$;
revoke all on function public.complete_phase13_test_payment(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.complete_phase13_test_payment(uuid,uuid)
  to service_role;
comment on function public.complete_phase13_test_payment(uuid,uuid) is
  'Service-role-only public API bridge to the private Phase 1.3 simulated payment routine.';
