import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// تسوية وردية صندوق من `admin_hr_discrepancies()`.
///
/// الصف يُلتقط عند إغلاق الوردية ويحفظ حسابها كما حسبته القاعدة: الفرق الموقّع
/// `signed_variance` والمبلغ `amount` مرجعه وردة الصندوق نفسها، لا تقدير من
/// الشاشة. نسبة المسؤولية إلى موظف قرار مستقل عن اكتشاف العجز.
class HrDiscrepancy {
  const HrDiscrepancy({
    required this.id,
    required this.shiftId,
    required this.branchId,
    required this.branchName,
    required this.drawerCashierId,
    required this.drawerCashierName,
    required this.attributedStaffId,
    required this.attributedStaffName,
    required this.signedVariance,
    required this.amount,
    required this.currencyCode,
    required this.status,
    required this.reviewNote,
    required this.evidence,
    required this.reviewerName,
    required this.reviewedAt,
    required this.createdAt,
    required this.openedAtLocal,
    required this.closedAtLocal,
    required this.expectedCash,
    required this.countedCash,
    required this.deductionAdjustmentId,
  });

  final String id;

  /// وردية `payments.pos_shifts` التي جاء منها هذا الصف؛ لا تُعدّل أبدًا.
  final String shiftId;
  final String branchId;
  final String branchName;

  /// من كان على الصندوق كما تسجله الوردية نفسها.
  final String drawerCashierId;
  final String drawerCashierName;

  /// من نُسب إليه العجز بعد التحقيق؛ null ما دام لم يُنسب لأحد.
  final String? attributedStaffId;
  final String attributedStaffName;

  /// سالبًا عند العجز: عدّاد الإغلاق ناقص المتوقع، كما حسبته 212.
  final double signedVariance;

  /// مقدار ما يُنظر فيه، موجبًا دائمًا.
  final double amount;
  final String currencyCode;

  /// `pending_review|explained|reconciliation_required|confirmed|rejected|`
  /// `deduction_approved|closed`
  final String status;
  final String reviewNote;

  /// سطور الأدلة التي تراكمت عبر المراجعات، تضيف القاعدة إليها ولا تمحوها.
  final String evidence;
  final String reviewerName;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  /// الوردية كما هي في صفها، للعرض بلا إعادة حساب.
  final String openedAtLocal;
  final String closedAtLocal;
  final double expectedCash;
  final double countedCash;

  /// قيد الحسم الذي أنتجه قرار `deduct`، إن وُجد.
  final String? deductionAdjustmentId;

  bool get isPendingReview => status == 'pending_review';
  bool get isConfirmed => status == 'confirmed';
  bool get hasShortage => signedVariance < 0;

  /// هل صار الحسم قرارًا: لا يُعاد طلبه على صف أُقرّ له قيد.
  bool get hasDeduction => deductionAdjustmentId != null;

  factory HrDiscrepancy.fromJson(Map<String, dynamic> json) {
    final shift = hrMap(json['shift']);
    return HrDiscrepancy(
      id: hrText(json['id']),
      shiftId: hrText(json['shift_id']),
      branchId: hrText(json['branch_id']),
      branchName: hrText(json['branch_name_ar']).isEmpty
          ? hrText(json['branch_name_en'])
          : hrText(json['branch_name_ar']),
      drawerCashierId: hrText(json['drawer_cashier_id']),
      drawerCashierName: hrText(json['drawer_cashier_name']),
      attributedStaffId: hrId(json['attributed_staff_id']),
      attributedStaffName: hrText(json['attributed_staff_name']),
      signedVariance: hrNum(json['signed_variance']),
      amount: hrNum(json['amount']),
      currencyCode: hrText(json['currency_code']),
      status: hrText(json['status']),
      reviewNote: hrText(json['review_note']),
      evidence: hrText(json['evidence']),
      reviewerName: hrText(json['reviewer_name']),
      reviewedAt: hrDate(json['reviewed_at']),
      createdAt: hrDate(json['created_at']),
      openedAtLocal: hrText(shift['opened_at_local']),
      closedAtLocal: hrText(shift['closed_at_local']),
      expectedCash: hrNum(shift['expected_cash']),
      countedCash: hrNum(shift['counted_cash']),
      deductionAdjustmentId: hrId(json['deduction_adjustment_id']),
    );
  }
}
