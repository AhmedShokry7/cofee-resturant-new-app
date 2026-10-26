class AdminAuditMetrics {
  const AdminAuditMetrics({
    this.total = 0,
    this.today = 0,
    this.week = 0,
    this.critical = 0,
    this.criticalWeek = 0,
    this.actors = 0,
    this.actorsWeek = 0,
    this.branches = 0,
    this.latestAt,
  });

  static const empty = AdminAuditMetrics();

  final int total;
  final int today;
  final int week;
  final int critical;
  final int criticalWeek;
  final int actors;
  final int actorsWeek;
  final int branches;
  final DateTime? latestAt;

  factory AdminAuditMetrics.fromJson(Map<String, dynamic> json) {
    return AdminAuditMetrics(
      total: _toInt(json['total']),
      today: _toInt(json['today']),
      week: _toInt(json['week']),
      critical: _toInt(json['critical']),
      criticalWeek: _toInt(json['critical_week']),
      actors: _toInt(json['actors']),
      actorsWeek: _toInt(json['actors_week']),
      branches: _toInt(json['branches']),
      latestAt: _toDateTime(json['latest_at']),
    );
  }

  static int _toInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
