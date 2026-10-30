import 'package:admin_app/core/locale/app_strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// الرفض كما تقوله القاعدة، مصلحًا إلى ما تعرفه الشاشة.
///
/// كل دالة في Migration 212 ترفض بـ `RAISE EXCEPTION` مع SQLSTATE، فلا يوجد
/// غلاف `{ok:false}` ولا سبب داخل الرد: الرسالة نفسها هي الدليل. تُحمَل هنا
/// ليراها المدير بحروف قاعدته بدل أن تختفي خلف «حدث خطأ».
class HrRefusal implements Exception {
  const HrRefusal({required this.sqlState, required this.message});

  /// رمز SQLSTATE كما رفعته القاعدة: `42501` صلاحية أو نطاق، `P0002` غير موجود،
  /// `22023` قيمة مرفوضة، `23505` تكرار، `23514` انتقال حالة ممنوع.
  final String sqlState;

  /// نص القاعدة الحرفي، يُعرض كما هو حين لا تعرف الشاشة ترجمة له.
  final String message;

  bool get isPermission => sqlState == '42501';
  bool get isNotFound => sqlState == 'P0002';
  bool get isValidation => sqlState == '22023';
  bool get isDuplicate => sqlState == '23505';
  bool get isStateGuard => sqlState == '23514';

  @override
  String toString() => message;
}

/// تحويل استجابة Supabase الفاشلة إلى رفض HR واحد.
///
/// تستدعيها مستودعات الفيتشر في كل `catch`، فيبقى مصدر الرمز واحدًا ولا تقرر
/// أي شاشة أن استثناءً مجهولًا هو «نقص صلاحية».
HrRefusal hrRefusalOf(Object error) {
  if (error is HrRefusal) return error;
  if (error is PostgrestException) {
    return HrRefusal(sqlState: error.code ?? '', message: error.message);
  }
  return HrRefusal(sqlState: '', message: '$error');
}

/// الرسالة التي تُعرض باللفظ المحلي حين تعرف الشاشة مقابلًا له، أو نص القاعدة.
///
/// مطابقة بنمط لا بمفتاح واحد، لأن القاعدة تكتب تفاصيل متغيّرة في آخر النص مثل
/// `missing permission: hr.payroll.read` و`unknown discrepancy action: x`.
String hrRefusalMessage(HrRefusal refusal) {
  final text = refusal.message;
  for (final entry in _orderedHrMessages) {
    if (text.contains(entry.key)) return entry.value();
  }
  return text;
}

/// المطابقة بالأطول أولًا: `employee not found` جزء من `attributed employee
/// not found or inactive`، والمرتب كما كُتب كان يبتلع الرسالة الأخصّ ويعرض
/// «الموظف غير موجود» حين المقصود أن المنسوب إلى العجز لا يعمل في الفرع.
final List<MapEntry<String, String Function()>> _orderedHrMessages =
    _hrMessages.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

/// مقابل كل رفض تكتبه 212: مفتاح البحث في نص القاعدة، ورسالة للمستخدم.
final Map<String, String Function()> _hrMessages = <String, String Function()>{
  'not authenticated': () => S.hrNotAuthenticated,
  'missing permission:': () => S.hrMissingPermission,
  'employee not found': () => S.hrEmployeeNotFound,
  'invalid employment type': () => S.hrInvalidEmploymentType,
  'invalid employment status': () => S.hrInvalidEmploymentStatus,
  'a terminated employment needs a termination date': () =>
      S.hrTerminationDateRequired,
  'termination date precedes hire date': () => S.hrTerminationBeforeHire,
  'staff member out of scope': () => S.hrOutOfScope,
  'branch out of scope': () => S.hrBranchOutOfScope,
  'already clocked in': () => S.hrAlreadyClockedIn,
  'no open attendance session': () => S.hrNoOpenSession,
  'a break is already open': () => S.hrBreakAlreadyOpen,
  'this session already used its break': () => S.hrBreakUsed,
  'no open break': () => S.hrNoOpenBreak,
  'invalid attendance date range': () => S.hrInvalidDateRange,
  'attendance range is limited': () => S.hrRangeTooWide,
  'an attendance correction needs a reason': () => S.hrCorrectionNeedsReason,
  'no change proposed': () => S.hrNoChangeProposed,
  'clock out must follow clock in': () => S.hrClockOutBeforeIn,
  'attendance session not found': () => S.hrSessionNotFound,
  'attendance correction not found': () => S.hrCorrectionNotFound,
  'attendance correction is already reviewed': () => S.hrCorrectionReviewed,
  'you cannot approve your own attendance correction': () =>
      S.hrSelfApproveCorrection,
  'a new attendance record needs a clock-in time': () => S.hrNeedsClockIn,
  'the corrected session overlaps another session': () => S.hrSessionOverlap,
  'the employee has no branch to record attendance in': () =>
      S.hrNoBranchForAttendance,
  'overlapping work schedule': () => S.hrScheduleOverlap,
  'invalid schedule window': () => S.hrInvalidScheduleWindow,
  'invalid schedule date range': () => S.hrInvalidScheduleRange,
  'schedule range is limited': () => S.hrScheduleRangeTooWide,
  'a shift cannot exceed 24 hours': () => S.hrScheduleTooLong,
  'invalid break length': () => S.hrInvalidBreakLength,
  'invalid schedule status': () => S.hrInvalidScheduleStatus,
  'work schedule not found': () => S.hrScheduleNotFound,
  'invalid leave dates': () => S.hrInvalidLeaveDates,
  'leave request is too long': () => S.hrLeaveTooLong,
  'leave type not found': () => S.hrLeaveTypeNotFound,
  'this leave type requires a supporting document': () =>
      S.hrLeaveNeedsDocument,
  'leave balance is not configured for this year': () => S.hrNoBalanceForYear,
  'insufficient leave balance': () => S.hrInsufficientBalance,
  'overlapping leave request': () => S.hrLeaveOverlap,
  'leave request not found': () => S.hrLeaveNotFound,
  'leave request out of scope': () => S.hrLeaveOutOfScope,
  'leave request is already reviewed': () => S.hrLeaveAlreadyReviewed,
  'you cannot approve your own leave request': () => S.hrSelfApproveLeave,
  'leave request cannot be cancelled in its current state': () =>
      S.hrLeaveNotCancellable,
  'invalid leave status': () => S.hrInvalidLeaveStatus,
  'invalid leave year': () => S.hrInvalidLeaveYear,
  'entitled days cannot be negative': () => S.hrNegativeEntitlement,
  'this leave type does not track a balance': () => S.hrLeaveTypeNoBalance,
  'entitlement cannot be below the days already used': () =>
      S.hrEntitlementBelowUsed,
  'invalid basic salary': () => S.hrInvalidSalary,
  'allowances cannot be negative': () => S.hrNegativeAllowance,
  'overlapping compensation period': () => S.hrCompensationOverlap,
  'a compensation record already starts on this date': () =>
      S.hrCompensationSameDate,
  'cannot backdate before a later compensation record': () =>
      S.hrCompensationBackdate,
  'invalid payroll year': () => S.hrInvalidPayrollYear,
  'invalid payroll month': () => S.hrInvalidPayrollMonth,
  'this payroll period has not started yet': () => S.hrPeriodNotStarted,
  'this payroll period is already approved': () => S.hrPeriodAlreadyApproved,
  'invalid payroll run transition': () => S.hrRunTransitionBlocked,
  'payroll run not found': () => S.hrRunNotFound,
  'only a calculated run can be approved': () => S.hrOnlyCalculatedApprovable,
  'only an approved run can be marked paid': () => S.hrOnlyApprovedPayable,
  'only a draft or calculated run can be cancelled': () =>
      S.hrRunNotCancellable,
  'the person who calculated this run cannot approve it': () =>
      S.hrSelfApproveRun,
  'an advance in this run changed after calculation': () =>
      S.hrAdvanceChangedRegenerate,
  'payroll runs answer for the whole brand': () => S.hrPayrollIsBrandLevel,
  'all-branch scope': () => S.hrNeedsAllBranchScope,
  'payslip not found': () => S.hrStatementNotFound,
  'this payslip is not final yet': () => S.hrPayslipNotFinal,
  'an approved payroll statement is immutable': () => S.hrStatementImmutable,
  'an approved payroll statement cannot be deleted': () =>
      S.hrStatementUndeletable,
  'invalid correction status': () => S.hrInvalidCorrectionStatus,
  'invalid correction kind': () => S.hrInvalidCorrectionKind,
  'correction amount must be positive': () => S.hrCorrectionNotPositive,
  'a correction needs a reason': () => S.hrCorrectionReasonRequired,
  'a correction applies to an approved or paid payslip': () =>
      S.hrCorrectionNeedsApproved,
  'a correction starts after the corrected period': () =>
      S.hrCorrectionAfterPeriod,
  'advance amount must be positive': () => S.hrAdvanceNotPositive,
  'an advance request needs a reason': () => S.hrAdvanceNeedsReason,
  'installment must be positive': () => S.hrInvalidInstallment,
  'an advance request is already open': () => S.hrAdvanceAlreadyOpen,
  'advance not found': () => S.hrAdvanceNotFound,
  'invalid advance status': () => S.hrInvalidAdvanceStatus,
  'this advance is already reviewed': () => S.hrAdvanceAlreadyReviewed,
  'you cannot review your own advance request': () => S.hrSelfReviewAdvance,
  'only an approved advance can be disbursed': () => S.hrAdvanceNotDisbursable,
  'this advance cannot be cancelled': () => S.hrAdvanceNotCancellable,
  'part of this advance is already recovered': () => S.hrAdvancePartlySettled,
  'a disbursed advance can only be cancelled by finance': () =>
      S.hrAdvanceFinanceOnly,
  'advance out of scope': () => S.hrAdvanceOutOfScope,
  'invalid adjustment kind': () => S.hrInvalidAdjustmentKind,
  'adjustment amount must be positive': () => S.hrAdjustmentNotPositive,
  'an adjustment needs a reason': () => S.hrAdjustmentNeedsReason,
  'quantity must be positive when given': () => S.hrInvalidQuantity,
  'adjustment not found': () => S.hrAdjustmentNotFound,
  'this adjustment is already reviewed': () => S.hrAdjustmentAlreadyReviewed,
  'you cannot approve your own adjustment': () => S.hrSelfApproveAdjustment,
  'this adjustment is already part of a payroll run': () =>
      S.hrAdjustmentAlreadyInRun,
  'only an approved adjustment can be reversed': () =>
      S.hrAdjustmentNotReversible,
  'this adjustment is already in a payroll snapshot': () =>
      S.hrAdjustmentInSnapshot,
  'a reversal needs a reason': () => S.hrReversalNeedsReason,
  'invalid adjustment status': () => S.hrInvalidAdjustmentStatus,
  'invalid adjustment source': () => S.hrInvalidAdjustmentSource,
  'staff member is required': () => S.hrStaffRequired,
  'branch not found or inactive': () => S.hrBranchInactive,
  'invalid discrepancy status': () => S.hrInvalidDiscrepancyStatus,
  'discrepancy not found': () => S.hrDiscrepancyNotFound,
  'confirm the discrepancy before approving a deduction': () =>
      S.hrConfirmBeforeDeduct,
  'unknown discrepancy action': () => S.hrUnknownDiscrepancyAction,
  'cannot be explained in its current state': () =>
      S.hrDiscrepancyNotExplainable,
  'cannot be moved to reconciliation in its current state': () =>
      S.hrDiscrepancyNotReconcilable,
  'cannot be confirmed in its current state': () =>
      S.hrDiscrepancyNotConfirmable,
  'cannot be rejected in its current state': () => S.hrDiscrepancyNotRejectable,
  'cannot be closed in its current state': () => S.hrDiscrepancyNotClosable,
  'an explanation needs a note': () => S.hrExplanationNeedsNote,
  'rejecting a discrepancy needs a note': () => S.hrRejectionNeedsNote,
  'confirming a discrepancy requires naming the responsible employee': () =>
      S.hrConfirmNeedsEmployee,
  'attributed employee not found or inactive': () => S.hrAttributedNotFound,
  'the attributed employee does not work in this branch': () =>
      S.hrAttributedWrongBranch,
  'a reviewer cannot attribute a shortage to themselves': () =>
      S.hrAttributeToSelf,
  'no employee is attributed to this discrepancy': () => S.hrNoOneAttributed,
  'a reviewer cannot deduct from themselves': () => S.hrDeductFromSelf,
  'cashier deductions are disabled in the HR settings': () =>
      S.hrDeductionsDisabled,
  'the deduction must be positive and no larger than the discrepancy': () =>
      S.hrDeductionOutOfRange,
  'a deduction already exists for this discrepancy': () => S.hrDeductionExists,
  'approving a deduction needs a note explaining the decision': () =>
      S.hrDeductionNeedsNote,
  'unknown time zone': () => S.hrUnknownTimeZone,
  'late grace must be between': () => S.hrGraceOutOfRange,
  'minute rates must be between': () => S.hrRateOutOfRange,
  'absence day rate is out of range': () => S.hrAbsenceRateOutOfRange,
  'the deduction cap must be between 0 and 100 percent': () =>
      S.hrCapOutOfRange,
  'cashier deductions need a positive cap': () => S.hrDeductionsNeedCap,
  'leave type code must be lowercase letters and underscores': () =>
      S.hrLeaveTypeCodeShape,
  'both names are required': () => S.hrBothNamesRequired,
  'leave type not found or inactive': () => S.hrLeaveTypeNotFound,
  'default annual days cannot be negative': () => S.hrNegativeEntitlement,
};
