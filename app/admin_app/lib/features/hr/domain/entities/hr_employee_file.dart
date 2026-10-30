import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// بند أجر سارٍ أو سطر من تاريخه، كما ترسله `admin_hr_employee()`.
///
/// `current` يفتح البدلات ثلاثة أسطر، و`history` يرسلها سطرًا واحدًا جمعته
/// القاعدة. الحقول التي لا يرسلها القسم تبقى null، فلا تعرض الشاشة جمعًا لم
/// تحسبه له.
class HrCompensation {
  const HrCompensation({
    required this.id,
    required this.basicSalary,
    this.housingAllowance,
    this.transportAllowance,
    this.otherAllowance,
    this.allowancesTotal,
    required this.currencyCode,
    required this.effectiveFrom,
    this.effectiveTo,
    this.note = '',
  });

  final String id;
  final double basicSalary;

  /// تفصيل البدلات؛ لا يرسله سطر التاريخ فيبقى null بدل اختراعه في الواجهة.
  final double? housingAllowance;
  final double? transportAllowance;
  final double? otherAllowance;

  /// مجموع البدلات كما roundته القاعدة في سطر التاريخ.
  final double? allowancesTotal;
  final String currencyCode;
  final DateTime? effectiveFrom;

  /// null = الأجر ما زال ساريًا.
  final DateTime? effectiveTo;
  final String note;

  bool get isCurrent => effectiveTo == null;

  factory HrCompensation.fromJson(Map<String, dynamic> json) => HrCompensation(
    id: hrText(json['id']),
    basicSalary: hrNum(json['basic_salary']),
    housingAllowance: json['housing_allowance'] == null
        ? null
        : hrNum(json['housing_allowance']),
    transportAllowance: json['transport_allowance'] == null
        ? null
        : hrNum(json['transport_allowance']),
    otherAllowance: json['other_allowance'] == null
        ? null
        : hrNum(json['other_allowance']),
    allowancesTotal: json['allowances'] == null
        ? null
        : hrNum(json['allowances']),
    currencyCode: hrText(json['currency_code']),
    effectiveFrom: hrDate(json['effective_from']),
    effectiveTo: hrDate(json['effective_to']),
    note: hrText(json['note']),
  );
}

/// سلفة في ملف الموظف؛ `outstanding` تحسبه القاعدة بـ round لا الشاشة.
class HrAdvanceBrief {
  const HrAdvanceBrief({
    required this.id,
    required this.amount,
    required this.settledAmount,
    required this.outstanding,
    required this.status,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final double amount;
  final double settledAmount;
  final double outstanding;
  final String status;
  final String reason;
  final DateTime? createdAt;

  bool get isStillOpen => status == 'pending' || status == 'approved';

  factory HrAdvanceBrief.fromJson(Map<String, dynamic> json) => HrAdvanceBrief(
    id: hrText(json['id']),
    amount: hrNum(json['amount']),
    settledAmount: hrNum(json['settled_amount']),
    outstanding: hrNum(json['outstanding']),
    status: hrText(json['status']),
    reason: hrText(json['reason']),
    createdAt: hrDate(json['created_at']),
  );
}

/// طلب إجازة مختصر كما يظهر في ملف الموظف.
class HrLeaveBrief {
  const HrLeaveBrief({
    required this.id,
    required this.typeName,
    required this.startsOn,
    required this.endsOn,
    required this.days,
    required this.status,
    required this.reason,
    required this.reviewNote,
  });

  final String id;
  final String typeName;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final int days;
  final String status;
  final String reason;
  final String reviewNote;

  factory HrLeaveBrief.fromJson(Map<String, dynamic> json) => HrLeaveBrief(
    id: hrText(json['id']),
    typeName: hrText(json['type_name_ar']).isEmpty
        ? hrText(json['type_name_en'])
        : hrText(json['type_name_ar']),
    startsOn: hrDate(json['starts_on']),
    endsOn: hrDate(json['ends_on']),
    days: hrInt(json['days']),
    status: hrText(json['status']),
    reason: hrText(json['reason']),
    reviewNote: hrText(json['review_note']),
  );
}

/// تسوية في ملف الموظف، بلا اسم الطالب ولا ملاحظة المراجع — هذان في قائمة المال.
class HrAdjustmentBrief {
  const HrAdjustmentBrief({
    required this.id,
    required this.kind,
    required this.amount,
    required this.reason,
    required this.status,
    required this.sourceType,
    required this.effectiveDate,
    required this.payrollRunId,
  });

  final String id;

  /// `allowance|bonus|commission|overtime|deduction`.
  final String kind;
  final double amount;
  final String reason;

  /// `pending|approved|rejected|reversed|cancelled`.
  final String status;

  /// `manual` أو `cashier_discrepancy` — النسب يقرئه الموظف قبل أن يعترض.
  final String sourceType;
  final DateTime? effectiveDate;

  /// الدورة التي استوعبت التسوية؛ فارغ ما لم تُدفع أو تُحسب.
  final String payrollRunId;

  bool get isDeduction => kind == 'deduction';
  bool get isClaimed => payrollRunId.isNotEmpty;

  factory HrAdjustmentBrief.fromJson(Map<String, dynamic> json) =>
      HrAdjustmentBrief(
        id: hrText(json['id']),
        kind: hrText(json['kind']),
        amount: hrNum(json['amount']),
        reason: hrText(json['reason']),
        status: hrText(json['status']),
        sourceType: hrText(json['source_type']),
        effectiveDate: hrDate(json['effective_date']),
        payrollRunId: hrText(json['payroll_run_id']),
      );
}

/// ملف موظف واحد من `admin_hr_employee()`.
///
/// الأقسام التي لا يقرأها المسموح تكون null، لا قائمة فارغة: الفرق بين «ليس لك
/// أن ترى» و«لا سجل له» قرارٌ للقاعدة، والشاشة تعرضه بهذا الفرق لا بطرح صفر.
class HrEmployeeFile {
  const HrEmployeeFile({
    required this.employee,
    required this.acceptedAt,
    this.attendance,
    this.leave,
    this.canSeeCompensation = false,
    this.currentCompensation,
    this.compensationHistory = const <HrCompensation>[],
    this.payslips,
    this.advances,
    this.adjustments,
    this.cashierShifts,
  });

  final HrEmployee employee;
  final DateTime? acceptedAt;

  /// null حين لا صلاحية حضور لهذا القارئ.
  final List<HrAttendanceBrief>? attendance;

  /// الإجازات مرئية لصاحب الملف ولقارئ HR على السواء، فلا gate عليها في 212.
  final List<HrLeaveBrief>? leave;

  /// هل قرأ القارئ قسم الأجر كله؛ `currentCompensation` وحدها لا تفرّق بين
  /// «لا تركيبة مكتوبة» و«لا إذن بالقراءة».
  final bool canSeeCompensation;
  final HrCompensation? currentCompensation;
  final List<HrCompensation> compensationHistory;

  /// قسيمات نهائية فقط: لا تعرض القاعدة ما لم يُعتمد أو يُدفع.
  final List<HrPayslipSummary>? payslips;
  final List<HrAdvanceBrief>? advances;
  final List<HrAdjustmentBrief>? adjustments;
  final List<HrCashierShift>? cashierShifts;

  bool get canSeePayroll => payslips != null;
  bool get canSeeFinance => advances != null || adjustments != null;

  factory HrEmployeeFile.fromJson(Map<String, dynamic> json) {
    final compensation = json['compensation'] == null
        ? const <String, dynamic>{}
        : hrMap(json['compensation']);
    return HrEmployeeFile(
      employee: HrEmployee.fromFileJson(json),
      acceptedAt: hrDate(json['accepted_at']),
      attendance: json['attendance'] == null
          ? null
          : hrMaps(json['attendance']).map(HrAttendanceBrief.fromJson).toList(),
      leave: hrMaps(json['leave']).map(HrLeaveBrief.fromJson).toList(),
      canSeeCompensation: json['compensation'] != null,
      currentCompensation: compensation['current'] == null
          ? null
          : HrCompensation.fromJson(hrMap(compensation['current'])),
      compensationHistory: hrMaps(compensation['history'])
          .map(HrCompensation.fromJson)
          .toList(),
      payslips: json['payslips'] == null
          ? null
          : hrMaps(json['payslips']).map(HrPayslipSummary.fromJson).toList(),
      advances: json['advances'] == null
          ? null
          : hrMaps(json['advances']).map(HrAdvanceBrief.fromJson).toList(),
      adjustments: json['adjustments'] == null
          ? null
          : hrMaps(json['adjustments'])
                .map(HrAdjustmentBrief.fromJson)
                .toList(),
      cashierShifts: json['cashier_shifts'] == null
          ? null
          : hrMaps(json['cashier_shifts'])
                .map(HrCashierShift.fromJson)
                .toList(),
    );
  }
}
