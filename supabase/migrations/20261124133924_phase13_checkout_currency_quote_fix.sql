-- Return currency from the verified checkout quote. The row type returned by
-- orders.place_order_with_lines has no currency_code field.
create or replace function public.phase13_test_checkout(p_run_id uuid,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $fn$
declare v_uid uuid:=auth.uid(); v_profile payments.phase13_test_seller_profiles%rowtype;
  v_quote record; v_order record; v_lines jsonb;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  if p_run_id is distinct from 'b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid
     or p_idempotency_key is null then
    raise exception 'invalid Phase 1.3 test checkout request' using errcode='22023';
  end if;
  if not exists(select 1 from payments.phase13_test_customers c
      join payments.phase13_test_identities i on i.user_id=c.user_id and i.run_id=c.run_id
      where c.user_id=v_uid and c.run_id=p_run_id and i.identity_kind='customer'
        and c.expires_at>now() and i.expires_at>now()) then
    raise exception 'dedicated Phase 1.3 customer identity is required' using errcode='42501';
  end if;
  select * into v_profile from payments.phase13_test_seller_profiles p
   where p.run_id=p_run_id and p.branch_id='10dbfb03-ed35-4a79-9116-c44c7bb0ec66'::uuid
     and p.expires_at>now();
  if not found then raise exception 'Phase 1.3 test run is expired or unavailable' using errcode='55000'; end if;
  if not exists(select 1 from core.branches b where b.id=v_profile.branch_id
      and not b.is_active and b.settings->>'phase13_test_run_id'=p_run_id::text)
     or not exists(select 1 from catalog.categories c where c.id='c4333e36-5ac9-446d-9394-eb043fc24d03'::uuid and not c.is_active)
     or not exists(select 1 from catalog.products p where p.id='8d98c73d-43e9-484f-9dab-9a10d0513e70'::uuid
       and p.category_id='c4333e36-5ac9-446d-9394-eb043fc24d03'::uuid and p.archived_at is null)
     or not exists(select 1 from catalog.branch_product_pricing bpp where bpp.branch_id=v_profile.branch_id
       and bpp.product_id='8d98c73d-43e9-484f-9dab-9a10d0513e70'::uuid and coalesce(bpp.is_available,true)) then
    raise exception 'isolated Phase 1.3 fixtures are unavailable' using errcode='55000';
  end if;
  perform set_config('app.phase13_test_run_id',p_run_id::text,true);
  v_lines:=jsonb_build_array(jsonb_build_object(
    'product_id','8d98c73d-43e9-484f-9dab-9a10d0513e70','quantity',1,'option_value_ids','[]'::jsonb));
  select * into v_quote from public.quote_checkout(v_profile.branch_id,v_lines,'pickup',null,null,null);
  select * into v_order from orders.place_order_with_lines(
    v_profile.branch_id,v_lines,'phase13:'||p_run_id::text||':'||p_idempotency_key::text,
    'pickup',null,null,'Phase 1.3 isolated test run '||p_run_id::text,null);
  if abs(v_order.grand_total-v_quote.grand_total)>0.005 then
    raise exception 'test order total does not match isolated seller quote' using errcode='40001';
  end if;
  return jsonb_build_object('order_id',v_order.order_id,'order_number',v_order.order_number,
    'run_id',p_run_id,'test_only',true,'branch_id',v_profile.branch_id,
    'subtotal',v_order.subtotal,'vat_amount',v_order.tax_total,'grand_total',v_order.grand_total,
    'currency_code',v_quote.currency_code,'reused_existing_order',v_order.reused_existing_order);
end;
$fn$;
revoke all on function public.phase13_test_checkout(uuid,uuid) from public,anon,authenticated;
grant execute on function public.phase13_test_checkout(uuid,uuid) to authenticated;
comment on function public.phase13_test_checkout(uuid,uuid) is
  'Run-pinned test-only checkout for dedicated Phase 1.3 customers; normal browsing and checkout remain unchanged.';
