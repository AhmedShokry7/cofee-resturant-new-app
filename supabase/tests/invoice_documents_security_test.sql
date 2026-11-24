-- Contract and privilege assertions for migration 264. Run as a privileged
-- role against an isolated database after migrations 262-264.
\set ON_ERROR_STOP on

select case when coalesce((select public from storage.buckets where id='invoice-documents'),true)=false
  then 'PASS' else 'FAIL: invoice bucket is missing or public' end as private_bucket;
select case when (select file_size_limit=10485760 and allowed_mime_types=array['application/pdf']::text[]
  from storage.buckets where id='invoice-documents')
  then 'PASS' else 'FAIL: invoice bucket MIME/size limits differ' end as bucket_limits;
select case when not has_table_privilege('anon','orders.invoice_documents','SELECT')
  and not has_table_privilege('authenticated','orders.invoice_documents','SELECT')
  and has_table_privilege('service_role','orders.invoice_documents','SELECT')
  then 'PASS' else 'FAIL: invoice document metadata privileges are too broad' end as metadata_privileges;
select case when not exists (
  select 1 from pg_policies where schemaname='storage' and tablename='objects'
    and (coalesce(qual,'') ilike '%invoice-documents%' or coalesce(with_check,'') ilike '%invoice-documents%')
  ) then 'PASS' else 'FAIL: client storage policy references the invoice bucket' end as no_client_storage_policy;
select case when not exists (
  select 1 from pg_policies where schemaname='storage' and tablename='objects'
    and (roles::text ilike '%anon%' or roles::text ilike '%authenticated%' or roles::text ilike '%public%')
    and ((cmd in ('SELECT','DELETE','ALL') and coalesce(qual,'') !~* 'bucket_id')
      or (cmd in ('INSERT','UPDATE','ALL') and coalesce(with_check,'') !~* 'bucket_id'))
  ) then 'PASS' else 'FAIL: a broad storage policy could bypass invoice bucket isolation' end as no_global_storage_policy;
select case when has_function_privilege('service_role','public.claim_invoice_document_generation(uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.claim_invoice_document_generation(uuid)','EXECUTE')
  and has_function_privilege('service_role','public.complete_invoice_document_generation(uuid,text,text,bigint)','EXECUTE')
  and not has_function_privilege('authenticated','public.complete_invoice_document_generation(uuid,text,text,bigint)','EXECUTE')
  then 'PASS' else 'FAIL: document lifecycle RPC is not service-role-only' end as lifecycle_rpc_privileges;
select case when has_function_privilege('authenticated','public.invoice_document_access(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.invoice_document_access(uuid)','EXECUTE')
  then 'PASS' else 'FAIL: invoice access RPC grants are incorrect' end as access_rpc_privileges;
select case when exists(select 1 from pg_trigger where tgname='tr_invoice_document_row' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgname='tr_invoices_immutable' and not tgisinternal)
  then 'PASS' else 'FAIL: invoice metadata or financial immutability trigger missing' end as invoice_triggers;
select case when exists(select 1 from pg_constraint where conrelid='orders.invoice_documents'::regclass
  and conname='invoice_document_ready_fields')
  then 'PASS' else 'FAIL: ready documents can lack path/hash/size/time metadata' end as ready_state_constraint;
select case when pg_get_functiondef('public.claim_invoice_document_generation(uuid)'::regprocedure)
  ilike '%for update%' and pg_get_functiondef('public.claim_invoice_document_generation(uuid)'::regprocedure)
  ilike '%generation_started_at%' and pg_get_functiondef('public.complete_invoice_document_generation(uuid,text,text,bigint)'::regprocedure)
  ilike '%status = ''generating''%'
  then 'PASS' else 'FAIL: document generation claim/complete is not serialized and state guarded' end as generation_idempotency_contract;
select case when pg_get_functiondef('public.invoice_document_access(uuid)'::regprocedure)
  ilike '%o.user_id = auth.uid()%' and pg_get_functiondef('public.invoice_document_access(uuid)'::regprocedure)
  ilike '%identity.has_permission(''orders.read'')%' and pg_get_functiondef('public.invoice_document_access(uuid)'::regprocedure)
  ilike '%identity.can_manage_branch%'
  then 'PASS' else 'FAIL: invoice access function lacks owner/staff branch checks' end as invoice_access_contract;
select case when exists(select 1 from pg_indexes where schemaname='orders' and tablename='invoices'
  and indexdef ilike '%unique%order_id%')
  then 'PASS' else 'FAIL: one-invoice-per-order uniqueness missing' end as invoice_idempotency_constraint;
select case when exists(select 1 from pg_trigger where tgname='tr_invoices_immutable' and not tgisinternal)
  and not has_table_privilege('authenticated','orders.invoices','UPDATE')
  then 'PASS' else 'FAIL: financial invoice snapshot has an update path for clients' end as invoice_immutability;
select case when pg_get_functiondef('public.claim_payment_refund(uuid,numeric,text,text,uuid)'::regprocedure)
  ilike '%for update%' and pg_get_functiondef('public.claim_payment_refund(uuid,numeric,text,text,uuid)'::regprocedure)
  ilike '%pending%unknown%succeeded%'
  and pg_get_functiondef('public.complete_payment_refund(uuid,text,numeric,text,jsonb)'::regprocedure)
  ilike '%a completed refund cannot be changed%'
  then 'PASS' else 'FAIL: refund lock/reservation/idempotent completion guard missing' end as refund_idempotency_contract;
select case when exists(select 1 from pg_constraint where conrelid='orders.invoice_adjustments'::regclass
  and contype='f' and conname ilike '%payment_refund_id%')
  and exists(select 1 from pg_constraint where conrelid='orders.invoice_adjustments'::regclass
  and conname ilike '%payment_refund_id%' and contype='u')
  then 'PASS' else 'FAIL: invoice adjustment refund relationship is not unique and constrained' end as adjustment_refund_relationship;

-- Deterministic ledger fixtures for refund reconciliation. Pending and unknown
-- amounts reserve capacity; failed requests do not; completed partial refunds
-- use their confirmed amounts.
with fixture(status, requested, confirmed) as (
  values ('succeeded', 20.00::numeric, 20.00::numeric),
         ('succeeded', 15.00::numeric, 15.00::numeric),
         ('pending', 10.00::numeric, null::numeric),
         ('unknown', 5.00::numeric, null::numeric),
         ('failed', 40.00::numeric, null::numeric)
), totals as (
  select sum(confirmed) filter(where status='succeeded') as cumulative_success,
    sum(case when status='succeeded' then confirmed
             when status in ('pending','unknown') then requested else 0 end) as reserved
  from fixture
)
select case when cumulative_success=35.00 and reserved=50.00
  then 'PASS' else 'FAIL: cumulative/remaining-refund fixture mismatch' end as refund_ledger_fixture
from totals;

with fixture(order_id, paid_total, invoice_total, capture_total, tax_treatment, taxable_base, vat) as (
  values ('paid-match'::text, 115.00::numeric, 115.00::numeric, 115.00::numeric,
          'standard'::text, 100.00::numeric, 15.00::numeric),
         ('paid-no-invoice', 50.00, null, 50.00, null, null, null),
         ('paid-capture-mismatch', 200.00, 200.00, 198.00,
          'standard', 173.91, 26.09)
), result as (
  select count(*) paid_count, sum(paid_total) paid_total,
    count(*) filter(where paid_total is not null and invoice_total is null) missing_invoices,
    count(*) filter(where invoice_total is not null and abs(capture_total-invoice_total)>=0.01) payment_mismatches,
    sum(taxable_base) taxable_base, sum(vat) vat
  from fixture
)
select case when paid_count=3 and paid_total=365.00 and missing_invoices=1
  and payment_mismatches=1 and taxable_base=273.91 and vat=41.09
  then 'PASS' else 'FAIL: invoice/payment reconciliation fixture mismatch' end as reconciliation_fixture
from result;

with adjustments(kind, amount, vat) as (
  values ('credit_note'::text, 10.00::numeric, 1.50::numeric),
         ('debit_note', 5.00, 0.75)
), result as (
  select sum(case when kind='credit_note' then -amount else amount end) signed_amount,
    sum(case when kind='credit_note' then -vat else vat end) signed_vat
  from adjustments
)
select case when signed_amount=-5.00 and signed_vat=-0.75
  then 'PASS' else 'FAIL: adjustment sign fixture mismatch' end as adjustment_fixture
from result;

-- Note: ownership/staff branch claims, real concurrent row-lock behavior, and
-- delayed Tap-webhook replay require authenticated fixtures and a running
-- PostgreSQL/Supabase test environment. This file deliberately does not claim
-- those runtime integration checks.
