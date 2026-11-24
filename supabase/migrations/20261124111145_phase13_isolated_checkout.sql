-- Dedicated, authenticated checkout for the single Phase 1.3 test run.
-- It leaves public catalogue visibility and global VAT configuration untouched.
begin;

create or replace function payments.phase13_test_checkout_context()
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select nullif(current_setting('app.phase13_test_run_id', true), '') =
         'b105bd82-18df-4e6a-9b10-306d5ed5e1bc'
     and auth.uid() is not null
     and exists (
       select 1
         from payments.phase13_test_customers c
         join payments.phase13_test_identities i
           on i.user_id=c.user_id and i.run_id=c.run_id
        where c.user_id=auth.uid()
          and c.run_id='b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid
          and i.identity_kind='customer'
          and c.expires_at>now() and i.expires_at>now()
     )
     and exists (
       select 1 from payments.phase13_test_seller_profiles p
        where p.run_id='b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid
          and p.branch_id='10dbfb03-ed35-4a79-9116-c44c7bb0ec66'::uuid
          and p.expires_at>now()
     )
$fn$;
revoke all on function payments.phase13_test_checkout_context() from public, anon, authenticated;
grant execute on function payments.phase13_test_checkout_context() to service_role;

-- Inactive test products remain unavailable everywhere except the run-pinned,
-- authenticated pricing path. All existing option/stock/cart validation stays in place.
create or replace function catalog.resolve_product_base_price(
  p_branch_id uuid,
  p_product_id uuid
)
returns table (
  unit_price numeric, currency_code text, is_available boolean,
  unavailable_reason text, regular_price numeric, discount_percentage numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_base numeric; v_override numeric; v_available boolean; v_reason text;
  v_active boolean; v_archived timestamptz; v_currency text; v_regular numeric;
  v_now timestamptz := now(); v_general_pct numeric; v_branch_pct numeric;
  v_use_general boolean; v_branch_start timestamptz; v_branch_end timestamptz;
  v_general_start timestamptz; v_general_end timestamptz; v_pct numeric;
  v_test_context boolean := false;
begin
  v_test_context := payments.phase13_test_checkout_context()
    and p_branch_id='10dbfb03-ed35-4a79-9116-c44c7bb0ec66'::uuid
    and p_product_id='8d98c73d-43e9-484f-9dab-9a10d0513e70'::uuid;

  select p.base_price, p.is_active, p.archived_at,
         p.discount_percentage, p.discount_starts_at, p.discount_ends_at
    into v_base, v_active, v_archived, v_general_pct, v_general_start, v_general_end
    from catalog.products p where p.id=p_product_id;
  if not found then raise exception 'product % not found',p_product_id using errcode='P0002'; end if;

  select b.currency_code into v_currency from core.brands b limit 1;
  select bpp.price_override,bpp.is_available,bpp.unavailable_reason,
         bpp.discount_percentage,bpp.discount_starts_at,bpp.discount_ends_at,
         bpp.use_general_discount
    into v_override,v_available,v_reason,v_branch_pct,v_branch_start,v_branch_end,v_use_general
    from catalog.branch_product_pricing bpp
   where bpp.branch_id=p_branch_id and bpp.product_id=p_product_id;

  v_available:=coalesce(v_available,true);
  if (not v_active or v_archived is not null) and not v_test_context then
    v_available:=false; v_reason:=coalesce(v_reason,'product inactive');
  end if;
  v_regular:=coalesce(v_override,v_base);
  if v_general_pct is null or (v_general_start is not null and v_now<v_general_start)
     or (v_general_end is not null and v_now>v_general_end) then v_general_pct:=0; end if;
  if v_branch_pct is null or (v_branch_start is not null and v_now<v_branch_start)
     or (v_branch_end is not null and v_now>v_branch_end) then v_branch_pct:=null; end if;
  v_use_general:=coalesce(v_use_general,true);
  if v_branch_pct is not null then v_pct:=v_branch_pct;
  elsif v_use_general then v_pct:=v_general_pct; else v_pct:=0; end if;
  return query select round(v_regular*(1-v_pct/100.0),2),v_currency,v_available,v_reason,
    round(v_regular,2),round(v_pct,2);
end;
$fn$;
revoke all on function catalog.resolve_product_base_price(uuid,uuid) from public,anon,authenticated;

-- Preserve the production wrapper's global VAT behavior verbatim. Only a
-- verified transaction context reads the run-scoped synthetic VAT profile.
create or replace function public.quote_checkout(
  p_branch_id uuid,p_lines jsonb,p_fulfillment_type text,
  p_delivery_zone_id uuid default null,p_coupon_code text default null,p_address_id uuid default null
)
returns table (subtotal numeric,discount_total numeric,delivery_fee numeric,tax_total numeric,
  grand_total numeric,currency_code text,product_discount_total numeric)
language plpgsql security definer set search_path = ''
as $fn$
declare v_quote record; v_rate numeric(5,2); v_included boolean; v_registered text;
  v_fee_taxable boolean; v_amounts record;
begin
  select * into v_quote from public.quote_checkout_legacy(
    p_branch_id,p_lines,p_fulfillment_type,p_delivery_zone_id,p_coupon_code,p_address_id);
  if payments.phase13_test_checkout_context()
     and p_branch_id='10dbfb03-ed35-4a79-9116-c44c7bb0ec66'::uuid then
    select p.tax_rate,p.tax_included,p.delivery_fee_taxable
      into v_rate,v_included,v_fee_taxable
      from payments.phase13_test_seller_profiles p
     where p.run_id='b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid
       and p.branch_id=p_branch_id and p.expires_at>now();
    if not found then raise exception 'Phase 1.3 test run is expired or unavailable' using errcode='55000'; end if;
  else
    select b.tax_rate,b.tax_included,b.tax_registration_status,b.delivery_fee_taxable
      into v_rate,v_included,v_registered,v_fee_taxable from core.brands b order by b.created_at limit 1;
    if v_registered='unregistered' and v_rate<>0 then
      raise exception 'unregistered business must configure a zero tax rate' using errcode='23514';
    end if;
    if v_registered='registered' and v_rate<=0 then
      raise exception 'registered business must configure its applicable positive VAT rate' using errcode='23514';
    end if;
  end if;
  select * into v_amounts from orders.calculate_vat_amounts(
    v_quote.subtotal,v_quote.discount_total,v_quote.delivery_fee,coalesce(v_rate,0),
    v_included,v_fee_taxable);
  return query select v_quote.subtotal,v_quote.discount_total,v_quote.delivery_fee,
    v_amounts.vat_amount,v_amounts.grand_total,v_quote.currency_code,v_quote.product_discount_total;
end;
$fn$;
revoke all on function public.quote_checkout(uuid,jsonb,text,uuid,text,uuid) from public,anon;
grant execute on function public.quote_checkout(uuid,jsonb,text,uuid,text,uuid) to authenticated,service_role;

-- Fixed fixture IDs and fixed pickup order inputs prevent this RPC becoming a
-- general-purpose checkout or a way to select arbitrary test seller data.
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
    'currency_code',v_order.currency_code,'reused_existing_order',v_order.reused_existing_order);
end;
$fn$;
revoke all on function public.phase13_test_checkout(uuid,uuid) from public,anon,authenticated;
grant execute on function public.phase13_test_checkout(uuid,uuid) to authenticated;
comment on function public.phase13_test_checkout(uuid,uuid) is
  'Run-pinned test-only checkout for dedicated Phase 1.3 customers; normal browsing and checkout remain unchanged.';

-- Staff reader can be scoped to the isolated inactive branch; no public activation is needed.
create or replace function payments.register_phase13_test_identity(
  p_user_id uuid,p_run_id uuid,p_identity_kind text,p_expires_at timestamptz,p_branch_id uuid default null
)
returns void language plpgsql security definer set search_path = ''
as $fn$
declare v_email text; v_role_id uuid; v_role_code text; v_staff_id uuid; v_orders_read uuid;
begin
  if p_user_id is null or p_run_id is null
     or p_identity_kind not in ('customer','customer_denied','staff_reader','staff_denied')
     or p_expires_at<=now() or p_expires_at>now()+interval '48 hours' then
    raise exception 'invalid Phase 1.3 test identity registration' using errcode='22023';
  end if;
  select u.email into v_email from auth.users u where u.id=p_user_id;
  if not found or v_email is null or lower(v_email) not like '%@example.invalid' then
    raise exception 'only newly provisioned .invalid test accounts can be registered' using errcode='42501';
  end if;
  if exists(select 1 from identity.staff_members sm where sm.user_id=p_user_id)
     or exists(select 1 from payments.phase13_test_identities ti where ti.user_id=p_user_id) then
    raise exception 'identity is already in use; no existing account may be repurposed' using errcode='23505';
  end if;
  if p_identity_kind='staff_reader' then
    if p_branch_id is null or not exists(select 1 from core.branches b where b.id=p_branch_id
      and b.settings->>'phase13_test_run_id'=p_run_id::text and not b.is_active
      and exists(select 1 from payments.phase13_test_seller_profiles p where p.branch_id=b.id
        and p.run_id=p_run_id and p.expires_at>now())) then
      raise exception 'a dedicated inactive Phase 1.3 test branch is required' using errcode='22023';
    end if;
  elsif p_branch_id is not null then
    raise exception 'branch scope is only valid for the dedicated test reader' using errcode='22023';
  end if;
  insert into payments.phase13_test_identities(user_id,run_id,identity_kind,branch_id,expires_at)
    values(p_user_id,p_run_id,p_identity_kind,p_branch_id,p_expires_at);
  if p_identity_kind='customer' then
    insert into payments.phase13_test_customers(user_id,run_id,expires_at) values(p_user_id,p_run_id,p_expires_at);
  elsif p_identity_kind in ('staff_reader','staff_denied') then
    insert into identity.staff_members(user_id,status,full_name,email,accepted_at)
      values(p_user_id,'active','Phase 1.3 Test Staff',v_email,now()) returning id into v_staff_id;
    if p_identity_kind='staff_reader' then
      v_role_code:='phase13_invoice_reader_'||replace(p_run_id::text,'-','');
      insert into identity.roles(code,name_ar,name_en,description,is_system)
        values(v_role_code,'قارئ فواتير الاختبار','Phase 1.3 invoice test reader',
          'Temporary test-only role limited to orders.read on one dedicated test branch.',false)
        returning id into v_role_id;
      select p.id into v_orders_read from identity.permissions p where p.code='orders.read';
      if v_orders_read is null then raise exception 'orders.read permission is unavailable'; end if;
      insert into identity.role_permissions(role_id,permission_id) values(v_role_id,v_orders_read);
      insert into identity.staff_roles(staff_id,role_id,branch_id) values(v_staff_id,v_role_id,p_branch_id);
    end if;
  end if;
end;
$fn$;
revoke all on function payments.register_phase13_test_identity(uuid,uuid,text,timestamptz,uuid) from public,anon,authenticated;
grant execute on function payments.register_phase13_test_identity(uuid,uuid,text,timestamptz,uuid) to service_role;

commit;
