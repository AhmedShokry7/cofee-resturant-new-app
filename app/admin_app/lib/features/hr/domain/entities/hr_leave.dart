import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// رصيد إجازة لسنة واحدة، كما يرسله الطلب نفسه في `balance`.
///
/// يُستهلك الرصيد عند الاعتماد لا عند الطلب، فـ `remaining` قراءة لا حجز.
class HrLeaveBalance {
  const HrLeaveBalance({
    required this.year,
    required this.entitledDays,
    required this.usedDays,
    required this.remainingDays,
  });

  final int year;
  final double entitledDays;
  final double usedDays;
  final double remainingDays;

  factory HrLeaveBalance.fromJson(Map<String, dynamic> json) => HrLeaveBalance(
    year: hrInt(json['year']),
    entitledDays: hrNum(json['entitled_days']),
    usedDays: hrNum(json['used_days']),
    remainingDays: hrNum(json['remaining_days']),
  );
}

/// طلب إجازة من `admin_hr_leave_requests()` أو من ردّ الإنشاء.
class HrLeaveRequest {
  const HrLeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.leaveTypeId,
    required this.typeName,
    required this.isPaid,
    required this.tracksBalance,
    required this.startsOn,
    required this.endsOn,
    required this.days,
    required this.reason,
    required this.supportingDocument,
    required this.status,
    required this.requestedByName,
    required this.reviewedByName,
    required this.reviewedAtLocal,
    required this.reviewNote,
    required this.createdAtLocal,
    this.balance,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String leaveTypeId;
  final String typeName;
  final bool isPaid;

  /// أنواع لا رصيد لها (مثلًا المرضية غير المتتبَّعة): لا استحقاق يُراجَع.
  final bool tracksBalance;
  final DateTime? startsOn;
  final DateTime? endsOn;

  /// عدد الأيام كما حسبته القاعدة: نهاية ناقص بداية زائد واحد.
  final int days;
  final String reason;

  /// المسار المرفوع حين يطلب النوع مستندًا؛ ترفض القاعدة بدونه.
  final String supportingDocument;

  /// `pending|approved|rejected|cancelled`.
  final String status;
  final String requestedByName;
  final String reviewedByName;
  final String reviewedAtLocal;
  final String reviewNote;
  final String createdAtLocal;
  final HrLeaveBalance? balance;

  bool get isPending => status == 'pending';

  factory HrLeaveRequest.fromJson(Map<String, dynamic> json) => HrLeaveRequest(
    id: hrText(json['id']),
    staffId: hrText(json['staff_id']),
    staffName: hrText(json['staff_name']),
    leaveTypeId: hrText(json['leave_type_id']),
    typeName: hrText(json['type_name_ar']).isEmpty
        ? hrText(json['type_name_en'])
        : hrText(json['type_name_ar']),
    isPaid: hrBool(json['is_paid']),
    tracksBalance: hrBool(json['tracks_balance']),
    startsOn: hrDate(json['starts_on']),
    endsOn: hrDate(json['ends_on']),
    days: hrInt(json['days']),
    reason: hrText(json['reason']),
    supportingDocument: hrText(json['supporting_document']),
    status: hrText(json['status']),
    requestedByName: hrText(json['requested_by_name']),
    reviewedByName: hrText(json['reviewed_by_name']),
    reviewedAtLocal: hrText(json['reviewed_at_local']),
    reviewNote: hrText(json['review_note']),
    createdAtLocal: hrText(json['created_at_local']),
    balance: json['balance'] == null
        ? null
        : HrLeaveBalance.fromJson(hrMap(json['balance'])),
  );
}
