import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// الفرع كما تحتاجه شاشات HR: اسم للغتين ومعرّف للقاعدة.
class HrBranch {
  const HrBranch({
    required this.id,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  factory HrBranch.fromJson(Map<String, dynamic> json) => HrBranch(
    id: hrText(json['id']),
    nameAr: hrText(json['name_ar']),
    nameEn: hrText(json['name_en']),
  );
}

/// نوع إجازة كما تقرأه 212 من `hr.leave_types`.
class HrLeaveType {
  const HrLeaveType({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.requiresDocument,
    required this.isPaid,
    required this.tracksBalance,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;

  /// أنواع لا تُقبل بدون مرفق، فتُغلق القاعدة الطلب وترفضه.
  final bool requiresDocument;
  final bool isPaid;

  /// الأنواع التي تُخصم من رصيد السنة؛ لا رصيد لما لا يتتبعه.
  final bool tracksBalance;

  factory HrLeaveType.fromJson(Map<String, dynamic> json) => HrLeaveType(
    id: hrText(json['id']),
    code: hrText(json['code']),
    nameAr: hrText(json['name_ar']),
    nameEn: hrText(json['name_en']),
    requiresDocument: hrBool(json['requires_document']),
    isPaid: hrBool(json['is_paid']),
    tracksBalance: hrBool(json['tracks_balance']),
  );
}

/// سياسة HR كما في `hr.settings`، وهي التي تحسب بها القاعدة لا الشاشة.
class HrSettings {
  const HrSettings({
    this.businessTimeZone = 'Asia/Riyadh',
    this.lateGraceMinutes = 0,
    this.cashierDeductionAllowed = false,
    this.maxSalaryDeductionPercent = 0,
    this.lateMinuteRate,
    this.earlyMinuteRate,
    this.absenceDayRate,
  });

  final String businessTimeZone;

  /// الدقائق التي لا تُحسب تأخيرًا بعد بداية الجدول المنشور.
  final int lateGraceMinutes;

  /// هل تجوز تسوية عجز الصندوق بخصم من الأجر أصلًا.
  final bool cashierDeductionAllowed;
  final double maxSalaryDeductionPercent;

  /// أسعار الحسم لكل دقيقة؛ null لمن لا يملك صلاحية السياسة أن يقرؤها.
  final double? lateMinuteRate;
  final double? earlyMinuteRate;
  final double? absenceDayRate;

  static const HrSettings unknown = HrSettings();

  factory HrSettings.fromJson(Map<String, dynamic> json) => HrSettings(
    businessTimeZone: hrText(json['business_time_zone']).isEmpty
        ? 'Asia/Riyadh'
        : hrText(json['business_time_zone']),
    lateGraceMinutes: hrInt(json['late_grace_minutes']),
    cashierDeductionAllowed: hrBool(json['cashier_deduction_allowed']),
    maxSalaryDeductionPercent: hrNum(json['max_salary_deduction_percent']),
    lateMinuteRate: json['late_minute_rate'] == null
        ? null
        : hrNum(json['late_minute_rate']),
    earlyMinuteRate: json['early_minute_rate'] == null
        ? null
        : hrNum(json['early_minute_rate']),
    absenceDayRate: json['absence_day_rate'] == null
        ? null
        : hrNum(json['absence_day_rate']),
  );
}

/// ما تُجيب به `admin_hr_reference()`: قوائم الاختيار وسياسةُ نطاق القارئ.
///
/// تُقرأ مرة واحدة وتُشارك بين شاشات HR، فالقاعدة هي التي تقرر أي الفروع يديرها
/// هذا الموظف وكم يُعرض من أسعار السياسة.
class HrReference {
  const HrReference({
    this.branches = const <HrBranch>[],
    this.leaveTypes = const <HrLeaveType>[],
    this.departments = const <String>[],
    this.settings = HrSettings.unknown,
    this.myStaffId,
  });

  final List<HrBranch> branches;
  final List<HrLeaveType> leaveTypes;
  final List<String> departments;
  final HrSettings settings;

  /// موظف الأدمن الذي يقرأ؛ null حين لا صف `active` لحساب الدخول.
  final String? myStaffId;

  bool get isEmpty =>
      branches.isEmpty && leaveTypes.isEmpty && myStaffId == null;

  HrBranch branchNamed(String? id) {
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return const HrBranch(id: '', nameAr: '', nameEn: '');
  }

  factory HrReference.fromJson(Map<String, dynamic> json) => HrReference(
    branches: hrMaps(json['branches']).map(HrBranch.fromJson).toList(),
    leaveTypes: hrMaps(json['leave_types']).map(HrLeaveType.fromJson).toList(),
    departments: [
      for (final item
          in json['departments'] is List
              ? json['departments'] as List
              : const <Object>[])
        hrText(item),
    ],
    settings: HrSettings.fromJson(hrMap(json['settings'])),
    myStaffId: hrId(json['my_staff_id']),
  );
}
