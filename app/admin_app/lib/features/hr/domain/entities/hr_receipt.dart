import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// إيصال كتابة من 212: المعرّف والحالة وما رافقهما من أرقام.
///
/// دوال الكتابة تردّ كائنًا صغيرًا (`{run_id, status}` مثلًا)، لا الصف كاملًا.
/// لو حوّلته الشاشة إلى كيان كامل لظهرت المجاميع صفرًا وهي لم تُقرأ قط، وهذا
/// بالضبط ما يمنع هذا النوع: ما لا ورد في الرد يبقى غائبًا لا صفرًا.
class HrReceipt {
  const HrReceipt({
    required this.id,
    required this.status,
    this.count = 0,
    this.amounts = const <String, double>{},
  });

  /// المعرّف الذي كتبته القاعدة، بأي اسم ورد (`id` أو `run_id` أو...).
  final String id;

  /// الحالة بعد القرار، كما ختمتها القاعدة لا كما طلبت الشاشة.
  final String status;

  /// عدد الصفوف التي أنتجها الأمر، حين تردّه القاعدة (`statement_count`).
  final int count;

  /// الأرقام التي ردّها الأمر بأسمائها، لعرضها حيث تحتاجها الشاشة.
  final Map<String, double> amounts;

  bool get isReal => id.isNotEmpty;

  double? amount(String key) => amounts[key];

  static const List<String> _idKeys = <String>[
    'id',
    'run_id',
    'advance_id',
    'adjustment_id',
    'discrepancy_id',
    'request_id',
    'correction_id',
    'statement_id',
    'session_id',
    'type_id',
  ];

  factory HrReceipt.fromJson(Map<String, dynamic> json) {
    final id = _idKeys
        .map((key) => hrText(json[key]))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final amounts = <String, double>{};
    for (final key in const <String>[
      'total_gross',
      'total_deductions',
      'total_net',
      'amount',
      'installment_amount',
      'days',
      'entitled_days',
    ]) {
      final value = json[key];
      if (value is num || value is String) amounts[key] = hrNum(value);
    }
    return HrReceipt(
      id: id,
      status: hrText(json['status']),
      count: hrInt(json['statement_count']),
      amounts: amounts,
    );
  }

  static final HrReceipt empty = HrReceipt.fromJson(const <String, dynamic>{});
}
