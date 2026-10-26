/// The headline numbers of the branches page.
class AdminBranchMetrics {
  const AdminBranchMetrics({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.withoutLocation = 0,
    this.zonesCovered = 0,
    this.orders30d = 0,
    this.staffAssigned = 0,
  });

  final int total;
  final int active;
  final int inactive;
  final int withoutLocation;
  final int zonesCovered;
  final int orders30d;
  final int staffAssigned;

  static const empty = AdminBranchMetrics();

  factory AdminBranchMetrics.fromJson(Map<String, dynamic> json) {
    return AdminBranchMetrics(
      total: _count(json['total']),
      active: _count(json['active']),
      inactive: _count(json['inactive']),
      withoutLocation: _count(json['without_location']),
      zonesCovered: _count(json['zones_covered']),
      orders30d: _count(json['orders_30d']),
      staffAssigned: _count(json['staff_assigned']),
    );
  }

  double get activeShare => total == 0 ? 0 : active / total;

  static int _count(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }
}
