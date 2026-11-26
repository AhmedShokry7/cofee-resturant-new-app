-- Server-bound, short-lived approvals for catalog and coupon actions initiated
-- by the admin assistant. The model never receives a direct SQL interface.
create table if not exists _ops.admin_assistant_action_previews (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null,
  auth_session_id uuid,
  action_type text not null check (action_type in (
    'catalog.product.save',
    'catalog.category.save',
    'marketing.coupon.save',
    'marketing.coupon.activate'
  )),
  target_id uuid,
  branch_id uuid,
  payload jsonb not null,
  expected_state jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  consumed_at timestamptz,
  result jsonb
);

create index if not exists ix_admin_assistant_action_previews_actor_expiry
  on _ops.admin_assistant_action_previews (actor_user_id, expires_at);

alter table _ops.admin_assistant_action_previews enable row level security;
revoke all on table _ops.admin_assistant_action_previews from public, anon, authenticated;

create or replace function public.admin_assistant_prepare_product(
  p_product_id uuid,
  p_payload jsonb,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_preview_id uuid;
  v_expected jsonb;
  v_stock integer;
begin
  if not identity.is_staff()
     or not identity.has_permission('catalog.product.write') then
    raise exception 'missing permission: catalog.product.write' using errcode = '42501';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or coalesce(length(btrim(p_payload->>'name_ar')), 0) = 0
     or nullif(btrim(p_payload->>'base_price'), '') is null then
    raise exception 'invalid product payload' using errcode = '22023';
  end if;
  if (p_payload->>'base_price')::numeric < 0 then
    raise exception 'product price cannot be negative' using errcode = '22023';
  end if;
  if nullif(p_payload->>'category_id', '') is not null
     and not exists (select 1 from catalog.categories c where c.id = (p_payload->>'category_id')::uuid) then
    raise exception 'unknown category' using errcode = '22023';
  end if;
  if (p_payload ? 'stock_quantity') and p_payload->'stock_quantity' <> 'null'::jsonb then
    if not identity.has_permission('inventory.adjust') then
      raise exception 'missing permission: inventory.adjust' using errcode = '42501';
    end if;
    if p_branch_id is null or not identity.can_manage_branch(p_branch_id) then
      raise exception 'stock branch out of scope' using errcode = '42501';
    end if;
    if (p_payload->>'stock_quantity')::integer < 0 then
      raise exception 'stock quantity cannot be negative' using errcode = '22023';
    end if;
  end if;

  if p_product_id is not null then
    select to_jsonb(p) into v_expected
      from catalog.products p
     where p.id = p_product_id;
    if v_expected is null then
      raise exception 'product not found' using errcode = '22023';
    end if;
    if p_payload ? 'stock_quantity' and p_payload->'stock_quantity' <> 'null'::jsonb then
      select bs.quantity_on_hand into v_stock
        from inventory.branch_stock bs
       where bs.branch_id = p_branch_id
         and bs.product_id = p_product_id
         and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
      v_expected := jsonb_build_object('product', v_expected, 'stock_quantity', v_stock);
    else
      v_expected := jsonb_build_object('product', v_expected);
    end if;
  end if;

  delete from _ops.admin_assistant_action_previews
   where actor_user_id = auth.uid() and expires_at < now() - interval '1 day';
  insert into _ops.admin_assistant_action_previews
    (actor_user_id, auth_session_id, action_type, target_id, branch_id, payload, expected_state)
  values
    (auth.uid(), nullif(auth.jwt()->>'session_id', '')::uuid, 'catalog.product.save', p_product_id, p_branch_id, p_payload, v_expected)
  returning id into v_preview_id;
  return jsonb_build_object(
    'preview_id', v_preview_id,
    'expires_at', now() + interval '5 minutes',
    'old_values', v_expected
  );
end;
$fn$;

create or replace function public.admin_assistant_prepare_category(
  p_category_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_id uuid; v_expected jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('catalog.category.write') then
    raise exception 'missing permission: catalog.category.write' using errcode = '42501';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or coalesce(length(btrim(p_payload->>'name_ar')), 0) = 0
     or coalesce(length(btrim(p_payload->>'name_en')), 0) = 0 then
    raise exception 'invalid category payload' using errcode = '22023';
  end if;
  if p_category_id is not null then
    select to_jsonb(c) into v_expected from catalog.categories c where c.id = p_category_id;
    if v_expected is null then raise exception 'category not found' using errcode = '22023'; end if;
  end if;
  insert into _ops.admin_assistant_action_previews
    (actor_user_id, auth_session_id, action_type, target_id, payload, expected_state)
  values (auth.uid(), nullif(auth.jwt()->>'session_id', '')::uuid, 'catalog.category.save', p_category_id, p_payload, v_expected)
  returning id into v_id;
  return jsonb_build_object('preview_id', v_id, 'expires_at', now() + interval '5 minutes', 'old_values', v_expected);
end;
$fn$;

create or replace function public.admin_assistant_prepare_coupon(p_coupon jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
  v_preview_id uuid;
  v_expected jsonb;
  v_payload jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_coupon is null or jsonb_typeof(p_coupon) <> 'object' then
    raise exception 'invalid coupon payload' using errcode = '22023';
  end if;
  v_id := nullif(p_coupon->>'id', '')::uuid;
  if v_id is not null then
    select jsonb_build_object(
      'coupon', to_jsonb(c),
      'category_ids', coalesce((select jsonb_agg(cc.category_id order by cc.category_id) from marketing.coupons_categories cc where cc.coupon_id = c.id), '[]'::jsonb),
      'product_ids', coalesce((select jsonb_agg(cp.product_id order by cp.product_id) from marketing.coupons_products cp where cp.coupon_id = c.id), '[]'::jsonb)
    ) into v_expected from marketing.coupons c where c.id = v_id;
    if v_expected is null then raise exception 'coupon not found' using errcode = '22023'; end if;
    -- Updating coupon terms never silently activates a paused campaign. Use
    -- the separate activation preview for that consequential transition.
    v_payload := jsonb_set(p_coupon, '{is_active}', v_expected->'coupon'->'is_active', true);
  else
    -- Assistant-created coupons are drafts; activation is a separate action.
    v_payload := p_coupon || jsonb_build_object('is_active', false);
  end if;
  insert into _ops.admin_assistant_action_previews
    (actor_user_id, auth_session_id, action_type, target_id, payload, expected_state)
  values (auth.uid(), nullif(auth.jwt()->>'session_id', '')::uuid, 'marketing.coupon.save', v_id, v_payload, v_expected)
  returning id into v_preview_id;
  return jsonb_build_object('preview_id', v_preview_id, 'expires_at', now() + interval '5 minutes', 'old_values', v_expected);
end;
$fn$;

create or replace function public.admin_assistant_prepare_coupon_activation(
  p_coupon_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_expected jsonb; v_id uuid;
begin
  if not identity.is_staff() or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_active is null then raise exception 'an active state is required' using errcode = '22023'; end if;
  select jsonb_build_object(
    'coupon', to_jsonb(c),
    'category_ids', coalesce((select jsonb_agg(cc.category_id order by cc.category_id) from marketing.coupons_categories cc where cc.coupon_id = c.id), '[]'::jsonb),
    'product_ids', coalesce((select jsonb_agg(cp.product_id order by cp.product_id) from marketing.coupons_products cp where cp.coupon_id = c.id), '[]'::jsonb)
  ) into v_expected from marketing.coupons c where c.id = p_coupon_id;
  if v_expected is null then raise exception 'coupon not found' using errcode = '22023'; end if;
  insert into _ops.admin_assistant_action_previews
    (actor_user_id, auth_session_id, action_type, target_id, payload, expected_state)
  values (auth.uid(), nullif(auth.jwt()->>'session_id', '')::uuid, 'marketing.coupon.activate', p_coupon_id, jsonb_build_object('is_active', p_active), v_expected)
  returning id into v_id;
  return jsonb_build_object('preview_id', v_id, 'expires_at', now() + interval '5 minutes', 'old_values', v_expected);
end;
$fn$;

create or replace function public.admin_assistant_execute_catalog_action(p_preview_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_preview _ops.admin_assistant_action_previews%rowtype;
  v_current jsonb;
  v_product jsonb;
  v_category jsonb;
  v_coupon jsonb;
  v_stock integer;
  v_result jsonb;
  v_entity_id uuid;
begin
  if not identity.is_staff() then raise exception 'active staff required' using errcode = '42501'; end if;
  select * into v_preview from _ops.admin_assistant_action_previews p
   where p.id = p_preview_id and p.actor_user_id = auth.uid() for update;
  if not found then raise exception 'preview not found' using errcode = '42501'; end if;
  if v_preview.auth_session_id is distinct from nullif(auth.jwt()->>'session_id', '')::uuid then
    raise exception 'preview belongs to a different session' using errcode = '42501';
  end if;
  if v_preview.consumed_at is not null then return coalesce(v_preview.result, jsonb_build_object('ok', true, 'replayed', true)); end if;
  if v_preview.expires_at <= now() then raise exception 'preview expired' using errcode = '40001'; end if;

  case v_preview.action_type
  when 'catalog.product.save' then
    if not identity.has_permission('catalog.product.write') then raise exception 'missing permission: catalog.product.write' using errcode = '42501'; end if;
    v_product := v_preview.payload;
    if v_product ? 'stock_quantity' and v_product->'stock_quantity' <> 'null'::jsonb then
      if not identity.has_permission('inventory.adjust') or v_preview.branch_id is null
         or not identity.can_manage_branch(v_preview.branch_id) then
        raise exception 'missing inventory permission or branch scope' using errcode = '42501';
      end if;
    end if;
    if v_preview.target_id is null then
      if v_preview.expected_state is not null then raise exception 'invalid create preview' using errcode = '40001'; end if;
    else
      select to_jsonb(p) into v_current from catalog.products p where p.id = v_preview.target_id for update;
      if v_current is null then raise exception 'product changed after preview' using errcode = '40001'; end if;
      if v_preview.expected_state ? 'stock_quantity' then
        select bs.quantity_on_hand into v_stock from inventory.branch_stock bs
         where bs.branch_id = v_preview.branch_id and bs.product_id = v_preview.target_id
           and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid for update;
        v_current := jsonb_build_object('product', v_current, 'stock_quantity', v_stock);
      else v_current := jsonb_build_object('product', v_current); end if;
      if v_current is distinct from v_preview.expected_state then raise exception 'product changed after preview' using errcode = '40001'; end if;
    end if;
    v_result := public.admin_save_product(
      v_preview.target_id,
      v_product->>'name_ar', v_product->>'name_en', v_product->>'description_ar', v_product->>'description_en',
      v_product->>'sku', v_product->>'slug', coalesce((v_product->>'base_price')::numeric, 0),
      nullif(v_product->>'compare_at_price', '')::numeric, nullif(v_product->>'category_id', '')::uuid,
      v_product->>'image_url', coalesce((v_product->>'is_featured')::boolean, false),
      coalesce((v_product->>'is_active')::boolean, true), nullif(v_product->>'prep_minutes', '')::integer,
      nullif(v_product->>'discount_percentage', '')::numeric, nullif(v_product->>'discount_starts_at', '')::timestamptz,
      nullif(v_product->>'discount_ends_at', '')::timestamptz, nullif(v_product->>'calories', '')::integer,
      case when jsonb_typeof(v_product->'allergens') = 'array' then array(select jsonb_array_elements_text(v_product->'allergens')) else null end,
      nullif(v_product->>'stock_quantity', '')::integer, v_preview.branch_id
    );
    v_entity_id := (v_result->>'id')::uuid;
    perform identity.audit(case when v_preview.target_id is null then 'catalog.product.create' else 'catalog.product.update' end,
      'product', v_entity_id, v_preview.expected_state, v_result,
      case when v_preview.payload ? 'stock_quantity' then v_preview.branch_id else null end);

  when 'catalog.category.save' then
    if not identity.has_permission('catalog.category.write') then raise exception 'missing permission: catalog.category.write' using errcode = '42501'; end if;
    if v_preview.target_id is null then
      if v_preview.expected_state is not null then raise exception 'invalid create preview' using errcode = '40001'; end if;
      v_result := public.admin_create_category(v_preview.payload->>'name_ar', v_preview.payload->>'name_en', v_preview.payload->>'description_ar', v_preview.payload->>'description_en');
      v_entity_id := (v_result->>'id')::uuid;
      perform identity.audit('catalog.category.create', 'category', v_entity_id, null, v_result);
    else
      select to_jsonb(c) into v_current from catalog.categories c where c.id = v_preview.target_id for update;
      if v_current is distinct from v_preview.expected_state then raise exception 'category changed after preview' using errcode = '40001'; end if;
      v_result := public.admin_update_category(v_preview.target_id, v_preview.payload->>'name_ar', v_preview.payload->>'name_en', v_preview.payload->>'description_ar', v_preview.payload->>'description_en');
      perform identity.audit('catalog.category.update', 'category', v_preview.target_id, v_current, v_result);
      v_entity_id := v_preview.target_id;
    end if;

  when 'marketing.coupon.save' then
    if not identity.has_permission('settings.write') then raise exception 'missing permission: settings.write' using errcode = '42501'; end if;
    if v_preview.target_id is not null then
      select jsonb_build_object(
        'coupon', to_jsonb(c),
        'category_ids', coalesce((select jsonb_agg(cc.category_id order by cc.category_id) from marketing.coupons_categories cc where cc.coupon_id = c.id), '[]'::jsonb),
        'product_ids', coalesce((select jsonb_agg(cp.product_id order by cp.product_id) from marketing.coupons_products cp where cp.coupon_id = c.id), '[]'::jsonb)
      ) into v_current from marketing.coupons c where c.id = v_preview.target_id for update of c;
      if v_current is distinct from v_preview.expected_state then raise exception 'coupon changed after preview' using errcode = '40001'; end if;
    elsif v_preview.expected_state is not null then raise exception 'invalid coupon create preview' using errcode = '40001'; end if;
    v_result := public.admin_save_coupon(v_preview.payload);
    if v_result->>'ok' is distinct from 'true' then
      update _ops.admin_assistant_action_previews set consumed_at = now(), result = v_result where id = v_preview.id;
      return v_result;
    end if;
    v_entity_id := nullif(v_result->>'id', '')::uuid;

  when 'marketing.coupon.activate' then
    if not identity.has_permission('settings.write') then raise exception 'missing permission: settings.write' using errcode = '42501'; end if;
    select jsonb_build_object(
      'coupon', to_jsonb(c),
      'category_ids', coalesce((select jsonb_agg(cc.category_id order by cc.category_id) from marketing.coupons_categories cc where cc.coupon_id = c.id), '[]'::jsonb),
      'product_ids', coalesce((select jsonb_agg(cp.product_id order by cp.product_id) from marketing.coupons_products cp where cp.coupon_id = c.id), '[]'::jsonb)
    ) into v_current from marketing.coupons c where c.id = v_preview.target_id for update of c;
    if v_current is distinct from v_preview.expected_state then raise exception 'coupon changed after preview' using errcode = '40001'; end if;
    v_result := public.admin_set_coupon_active(v_preview.target_id, coalesce((v_preview.payload->>'is_active')::boolean, false));
    if v_result->>'ok' is distinct from 'true' then return v_result; end if;
    v_entity_id := v_preview.target_id;
  end case;

  v_result := coalesce(v_result, jsonb_build_object('ok', true, 'id', v_entity_id));
  update _ops.admin_assistant_action_previews set consumed_at = now(), result = v_result where id = v_preview.id;
  v_result := v_result || jsonb_build_object('action_type', v_preview.action_type);
  update _ops.admin_assistant_action_previews set result = v_result where id = v_preview.id;
  return v_result;
end;
$fn$;

create or replace function public.admin_assistant_cancel_action(p_preview_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then raise exception 'active staff required' using errcode = '42501'; end if;
  delete from _ops.admin_assistant_action_previews
   where id = p_preview_id and actor_user_id = auth.uid() and consumed_at is null;
end;
$fn$;

revoke all on function public.admin_assistant_prepare_product(uuid, jsonb, uuid) from public, anon;
revoke all on function public.admin_assistant_prepare_category(uuid, jsonb) from public, anon;
revoke all on function public.admin_assistant_prepare_coupon(jsonb) from public, anon;
revoke all on function public.admin_assistant_prepare_coupon_activation(uuid, boolean) from public, anon;
revoke all on function public.admin_assistant_execute_catalog_action(uuid) from public, anon;
revoke all on function public.admin_assistant_cancel_action(uuid) from public, anon;
grant execute on function public.admin_assistant_prepare_product(uuid, jsonb, uuid) to authenticated;
grant execute on function public.admin_assistant_prepare_category(uuid, jsonb) to authenticated;
grant execute on function public.admin_assistant_prepare_coupon(jsonb) to authenticated;
grant execute on function public.admin_assistant_prepare_coupon_activation(uuid, boolean) to authenticated;
grant execute on function public.admin_assistant_execute_catalog_action(uuid) to authenticated;
grant execute on function public.admin_assistant_cancel_action(uuid) to authenticated;
