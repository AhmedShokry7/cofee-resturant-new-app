class AdminKitchenMetrics {
  const AdminKitchenMetrics({
    this.queued = 0,
    this.preparing = 0,
    this.ready = 0,
    this.active = 0,
    this.completedToday = 0,
    this.late = 0,
    this.oldestWaitMinutes = 0,
    this.avgPrepMinutes = 0,
  });

  static const empty = AdminKitchenMetrics();

  final int queued;
  final int preparing;
  final int ready;
  final int active;
  final int completedToday;
  final int late;
  final int oldestWaitMinutes;
  final double avgPrepMinutes;

  bool get hasActiveTickets => active > 0;

  factory AdminKitchenMetrics.fromJson(Map<String, dynamic> json) {
    return AdminKitchenMetrics(
      queued: _toInt(json['queued']),
      preparing: _toInt(json['preparing']),
      ready: _toInt(json['ready']),
      active: _toInt(json['active']),
      completedToday: _toInt(json['completed_today']),
      late: _toInt(json['late']),
      oldestWaitMinutes: _toInt(json['oldest_wait_minutes']),
      avgPrepMinutes: _toDouble(json['avg_prep_minutes']),
    );
  }

  static int _toInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}
