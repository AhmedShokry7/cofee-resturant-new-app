import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:flutter/material.dart';

/// لفظ حالة مخزّنة في 212 ولونها، في موضع واحد.
///
/// الكلمات هنا ألفاظ واجهة لا مفاتيح بحث: المفتاح هو الحرف الذي تكتبه القاعدة
/// في العمود، ولو تُرجم في كل شاشة وحدها لظهر السطر نفسه بثلاثة أسماء.
class HrLabel {
  const HrLabel(this.text, this.color);

  final String text;
  final Color color;
}

/// حالة سطر HR كما تُعرض بشارتها.
///
/// الحالات المشتركة بين الجداول (pending/approved/…) تُلفظ مرة واحدة، فـ`closed`
/// في الجلسة غير `closed` في فرق الصندوق لكن اللفظ واحد والمعنى في السياق.
HrLabel hrStatusLabel(String status) => switch (status) {
  'active' => HrLabel(S.hrStatusActive, AppColor.adminAccent),
  'probation' => HrLabel(S.hrStatusProbation, AppColor.adminWarning),
  'on_leave' => HrLabel(S.hrStatusOnLeave, AppColor.statusBlue),
  'terminated' => HrLabel(S.hrStatusTerminated, AppColor.greyColor),
  'invited' => HrLabel(S.staffStatusInvited, AppColor.adminWarning),
  'suspended' => HrLabel(S.staffStatusSuspended, AppColor.errorColor),
  'open' => HrLabel(S.hrStatusOpen, AppColor.adminAccent),
  'closed' => HrLabel(S.hrStatusClosed, AppColor.greyColor),
  'draft' => HrLabel(S.hrStatusDraft, AppColor.greyColor),
  'published' => HrLabel(S.hrStatusPublished, AppColor.adminAccent),
  'pending' => HrLabel(S.hrStatusPending, AppColor.adminWarning),
  'pending_review' => HrLabel(S.hrStatusPendingReview, AppColor.adminWarning),
  'approved' => HrLabel(S.hrStatusApproved, AppColor.adminAccent),
  'rejected' => HrLabel(S.hrStatusRejected, AppColor.errorColor),
  'cancelled' => HrLabel(S.hrStatusCancelled, AppColor.greyColor),
  'calculated' => HrLabel(S.hrStatusCalculated, AppColor.statusBlue),
  'paid' => HrLabel(S.hrStatusPaid, AppColor.adminAccent),
  'disbursed' => HrLabel(S.hrStatusDisbursed, AppColor.statusViolet),
  'settled' => HrLabel(S.hrStatusSettled, AppColor.greyColor),
  'reversed' => HrLabel(S.hrStatusReversed, AppColor.statusOrange),
  'explained' => HrLabel(S.hrStatusExplained, AppColor.statusBlue),
  'reconciliation_required' => HrLabel(
    S.hrStatusReconciliation,
    AppColor.statusAmber,
  ),
  'confirmed' => HrLabel(S.hrStatusConfirmed, AppColor.statusIndigo),
  'deduction_approved' => HrLabel(
    S.hrStatusDeductionApproved,
    AppColor.errorColor,
  ),
  _ => HrLabel(status, AppColor.greyColor),
};

/// نوع التوظيف كما يختاره سجل العقد.
String hrEmploymentTypeLabel(String type) => switch (type) {
  'full_time' => S.hrTypeFullTime,
  'part_time' => S.hrTypePartTime,
  'contract' => S.hrTypeContract,
  _ => type,
};

/// kind السطر المالي: زيادة أو خصم، أو نوع التسوية نفسها.
String hrKindLabel(String kind) => switch (kind) {
  'addition' => S.hrKindAddition,
  'deduction' => S.hrKindDeduction,
  'allowance' => S.hrKindAllowance,
  'bonus' => S.hrKindBonus,
  'commission' => S.hrKindCommission,
  'overtime' => S.hrKindOvertime,
  _ => kind,
};

/// فئة سطر الرواتب، وهي التي تشرح من أين جاء المبلغ.
String hrCategoryLabel(String category) => switch (category) {
  'basic' => S.hrCategoryBasic,
  'allowance' => S.hrKindAllowance,
  'bonus' => S.hrKindBonus,
  'commission' => S.hrKindCommission,
  'overtime' => S.hrKindOvertime,
  'advance' => S.hrCategoryAdvance,
  'attendance' => S.hrCategoryAttendance,
  'cashier_shortage' => S.hrCategoryCashierShortage,
  'manual' => S.hrCategoryManual,
  'correction' => S.hrCategoryCorrection,
  _ => category,
};

/// مصدر السطر: أي دالة كتبته، فالأثر المالي بلا مصدر لا يُتتبَّع.
String hrSourceLabel(String source) => switch (source) {
  'compensation' => S.hrSourceCompensation,
  'adjustment' => S.hrSourceAdjustment,
  'salary_advance' => S.hrSourceSalaryAdvance,
  'attendance_policy' => S.hrSourceAttendancePolicy,
  'manual' => S.hrSourceManual,
  'payroll_correction' => S.hrSourcePayrollCorrection,
  'cashier_discrepancy' => S.hrSourceCashierDiscrepancy,
  'adjustment_reversal' => S.hrSourceAdjustmentReversal,
  _ => source,
};
