import 'package:admin_app/core/locale/app_locale.dart';

/// Temporary feature-owned vocabulary. The host shell can map these labels to
/// shared `S` entries without coupling this feature to Staff's identity copy.
abstract final class HrEmployeeStrings {
  static bool get _ar => AppLocale.instance.isArabic;

  static String get fileAction => _ar ? 'الملف الوظيفي' : 'Employment file';
  static String get fileTitle => _ar ? 'ملف الموظف' : 'Employee file';
  static String get overview => _ar ? 'نظرة عامة' : 'Overview';
  static String get employment => _ar ? 'العمل' : 'Employment';
  static String get organization => _ar ? 'التنظيم' : 'Organization';
  static String get attendance => _ar ? 'الحضور' : 'Attendance';
  static String get leave => _ar ? 'الإجازات' : 'Leave';
  static String get payAndFinance => _ar ? 'الأجور والماليات' : 'Pay & finance';
  static String get editEmployment =>
      _ar ? 'تعديل بيانات العمل' : 'Edit employment';
  static String get save => _ar ? 'حفظ بيانات العمل' : 'Save employment';
  static String get saving => _ar ? 'جارٍ الحفظ…' : 'Saving…';
  static String get saved => _ar ? 'تم حفظ بيانات العمل' : 'Employment saved';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
  static String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get close => _ar ? 'إغلاق' : 'Close';
  static String get loading =>
      _ar ? 'جارٍ تحميل الملف الوظيفي…' : 'Loading employment file…';
  static String get loadFailed =>
      _ar ? 'تعذر تحميل الملف الوظيفي' : 'Could not load the employment file';
  static String get saveFailed =>
      _ar ? 'تعذر حفظ بيانات العمل' : 'Could not save employment';
  static String get noEmployment => _ar
      ? 'لا توجد بيانات عمل لهذا الحساب'
      : 'No employment record is available for this account';
  static String get noValue => _ar ? 'غير محدد' : 'Not set';
  static String get noRows => _ar ? 'لا توجد سجلات' : 'No records';
  static String get restricted => _ar
      ? 'لا تملك صلاحية عرض هذه البيانات'
      : 'You do not have permission to view this data';
  static String get accountStatus => _ar ? 'حالة الحساب' : 'Account status';
  static String get employmentStatus =>
      _ar ? 'الحالة الوظيفية' : 'Employment status';
  static String get fullName => _ar ? 'الاسم' : 'Name';
  static String get email => _ar ? 'البريد الإلكتروني' : 'Email';
  static String get employeeNumber => _ar ? 'الرقم الوظيفي' : 'Employee number';
  static String get department => _ar ? 'القسم' : 'Department';
  static String get jobTitle => _ar ? 'المسمى الوظيفي' : 'Job title';
  static String get employmentType => _ar ? 'نوع التوظيف' : 'Employment type';
  static String get hireDate => _ar ? 'تاريخ التعيين' : 'Hire date';
  static String get terminationDate =>
      _ar ? 'تاريخ انتهاء العمل' : 'Termination date';
  static String get phone => _ar ? 'رقم التواصل' : 'Phone';
  static String get emergencyName =>
      _ar ? 'اسم جهة اتصال الطوارئ' : 'Emergency contact name';
  static String get emergencyPhone =>
      _ar ? 'هاتف الطوارئ' : 'Emergency contact phone';
  static String get notes => _ar ? 'ملاحظات' : 'Notes';
  static String get branches => _ar ? 'الفروع' : 'Branches';
  static String get roles => _ar ? 'الأدوار' : 'Roles';
  static String get acceptedAt =>
      _ar ? 'تاريخ تفعيل الحساب' : 'Account accepted';
  static String get active => _ar ? 'نشط' : 'Active';
  static String get probation => _ar ? 'فترة تجربة' : 'Probation';
  static String get onLeave => _ar ? 'في إجازة' : 'On leave';
  static String get terminated => _ar ? 'منتهٍ' : 'Terminated';
  static String get fullTime => _ar ? 'دوام كامل' : 'Full time';
  static String get partTime => _ar ? 'دوام جزئي' : 'Part time';
  static String get contract => _ar ? 'عقد' : 'Contract';
  static String get invalidDate => _ar
      ? 'أدخل تاريخًا صحيحًا بصيغة YYYY-MM-DD'
      : 'Enter a valid date as YYYY-MM-DD';
  static String get terminationRequired => _ar
      ? 'أدخل تاريخ انتهاء العمل للحالة المنتهية'
      : 'A termination date is required for terminated employment';
  static String get terminationBeforeHire => _ar
      ? 'يجب ألا يسبق انتهاء العمل تاريخ التعيين'
      : 'Termination cannot be before the hire date';
  static String get code => _ar ? 'الرمز' : 'Code';
  static String get status => _ar ? 'الحالة' : 'Status';
  static String get date => _ar ? 'التاريخ' : 'Date';
  static String get amount => _ar ? 'المبلغ' : 'Amount';
  static String get reason => _ar ? 'السبب' : 'Reason';
  static String get salary => _ar ? 'الراتب' : 'Salary';
  static String get gross => _ar ? 'الإجمالي' : 'Gross';
  static String get deductions => _ar ? 'الخصومات' : 'Deductions';
  static String get net => _ar ? 'الصافي' : 'Net';
  static String get outstanding => _ar ? 'المتبقي' : 'Outstanding';
  static String get effectiveFrom => _ar ? 'ساري من' : 'Effective from';
  static String get effectiveTo => _ar ? 'ساري حتى' : 'Effective to';
}
