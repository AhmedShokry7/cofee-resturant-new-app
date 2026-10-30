import 'package:admin_app/core/locale/app_strings.dart';

/// إجراءات فرق الصندوق كما تسمّيها 212 في `admin_hr_review_discrepancy`.
///
/// أسماء الدالة في القاعدة هي هذه الحروف، والاسم الذي يُرسَل خطأً يُرجع
/// `unknown discrepancy action`، فتُكتب مرة واحدة هنا بدل أن تُنسخ في كل شاشة.
enum HrDiscrepancyAction {
  explain('explain'),
  reconcile('reconcile'),
  confirm('confirm'),
  reject('reject'),
  deduct('deduct'),
  close('close');

  const HrDiscrepancyAction(this.wire);

  /// الحرف الذي يذهب في `p_action` كما تنطقه القاعدة.
  final String wire;

  String get label => switch (this) {
    HrDiscrepancyAction.explain => S.hrActionExplain,
    HrDiscrepancyAction.reconcile => S.hrActionReconcile,
    HrDiscrepancyAction.confirm => S.hrActionConfirm,
    HrDiscrepancyAction.reject => S.hrActionReject,
    HrDiscrepancyAction.deduct => S.hrActionDeduct,
    HrDiscrepancyAction.close => S.hrActionClose,
  };
}
