/// The health filter of the inventory directory. [value] matches the status
/// returned by `admin_inventory_directory`.
enum InventoryStatusFilter {
  all(null),
  out('out'),
  low('low'),
  ok('ok');

  const InventoryStatusFilter(this.value);

  final String? value;
}

/// The movement type filter of the ledger. [value] matches movement_type.
enum StockMovementTypeFilter {
  all(null),
  receipt('receipt'),
  issue('issue'),
  waste('waste'),
  count('count');

  const StockMovementTypeFilter(this.value);

  final String? value;
}

/// The period filter of the ledger and its metrics.
enum StockMovementPeriod {
  all(null),
  today('today'),
  week('week'),
  month('month');

  const StockMovementPeriod(this.value);

  final String? value;
}
