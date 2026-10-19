import 'package:admin_app/core/locale/app_locale.dart';

/// Every user-visible admin string in one place.
///
/// Each getter reads the current [AppLocale] at build time, so toggling the
/// language rebuilds the whole tree and every label flips together.
class S {
  S._();

  static bool get _ar => AppLocale.instance.isArabic;

  static String get appName => _ar ? 'إدارة القهوة' : 'Coffee Admin';
  static String get admin => _ar ? 'الإدارة' : 'Admin';

  // ---------- Sidebar ----------
  static String get signOut => _ar ? 'تسجيل الخروج' : 'Sign out';
  static String get owner => _ar ? 'المالك' : 'Owner';
  static String get staff => _ar ? 'موظف' : 'Staff';

  // ---------- Destinations ----------
  static String get dashboard => _ar ? 'لوحة التحكم' : 'Dashboard';
  static String get orders => _ar ? 'الطلبات' : 'Orders';
  static String get products => _ar ? 'المنتجات' : 'Products';
  static String get categories => _ar ? 'التصنيفات' : 'Categories';
  static String get inventory => _ar ? 'المخزون' : 'Inventory';
  static String get customers => _ar ? 'العملاء' : 'Customers';
  static String get staffLabel => _ar ? 'الموظفون' : 'Staff';
  static String get settings => _ar ? 'الإعدادات' : 'Settings';

  // ---------- App bar ----------
  static String get search => _ar ? 'بحث' : 'Search';
  static String get language => _ar ? 'اللغة' : 'Language';
  static String get theme => _ar ? 'المظهر' : 'Theme';
  static String get menu => _ar ? 'القائمة' : 'Menu';
  static String get clearSearch => _ar ? 'مسح البحث' : 'Clear search';

  // ---------- Per-page search hints ----------
  static String get searchDashboardHint =>
      _ar ? 'ابحث في الطلبات والعملاء...' : 'Search orders and customers...';
  static String get searchOrdersHint =>
      _ar ? 'ابحث برقم الطلب أو العميل...' : 'Search by order number or customer...';
  static String get searchProductsHint =>
      _ar ? 'ابحث عن منتج...' : 'Search products...';
  static String get searchCategoriesHint =>
      _ar ? 'ابحث عن تصنيف...' : 'Search categories...';
  static String get searchInventoryHint =>
      _ar ? 'ابحث في المخزون...' : 'Search inventory...';
  static String get searchCustomersHint =>
      _ar ? 'ابحث عن عميل...' : 'Search customers...';
  static String get searchStaffHint =>
      _ar ? 'ابحث عن موظف...' : 'Search staff...';
  static String get searchSettingsHint =>
      _ar ? 'ابحث في الإعدادات...' : 'Search settings...';
  static String get searchDefaultHint => _ar ? 'ابحث...' : 'Search...';

  // ---------- Dashboard ----------
  static String get welcomeBack => _ar ? 'مرحبًا بعودتك' : 'Welcome back';
  static String welcomeBackName(String name) =>
      _ar ? 'مرحبًا بعودتك، $name.' : 'Welcome back, $name.';
  static String get todayOrders => _ar ? 'طلبات اليوم' : "Today's orders";
  static String get todayRevenue => _ar ? 'إيرادات اليوم' : "Today's revenue";
  static String get activeOrders => _ar ? 'الطلبات النشطة' : 'Active orders';
  static String get activeProducts => _ar ? 'المنتجات النشطة' : 'Active products';
  static String get customersLabel => _ar ? 'العملاء' : 'Customers';
  static String get activeBranches => _ar ? 'الفروع النشطة' : 'Active branches';
  static String get recentOrders => _ar ? 'أحدث الطلبات' : 'Recent orders';
  static String get noOrdersYet => _ar ? 'لا توجد طلبات بعد.' : 'No orders yet.';
  static String get refresh => _ar ? 'تحديث' : 'Refresh';
  static String get totalOrdersToDate =>
      _ar ? 'إجمالي الطلبات حتى الآن' : 'Total orders to date';
  static String get noDashboardMetrics => _ar
      ? 'دورك لا يتضمن مقاييس لوحة التحكم.'
      : 'Your role does not include dashboard metrics.';
  static String get couldNotLoadDashboard =>
      _ar ? 'تعذر تحميل لوحة التحكم' : 'Could not load dashboard';
  static String get tryAgain => _ar ? 'حاول مرة أخرى' : 'Try again';
  static String get delivery => _ar ? 'توصيل' : 'Delivery';
  static String get pickup => _ar ? 'استلام' : 'Pickup';

  // ---------- Coming soon ----------
  static String get comingSoon => _ar ? 'قريبًا' : 'Coming soon';
  static String get comingSoonDescription => _ar
      ? 'هذا القسم ضمن خطة بناء لوحة الإدارة. طبقة البيانات جاهزة بالفعل.'
      : 'This section is next in the admin build. The data layer is already in place.';

  // ---------- Auth / login ----------
  static String get staffSignIn => _ar ? 'تسجيل دخول الموظفين' : 'Staff sign in';
  static String get staffSignInSubtitle => _ar
      ? 'استخدم حساب الموظف الخاص بك للوصول إلى لوحة التحكم.'
      : 'Use your staff account to access the dashboard.';
  static String get email => _ar ? 'البريد الإلكتروني' : 'Email';
  static String get password => _ar ? 'كلمة المرور' : 'Password';
  static String get signIn => _ar ? 'تسجيل الدخول' : 'Sign in';
  static String get emailRequired =>
      _ar ? 'البريد الإلكتروني مطلوب.' : 'Email is required.';
  static String get validEmail =>
      _ar ? 'أدخل بريدًا إلكترونيًا صحيحًا.' : 'Enter a valid email.';
  static String get passwordRequired =>
      _ar ? 'كلمة المرور مطلوبة.' : 'Password is required.';
  static String get manageBrandSubtitle => _ar
      ? 'أدر الطلبات والقائمة والفروع والموظفين في مكان واحد.'
      : 'Manage orders, catalog, branches and staff in one place.';

  // ---------- Sign out dialog ----------
  static String get signOutTitle => _ar ? 'تسجيل الخروج' : 'Sign out';
  static String get signOutMessage => _ar
      ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
      : 'Are you sure you want to sign out?';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
}
