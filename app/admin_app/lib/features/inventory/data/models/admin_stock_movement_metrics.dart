class AdminStockMovementMetrics {
  const AdminStockMovementMetrics({
    this.total = 0,
    this.receipts = 0,
    this.issues = 0,
    this.waste = 0,
    this.counts = 0,
    this.receivedValue = 0,
    this.issuedValue = 0,
    this.wasteValue = 0,
    this.actors = 0,
    this.latestAt,
  });

  static const empty = AdminStockMovementMetrics();

  final int total;
  final int receipts;
  final int issues;
  final int waste;
  final int counts;
  final double receivedValue;
  final double issuedValue;
  final double wasteValue;
  final int actors;
  final DateTime? latestAt;

  factory AdminStockMovementMetrics.fromJson(Map<String, dynamic> json) {
    return AdminStockMovementMetrics(
      total: _toInt(json['total']),
      receipts: _toInt(json['receipts']),
      issues: _toInt(json['issues']),
      waste: _toInt(json['waste']),
      counts: _toInt(json['counts']),
      receivedValue: _toDouble(json['received_value']),
      issuedValue: _toDouble(json['issued_value']),
      wasteValue: _toDouble(json['waste_value']),
      actors: _toInt(json['actors']),
      latestAt: _toDate(json['latest_at']),
    );
  }

  static int _toInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static DateTime? _toDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
