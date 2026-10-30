import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// سلفة من `admin_hr_advances()`.
///
/// الاعتماد ليس مالًا مدفوعًا، والصرف ليس مالًا مُستردًا: الحالات ثلاث
/// منفصلات (`approved` ثم `disbursed` ثم `settled`) والشاشة تفرق بينها لأن
/// القاعدة تفرق.
class HrAdvance {
  const HrAdvance({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.amount,
    required this.installmentAmount,
    required this.settledAmount,
    required this.outstanding,
    required this.currencyCode,
    required this.reason,
    required this.status,
    required this.requestedBy,
    required this.reviewedBy,
    required this.reviewNote,
    required this.disbursedAt,
    required this.createdAt,
  });

  final String id;
  final String staffId;
  final String staffName;
  final double amount;

  /// القسط الذي وافق عليه المراجع؛ قد يكون أقل من السلفة على دورات.
  final double installmentAmount;
  final double settledAmount;

  /// ما بقي يُسترد، حسابته القاعدة بـ round إلى مرتبتين.
  final double outstanding;
  final String currencyCode;
  final String reason;

  /// `pending|approved|rejected|disbursed|settled|cancelled`.
  final String status;
  final String requestedBy;
  final String reviewedBy;
  final String reviewNote;
  final DateTime? disbursedAt;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDisbursed => status == 'disbursed';

  /// هل ما زال للطلب مسار: لا رجوع بعد الصرف أو الرد أو الإلغاء.
  bool get isOpen => isPending || isApproved || isDisbursed;

  factory HrAdvance.fromJson(Map<String, dynamic> json) => HrAdvance(
    id: hrText(json['id']),
    staffId: hrText(json['staff_id']),
    staffName: hrText(json['staff_name']),
    amount: hrNum(json['amount']),
    installmentAmount: hrNum(json['installment_amount']),
    settledAmount: hrNum(json['settled_amount']),
    outstanding: hrNum(json['outstanding']),
    currencyCode: hrText(json['currency_code']),
    reason: hrText(json['reason']),
    status: hrText(json['status']),
    requestedBy: hrText(json['requested_by']),
    reviewedBy: hrText(json['reviewed_by']),
    reviewNote: hrText(json['review_note']),
    disbursedAt: hrDate(json['disbursed_at']),
    createdAt: hrDate(json['created_at']),
  );
}

/// إضافة أو حسم معتمد أو معلّق، من `admin_hr_adjustments()`.
///
/// `claimed` هي الجواب عن «هل دخلت هذه الدورة فعلًا»: متى رُبط الصف بدورة
/// صار السطر محفورًا في لقطة، فلا يُعكس بل يُصحَّح.
class HrAdjustment {
  const HrAdjustment({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.kind,
    required this.amount,
    required this.quantity,
    required this.effectiveDate,
    required this.reason,
    required this.status,
    required this.sourceType,
    required this.sourceId,
    required this.payrollRunId,
    required this.claimed,
    required this.requestedBy,
    required this.reviewedBy,
    required this.reviewNote,
    required this.createdAt,
  });

  final String id;
  final String staffId;
  final String staffName;

  /// `allowance|bonus|commission|overtime|deduction`.
  final String kind;
  final double amount;

  /// عدد الوحدات حين يكون البند عدديًا (ساعات إضافية مثلًا).
  final double? quantity;
  final DateTime? effectiveDate;
  final String reason;

  /// `pending|approved|rejected|reversed|cancelled`.
  final String status;

  /// `manual|cashier_discrepancy|payroll_correction|adjustment_reversal`.
  final String sourceType;
  final String sourceId;
  final String payrollRunId;
  final bool claimed;
  final String requestedBy;
  final String reviewedBy;
  final String reviewNote;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeduction => kind == 'deduction';

  /// يعكس القاعدة: ما دخل لقطة معتمدة لا يُعكس، بل يُصحَّح بقيد لاحق.
  bool get canReverse => isApproved && !claimed;

  factory HrAdjustment.fromJson(Map<String, dynamic> json) => HrAdjustment(
    id: hrText(json['id']),
    staffId: hrText(json['staff_id']),
    staffName: hrText(json['staff_name']),
    kind: hrText(json['kind']),
    amount: hrNum(json['amount']),
    quantity: json['quantity'] == null ? null : hrNum(json['quantity']),
    effectiveDate: hrDate(json['effective_date']),
    reason: hrText(json['reason']),
    status: hrText(json['status']),
    sourceType: hrText(json['source_type']),
    sourceId: hrText(json['source_id']),
    payrollRunId: hrText(json['payroll_run_id']),
    claimed: hrBool(json['claimed']),
    requestedBy: hrText(json['requested_by']),
    reviewedBy: hrText(json['reviewed_by']),
    reviewNote: hrText(json['review_note']),
    createdAt: hrDate(json['created_at']),
  );
}
