class AdminInventoryMetrics {
  const AdminInventoryMetrics({
    this.total = 0,
    this.low = 0,
    this.out = 0,
    this.stockValue = 0,
    this.categories = 0,
    this.branches = 0,
    this.latestMovementAt,
  });

  static const empty = AdminInventoryMetrics();

  final int total;
  final int low;
  final int out;
  final double stockValue;
  final int categories;
  final int branches;
  final DateTime? latestMovementAt;

  factory AdminInventoryMetrics.fromJson(Map<String, dynamic> json) {
    return AdminInventoryMetrics(
      total: _toInt(json['total']),
      low: _toInt(json['low']),
      out: _toInt(json['out']),
      stockValue: _toDouble(json['stock_value']),
      categories: _toInt(json['categories']),
      branches: _toInt(json['branches']),
      latestMovementAt: _toDate(json['latest_movement_at']),
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
