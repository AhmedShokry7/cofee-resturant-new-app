-- Private, server-managed PDF lifecycle for the immutable invoice snapshots
-- introduced in 262. Keeping document state separate preserves invoice
-- immutability and gives retries an independent lifecycle.
begin;

create table if not exists orders.invoice_documents (
  invoice_id uuid primary key references orders.invoices(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending','generating','ready','failed')),
  object_path text,
  content_sha256 text check (content_sha256 is null or content_sha256 ~ '^[0-9a-f]{64}$'),
  content_length bigint check (content_length is null or content_length between 1 and 10485760),
  generation_attempts integer not null default 0 check (generation_attempts >= 0),
  generation_started_at timestamptz,
  generated_at timestamptz,
  last_error_code text,
  updated_at timestamptz not null default now(),
  constraint invoice_document_ready_fields check (
    status <> 'ready' or (object_path is not null and content_sha256 is not null
      and content_length is not null and generated_at is not null)
  )
);

alter table orders.invoice_documents enable row level security;
revoke all on orders.invoice_documents from public, anon, authenticated;
grant all on orders.invoice_documents to service_role;

insert into orders.invoice_documents (invoice_id)
select id from orders.invoices
on conflict (invoice_id) do nothing;

create or replace function orders.ensure_invoice_document_row()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  insert into orders.invoice_documents(invoice_id) values (new.id)
  on conflict (invoice_id) do nothing;
  return new;
end;
$fn$;
revoke all on function orders.ensure_invoice_document_row() from public, anon, authenticated;
grant execute on function orders.ensure_invoice_document_row() to service_role;
drop trigger if exists tr_invoice_document_row on orders.invoices;
create trigger tr_invoice_document_row after insert on orders.invoices
  for each row execute function orders.ensure_invoice_document_row();

-- Private bucket with no client policies. Only the Edge Function's service
-- credential can upload, inspect, or sign objects in this bucket.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('invoice-documents','invoice-documents',false,10485760,array['application/pdf'])
on conflict (id) do update set name = excluded.name, public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists invoice_documents_client_read on storage.objects;
drop policy if exists invoice_documents_client_insert on storage.objects;
drop policy if exists invoice_documents_client_update on storage.objects;
drop policy if exists invoice_documents_client_delete on storage.objects;

create or replace function public.invoice_document_access(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  select jsonb_build_object(
    'invoice_id', i.id, 'invoice_number', i.invoice_number,
    'invoice_type', i.invoice_type, 'status', i.status,
    'issued_at', i.issued_at, 'currency_code', i.currency_code,
    'snapshot', i.snapshot, 'snapshot_sha256', i.snapshot_sha256,
    'document_status', coalesce(d.status, 'pending')
  ) into v_result
  from orders.invoices i
  join orders.orders o on o.id = i.order_id
  left join orders.invoice_documents d on d.invoice_id = i.id
  where i.id = p_invoice_id
    and i.status = 'issued'
    and (o.user_id = auth.uid() or (
      identity.is_staff() and identity.has_permission('orders.read')
      and identity.can_manage_branch(i.branch_id)
    ));
  if v_result is null then raise exception 'invoice not found' using errcode = 'P0002'; end if;
  return v_result;
end;
$fn$;
revoke all on function public.invoice_document_access(uuid) from public, anon;
grant execute on function public.invoice_document_access(uuid) to authenticated;

create or replace function public.my_order_invoice(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  select jsonb_build_object(
    'invoice_id', i.id, 'invoice_number', i.invoice_number,
    'invoice_type', i.invoice_type, 'status', i.status,
    'issued_at', i.issued_at, 'currency_code', i.currency_code,
    'snapshot', i.snapshot, 'document_status', coalesce(d.status,'pending'),
    'document_url', null
  ) into v_result
    from orders.invoices i join orders.orders o on o.id=i.order_id
    left join orders.invoice_documents d on d.invoice_id=i.id
   where o.id=p_order_id and o.user_id=auth.uid();
  return v_result;
end;
$fn$;
revoke all on function public.my_order_invoice(uuid) from public, anon;
grant execute on function public.my_order_invoice(uuid) to authenticated;

create or replace function public.admin_order_invoice(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'invoice_id',i.id,'invoice_number',i.invoice_number,'invoice_type',i.invoice_type,
    'status',i.status,'zatca_status',i.zatca_status,'issued_at',i.issued_at,
    'currency_code',i.currency_code,'snapshot',i.snapshot,'snapshot_sha256',i.snapshot_sha256,
    'document_status',coalesce(d.status,'pending')
  ) into v_result from orders.invoices i
    left join orders.invoice_documents d on d.invoice_id=i.id
   where i.order_id=p_order_id and identity.can_manage_branch(i.branch_id);
  return v_result;
end;
$fn$;
revoke all on function public.admin_order_invoice(uuid) from public, anon;
grant execute on function public.admin_order_invoice(uuid) to authenticated;

create or replace function public.admin_invoice_history(
  p_from timestamptz default null, p_until timestamptz default null,
  p_branch_id uuid default null, p_search text default null
)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',i.id,'invoice_number',i.invoice_number,'invoice_type',i.invoice_type,
    'status',i.status,'document_status',coalesce(d.status,'pending'),
    'issued_at',i.issued_at,'currency_code',i.currency_code,'order_id',i.order_id,
    'branch_id',i.branch_id,'snapshot',i.snapshot,'snapshot_sha256',i.snapshot_sha256
  ) order by i.issued_at desc),'[]'::jsonb) into v_result
  from orders.invoices i join orders.orders o on o.id=i.order_id
  left join orders.invoice_documents d on d.invoice_id=i.id
  where identity.can_manage_branch(i.branch_id)
    and (p_branch_id is null or i.branch_id=p_branch_id)
    and (p_from is null or i.issued_at>=p_from)
    and (p_until is null or i.issued_at<p_until)
    and (nullif(btrim(coalesce(p_search,'')),'') is null
      or i.invoice_number ilike '%'||btrim(p_search)||'%'
      or o.order_number ilike '%'||btrim(p_search)||'%');
  return v_result;
end;
$fn$;
revoke all on function public.admin_invoice_history(timestamptz,timestamptz,uuid,text) from public, anon;
grant execute on function public.admin_invoice_history(timestamptz,timestamptz,uuid,text) to authenticated;

create or replace function public.claim_invoice_document_generation(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_invoice orders.invoices%rowtype;
  v_doc orders.invoice_documents%rowtype;
  v_path text;
begin
  select * into v_invoice from orders.invoices where id = p_invoice_id and status = 'issued';
  if not found then raise exception 'issued invoice not found' using errcode = 'P0002'; end if;
  insert into orders.invoice_documents(invoice_id) values (p_invoice_id)
    on conflict(invoice_id) do nothing;
  select * into v_doc from orders.invoice_documents where invoice_id = p_invoice_id for update;
  v_path := 'invoices/' || v_invoice.id::text || '/' || v_invoice.snapshot_sha256 || '.pdf';
  if v_doc.status = 'ready' and v_doc.object_path = v_path then
    return jsonb_build_object('status','ready','object_path',v_path,
      'content_sha256',v_doc.content_sha256,'content_length',v_doc.content_length);
  end if;
  if v_doc.status = 'generating'
     and v_doc.generation_started_at > now() - interval '10 minutes' then
    return jsonb_build_object('status','generating');
  end if;
  update orders.invoice_documents set status = 'generating', object_path = v_path,
    content_sha256 = null, content_length = null, generated_at = null,
    generation_started_at = now(), generation_attempts = generation_attempts + 1,
    last_error_code = null, updated_at = now()
   where invoice_id = p_invoice_id;
  return jsonb_build_object('status','claimed','object_path',v_path,
    'invoice_id',v_invoice.id,'invoice_number',v_invoice.invoice_number,
    'snapshot',v_invoice.snapshot,'snapshot_sha256',v_invoice.snapshot_sha256);
end;
$fn$;
revoke all on function public.claim_invoice_document_generation(uuid) from public, anon, authenticated;
grant execute on function public.claim_invoice_document_generation(uuid) to service_role;

create or replace function public.complete_invoice_document_generation(
  p_invoice_id uuid, p_object_path text, p_content_sha256 text, p_content_length bigint
)
returns void language plpgsql security definer set search_path = '' as $fn$
declare v_invoice orders.invoices%rowtype; v_expected text;
begin
  select * into v_invoice from orders.invoices where id = p_invoice_id and status = 'issued';
  if not found then raise exception 'issued invoice not found' using errcode = 'P0002'; end if;
  v_expected := 'invoices/' || v_invoice.id::text || '/' || v_invoice.snapshot_sha256 || '.pdf';
  if p_object_path is distinct from v_expected or p_content_sha256 !~ '^[0-9a-f]{64}$'
     or p_content_length not between 1 and 10485760 then
    raise exception 'invalid invoice document metadata' using errcode = '22023';
  end if;
  update orders.invoice_documents set status = 'ready', object_path = v_expected,
    content_sha256 = p_content_sha256, content_length = p_content_length,
    generated_at = now(), updated_at = now(), last_error_code = null
   where invoice_id = p_invoice_id and status = 'generating';
  if not found then raise exception 'document generation was not claimed' using errcode = '55000'; end if;
end;
$fn$;
revoke all on function public.complete_invoice_document_generation(uuid,text,text,bigint) from public, anon, authenticated;
grant execute on function public.complete_invoice_document_generation(uuid,text,text,bigint) to service_role;

create or replace function public.fail_invoice_document_generation(p_invoice_id uuid, p_error_code text)
returns void language sql security definer set search_path = '' as $fn$
  update orders.invoice_documents set status = 'failed',
    last_error_code = left(coalesce(nullif(p_error_code,''),'generation_failed'),64),
    updated_at = now()
  where invoice_id = p_invoice_id and status = 'generating';
$fn$;
revoke all on function public.fail_invoice_document_generation(uuid,text) from public, anon, authenticated;
grant execute on function public.fail_invoice_document_generation(uuid,text) to service_role;

-- Reconciliation is computed from paid-order snapshots and payment/refund
-- ledger rows. Current catalogue prices are never consulted.
create or replace function public.admin_financial_reconciliation(
  p_from timestamptz, p_until timestamptz, p_branch_id uuid default null
)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v_result jsonb;
begin
  if not identity.is_staff() or not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;
  if p_from is null or p_until is null or p_until <= p_from then
    raise exception 'valid reporting period required' using errcode = '22023';
  end if;

  select jsonb_build_object(
    'from', p_from, 'until', p_until,
    'orders', jsonb_build_object(
      'paid_count', (select count(*) from orders.orders o
        where o.payment_status in ('paid','refunded') and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)),
      'paid_total', coalesce((select sum(o.grand_total) from orders.orders o
        where o.payment_status in ('paid','refunded') and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)),0),
      'missing_invoice_count', (select count(*) from orders.orders o
        where o.payment_status in ('paid','refunded') and o.status <> 'cancelled'
          and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)
          and not exists (select 1 from orders.invoices i where i.order_id = o.id)),
      'missing_invoice_order_ids', coalesce((select jsonb_agg(o.id order by o.placed_at)
        from orders.orders o where o.payment_status in ('paid','refunded') and o.status <> 'cancelled'
          and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)
          and not exists (select 1 from orders.invoices i where i.order_id = o.id)), '[]'::jsonb)
    ),
    'invoice_documents', jsonb_build_object(
      'not_ready_count', (select count(*) from orders.invoices i
        join orders.orders o on o.id=i.order_id left join orders.invoice_documents d on d.invoice_id=i.id
        where i.issued_at>=p_from and i.issued_at<p_until and coalesce(d.status,'pending')<>'ready'
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),
      'failed_count', (select count(*) from orders.invoice_documents d join orders.invoices i on i.id=d.invoice_id
        where d.status='failed' and i.issued_at>=p_from and i.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id))
    ),
    'duplicate_invoice_orders', coalesce((select jsonb_agg(q.order_id) from (
      select i.order_id from orders.invoices i where i.issued_at>=p_from and i.issued_at<p_until
        and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)
      group by i.order_id having count(*)>1
    ) q),'[]'::jsonb),
    'payment_invoice_mismatches', coalesce((
      select jsonb_agg(jsonb_build_object('order_id',x.order_id,'invoice_total',x.invoice_total,
        'captured_total',x.captured_total,'difference',round(x.captured_total-x.invoice_total,2)) order by x.order_id)
      from (
        select i.order_id, (i.snapshot->>'grand_total')::numeric as invoice_total,
          coalesce(sum(pt.amount) filter (where pt.status in ('captured','refunded')),0) as captured_total
        from orders.invoices i join orders.orders o on o.id=i.order_id
        left join payments.payment_transactions pt on pt.order_id=o.id
        where i.issued_at >= p_from and i.issued_at < p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)
        group by i.order_id,i.snapshot
        having abs(coalesce(sum(pt.amount) filter (where pt.status in ('captured','refunded')),0)
          - (i.snapshot->>'grand_total')::numeric) >= 0.01
      ) x
    ), '[]'::jsonb),
    'vat_by_treatment', coalesce((
      select jsonb_agg(jsonb_build_object('tax_treatment',x.tax_treatment,
        'invoice_count',x.invoice_count,'taxable_base',x.taxable_base,'vat_amount',x.vat_amount)
        order by x.tax_treatment)
      from (select coalesce(i.snapshot->>'tax_treatment','unknown') tax_treatment,
        count(*) invoice_count,
        coalesce(sum((i.snapshot->>'taxable_base')::numeric),0) taxable_base,
        coalesce(sum((i.snapshot->>'vat_amount')::numeric),0) vat_amount
        from orders.invoices i where i.issued_at >= p_from and i.issued_at < p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)
        group by coalesce(i.snapshot->>'tax_treatment','unknown')) x
    ), '[]'::jsonb),
    'refunds', jsonb_build_object(
      'requested_amount', coalesce((select sum(r.requested_amount) from payments.payment_refunds r
        join orders.orders o on o.id=r.order_id where r.requested_at >= p_from and r.requested_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),0),
      'confirmed_amount', coalesce((select sum(r.confirmed_amount) from payments.payment_refunds r
        join orders.orders o on o.id=r.order_id where r.status='succeeded' and r.completed_at >= p_from and r.completed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),0),
      'fully_refunded_payment_count', (select count(*) from payments.payment_transactions pt
        join orders.orders o on o.id=pt.order_id where pt.status='refunded'
          and pt.paid_at>=p_from and pt.paid_at<p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'partially_refunded_payment_count', (select count(*) from payments.payment_transactions pt
        join orders.orders o on o.id=pt.order_id where pt.status='captured'
          and pt.refund_status='partially_refunded' and pt.paid_at>=p_from and pt.paid_at<p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'pending_count', (select count(*) from payments.payment_refunds r join orders.orders o on o.id=r.order_id
        where r.status in ('pending','unknown') and r.requested_at>=p_from and r.requested_at<p_until
          and identity.can_manage_branch(o.branch_id)
          and (p_branch_id is null or o.branch_id=p_branch_id)),
      'failed_count', (select count(*) from payments.payment_refunds r join orders.orders o on o.id=r.order_id
        where r.status='failed' and r.completed_at >= p_from and r.completed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'over_reserved_count', (select count(*) from (
        select pt.id from payments.payment_transactions pt join orders.orders o on o.id=pt.order_id
        join payments.payment_refunds r on r.payment_transaction_id=pt.id
        where pt.status in ('captured','refunded') and identity.can_manage_branch(o.branch_id)
          and (p_branch_id is null or o.branch_id=p_branch_id)
        group by pt.id,pt.amount having sum(case when r.status='succeeded' then r.confirmed_amount
          when r.status in ('pending','unknown') then r.requested_amount else 0 end)>pt.amount
      ) q),
      'remaining_refundable_balance', coalesce((select sum(greatest(pt.amount-coalesce(rsv.reserved,0),0))
        from payments.payment_transactions pt join orders.orders o on o.id=pt.order_id
        left join lateral (select sum(case when r.status='succeeded' then r.confirmed_amount
          when r.status in ('pending','unknown') then r.requested_amount else 0 end) reserved
          from payments.payment_refunds r where r.payment_transaction_id=pt.id) rsv on true
        where pt.status in ('captured','refunded') and identity.can_manage_branch(o.branch_id)
          and (p_branch_id is null or o.branch_id=p_branch_id)),0)
    ),
    'adjustments', jsonb_build_object(
      'credit_note_amount', coalesce((select sum(a.amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where a.adjustment_type='credit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0),
      'credit_note_vat', coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where a.adjustment_type='credit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0),
      'debit_note_amount', coalesce((select sum(a.amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where a.adjustment_type='debit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0),
      'debit_note_vat', coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a join orders.invoices i on i.id=a.invoice_id
        where a.adjustment_type='debit_note' and a.issued_at>=p_from and a.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),0)
    ),
    'net_sales', (select jsonb_build_object(
      'invoice_gross', coalesce(sum((i.snapshot->>'grand_total')::numeric),0),
      'invoice_taxable_base', coalesce(sum((i.snapshot->>'taxable_base')::numeric),0),
      'invoice_vat', coalesce(sum((i.snapshot->>'vat_amount')::numeric),0),
      'net_taxable_sales', coalesce(sum((i.snapshot->>'taxable_base')::numeric),0)
        - coalesce((select sum(a.amount-a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where a.adjustment_type='credit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
        + coalesce((select sum(a.amount-a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where a.adjustment_type='debit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0),
      'net_vat', coalesce(sum((i.snapshot->>'vat_amount')::numeric),0)
        - coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where a.adjustment_type='credit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
        + coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where a.adjustment_type='debit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
    ) from orders.invoices i where i.issued_at>=p_from and i.issued_at<p_until
      and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id))
  ) into v_result;
  return v_result;
end;
$fn$;
revoke all on function public.admin_financial_reconciliation(timestamptz,timestamptz,uuid) from public, anon;
grant execute on function public.admin_financial_reconciliation(timestamptz,timestamptz,uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
