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
  static String get role => _ar ? 'الدور' : 'Role';
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
  static String get searchOrdersHint => _ar
      ? 'ابحث برقم الطلب أو العميل...'
      : 'Search by order number or customer...';
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
  static String get activeProducts =>
      _ar ? 'المنتجات النشطة' : 'Active products';
  static String get customersLabel => _ar ? 'العملاء' : 'Customers';
  static String get activeBranches => _ar ? 'الفروع النشطة' : 'Active branches';
  static String get recentOrders => _ar ? 'أحدث الطلبات' : 'Recent orders';
  static String get noOrdersYet =>
      _ar ? 'لا توجد طلبات بعد.' : 'No orders yet.';
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

  // ---------- Auth / login ----------
  static String get staffSignIn =>
      _ar ? 'تسجيل دخول الموظفين' : 'Staff sign in';
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

  // ---------- Catalog ----------
  static String get all => _ar ? 'الكل' : 'All';

  // Actions
  static String get addCategory => _ar ? 'إضافة تصنيف' : 'Add category';
  static String get editCategory => _ar ? 'تعديل التصنيف' : 'Edit category';
  static String get addProduct => _ar ? 'إضافة منتج' : 'Add product';
  static String get editProduct => _ar ? 'تعديل المنتج' : 'Edit product';
  static String get save => _ar ? 'حفظ' : 'Save';
  static String get edit => _ar ? 'تعديل' : 'Edit';
  static String get delete => _ar ? 'حذف' : 'Delete';
  static String get archive => _ar ? 'أرشفة' : 'Archive';
  static String get restore => _ar ? 'استعادة' : 'Restore';

  // Fields
  static String get image => _ar ? 'الصورة' : 'Image';
  static String get name => _ar ? 'الاسم' : 'Name';
  static String get nameAr => _ar ? 'الاسم بالعربية' : 'Name (Arabic)';
  static String get nameEn => _ar ? 'الاسم بالإنجليزية' : 'Name (English)';
  static String get slug => _ar ? 'الرابط' : 'Slug';
  static String get category => _ar ? 'التصنيف' : 'Category';
  static String get categoryFilter => _ar ? 'تصنيف المنتج' : 'Product category';
  static String get sku => _ar ? 'كود المنتج' : 'SKU';
  static String get price => _ar ? 'السعر' : 'Price';
  static String get compareAtPrice =>
      _ar ? 'السعر المقارن' : 'Compare at price';
  static String get prepMinutes => _ar ? 'دقيقة التحضير' : 'Prep minutes';
  static String get featured => _ar ? 'مميز' : 'Featured';
  static String get isFeatured => _ar ? 'منتج مميز' : 'Featured product';
  static String get status => _ar ? 'الحالة' : 'Status';
  static String get active => _ar ? 'مفعل' : 'Active';
  static String get inactive => _ar ? 'معطل' : 'Inactive';
  static String get archived => _ar ? 'مؤرشف' : 'Archived';
  static String get actions => _ar ? 'عمليات' : 'Actions';
  static String get iconKey => _ar ? 'مفتاح الأيقونة' : 'Icon key';
  static String get imageUrl => _ar ? 'رابط الصورة' : 'Image URL';
  static String get descriptionAr =>
      _ar ? 'الوصف بالعربية' : 'Description (Arabic)';
  static String get descriptionEn =>
      _ar ? 'الوصف بالإنجليزية' : 'Description (English)';
  static String get sortOrder => _ar ? 'ترتيب العرض' : 'Sort order';
  static String get isActive => _ar ? 'مفعل' : 'Active';
  static String get parent => _ar ? 'التصنيف الأم' : 'Parent category';

  // Validation
  static String get requiredField =>
      _ar ? 'هذا الحقل مطلوب' : 'This field is required';
  static String get invalidPrice => _ar ? 'سعر غير صالح' : 'Invalid price';
  static String get invalidNumber => _ar ? 'رقم غير صالح' : 'Invalid number';
  static String get compareAtMustBeHigher => _ar
      ? 'يجب أن يكون السعر المقارن أعلى من السعر الأساسي'
      : 'Compare-at price must be higher than the base price';

  // Empty states
  static String get noCategoriesFound =>
      _ar ? 'لا توجد تصنيفات مطابقة' : 'No categories found';
  static String get noProductsFound =>
      _ar ? 'لا توجد منتجات مطابقة' : 'No products found';

  // Messages
  static String get saved => _ar ? 'تم الحفظ' : 'Saved';
  static String get deleted => _ar ? 'تم الحذف' : 'Deleted';
  static String get couldNotLoadCategories =>
      _ar ? 'تعذر تحميل التصنيفات' : 'Could not load categories';
  static String get couldNotLoadProducts =>
      _ar ? 'تعذر تحميل المنتجات' : 'Could not load products';

  static String categoriesCount(int count) => count == 1
      ? _ar
            ? 'تصنيف واحد'
            : '1 category'
      : _ar
      ? '$count تصنيفات'
      : '$count categories';

  static String productsCount(int count) => count == 1
      ? _ar
            ? 'منتج واحد'
            : '1 product'
      : _ar
      ? '$count منتجات'
      : '$count products';

  static String deleteCategoryConfirm(String name) => _ar
      ? 'هل أنت متأكد أنك تريد حذف التصنيف "$name"؟'
      : 'Are you sure you want to delete the category "$name"?';

  static String deleteProductConfirm(String name) => _ar
      ? 'هل أنت متأكد أنك تريد حذف المنتج "$name"؟'
      : 'Are you sure you want to delete the product "$name"?';

  // ---------- Customers ----------
  static String get noCustomersFound =>
      _ar ? 'لا يوجد عملاء' : 'No customers yet';
  static String get customerName => _ar ? 'اسم العميل' : 'Customer name';
  static String get emailAddress => _ar ? 'البريد الإلكتروني' : 'Email';
  static String get phone => _ar ? 'الهاتف' : 'Phone';
  static String get ordersCountLabel => _ar ? 'عدد الطلبات' : 'Orders';
  static String get totalSpent => _ar ? 'إجمالي الإنفاق' : 'Total spent';
  static String get lastOrder => _ar ? 'آخر طلب' : 'Last order';
  static String get editCustomerTitle => _ar ? 'تعديل العميل' : 'Edit customer';
  static String get fullName => _ar ? 'الاسم الكامل' : 'Full name';

  static String customersCount(int count) => count == 1
      ? _ar
            ? 'عميل واحد'
            : '1 customer'
      : _ar
      ? '$count عملاء'
      : '$count customers';

  // ---------- Inventory ----------
  static String get noInventoryItems =>
      _ar ? 'لا توجد أصناف في المخزون' : 'No inventory items';
  static String get productName => _ar ? 'اسم المنتج' : 'Product';
  static String get currentStock => _ar ? 'المخزون الحالي' : 'Current stock';
  static String get minStock => _ar ? 'الحد الأدنى' : 'Min stock';
  static String get unit => _ar ? 'الوحدة' : 'Unit';
  static String get lowStock => _ar ? 'منخفض' : 'Low';
  static String get inStock => _ar ? 'متوفر' : 'In stock';
  static String get editStockTitle => _ar ? 'تعديل المخزون' : 'Edit stock';

  static String inventoryCount(int count) => count == 1
      ? _ar
            ? 'صنف واحد'
            : '1 item'
      : _ar
      ? '$count أصناف'
      : '$count items';

  static String lowStockCount(int count) => count == 1
      ? _ar
            ? 'صنف منخفض'
            : '1 low stock item'
      : _ar
      ? '$count أصناف منخفضة'
      : '$count low stock items';

  // ---------- Orders ----------
  static String get noOrdersFound => _ar ? 'لا توجد طلبات' : 'No orders yet';
  static String get orderNumber => _ar ? 'رقم الطلب' : 'Order number';
  static String get customer => _ar ? 'العميل' : 'Customer';
  static String get total => _ar ? 'المجموع' : 'Total';
  static String get fulfillmentType => _ar ? 'نوع التوصيل' : 'Delivery type';
  static String get date => _ar ? 'التاريخ' : 'Date';
  static String get statusPending => _ar ? 'قيد الانتظار' : 'Pending';
  static String get statusConfirmed => _ar ? 'مؤكد' : 'Confirmed';
  static String get statusPreparing => _ar ? 'قيد التحضير' : 'Preparing';
  static String get statusReady => _ar ? 'جاهز' : 'Ready';
  static String get statusOutForDelivery =>
      _ar ? 'في طريقه للتوصيل' : 'Out for delivery';
  static String get statusCompleted => _ar ? 'مكتمل' : 'Completed';
  static String get statusCancelled => _ar ? 'ملغي' : 'Cancelled';

  static String orderStatusLabel(String status) => switch (status) {
    'pending' => statusPending,
    'confirmed' => statusConfirmed,
    'preparing' => statusPreparing,
    'ready' => statusReady,
    'out_for_delivery' => statusOutForDelivery,
    'completed' => statusCompleted,
    'cancelled' => statusCancelled,
    _ => status,
  };

  // ---------- Staff ----------
  static String get noStaffFound => _ar ? 'لا يوجد موظفين' : 'No staff members';
  static String get staffName => _ar ? 'اسم الموظف' : 'Staff name';
  static String get roleColumn => _ar ? 'الدور' : 'Role';
  static String get roleManager => _ar ? 'مدير' : 'Manager';
  static String get roleCashier => _ar ? 'كاشير' : 'Cashier';
  static String get activeStatus => _ar ? 'نشط' : 'Active';
  static String get inactiveStatus => _ar ? 'غير نشط' : 'Inactive';
  static String get editStaffTitle => _ar ? 'تعديل الموظف' : 'Edit staff';
  static String get roleHint =>
      _ar ? 'الدور (owner/staff/manager)' : 'Role (owner/staff/manager)';

  static String staffCount(int count) => count == 1
      ? _ar
            ? 'موظف واحد'
            : '1 staff member'
      : _ar
      ? '$count موظفين'
      : '$count staff members';

  static String activeStaffCount(int count) => count == 1
      ? _ar
            ? 'موظف نشط'
            : '1 active staff member'
      : _ar
      ? '$count موظفين نشطين'
      : '$count active staff members';

  static String deleteOrderConfirm(String orderNumber) => _ar
      ? 'هل أنت متأكد أنك تريد حذف الطلب "$orderNumber"؟'
      : 'Are you sure you want to delete the order "$orderNumber"?';

  // ---------- Load errors ----------
  static String get couldNotLoadCustomers =>
      _ar ? 'تعذر تحميل العملاء' : 'Could not load customers';
  static String get couldNotLoadInventory =>
      _ar ? 'تعذر تحميل المخزون' : 'Could not load inventory';
  static String get couldNotLoadOrders =>
      _ar ? 'تعذر تحميل الطلبات' : 'Could not load orders';
  static String get couldNotLoadStaff =>
      _ar ? 'تعذر تحميل الموظفين' : 'Could not load staff';

  // ---------- Settings ----------
  static String get preferences => _ar ? 'التفضيلات' : 'Preferences';
  static String get changePassword =>
      _ar ? 'تغيير كلمة المرور' : 'Change password';
  static String get currentPassword =>
      _ar ? 'كلمة المرور الحالية' : 'Current password';
  static String get newPassword => _ar ? 'كلمة المرور الجديدة' : 'New password';
  static String get confirmNewPassword =>
      _ar ? 'تأكيد كلمة المرور الجديدة' : 'Confirm new password';
  static String get themeSystem => _ar ? 'النظام' : 'System';
  static String get themeLight => _ar ? 'فاتح' : 'Light';
  static String get themeDark => _ar ? 'داكن' : 'Dark';
  static String get arabicLabel => _ar ? 'العربية' : 'Arabic';
  static String get englishLabel => _ar ? 'الإنجليزية' : 'English';
  static String get statusActive => _ar ? 'نشط' : 'Active';
  static String get more => _ar ? 'المزيد' : 'More';
  static String get viewTable => _ar ? 'عرض كجدول' : 'Table view';
  static String get viewCards => _ar ? 'عرض ككروت' : 'Card view';
  static String get sectionManagement => _ar ? 'الإدارة' : 'Management';
  static String get sectionSettings =>
      _ar ? 'الإعدادات العامة' : 'General settings';
  static String get sectionOperations => _ar ? 'العمليات' : 'Operations';
  static String get sectionPeople =>
      _ar ? 'الأشخاص والفروع' : 'People and branches';
  static String get sectionContent =>
      _ar ? 'المحتوى والإعدادات' : 'Content and settings';
  static String get sectionGrowth =>
      _ar ? 'النمو والتفاعل' : 'Growth and engagement';

  // ---------- Feature placeholders ----------
  static String get soonBadge => _ar ? 'قريباً' : 'Soon';
  static String get featureNotBuilt => _ar
      ? 'هذه الميزة موجودة في قاعدة البيانات لكنها لم تُبنَ بعد في لوحة التحكم.'
      : 'This feature exists in the database but is not built in the dashboard yet.';
  static String get databaseTables =>
      _ar ? 'جداول قاعدة البيانات' : 'Database tables';
  static String get noDatabaseTables =>
      _ar ? 'لا توجد جداول مرتبطة مباشرة.' : 'No directly related tables.';

  static String get bundles => _ar ? 'الباقات' : 'Bundles';
  static String get branchPricing => _ar ? 'تسعير الفروع' : 'Branch pricing';
  static String get carts => _ar ? 'سلة المشتريات' : 'Carts';
  static String get stockMovements => _ar ? 'حركة المخزون' : 'Stock movements';
  static String get payments => _ar ? 'المدفوعات' : 'Payments';
  static String get savedCards => _ar ? 'البطاقات المحفوظة' : 'Saved cards';
  static String get addresses => _ar ? 'العناوين' : 'Addresses';
  static String get rolesAndPermissions =>
      _ar ? 'الأدوار والصلاحيات' : 'Roles and permissions';
  static String get auditLog => _ar ? 'سجل التدقيق' : 'Audit log';
  static String get branches => _ar ? 'الفروع' : 'Branches';
  static String get deliveryZones => _ar ? 'مناطق التوصيل' : 'Delivery zones';
  static String get content => _ar ? 'المحتوى' : 'Content';
  static String get appSettings => _ar ? 'إعدادات التطبيق' : 'App settings';
  static String get coupons => _ar ? 'الكوبونات' : 'Coupons';
  static String get banners => _ar ? 'البانرات' : 'Banners';
  static String get loyalty => _ar ? 'الولاء والنقاط' : 'Loyalty and points';
  static String get subscriptions => _ar ? 'الاشتراكات' : 'Subscriptions';
  static String get reviews => _ar ? 'التقييمات' : 'Reviews';
  static String get notifications => _ar ? 'الإشعارات' : 'Notifications';
  static String get favorites => _ar ? 'المفضلة' : 'Favorites';
  static String get customerWebsites =>
      _ar ? 'مواقع العملاء' : 'Customer websites';
  static String get aiKnowledge =>
      _ar ? 'معرفة المساعد الذكي' : 'Assistant knowledge';

  static String get searchBundlesHint =>
      _ar ? 'ابحث في الباقات...' : 'Search bundles...';
  static String get searchPricingHint =>
      _ar ? 'ابحث في التسعير...' : 'Search pricing...';
  static String get searchCartsHint =>
      _ar ? 'ابحث في السلال...' : 'Search carts...';
  static String get searchStockMovementsHint =>
      _ar ? 'ابحث في حركة المخزون...' : 'Search stock movements...';
  static String get searchPaymentsHint =>
      _ar ? 'ابحث في المدفوعات...' : 'Search payments...';
  static String get searchSavedCardsHint =>
      _ar ? 'ابحث في البطاقات المحفوظة...' : 'Search saved cards...';
  static String get searchAddressesHint =>
      _ar ? 'ابحث في العناوين...' : 'Search addresses...';
  static String get searchRolesHint =>
      _ar ? 'ابحث في الأدوار...' : 'Search roles...';
  static String get searchAuditLogHint =>
      _ar ? 'ابحث في سجل التدقيق...' : 'Search the audit log...';
  static String get searchBranchesHint =>
      _ar ? 'ابحث في الفروع...' : 'Search branches...';
  static String get searchDeliveryZonesHint =>
      _ar ? 'ابحث في مناطق التوصيل...' : 'Search delivery zones...';
  static String get searchContentHint =>
      _ar ? 'ابحث في المحتوى...' : 'Search content...';
  static String get searchAppSettingsHint =>
      _ar ? 'ابحث في الإعدادات...' : 'Search settings...';
  static String get searchCouponsHint =>
      _ar ? 'ابحث في الكوبونات...' : 'Search coupons...';
  static String get searchBannersHint =>
      _ar ? 'ابحث في البانرات...' : 'Search banners...';
  static String get searchLoyaltyHint =>
      _ar ? 'ابحث في الولاء...' : 'Search loyalty...';
  static String get searchSubscriptionsHint =>
      _ar ? 'ابحث في الاشتراكات...' : 'Search subscriptions...';
  static String get searchReviewsHint =>
      _ar ? 'ابحث في التقييمات...' : 'Search reviews...';
  static String get searchNotificationsHint =>
      _ar ? 'ابحث في الإشعارات...' : 'Search notifications...';
  static String get searchFavoritesHint =>
      _ar ? 'ابحث في المفضلة...' : 'Search favorites...';
  static String get searchWebsitesHint =>
      _ar ? 'ابحث في مواقع العملاء...' : 'Search websites...';
  static String get searchAiKnowledgeHint =>
      _ar ? 'ابحث في معرفة المساعد...' : 'Search assistant knowledge...';
  static String get newBadge => _ar ? 'جديد' : 'New';
  static String get changeImage => _ar ? 'تغيير الصورة' : 'Change image';
  static String get addImageOrVideo =>
      _ar ? 'إضافة صورة أو فيديو' : 'Add image or video';
  static String get selectProductCategory =>
      _ar ? 'اختر تصنيف المنتج' : 'Choose a product category';
  static String get selectLocalCategory =>
      _ar ? 'اختر تصنيف محلي' : 'Choose a local category';
  static String get localCategory => _ar ? 'تصنيف محلي' : 'Local category';
  static String get languageCode => 'AR';
  static String get currency => _ar ? 'ر.س' : 'SAR';
  static String get productData => _ar ? 'بيانات المنتج' : 'Product data';
  static String get categoryData => _ar ? 'بيانات التصنيف' : 'Category data';
  static String get optionsAndQuantity =>
      _ar ? 'الخيارات والكمية' : 'Options and quantity';
  static String get addCategoryShort => _ar ? 'اضف تصنيف' : 'Add category';

  // ---------- Brand panel ----------
  static String get brandTitle => _ar
      ? 'نظام إدارة متكامل للمقاهي والمطاعم'
      : 'A complete management system for cafs and restaurants';
  static String get brandDescription => _ar
      ? 'تابع الطلبات والمخزون والعملاء والموظفين والتقارير من لوحة تحكم واحدة بتصميم احترافي وسريع الاستجابة.'
      : 'Track orders, inventory, customers, staff and reports from a single professional dashboard that adapts to every screen.';
}
