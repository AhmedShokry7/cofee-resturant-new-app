/// The audit domains the toolbar can filter by. [value] matches the first
/// segment of the action code stored by identity.audit().
enum AuditDomainFilter {
  all(null),
  branches('core'),
  orders('order'),
  catalog('catalog'),
  marketing('marketing'),
  loyalty('loyalty'),
  subscriptions('subscription'),
  engagement('engagement'),
  inventory('stock'),
  staff('staff'),
  payments('payment'),
  other('other');

  const AuditDomainFilter(this.value);

  final String? value;
}
