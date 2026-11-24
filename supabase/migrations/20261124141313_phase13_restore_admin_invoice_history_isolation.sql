-- Preserve the dedicated Phase 1.3 audit path while excluding test invoices
-- from the ordinary Admin invoice history after later financial migrations.
begin;

create or replace function public.admin_invoice_history(
  p_from timestamptz default null,
  p_until timestamptz default null,
  p_branch_id uuid default null,
  p_search text default null
)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $fn$
declare v_all jsonb;
begin
  v_all:=public.admin_invoice_history_all_internal(p_from,p_until,p_branch_id,p_search);
  return coalesce((
    select jsonb_agg(x.item order by x.ordinality)
      from jsonb_array_elements(coalesce(v_all,'[]'::jsonb)) with ordinality as x(item,ordinality)
     where coalesce(x.item->>'test_only','false') <> 'true'
  ),'[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_invoice_history(timestamptz,timestamptz,uuid,text)
  from public,anon;
grant execute on function public.admin_invoice_history(timestamptz,timestamptz,uuid,text)
  to authenticated,service_role;
comment on function public.admin_invoice_history(timestamptz,timestamptz,uuid,text) is
  'Ordinary Admin invoice history. Phase 1.3 test-only invoices are excluded; use the run-scoped audit RPC.';

commit;
