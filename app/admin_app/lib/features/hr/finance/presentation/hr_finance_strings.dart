import 'package:admin_app/core/locale/app_locale.dart';

abstract final class HrFinanceStrings {
  static bool get _ar => AppLocale.instance.isArabic;
  static String get title =>
      _ar ? 'العمليات المالية للموظفين' : 'Employee finance';
  static String get subtitle => _ar
      ? 'السلف والتسويات وفروقات الصناديق ضمن الصلاحيات والنطاق.'
      : 'Advances, adjustments and cashier discrepancies within your access scope.';
  static String get advances => _ar ? 'السلف' : 'Advances';
  static String get adjustments => _ar ? 'التسويات' : 'Adjustments';
  static String get discrepancies =>
      _ar ? 'فروقات الصندوق' : 'Cash discrepancies';
  static String get all => _ar ? 'الكل' : 'All';
  static String get pending => _ar ? 'معلّق' : 'Pending';
  static String get approved => _ar ? 'معتمد' : 'Approved';
  static String get rejected => _ar ? 'مرفوض' : 'Rejected';
  static String get disbursed => _ar ? 'مصروف' : 'Disbursed';
  static String get settled => _ar ? 'مسدد' : 'Settled';
  static String get cancelled => _ar ? 'ملغى' : 'Cancelled';
  static String get reversed => _ar ? 'معكوس' : 'Reversed';
  static String get noRecords => _ar ? 'لا توجد سجلات' : 'No records';
  static String get employee => _ar ? 'الموظف' : 'Employee';
  static String get amount => _ar ? 'المبلغ' : 'Amount';
  static String get installment => _ar ? 'قسط الخصم' : 'Payroll installment';
  static String get outstanding => _ar ? 'المتبقي' : 'Outstanding';
  static String get settledAmount => _ar ? 'المسدد' : 'Recovered';
  static String get reason => _ar ? 'السبب' : 'Reason';
  static String get note => _ar ? 'ملاحظة المراجعة' : 'Review note';
  static String get evidence =>
      _ar ? 'الدليل أو المرجع' : 'Evidence or reference';
  static String get approve => _ar ? 'اعتماد' : 'Approve';
  static String get reject => _ar ? 'رفض' : 'Reject';
  static String get disburse => _ar ? 'تسجيل الصرف' : 'Record disbursement';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
  static String get reverse => _ar ? 'عكس التسوية' : 'Reverse adjustment';
  static String get create => _ar ? 'إضافة تسوية' : 'Create adjustment';
  static String get save => _ar ? 'حفظ' : 'Save';
  static String get kind => _ar ? 'نوع التسوية' : 'Adjustment type';
  static String get allowance => _ar ? 'بدل' : 'Allowance';
  static String get bonus => _ar ? 'مكافأة' : 'Bonus';
  static String get commission => _ar ? 'عمولة' : 'Commission';
  static String get overtime => _ar ? 'عمل إضافي' : 'Overtime';
  static String get deduction => _ar ? 'خصم' : 'Deduction';
  static String get effectiveDate => _ar ? 'تاريخ السريان' : 'Effective date';
  static String get status => _ar ? 'الحالة' : 'Status';
  static String get claimed =>
      _ar ? 'أُدرجت في مسير رواتب' : 'Included in payroll';
  static String get branch => _ar ? 'الفرع' : 'Branch';
  static String get cashier => _ar ? 'أمين الصندوق' : 'Cashier';
  static String get attributedEmployee =>
      _ar ? 'الموظف المسؤول' : 'Attributed employee';
  static String get signedVariance => _ar ? 'فرق الصندوق' : 'Cash variance';
  static String get explain => _ar ? 'توضيح' : 'Explain';
  static String get reconcile =>
      _ar ? 'إحالة للمطابقة' : 'Require reconciliation';
  static String get confirm => _ar ? 'تأكيد المسؤولية' : 'Confirm attribution';
  static String get deduct => _ar ? 'اعتماد خصم' : 'Approve deduction';
  static String get close => _ar ? 'إغلاق الحالة' : 'Close case';
  static String get selectEmployee => _ar ? 'اختر موظفًا' : 'Select employee';
  static String get required =>
      _ar ? 'هذا الحقل مطلوب' : 'This field is required';
  static String get invalidNumber =>
      _ar ? 'أدخل مبلغًا صالحًا' : 'Enter a valid amount';
  static String get currency => _ar ? 'ر.س' : 'SAR';
  static String statusName(String value) => switch (value) {
    'pending' || 'pending_review' => pending,
    'approved' || 'confirmed' || 'deduction_approved' => approved,
    'rejected' => rejected,
    'disbursed' => disbursed,
    'settled' => settled,
    'cancelled' => cancelled,
    'reversed' => reversed,
    'explained' => _ar ? 'موضح' : 'Explained',
    'reconciliation_required' =>
      _ar ? 'يتطلب مطابقة' : 'Reconciliation required',
    'closed' => _ar ? 'مغلق' : 'Closed',
    _ => value,
  };
  static String kindName(String value) => switch (value) {
    'allowance' => allowance,
    'bonus' => bonus,
    'commission' => commission,
    'overtime' => overtime,
    'deduction' => deduction,
    _ => value,
  };
}
