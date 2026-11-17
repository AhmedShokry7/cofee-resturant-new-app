import '../../../../core/locale/app_locale.dart';

abstract final class HrOffboardingStrings {
  static bool get _ar => AppLocale.instance.isArabic;

  static String get title => _ar ? 'إنهاء الخدمة' : 'Offboarding';
  static String get subtitle => _ar
      ? 'تابع خطوات إنهاء الخدمة، والتسوية، وإيقاف الدخول كلٌّ على حدة.'
      : 'Track separation, settlement and account access as separate steps.';
  static String get start => _ar ? 'بدء إجراء إنهاء خدمة' : 'Start offboarding';
  static String get employee => _ar ? 'الموظف' : 'Employee';
  static String get lastDay => _ar ? 'آخر يوم عمل' : 'Last working day';
  static String get note => _ar ? 'ملاحظة' : 'Note';
  static String get open => _ar ? 'قيد الإجراء' : 'Open';
  static String get closed => _ar ? 'مكتمل' : 'Closed';
  static String get cancelled => _ar ? 'ملغي' : 'Cancelled';
  static String get empty =>
      _ar ? 'لا توجد إجراءات إنهاء خدمة.' : 'No offboarding cases yet.';
  static String get noPeople => _ar
      ? 'لا يوجد موظفون متاحون ضمن نطاقك.'
      : 'No employees are available in your scope.';
  static String get checklist => _ar ? 'قائمة الإنهاء' : 'Checklist';
  static String get assign =>
      _ar ? 'تعيين مسؤول وموعد' : 'Assign owner and due date';
  static String get owner => _ar ? 'المسؤول' : 'Owner';
  static String get dueDate => _ar ? 'تاريخ الاستحقاق' : 'Due date';
  static String get save => _ar ? 'حفظ' : 'Save';
  static String get markDone => _ar ? 'إتمام الخطوة' : 'Mark done';
  static String get markSkipped => _ar ? 'تجاوز الخطوة' : 'Skip step';
  static String get reopen => _ar ? 'إعادة إلى قيد الانتظار' : 'Set pending';
  static String get requiredNote => _ar
      ? 'اكتب ملاحظة لإتمام هذه الخطوة.'
      : 'Add a note before completing this step.';
  static String get finalSettlement =>
      _ar ? 'التسوية النهائية' : 'Final settlement';
  static String get settlementInstruction => _ar
      ? 'أدخل نتيجة المراجعة البشرية المعتمدة ومراجعها. لا يحسب النظام مكافأة نهاية الخدمة هنا.'
      : 'Record the human-reviewed settlement and its reference. No end-of-service formula is calculated here.';
  static String get finalize =>
      _ar ? 'اعتماد انتهاء الخدمة' : 'Finalize termination';
  static String get terminatedOn =>
      _ar ? 'تاريخ انتهاء الخدمة' : 'Termination date';
  static String get cancelCase => _ar ? 'إلغاء الإجراء' : 'Cancel case';
  static String get confirmCancel =>
      _ar ? 'تأكيد الإلغاء' : 'Confirm cancellation';
  static String get suspendAccess =>
      _ar ? 'إيقاف حساب الدخول' : 'Suspend account access';
  static String get suspendWarning => _ar
      ? 'سيوقف هذا الإجراء دخول الموظف إلى النظام بعد إغلاق ملف إنهاء الخدمة. لا يتم الإيقاف تلقائيًا.'
      : 'This will suspend sign-in after the offboarding case is closed. Suspension is never automatic.';
  static String get confirm => _ar ? 'تأكيد' : 'Confirm';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
  static String get pending => _ar ? 'بانتظار التنفيذ' : 'Pending';
  static String get done => _ar ? 'مكتمل' : 'Done';
  static String get skipped => _ar ? 'متجاوز' : 'Skipped';
  static String get failed =>
      _ar ? 'تعذر تحميل البيانات.' : 'Could not load data.';
  static String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get accessDenied => _ar
      ? 'لا تملك صلاحية عرض إجراءات إنهاء الخدمة.'
      : 'You do not have permission to view offboarding.';
  static String get created =>
      _ar ? 'بدأ إجراء إنهاء الخدمة.' : 'Offboarding case started.';
  static String get saved => _ar ? 'تم حفظ التغييرات.' : 'Changes saved.';
  static String get dateRequired =>
      _ar ? 'اختر تاريخ انتهاء الخدمة.' : 'Choose a termination date.';
  static String get settlementRequired => _ar
      ? 'أدخل توثيق التسوية البشرية المعتمدة.'
      : 'Enter the approved human settlement record.';
  static String get managerReview => _ar ? 'مراجعة المدير' : 'Manager review';
  static String get hrReview => _ar ? 'مراجعة الموارد البشرية' : 'HR review';
  static String get financeReview =>
      _ar ? 'المراجعة المالية' : 'Finance review';
  static String get obligations =>
      _ar ? 'إغلاق الالتزامات والعهد' : 'Return obligations and assets';
  static String get accessSuspensionStep =>
      _ar ? 'إيقاف الدخول' : 'Account access suspension';
  static String get requestedBy => _ar ? 'بدأه' : 'Requested by';
  static String get finalizedBy => _ar ? 'اعتمده' : 'Finalized by';
  static String get finalizedAt => _ar ? 'تاريخ الاعتماد' : 'Finalized at';
  static String get noOwner => _ar ? 'غير معيّن' : 'Unassigned';
  static String get actionError =>
      _ar ? 'تعذر تنفيذ الإجراء.' : 'The action could not be completed.';

  static String step(String code) => switch (code) {
    'manager_review' => managerReview,
    'hr_review' => hrReview,
    'finance_review' => financeReview,
    'obligations' => obligations,
    'final_settlement' => finalSettlement,
    'access_suspension' => accessSuspensionStep,
    _ => code,
  };

  static String status(String status) => switch (status) {
    'open' => open,
    'closed' => closed,
    'cancelled' => cancelled,
    'done' => done,
    'skipped' => skipped,
    _ => pending,
  };
}
