typedef HrJson = Map<String, dynamic>;

HrJson? hrJson(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<HrJson> hrJsonList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false)
    : const [];

class HrPayrollRun {
  const HrPayrollRun(this.json);
  final HrJson json;
  String get id => '${json['run_id'] ?? ''}';
  int get year => (json['period_year'] as num?)?.toInt() ?? 0;
  int get month => (json['period_month'] as num?)?.toInt() ?? 0;
  String get status => '${json['status'] ?? 'draft'}';
  String get scope => '${json['scope'] ?? 'brand'}';
  int get count => (json['statement_count'] as num?)?.toInt() ?? 0;
  bool get isClosed => json['closed_at'] != null;
  double get gross => (json['total_gross'] as num?)?.toDouble() ?? 0;
  double get deductions => (json['total_deductions'] as num?)?.toDouble() ?? 0;
  double get net => (json['total_net'] as num?)?.toDouble() ?? 0;
  List<HrJson> get statements => hrJsonList(json['statements']);
  factory HrPayrollRun.fromJson(HrJson json) => HrPayrollRun(json);
}

class HrPayrollPreview {
  const HrPayrollPreview(this.json);
  final HrJson json;
  int get year => (json['period_year'] as num?)?.toInt() ?? 0;
  int get month => (json['period_month'] as num?)?.toInt() ?? 0;
  HrJson? get run => hrJson(json['run']);
  List<HrJson> get employees => hrJsonList(json['employees']);
  List<HrJson> get missing => hrJsonList(json['missing_data']);
  List<HrJson> get adjustments => hrJsonList(json['adjustments_due']);
  double total(String key) => employees.fold<double>(
    0,
    (sum, row) => sum + ((row[key] as num?)?.toDouble() ?? 0),
  );
  factory HrPayrollPreview.fromJson(HrJson json) => HrPayrollPreview(json);
}
