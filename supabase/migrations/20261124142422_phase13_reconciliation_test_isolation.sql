-- Exclude Phase 1.3 isolated test records from ordinary reconciliation totals.
begin;

CREATE OR REPLACE FUNCTION public.admin_financial_reconciliation(p_from timestamp with time zone, p_until timestamp with time zone, p_branch_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
        where o.test_only is not true and o.payment_status in ('paid','refunded') and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)),
      'paid_total', coalesce((select sum(o.grand_total) from orders.orders o
        where o.test_only is not true and o.payment_status in ('paid','refunded') and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)),0),
      'missing_invoice_count', (select count(*) from orders.orders o
        where o.test_only is not true and o.payment_status in ('paid','refunded') and o.status <> 'cancelled'
          and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)
          and not exists (select 1 from orders.invoices i where i.order_id = o.id)),
      'missing_invoice_order_ids', coalesce((select jsonb_agg(o.id order by o.placed_at)
        from orders.orders o where o.test_only is not true and o.payment_status in ('paid','refunded') and o.status <> 'cancelled'
          and o.placed_at >= p_from and o.placed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id = p_branch_id)
          and not exists (select 1 from orders.invoices i where i.order_id = o.id)), '[]'::jsonb)
    ),
    'invoice_documents', jsonb_build_object(
      'not_ready_count', (select count(*) from orders.invoices i
        join orders.orders o on o.id=i.order_id left join orders.invoice_documents d on d.invoice_id=i.id
        where i.test_only is not true and i.issued_at>=p_from and i.issued_at<p_until and coalesce(d.status,'pending')<>'ready'
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)),
      'failed_count', (select count(*) from orders.invoice_documents d join orders.invoices i on i.id=d.invoice_id
        where d.status='failed' and i.issued_at>=p_from and i.issued_at<p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id))
    ),
    'duplicate_invoice_orders', coalesce((select jsonb_agg(q.order_id) from (
      select i.order_id from orders.invoices i where i.test_only is not true and i.issued_at>=p_from and i.issued_at<p_until
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
        where i.test_only is not true and i.issued_at >= p_from and i.issued_at < p_until
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
        from orders.invoices i where i.test_only is not true and i.issued_at >= p_from and i.issued_at < p_until
          and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id)
        group by coalesce(i.snapshot->>'tax_treatment','unknown')) x
    ), '[]'::jsonb),
    'refunds', jsonb_build_object(
      'requested_amount', coalesce((select sum(r.requested_amount) from payments.payment_refunds r
        join orders.orders o on o.id=r.order_id where o.test_only is not true and r.requested_at >= p_from and r.requested_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),0),
      'confirmed_amount', coalesce((select sum(r.confirmed_amount) from payments.payment_refunds r
        join orders.orders o on o.id=r.order_id where o.test_only is not true and r.status='succeeded' and r.completed_at >= p_from and r.completed_at < p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),0),
      'fully_refunded_payment_count', (select count(*) from payments.payment_transactions pt
        join orders.orders o on o.id=pt.order_id where o.test_only is not true and pt.status='refunded'
          and pt.paid_at>=p_from and pt.paid_at<p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'partially_refunded_payment_count', (select count(*) from payments.payment_transactions pt
        join orders.orders o on o.id=pt.order_id where o.test_only is not true and pt.status='captured'
          and pt.refund_status='partially_refunded' and pt.paid_at>=p_from and pt.paid_at<p_until
          and identity.can_manage_branch(o.branch_id) and (p_branch_id is null or o.branch_id=p_branch_id)),
      'pending_count', (select count(*) from payments.payment_refunds r join orders.orders o on o.id=r.order_id
        where o.test_only is not true and r.status in ('pending','unknown') and r.requested_at>=p_from and r.requested_at<p_until
          and identity.can_manage_branch(o.branch_id)
          and (p_branch_id is null or o.branch_id=p_branch_id)),
      'failed_count', (select count(*) from payments.payment_refunds r join orders.orders o on o.id=r.order_id
        where o.test_only is not true and r.status='failed' and r.completed_at >= p_from and r.completed_at < p_until
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
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='credit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
        + coalesce((select sum(a.amount-a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='debit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0),
      'net_vat', coalesce(sum((i.snapshot->>'vat_amount')::numeric),0)
        - coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='credit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
        + coalesce((select sum(a.vat_amount) from orders.invoice_adjustments a
          join orders.invoices ix on ix.id=a.invoice_id where ix.test_only is not true and a.adjustment_type='debit_note'
            and a.issued_at>=p_from and a.issued_at<p_until and identity.can_manage_branch(ix.branch_id)
            and (p_branch_id is null or ix.branch_id=p_branch_id)),0)
    ) from orders.invoices i where i.test_only is not true and i.issued_at>=p_from and i.issued_at<p_until
      and identity.can_manage_branch(i.branch_id) and (p_branch_id is null or i.branch_id=p_branch_id))
  ) into v_result;
  return v_result;
end;
$function$
;

commit;

