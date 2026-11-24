-- Internal trigger helpers must not be callable as PostgREST RPCs.
-- Their triggers and security-definer callers continue to invoke them as owner.
begin;

revoke all on function core.version_tax_configuration()
  from public, anon, authenticated;
revoke all on function core.record_tax_configuration()
  from public, anon, authenticated;
revoke all on function orders.snapshot_order_tax()
  from public, anon, authenticated;
revoke all on function orders.issue_invoice_for_order(uuid)
  from public, anon, authenticated;
revoke all on function orders.issue_eligible_invoice()
  from public, anon, authenticated;
revoke all on function orders.guard_invoice_immutability()
  from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
