import 'package:admin_app/core/locale/app_locale.dart';

abstract final class HrLeaveStrings {
  static bool get _ar => AppLocale.instance.isArabic;
  static String get title => _ar ? 'إدارة الإجازات' : 'Leave management';
  static String get subtitle => _ar
      ? 'مراجعة الطلبات وإدارة أنواع الإجازات والأرصدة ضمن نطاقك.'
      : 'Review requests and manage leave types and balances in your scope.';
  static String get filter => _ar ? 'حالة الطلب' : 'Request status';
  static String get all => _ar ? 'كل الطلبات' : 'All requests';
  static String get pending => _ar ? 'بانتظار المراجعة' : 'Pending';
  static String get approved => _ar ? 'موافق عليها' : 'Approved';
  static String get rejected => _ar ? 'مرفوضة' : 'Rejected';
  static String get cancelled => _ar ? 'ملغاة' : 'Cancelled';
  static String get noRequests =>
      _ar ? 'لا توجد طلبات إجازة' : 'No leave requests';
  static String get employee => _ar ? 'الموظف' : 'Employee';
  static String get period => _ar ? 'الفترة' : 'Period';
  static String get days => _ar ? 'الأيام' : 'Days';
  static String get reason => _ar ? 'السبب' : 'Reason';
  static String get supportingDocument =>
      _ar ? 'يوجد مستند مرفق' : 'Supporting document provided';
  static String get paid => _ar ? 'مدفوعة' : 'Paid';
  static String get unpaid => _ar ? 'غير مدفوعة' : 'Unpaid';
  static String get balance => _ar ? 'رصيد الإجازة' : 'Leave balance';
  static String get entitled => _ar ? 'المستحق' : 'Entitled';
  static String get used => _ar ? 'المستخدم' : 'Used';
  static String get remaining => _ar ? 'المتبقي' : 'Remaining';
  static String get review => _ar ? 'مراجعة الطلب' : 'Review request';
  static String get approve => _ar ? 'موافقة' : 'Approve';
  static String get reject => _ar ? 'رفض' : 'Reject';
  static String get reviewNote => _ar ? 'ملاحظة المراجعة' : 'Review note';
  static String get rejectionReason =>
      _ar ? 'سبب الرفض مطلوب' : 'A rejection reason is required';
  static String get leaveTypes => _ar ? 'أنواع الإجازات' : 'Leave types';
  static String get addType => _ar ? 'إضافة نوع' : 'Add type';
  static String get editType => _ar ? 'تعديل النوع' : 'Edit type';
  static String get code => _ar ? 'الرمز' : 'Code';
  static String get nameAr => _ar ? 'الاسم بالعربية' : 'Arabic name';
  static String get nameEn => _ar ? 'الاسم بالإنجليزية' : 'English name';
  static String get needsDocument =>
      _ar ? 'يتطلب مستندًا' : 'Requires a document';
  static String get tracksBalance => _ar ? 'يتتبع الرصيد' : 'Tracks a balance';
  static String get defaultAnnualDays =>
      _ar ? 'الاستحقاق السنوي الافتراضي' : 'Default annual entitlement';
  static String get typeActive => _ar ? 'نشط' : 'Active';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
  static String get save => _ar ? 'حفظ' : 'Save';
  static String get required =>
      _ar ? 'هذا الحقل مطلوب' : 'This field is required';
  static String get balanceYear => _ar ? 'السنة' : 'Year';
  static String get entitlementDays =>
      _ar ? 'عدد الأيام المستحقة' : 'Entitled days';
  static String get saveBalance => _ar ? 'حفظ الرصيد' : 'Save balance';
  static String get openRequests => _ar ? 'مفتوحة' : 'Open';
  static String get close => _ar ? 'إغلاق' : 'Close';
}
