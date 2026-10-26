import 'package:admin_app/core/locale/app_locale.dart';

/// Every user-visible admin string in one place.
///
/// Each getter reads the current [AppLocale] at build time, so toggling the
/// language rebuilds the whole tree and every label flips together.
class S {
  S._();

  static bool get _ar => AppLocale.instance.isArabic;

  static String get appName => _ar ? 'غيم وسحب' : 'Ghem & Sohob';
  static String get admin => _ar ? 'الإدارة' : 'Admin';

  // ---------- Sidebar ----------
  static String get signOut => _ar ? 'تسجيل الخروج' : 'Sign out';
  static String get owner => _ar ? 'المالك' : 'Owner';
  static String get staff => _ar ? 'موظف' : 'Staff';

  // ---------- Destinations ----------
  static String get dashboard => _ar ? 'لوحة التحكم' : 'Dashboard';
  static String get orders => _ar ? 'الطلبات' : 'Orders';
  static String get ordersDescription => _ar
      ? 'تابعي جميع طلبات متجرك من مكان واحد.'
      : 'Review orders, update their status, and track paid revenue.';
  static String get orderDetails => _ar ? 'تفاصيل الطلب' : 'Order details';
  static String get back => _ar ? 'رجوع' : 'Back';
  static String get allOrders => _ar ? 'إجمالي الطلبات' : 'Total orders';
  static String get orderRevenue => _ar ? 'إجمالي المبيعات' : 'Total sales';
  static String get orderShipped => _ar ? 'تم الشحن' : 'Shipped';
  static String get orderWaitingPreparation =>
      _ar ? 'بانتظار التجهيز' : 'Awaiting preparation';
  static String get orderNewOrders => _ar ? 'طلبات جديدة' : 'new orders';
  static String get orderTrendNew => _ar ? 'جديد' : 'New';
  static String get ordersAll => _ar ? 'الكل' : 'All';
  static String get ordersPreparing => _ar ? 'قيد التجهيز' : 'Processing';
  static String get ordersFilter => _ar ? 'تصفية' : 'Filter';
  static String get ordersStatus => _ar ? 'الحالة' : 'Status';
  static String get ordersBranch => _ar ? 'الفرع' : 'Branch';
  static String get ordersRetry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get ordersAdd => _ar ? 'إضافة' : 'Add';
  static String get ordersBranchLocationUnavailable =>
      _ar ? 'موقع الفرع غير متاح' : 'Branch location is unavailable';
  static String get ordersSearch => _ar ? 'بحث' : 'Search';
  static String get ordersCancel => _ar ? 'إلغاء' : 'Cancel';
  static String get ordersExportExcel => _ar ? 'تصدير' : 'Export';
  static String get ordersExporting => _ar ? 'جارٍ التصدير' : 'Exporting';
  static String get ordersExportSuccess =>
      _ar ? 'تم تصدير الطلبات بنجاح' : 'Orders exported successfully';
  static String get ordersUnknownCustomer =>
      _ar ? 'عميل غير معروف' : 'Unknown customer';
  static String get ordersCustomerHistory =>
      _ar ? 'طلبات العميل السابقة' : 'Customer order history';
  static String get ordersNoPreviousOrders =>
      _ar ? 'لا توجد طلبات سابقة' : 'No previous orders';
  static String get ordersItems => _ar ? 'المنتج' : 'Product';
  static String get ordersAddProduct => _ar ? 'إضافة منتج' : 'Add product';
  static String get ordersNoProductsFound =>
      _ar ? 'لا توجد منتجات مطابقة' : 'No matching products';
  static String get ordersToday => _ar ? 'اليوم' : 'Today';
  static String get ordersYesterday => _ar ? 'أمس' : 'Yesterday';
  static String ordersRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count طلبًا'
      : 'Showing $from–$to of $count orders';
  static String get unknownOrderStatus =>
      _ar ? 'حالة غير معروفة' : 'Unknown status';
  static String get unknownPaymentStatus =>
      _ar ? 'حالة دفع غير معروفة' : 'Unknown payment status';
  static String get unknownFulfillment =>
      _ar ? 'نوع طلب غير معروف' : 'Unknown order type';
  static String get ordersLoadFailed => _ar
      ? 'تعذر تحميل الطلبات. حاول مرة أخرى.'
      : 'Orders could not be loaded. Please try again.';
  static String get orderActionFailed => _ar
      ? 'تعذر تحديث الطلب. حاول مرة أخرى.'
      : 'The order could not be updated. Please try again.';
  static String get orderExportFailed => _ar
      ? 'تعذر تصدير الطلبات. حاول مرة أخرى.'
      : 'Orders could not be exported. Please try again.';
  static String get orderItemsLabel => _ar ? 'العناصر' : 'Items';
  static String get customerIdLabel => _ar ? 'رقم العميل' : 'Customer ID';
  static String get customerPhoneLabel => _ar ? 'الهاتف' : 'Phone';
  static String get customerEmailLabel => _ar ? 'البريد الإلكتروني' : 'Email';
  static String get customerAddressLabel => _ar ? 'العنوان' : 'Address';
  static String get customerContactUnavailable =>
      _ar ? 'لا تتوفر بيانات الاتصال.' : 'No contact details are available.';
  static String get customerHistoryLoadFailed => _ar
      ? 'تعذر تحميل سجل طلبات العميل.'
      : 'Customer order history could not be loaded.';
  static String get olderOrder => _ar ? 'طلب أقدم' : 'Older order';
  static String get newerOrder => _ar ? 'طلب أحدث' : 'Newer order';
  static String get orderNotFound =>
      _ar ? 'لم يعد هذا الطلب متاحًا.' : 'This order is no longer available.';
  static String get previousPage => _ar ? 'الصفحة السابقة' : 'Previous page';
  static String get nextPage => _ar ? 'الصفحة التالية' : 'Next page';
  static String get viewOrder =>
      _ar ? 'عرض تفاصيل الطلب' : 'View order details';
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
  static String get emailHint => 'name@company.com';
  static String get passwordHint => '••••••••';
  static String get showPassword => _ar ? 'إظهار كلمة المرور' : 'Show password';
  static String get hidePassword => _ar ? 'إخفاء كلمة المرور' : 'Hide password';
  static String get signIn => _ar ? 'تسجيل الدخول' : 'Sign in';
  static String get emailRequired =>
      _ar ? 'البريد الإلكتروني مطلوب.' : 'Email is required.';
  static String get validEmail =>
      _ar ? 'أدخل بريدًا إلكترونيًا صحيحًا.' : 'Enter a valid email.';
  static String get passwordRequired =>
      _ar ? 'كلمة المرور مطلوبة.' : 'Password is required.';
  static String get signInFailed => _ar
      ? 'فشل تسجيل الدخول. حاول مرة أخرى.'
      : 'Sign in failed. Please try again.';
  static String get invalidCredentials =>
      _ar ? 'بيانات الدخول غير صحيحة.' : 'Invalid email or password.';
  static String get notActiveStaff => _ar
      ? 'هذا الحساب ليس موظفًا نشطًا.'
      : 'This account is not an active staff member.';
  static String get supabaseNotConfigured => _ar
      ? 'إعدادات Supabase غير مكتملة. تحقق من إعدادات التطبيق.'
      : 'Supabase is not configured. Check the admin app configuration.';
  static String get unableToSignIn => _ar
      ? 'تعذر تسجيل الدخول. حاول مرة أخرى.'
      : 'Unable to sign in. Please try again.';
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
  static String get noCategoriesYet =>
      _ar ? 'لا توجد تصنيفات بعد.' : 'No categories yet.';
  static String get noProductsFound =>
      _ar ? 'لا توجد منتجات مطابقة' : 'No products found';

  // Messages
  static String get saved => _ar ? 'تم الحفظ' : 'Saved';
  static String get saving => _ar ? 'جارٍ الحفظ' : 'Saving';
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
  static String get customersDescription => _ar
      ? 'تعرّفي على عملائك وابني معهم علاقات أقوى.'
      : 'Know your customers and build stronger relationships.';
  static String get customersSearchHint =>
      _ar ? 'ابحث بالاسم أو البريد الإلكتروني' : 'Search by name or email';
  static String get customersExport => _ar ? 'تصدير' : 'Export';
  static String get customersExporting => _ar ? 'جارٍ التصدير' : 'Exporting';
  static String get customersExportSuccess =>
      _ar ? 'تم تصدير العملاء بنجاح' : 'Customers exported successfully';
  static String get customersExportFailed => _ar
      ? 'تعذر تصدير العملاء. حاول مرة أخرى.'
      : 'Customers could not be exported. Please try again.';
  static String get customersFilter => _ar ? 'تصفية' : 'Filter';
  static String get customersFilterAll => _ar ? 'كل العملاء' : 'All customers';
  static String get customersFilterVip => _ar ? 'عملاء VIP' : 'VIP customers';
  static String get customersFilterBlacklisted =>
      _ar ? 'قائمة الحظر' : 'Blacklisted';
  static String get customersFilterBuyers =>
      _ar ? 'لديهم طلبات' : 'With orders';
  static String get customersFilterNoOrders =>
      _ar ? 'بدون طلبات' : 'Without orders';
  static String get customersClearFilter =>
      _ar ? 'مسح عوامل التصفية' : 'Clear filters';
  static String get customersAverageSpend =>
      _ar ? 'متوسط إنفاق العميل' : 'Average customer spend';
  static String get customersRepeatRate =>
      _ar ? 'معدل تكرار الشراء' : 'Repeat purchase rate';
  static String get customersNewThisMonth =>
      _ar ? 'عملاء جدد هذا الشهر' : 'New customers this month';
  static String get customersTotal =>
      _ar ? 'إجمالي العملاء' : 'Total customers';
  static String get customersJoinDate => _ar ? 'تاريخ الانضمام' : 'Join date';
  static String get customersNoLastOrder => _ar ? 'لا يوجد' : 'None';
  static String get customersNoMatches =>
      _ar ? 'لا توجد نتائج مطابقة.' : 'No matching customers.';
  static String get customersSelectAll => _ar ? 'تحديد الكل' : 'Select all';
  static String customersRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count عميلًا'
      : 'Showing $from–$to of $count customers';
  static String customerOrdersValue(int count) {
    if (count == 1) return _ar ? 'طلب واحد' : '1 order';
    return _ar ? '$count طلبات' : '$count orders';
  }

  static String get today => _ar ? 'اليوم' : 'Today';
  static String get tomorrow => _ar ? 'غدًا' : 'Tomorrow';
  static String get yesterday => _ar ? 'أمس' : 'Yesterday';
  static String get yes => _ar ? 'نعم' : 'Yes';
  static String get no => _ar ? 'لا' : 'No';
  static String get customerDetails =>
      _ar ? 'تفاصيل العميل' : 'Customer details';
  static String get customerManagement =>
      _ar ? 'إدارة العميل' : 'Customer management';
  static String get customerDefaultAddress => _ar ? 'افتراضي' : 'Default';
  static String get customerSaveFailed => _ar
      ? 'تعذر حفظ بيانات العميل. حاول مرة أخرى.'
      : 'Customer details could not be saved. Please try again.';
  static String get subscriptionStarts => _ar ? 'تبدأ' : 'Starts';
  static String get subscriptionEnds => _ar ? 'تنتهي' : 'Ends';
  static String get subscriptionCups => _ar ? 'الأكواب' : 'Cups';
  static String get noCustomersFound =>
      _ar ? 'لا يوجد عملاء بعد' : 'No customers yet';
  static String get customerName => _ar ? 'اسم العميل' : 'Customer name';
  static String get emailAddress => _ar ? 'البريد الإلكتروني' : 'Email';
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
  static String get noOrdersFound =>
      _ar ? 'لا توجد طلبات بعد' : 'No orders yet';
  static String get orderNumber => _ar ? 'رقم الطلب' : 'Order number';
  static String get customer => _ar ? 'العميل' : 'Customer';
  static String get total => _ar ? 'الإجمالي' : 'Total';
  static String get fulfillmentType => _ar ? 'نوع الطلب' : 'Order type';
  static String get date => _ar ? 'التاريخ' : 'Date';
  static String get statusPending => _ar ? 'قيد الانتظار' : 'Pending';
  static String get statusConfirmed => _ar ? 'مؤكد' : 'Confirmed';
  static String get statusPreparing => _ar ? 'قيد التحضير' : 'Preparing';
  static String get statusReady => _ar ? 'جاهز' : 'Ready';
  static String get statusOutForDelivery =>
      _ar ? 'في الطريق للتوصيل' : 'Out for delivery';
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
  static String get staffDescription => _ar
      ? 'تابعي فريق العمل وأدوارهم وصلاحياتهم من مكان واحد.'
      : 'Manage your team, their roles and permissions in one place.';
  static String get noStaffFound =>
      _ar ? 'لا يوجد موظفون بعد.' : 'No staff members yet.';
  static String get staffNoMatches => _ar
      ? 'لا يوجد موظفون مطابقون لهذا البحث.'
      : 'No staff members match this search.';
  static String get staffEmptyFilter =>
      _ar ? 'لا يوجد موظفون بهذه الحالة.' : 'No staff members in this status.';
  static String get staffFilterAll => _ar ? 'كل الموظفين' : 'All staff';
  static String get staffFilterActive => _ar ? 'النشطون' : 'Active';
  static String get staffFilterInvited => _ar ? 'دعوات معلّقة' : 'Invited';
  static String get staffFilterSuspended => _ar ? 'الموقوفون' : 'Suspended';
  static String get staffStatusInvited => _ar ? 'دعوة معلّقة' : 'Invited';
  static String get staffStatusSuspended => _ar ? 'موقوف' : 'Suspended';
  static String get staffMetricTotal => _ar ? 'إجمالي الفريق' : 'Team members';
  static String get staffMetricActive => _ar ? 'أعضاء نشطون' : 'Active members';
  static String get staffMetricInvited =>
      _ar ? 'دعوات معلّقة' : 'Pending invites';
  static String get staffMetricSuspended =>
      _ar ? 'أعضاء موقوفون' : 'Suspended members';
  static String get staffMemberColumn => _ar ? 'الموظف' : 'Staff member';
  static String get staffJoined => _ar ? 'تاريخ الانضمام' : 'Joined';
  static String get staffNoRoles => _ar ? 'بدون دور' : 'No roles';
  static String get staffFilter => _ar ? 'تصفية الموظفين' : 'Filter staff';
  static String get staffManagePermissions =>
      _ar ? 'إدارة الصلاحيات' : 'Manage permissions';
  static String get staffViewPermissions =>
      _ar ? 'عرض الصلاحيات' : 'View permissions';
  static String staffRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count موظفًا'
      : 'Showing $from–$to of $count staff members';
  static String staffPermissionsCount(int count) => count == 1
      ? _ar
            ? 'صلاحية واحدة'
            : '1 permission'
      : _ar
      ? '$count صلاحيات'
      : '$count permissions';
  static String get staffName => _ar ? 'اسم الموظف' : 'Staff name';
  static String get roleColumn => _ar ? 'الدور' : 'Role';
  static String get roleManager => _ar ? 'مدير' : 'Manager';
  static String get roleBranchManager => _ar ? 'مدير فرع' : 'Branch manager';
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
  static String get cartsDescription => _ar
      ? 'تابعي سلال العملاء النشطة والمتروكة من مكان واحد.'
      : 'Review active and abandoned customer carts in one place.';
  static String get stockMovements => _ar ? 'حركة المخزون' : 'Stock movements';
  static String get payments => _ar ? 'المدفوعات' : 'Payments';
  static String get paymentsDescription => _ar
      ? 'تابعي كل عمليات الدفع وحالاتها من مكان واحد.'
      : 'Review every payment transaction and its status in one place.';
  static String get paymentsExport => _ar ? 'تصدير' : 'Export';
  static String get paymentsPrint => _ar ? 'طباعة' : 'Print';
  static String get paymentPrintOne =>
      _ar ? 'طباعة هذه العملية' : 'Print this payment';
  static String get paymentsExportSuccess =>
      _ar ? 'تم تصدير المدفوعات بنجاح' : 'Payments exported successfully';
  static String get paymentsExportFailed => _ar
      ? 'تعذر تصدير المدفوعات. حاول مرة أخرى.'
      : 'Payments could not be exported. Please try again.';
  static String get paymentsPrintFailed => _ar
      ? 'تعذر فتح نافذة الطباعة. حاول مرة أخرى.'
      : 'The print dialog could not be opened. Please try again.';
  static String get paymentsPrintTitle =>
      _ar ? 'كشف المدفوعات' : 'Payments statement';
  static String get paymentsPrintGeneratedAt =>
      _ar ? 'تاريخ الطباعة' : 'Printed at';
  static String get paymentsPrintCollected =>
      _ar ? 'إجمالي المبالغ المحصّلة' : 'Collected total';
  static String paymentsPrintCount(int count) =>
      _ar ? 'عدد العمليات: $count' : 'Transactions: $count';
  static String get paymentReceiptTitle =>
      _ar ? 'إيصال دفع' : 'Payment receipt';
  static String get paymentReceiptDetails =>
      _ar ? 'تفاصيل العملية' : 'Transaction details';
  static String get paymentTransactionNumber =>
      _ar ? 'رقم العملية' : 'Transaction number';
  static String get paymentCardHolder => _ar ? 'حامل البطاقة' : 'Card holder';
  static String get createdAt => _ar ? 'تاريخ الإنشاء' : 'Created at';

  // ---------- Subscriptions ----------
  static String get subscriptionsDescription => _ar
      ? 'تابعي اشتراكات العملاء والباقات والتجديدات وسجل الاستخدام من مكان واحد.'
      : 'Track customer subscriptions, plans, renewals and usage in one place.';
  static String get subscriptionsActiveMetric =>
      _ar ? 'اشتراكات نشطة' : 'Active subscriptions';
  static String get subscriptionsExpiringSoonMetric =>
      _ar ? 'تنتهي خلال 7 أيام' : 'Expiring in 7 days';
  static String get subscriptionsPendingMetric =>
      _ar ? 'بانتظار الدفع' : 'Pending payment';
  static String get subscriptionsActiveCustomersMetric =>
      _ar ? 'عملاء نشطون' : 'Active customers';
  static String get subscriptionsFilter =>
      _ar ? 'تصفية الاشتراكات' : 'Filter subscriptions';
  static String get subscriptionsFilterAll =>
      _ar ? 'كل الاشتراكات' : 'All subscriptions';
  static String get subscriptionsFilterActive => _ar ? 'النشطة' : 'Active';
  static String get subscriptionsFilterExpiringSoon =>
      _ar ? 'تنتهي قريبًا' : 'Expiring soon';
  static String get subscriptionsFilterPending =>
      _ar ? 'بانتظار الدفع' : 'Pending payment';
  static String get subscriptionsFilterExpired => _ar ? 'المنتهية' : 'Expired';
  static String get subscriptionsFilterCancelled =>
      _ar ? 'الملغاة' : 'Cancelled';
  static String get subscriptionsNoMatches => _ar
      ? 'لا توجد اشتراكات مطابقة لهذا البحث أو التصفية.'
      : 'No subscriptions match this search or filter.';
  static String subscriptionsRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count اشتراكًا'
      : 'Showing $from–$to of $count subscriptions';
  static String get subscriptionsColumnCustomer => _ar ? 'العميل' : 'Customer';
  static String get subscriptionsColumnPlan => _ar ? 'الخطة' : 'Plan';
  static String get subscriptionsColumnCups => _ar ? 'الأكواب' : 'Cups';
  static String get subscriptionsColumnPeriod => _ar ? 'الفترة' : 'Period';
  static String get subscriptionsColumnLastUsed =>
      _ar ? 'آخر استخدام' : 'Last used';
  static String get subscriptionsColumnAutoRenew =>
      _ar ? 'التجديد' : 'Auto renew';
  static String get subscriptionsAutoRenew =>
      _ar ? 'التجديد التلقائي' : 'Auto renew';
  static String get subscriptionsPlanFallback =>
      _ar ? 'اشتراك' : 'Subscription';
  static String get subscriptionsViewAction =>
      _ar ? 'عرض التفاصيل' : 'View details';
  static String get subscriptionsDetailsTitle =>
      _ar ? 'تفاصيل الاشتراك' : 'Subscription details';
  static String get subscriptionsPlanSection => _ar ? 'الخطة' : 'Plan';
  static String get subscriptionsPlanCode => _ar ? 'كود الخطة' : 'Plan code';
  static String get subscriptionsPlanPrice => _ar ? 'سعر الخطة' : 'Plan price';
  static String get subscriptionsPlanDurationLabel =>
      _ar ? 'مدة الخطة' : 'Plan duration';
  static String subscriptionsPlanDuration(int days) => _ar
      ? (days == 1 ? 'يوم واحد' : '$days يومًا')
      : (days == 1 ? '1 day' : '$days days');
  static String get subscriptionsPeriodSection =>
      _ar ? 'الفترة والدفع' : 'Period and payment';
  static String get subscriptionsPaymentReference =>
      _ar ? 'مرجع الدفع' : 'Payment reference';
  static String get subscriptionsBonusBalance =>
      _ar ? 'رصيد المكافآت' : 'Bonus balance';
  static String get subscriptionsBonusUntil =>
      _ar ? 'تنتهي المكافآت' : 'Bonus expiry';
  static String get subscriptionsCupsEntitled => _ar ? 'المشمولة' : 'Entitled';
  static String get subscriptionsCupsUsed => _ar ? 'المستخدمة' : 'Used';
  static String get subscriptionsCupsCarried =>
      _ar ? 'المرحّلة' : 'Carried over';
  static String get subscriptionsCupsReserved => _ar ? 'المحجوزة' : 'Reserved';
  static String get subscriptionsCupsRemaining =>
      _ar ? 'المتبقية' : 'Remaining';
  static String get subscriptionsNotStartedYet =>
      _ar ? 'لم يبدأ بعد' : 'Not started yet';
  static String get subscriptionsDaysRemainingLabel =>
      _ar ? 'الأيام المتبقية' : 'Days remaining';
  static String get subscriptionsUsageRedemptions =>
      _ar ? 'مرات الاستخدام' : 'Redemptions';
  static String subscriptionsDaysRemaining(int days) => _ar
      ? (days == 1 ? 'يوم واحد متبقٍ' : '$days يومًا متبقيًا')
      : (days == 1 ? '1 day left' : '$days days left');
  static String subscriptionsUsageCountLabel(int count) => _ar
      ? (count == 1
            ? 'سجل الاستخدام (عملية واحدة)'
            : 'سجل الاستخدام ($count عمليات)')
      : (count == 1
            ? 'Usage history (1 redemption)'
            : 'Usage history ($count redemptions)');
  static String subscriptionsUsageLimited(int shown, int total) => _ar
      ? 'يتم عرض أحدث $shown من إجمالي $total عملية استخدام.'
      : 'Showing the latest $shown of $total redemptions.';
  static String get subscriptionsNoUsage => _ar
      ? 'لم يُستخدم هذا الاشتراك بعد.'
      : 'This subscription has not been used yet.';
  static String get subscriptionsUsageLoadFailed => _ar
      ? 'تعذر تحميل سجل استخدام الاشتراك.'
      : 'The subscription usage history could not be loaded.';
  static String get subscriptionsUsageMethodQr => _ar ? 'رمز QR' : 'QR code';
  static String get subscriptionsUsageMethodAppOrder =>
      _ar ? 'طلب عبر التطبيق' : 'App order';
  static String get subscriptionsUsageMethodManual =>
      _ar ? 'تسجيل يدوي' : 'Manual entry';
  static String subscriptionsCupsRedeemed(int quantity) => _ar
      ? (quantity == 1 ? 'كوب واحد' : '$quantity أكواب')
      : (quantity == 1 ? '1 cup' : '$quantity cups');
  static String get subscriptionStatusExpiringSoon =>
      _ar ? 'تنتهي قريبًا' : 'Expiring soon';
  static String get subscriptionStatusPendingPayment =>
      _ar ? 'بانتظار الدفع' : 'Pending payment';
  static String get subscriptionStatusExpired => _ar ? 'منتهي' : 'Expired';
  static String get subscriptionsCancelAction =>
      _ar ? 'إلغاء الاشتراك' : 'Cancel subscription';
  static String get subscriptionsCancelTitle =>
      _ar ? 'إلغاء الاشتراك؟' : 'Cancel this subscription?';
  static String get subscriptionsCancelMessage => _ar
      ? 'سيتوقف الاشتراك فورًا ولن يستطيع العميل استخدام الأكواب المتبقية. لا يمكن التراجع عن هذا الإجراء.'
      : 'The subscription stops immediately and the customer can no longer use the remaining cups. This cannot be undone.';
  static String get subscriptionsCancelPendingMessage => _ar
      ? 'سيتم إغلاق طلب الاشتراك المعلق. لم تُصدر أي أكواب لهذا الاشتراك بعد.'
      : 'The pending subscription request will be closed. No cups have been issued for it yet.';
  static String get subscriptionsCancelConfirm =>
      _ar ? 'نعم، إلغاء الاشتراك' : 'Yes, cancel subscription';
  static String get subscriptionsCancelKeep =>
      _ar ? 'الاحتفاظ بالاشتراك' : 'Keep subscription';
  static String get subscriptionsCancelledSuccess =>
      _ar ? 'تم إلغاء الاشتراك.' : 'The subscription was cancelled.';
  static String get subscriptionsCancelNotAllowed => _ar
      ? 'لا يمكن إلغاء هذا الاشتراك في حالته الحالية.'
      : 'This subscription cannot be cancelled in its current state.';
  static String get subscriptionsCancelReserved => _ar
      ? 'هناك أكواب محجوزة لطلبات قيد التنفيذ. أنهِ الطلبات أو ألغِها ثم حاول مرة أخرى.'
      : 'Cups are reserved for orders in progress. Finish or cancel those orders, then try again.';
  static String get subscriptionsCancelNotFound => _ar
      ? 'لم يعد هذا الاشتراك موجودًا.'
      : 'This subscription no longer exists.';
  static String get subscriptionsCancelFailed => _ar
      ? 'تعذر إلغاء الاشتراك. حاول مرة أخرى.'
      : 'The subscription could not be cancelled. Please try again.';
  static String get subscriptionsCancelBusy =>
      _ar ? 'جارٍ الإلغاء...' : 'Cancelling...';

  // ---------- Subscription plans ----------
  static String get subscriptionPlansDescription => _ar
      ? 'أنشئي باقات الاشتراك وعدّلي أسعارها ومزاياها ثم اعرضيها للعملاء.'
      : 'Create subscription plans, adjust their pricing and perks, then publish them to customers.';
  static String get subscriptionPlansTotalMetric =>
      _ar ? 'إجمالي الباقات' : 'Total plans';
  static String get subscriptionPlansOnSaleMetric =>
      _ar ? 'معروضة للبيع' : 'On sale';
  static String get subscriptionPlansActiveSubscribersMetric =>
      _ar ? 'مشتركون نشطون' : 'Active subscribers';
  static String get subscriptionPlansAutoRenewMetric =>
      _ar ? 'تدعم التجديد التلقائي' : 'Auto renew supported';
  static String get subscriptionPlansFilter =>
      _ar ? 'تصفية الباقات' : 'Filter plans';
  static String get subscriptionPlansFilterAll =>
      _ar ? 'كل الباقات' : 'All plans';
  static String get subscriptionPlansFilterOnSale =>
      _ar ? 'معروضة للبيع' : 'On sale';
  static String get subscriptionPlansFilterHidden =>
      _ar ? 'غير معروضة' : 'Not on sale';
  static String get subscriptionPlansFilterPaused => _ar ? 'موقوفة' : 'Paused';
  static String get subscriptionPlansNoMatches => _ar
      ? 'لا توجد باقات مطابقة لهذا البحث أو التصفية.'
      : 'No plans match this search or filter.';
  static String get noSubscriptionPlans => _ar
      ? 'لا توجد باقات اشتراك بعد. أضيفي أول باقة ليتمكن العملاء من الاشتراك.'
      : 'There are no subscription plans yet. Add the first plan so customers can subscribe.';
  static String subscriptionPlansRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count باقة'
      : 'Showing $from–$to of $count plans';
  static String get subscriptionPlansColumnPlan => _ar ? 'الباقة' : 'Plan';
  static String get subscriptionPlansColumnPrice => _ar ? 'السعر' : 'Price';
  static String get subscriptionPlansColumnDuration =>
      _ar ? 'المدة' : 'Duration';
  static String get subscriptionPlansColumnCups => _ar ? 'الأكواب' : 'Cups';
  static String get subscriptionPlansColumnProducts =>
      _ar ? 'المنتجات' : 'Products';
  static String get subscriptionPlansColumnBonus => _ar ? 'المكافأة' : 'Bonus';
  static String get subscriptionPlansColumnRenewal =>
      _ar ? 'التجديد' : 'Renewal';
  static String get subscriptionPlansColumnSubscribers =>
      _ar ? 'المشتركون' : 'Subscribers';
  static String get subscriptionPlanAddAction =>
      _ar ? 'إضافة باقة' : 'Add plan';
  static String get subscriptionPlanAddTitle =>
      _ar ? 'إضافة باقة اشتراك' : 'Add subscription plan';
  static String get subscriptionPlanEditTitle =>
      _ar ? 'تعديل باقة الاشتراك' : 'Edit subscription plan';
  static String get subscriptionPlanEditAction =>
      _ar ? 'تعديل الباقة' : 'Edit plan';
  static String get subscriptionPlanSaveAction =>
      _ar ? 'حفظ الباقة' : 'Save plan';
  static String get subscriptionPlanSaving =>
      _ar ? 'جارٍ الحفظ...' : 'Saving...';
  static String get subscriptionPlanSaved =>
      _ar ? 'تم حفظ الباقة.' : 'The plan was saved.';
  static String get subscriptionPlanSaveFailed => _ar
      ? 'تعذر حفظ الباقة. حاول مرة أخرى.'
      : 'The plan could not be saved. Please try again.';
  static String get subscriptionPlanDuplicateCode => _ar
      ? 'هذا الكود مستخدم في باقة أخرى. اختاري كودًا مختلفًا.'
      : 'This code is already used by another plan. Choose a different code.';
  static String get subscriptionPlanInvalidData => _ar
      ? 'تعذر حفظ البيانات. راجعي الحقول وحاولي مرة أخرى.'
      : 'The data could not be saved. Review the fields and try again.';
  static String get subscriptionPlanNotFound =>
      _ar ? 'لم تعد هذه الباقة موجودة.' : 'This plan no longer exists.';
  static String get subscriptionPlanActivate =>
      _ar ? 'تفعيل الباقة' : 'Activate plan';
  static String get subscriptionPlanPause =>
      _ar ? 'إيقاف الباقة' : 'Pause plan';
  static String get subscriptionPlanActivated =>
      _ar ? 'تم تفعيل الباقة.' : 'The plan was activated.';
  static String get subscriptionPlanPaused =>
      _ar ? 'تم إيقاف الباقة.' : 'The plan was paused.';
  static String get subscriptionPlanToggleFailed => _ar
      ? 'تعذر تحديث حالة الباقة. حاول مرة أخرى.'
      : 'The plan status could not be updated. Please try again.';
  static String get subscriptionPlanStatusOnSale => _ar ? 'معروضة' : 'On sale';
  static String get subscriptionPlanStatusHidden =>
      _ar ? 'غير معروضة' : 'Not on sale';
  static String get subscriptionPlanStatusPaused => _ar ? 'موقوفة' : 'Paused';
  static String get subscriptionPlanIdentitySection =>
      _ar ? 'بيانات الباقة' : 'Plan details';
  static String get subscriptionPlanNameAr =>
      _ar ? 'الاسم بالعربية' : 'Arabic name';
  static String get subscriptionPlanNameEn =>
      _ar ? 'الاسم بالإنجليزية' : 'English name';
  static String get subscriptionPlanCodeLabel => _ar ? 'الكود' : 'Code';
  static String get subscriptionPlanCodeHint =>
      _ar ? 'مثال: GOLD' : 'e.g. GOLD';
  static String get subscriptionPlanDescriptionAr =>
      _ar ? 'الوصف بالعربية' : 'Arabic description';
  static String get subscriptionPlanDescriptionEn =>
      _ar ? 'الوصف بالإنجليزية' : 'English description';
  static String get subscriptionPlanPricingSection =>
      _ar ? 'السعر والمدة' : 'Price and duration';
  static String get subscriptionPlanPriceLabel => _ar ? 'السعر' : 'Price';
  static String get subscriptionPlanCurrencyLabel =>
      _ar ? 'العملة' : 'Currency';
  static String get subscriptionPlanDurationDays =>
      _ar ? 'المدة بالأيام' : 'Duration in days';
  static String get subscriptionPlanCupsLabel =>
      _ar ? 'الأكواب في الدورة' : 'Cups per cycle';
  static String get subscriptionPlanRolloverLabel =>
      _ar ? 'حد ترحيل الأكواب' : 'Rollover cap';
  static String get subscriptionPlanBenefitsSection =>
      _ar ? 'المزايا والتجديد' : 'Perks and renewal';
  static String get subscriptionPlanBonusType =>
      _ar ? 'نوع المكافأة' : 'Bonus type';
  static String get subscriptionPlanBonusNone => _ar ? 'بدون' : 'None';
  static String get subscriptionPlanBonusPercent => _ar ? 'نسبة' : 'Percent';
  static String get subscriptionPlanBonusFixed =>
      _ar ? 'مبلغ ثابت' : 'Fixed amount';
  static String get subscriptionPlanBonusPoints => _ar ? 'نقاط' : 'Points';
  static String get subscriptionPlanBonusValue =>
      _ar ? 'قيمة المكافأة' : 'Bonus value';
  static String get subscriptionPlanBonusExpires =>
      _ar ? 'تنتهي المكافأة مع الدورة' : 'Bonus expires with the cycle';
  static String get subscriptionPlanRenewalPolicy =>
      _ar ? 'طريقة التجديد' : 'Renewal policy';
  static String get subscriptionPlanRenewalManual => _ar ? 'يدوي' : 'Manual';
  static String get subscriptionPlanRenewalAuto => _ar ? 'تلقائي' : 'Automatic';
  static String get subscriptionPlanAutoRenewSupported =>
      _ar ? 'تدعم التجديد التلقائي' : 'Supports auto renew';
  static String get subscriptionPlanVisibilitySection =>
      _ar ? 'العرض للعملاء' : 'Customer visibility';
  static String get subscriptionPlanActiveLabel =>
      _ar ? 'الباقة مفعّلة' : 'Plan is active';
  static String get subscriptionPlanForSaleLabel =>
      _ar ? 'معروضة للبيع للعملاء' : 'Available for sale';
  static String get subscriptionPlanActiveHint => _ar
      ? 'عند الإيقاف تختفي الباقة من التطبيق ولا تُقبل اشتراكات جديدة.'
      : 'A paused plan disappears from the app and accepts no new subscriptions.';
  static String get subscriptionPlanForSaleHint => _ar
      ? 'عند إخفائها تبقى الاشتراكات الحالية كما هي.'
      : 'Hiding the plan keeps existing subscriptions untouched.';
  static String get subscriptionPlanRequired =>
      _ar ? 'هذا الحقل مطلوب.' : 'This field is required.';
  static String get subscriptionPlanInvalidCode => _ar
      ? 'استخدمي حروفًا إنجليزية أو أرقامًا أو - أو _ فقط (حرفان على الأقل).'
      : 'Use English letters, digits, - or _ only (at least two characters).';
  static String get subscriptionPlanInvalidNumber =>
      _ar ? 'أدخلي رقمًا صحيحًا.' : 'Enter a valid number.';
  static String get subscriptionPlanInvalidCurrency => _ar
      ? 'استخدمي رمز عملة من ٣ حروف مثل SAR.'
      : 'Use a 3-letter currency code such as SAR.';
  static String get subscriptionPlanInvalidPrice =>
      _ar ? 'أدخلي سعرًا صحيحًا.' : 'Enter a valid price.';
  static String get subscriptionPlanInvalidDays => _ar
      ? 'يجب أن تكون المدة يومًا واحدًا على الأقل.'
      : 'The duration must be at least one day.';
  static String subscriptionPlanSubscribersValue(String total, String active) =>
      _ar
      ? '$total مشترك · $active نشط'
      : '$total subscribers · $active active';
  static String subscriptionPlanActiveCount(String active) =>
      _ar ? '$active نشط' : '$active active';
  static String subscriptionPlanRolloverValue(String cups) =>
      _ar ? 'ترحيل حتى $cups أكواب' : 'Roll over up to $cups cups';
  static String get subscriptionPlanPointsUnit => _ar ? 'نقطة' : 'points';
  static String get subscriptionPlanAllBranches =>
      _ar ? 'كل الفروع' : 'All branches';
  static String get subscriptionPlanSelectedBranches =>
      _ar ? 'فروع محددة' : 'Selected branches';
  static String get subscriptionPlanAllProducts =>
      _ar ? 'كل المنتجات' : 'All products';
  static String get subscriptionPlanSelectedProducts =>
      _ar ? 'منتجات محددة' : 'Selected products';
  static String get subscriptionPlanProductsSection =>
      _ar ? 'منتجات الباقة' : 'Plan products';
  static String get subscriptionPlanProductsHint => _ar
      ? 'حدّدي المنتجات التي يمكن استبدال أكواب الباقة بها، أو اتركيها لكل منتجات القائمة.'
      : 'Choose which products plan cups can be redeemed against, or keep every menu product.';
  static String get subscriptionPlanProductsAllHint => _ar
      ? 'تُستخدم أكواب الباقة مع أي منتج متاح في القائمة.'
      : 'Plan cups can be used with any available menu product.';
  static String get subscriptionPlanProductsSelectedHint => _ar
      ? 'تُستخدم أكواب الباقة فقط مع المنتجات المحددة أدناه.'
      : 'Plan cups can only be used with the products selected below.';
  static String subscriptionPlanProductsSelectedCount(int count) =>
      _ar ? 'محدد: $count' : 'Selected: $count';
  static String get subscriptionPlanProductsChoose =>
      _ar ? 'اختيار المنتجات' : 'Choose products';
  static String get subscriptionPlanProductsChange =>
      _ar ? 'تعديل الاختيار' : 'Change selection';
  static String get subscriptionPlanProductsNoneSelected =>
      _ar ? 'لم يتم اختيار منتجات بعد.' : 'No products selected yet.';
  static String get subscriptionPlanProductsRequired => _ar
      ? 'اختاري منتجًا واحدًا على الأقل، أو اجعلي الباقة تشمل كل المنتجات.'
      : 'Choose at least one product, or include all products.';
  static String get subscriptionPlanProductsLoading =>
      _ar ? 'جارٍ تحميل المنتجات...' : 'Loading products...';
  static String get subscriptionPlanProductsLoadFailed =>
      _ar ? 'تعذر تحميل المنتجات.' : 'Products could not be loaded.';
  static String get subscriptionPlanProductsEmptyCatalog => _ar
      ? 'لا توجد منتجات في الكتالوج بعد.'
      : 'There are no products in the catalog yet.';
  static String get subscriptionPlanProductsSaveMissing => _ar
      ? 'أضيفي منتجًا واحدًا على الأقل للباقة.'
      : 'Add at least one product to the plan.';
  static String get subscriptionPlanProductsSaveInvalid => _ar
      ? 'تعذر حفظ المنتجات المحددة. حدّثي القائمة وحاولي مرة أخرى.'
      : 'The selected products could not be saved. Refresh and try again.';
  static String get subscriptionPlanProductPickerTitle =>
      _ar ? 'اختيار منتجات الباقة' : 'Select plan products';
  static String subscriptionPlanProductPickerSelected(int count) =>
      _ar ? 'تم اختيار $count' : '$count selected';
  static String get subscriptionPlanProductPickerApply =>
      _ar ? 'تأكيد الاختيار' : 'Apply selection';
  static String get subscriptionPlanProductInactive =>
      _ar ? 'غير نشط' : 'Inactive';
  static String get subscriptionPlanProductRemove =>
      _ar ? 'إزالة من الباقة' : 'Remove from plan';

  // ---------- Loyalty ----------
  static String get loyaltyDescription => _ar
      ? 'حوّلي منتجات المتجر إلى مكافآت بنقاط، وتابعي أرصدة العملاء وحركات النقاط من مكان واحد.'
      : 'Turn catalog products into point rewards, and follow every member balance and points movement in one place.';
  static String get loyaltyAddReward => _ar ? 'إضافة مكافأة' : 'Add reward';
  static String get loyaltyMetricMembers =>
      _ar ? 'أعضاء البرنامج' : 'Loyalty members';
  static String get loyaltyMetricPointsOutstanding =>
      _ar ? 'نقاط لدى العملاء' : 'Customer points';
  static String get loyaltyMetricRedemptions =>
      _ar ? 'عمليات الاستبدال' : 'Redemptions';
  static String get loyaltyMetricActiveRewards =>
      _ar ? 'مكافآت نشطة' : 'Active rewards';
  static String get loyaltyProgramTitle =>
      _ar ? 'برنامج كسب النقاط' : 'Points earning program';
  static String get loyaltyProgramNoRule => _ar
      ? 'لا توجد قواعد ولاء معرّفة بعد.'
      : 'No loyalty rules are defined yet.';
  static String get loyaltyProgramEarnRateLabel =>
      _ar ? 'معدل الكسب' : 'Earning rate';
  static String get loyaltyProgramPointValueLabel =>
      _ar ? 'قيمة النقطة' : 'Point value';
  static String get loyaltyProgramValidityLabel =>
      _ar ? 'الصلاحية' : 'Validity';
  static String get loyaltyProgramOngoing => _ar ? 'ساري' : 'Ongoing';
  static String get loyaltyProgramScheduled => _ar ? 'مجدول' : 'Scheduled';
  static String get loyaltyProgramExpired => _ar ? 'منتهي' : 'Expired';
  static String loyaltyProgramEarnRate(String points, String amount) => _ar
      ? '$points نقطة لكل $amount ${S.currency}'
      : '$points points per $amount ${S.currency}';
  static String loyaltyProgramPointValue(String amount) =>
      _ar ? '$amount ${S.currency} للنقطة' : '$amount ${S.currency} per point';
  static String loyaltyProgramEndsOn(String date) =>
      _ar ? 'ينتهي في $date' : 'Ends $date';
  static String get loyaltyProgramEdit =>
      _ar ? 'تعديل البرنامج' : 'Edit program';
  static String get loyaltyProgramSetup =>
      _ar ? 'إعداد البرنامج' : 'Set up program';
  static String get loyaltyProgramEditTooltip =>
      _ar ? 'تعديل برنامج النقاط' : 'Edit points program';
  static String get loyaltyProgramDialogTitle =>
      _ar ? 'برنامج كسب النقاط' : 'Points earning program';
  static String get loyaltyProgramDialogIntro => _ar
      ? 'حدّدي عدد النقاط التي يكسبها العميل مقابل كل ١ ${S.currency} من قيمة الطلب، وقيمة النقطة عند الاستبدال.'
      : 'Set how many points a customer earns for every 1 ${S.currency} spent, and what a point is worth when redeemed.';
  static String get loyaltyProgramRateField =>
      _ar ? 'نقاط لكل ١ ${S.currency}' : 'Points per 1 ${S.currency}';
  static String get loyaltyProgramRateHint => _ar ? 'مثال: ١' : 'For example 1';
  static String get loyaltyProgramRateHelp => _ar
      ? 'عدد النقاط التي تُضاف للعميل مقابل كل وحدة من قيمة الطلب.'
      : 'The points added for every unit of the order total.';
  static String get loyaltyProgramValueField =>
      _ar ? 'قيمة النقطة (${S.currency})' : 'Point value (${S.currency})';
  static String get loyaltyProgramValueHint =>
      _ar ? 'مثال: ٠٫٠٥' : 'For example 0.05';
  static String get loyaltyProgramValueHelp => _ar
      ? 'القيمة التي تمثلها النقطة الواحدة عند الاستبدال.'
      : 'What a single point is worth when it is redeemed.';
  static String get loyaltyProgramPreviewTitle =>
      _ar ? 'معاينة مباشرة' : 'Live preview';
  static String loyaltyProgramPreviewEarn(String amount, String points) => _ar
      ? 'طلب بقيمة $amount يكسب $points نقطة'
      : 'An order of $amount earns $points points';
  static String loyaltyProgramPreviewWorth(String points, String amount) =>
      _ar ? '$points نقطة تعادل $amount' : '$points points are worth $amount';
  static String get loyaltyProgramPreviewPending => _ar
      ? 'أدخلي معدل الكسب وقيمة النقطة لعرض المعاينة.'
      : 'Enter an earning rate and point value to see the preview.';
  static String get loyaltyProgramActiveTitle =>
      _ar ? 'البرنامج مفعّل' : 'Program is active';
  static String get loyaltyProgramActiveHelp => _ar
      ? 'عند الإيقاف يتوقف كسب النقاط من الطلبات الجديدة مع بقاء أرصدة العملاء.'
      : 'Turning the program off stops new orders from earning points while keeping every balance.';
  static String get loyaltyProgramSaveAction =>
      _ar ? 'حفظ البرنامج' : 'Save program';
  static String get loyaltyProgramSaving => _ar ? 'جارٍ الحفظ...' : 'Saving...';
  static String get loyaltyProgramSaved =>
      _ar ? 'تم تحديث برنامج النقاط.' : 'The points program was updated.';
  static String get loyaltyProgramInvalidRate => _ar
      ? 'أدخلي عدد نقاط أكبر من صفر (بحد أقصى ١٠٠٠).'
      : 'Enter a points rate greater than zero (maximum 1000).';
  static String get loyaltyProgramInvalidValue => _ar
      ? 'أدخلي قيمة نقطة صحيحة (صفر أو أكثر، بحد أقصى ١٠٠٠).'
      : 'Enter a valid point value (zero or more, maximum 1000).';
  static String get loyaltyProgramNotFound => _ar
      ? 'لم يعد برنامج النقاط موجودًا. حدّثي الصفحة وحاولي مرة أخرى.'
      : 'The points program no longer exists. Refresh and try again.';
  static String get loyaltyProgramSaveFailed => _ar
      ? 'تعذر حفظ برنامج النقاط. حاولي مرة أخرى.'
      : 'The points program could not be saved. Please try again.';
  static String get loyaltyTabRewards => _ar ? 'المكافآت' : 'Rewards';
  static String get loyaltyTabMembers => _ar ? 'الأعضاء' : 'Members';
  static String get loyaltyTabActivity =>
      _ar ? 'سجل الحركات' : 'Points activity';
  static String get loyaltyRewardsSearchHint => _ar
      ? 'ابحث باسم المنتج أو الباقة أو الاشتراك...'
      : 'Search by product, bundle or plan...';
  static String get loyaltyMembersSearchHint => _ar
      ? 'ابحث بالاسم أو البريد أو الهاتف...'
      : 'Search by name, email or phone...';
  static String get loyaltyActivitySearchHint =>
      _ar ? 'ابحث في حركات النقاط...' : 'Search points movements...';
  static String get loyaltyRewardFilter =>
      _ar ? 'تصفية المكافآت' : 'Filter rewards';
  static String get loyaltyRewardFilterAll =>
      _ar ? 'كل المكافآت' : 'All rewards';
  static String get loyaltyRewardFilterActive => _ar ? 'نشطة' : 'Active';
  static String get loyaltyRewardFilterPaused => _ar ? 'متوقفة' : 'Paused';
  static String get loyaltyRewardFilterOutOfStock =>
      _ar ? 'نفدت الكمية' : 'Out of stock';
  static String get loyaltyMemberFilter =>
      _ar ? 'تصفية الأعضاء' : 'Filter members';
  static String get loyaltyMemberFilterAll =>
      _ar ? 'كل الأعضاء' : 'All members';
  static String get loyaltyMemberFilterWithPoints =>
      _ar ? 'لديهم نقاط' : 'With points';
  static String get loyaltyMemberFilterNoPoints =>
      _ar ? 'بدون نقاط' : 'No points';
  static String get loyaltyActivityFilter =>
      _ar ? 'تصفية الحركات' : 'Filter activity';
  static String get loyaltyActivityFilterAll =>
      _ar ? 'كل الحركات' : 'All activity';
  static String get loyaltyActivityReasonEarn =>
      _ar ? 'نقاط من طلب' : 'Earned on order';
  static String get loyaltyActivityReasonRedeem =>
      _ar ? 'استبدال مكافأة' : 'Reward redemption';
  static String get loyaltyActivityReasonAdjustment =>
      _ar ? 'تعديل يدوي' : 'Manual adjustment';
  static String get loyaltyActivityReasonExpire =>
      _ar ? 'نقاط منتهية' : 'Points expired';
  static String get loyaltyActivityReasonRefund => _ar ? 'استرداد' : 'Refund';
  static String get loyaltyActivityReasonOther =>
      _ar ? 'حركة نقاط' : 'Points movement';
  static String get loyaltyNoRewards => _ar
      ? 'لا توجد مكافآت بعد. أضيفي أول منتج أو باقة أو اشتراك ليصبح قابلًا للاستبدال بالنقاط.'
      : 'No rewards yet. Add the first product, bundle or plan customers can redeem with points.';
  static String get loyaltyNoRewardsMatches => _ar
      ? 'لا توجد مكافآت مطابقة لهذا البحث أو التصفية.'
      : 'No rewards match this search or filter.';
  static String get loyaltyNoMembers =>
      _ar ? 'لا يوجد أعضاء في برنامج الولاء بعد.' : 'No loyalty members yet.';
  static String get loyaltyNoMembersMatches => _ar
      ? 'لا يوجد أعضاء مطابقون لهذا البحث أو التصفية.'
      : 'No members match this search or filter.';
  static String get loyaltyNoActivity =>
      _ar ? 'لا توجد حركات نقاط بعد.' : 'No points activity yet.';
  static String get loyaltyNoActivityMatches => _ar
      ? 'لا توجد حركات مطابقة لهذا البحث أو التصفية.'
      : 'No activity matches this search or filter.';
  static String loyaltyRowsRewards(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count مكافأة'
      : 'Showing $from–$to of $count rewards';
  static String loyaltyRowsMembers(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count عضوًا'
      : 'Showing $from–$to of $count members';
  static String loyaltyRowsActivity(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count حركة'
      : 'Showing $from–$to of $count movements';
  static String loyaltyPoints(int points) => _ar
      ? (points == 1 ? 'نقطة واحدة' : '$points نقطة')
      : (points == 1 ? '1 point' : '$points points');
  static String loyaltyPointsEarned(int points) =>
      _ar ? '+$points نقطة' : '+$points points';
  static String loyaltyPointsSpent(int points) =>
      _ar ? '−$points نقطة' : '−$points points';
  static String get loyaltyPointUnit => _ar ? 'نقطة' : 'pts';
  static String get loyaltyRewardCouponTag => _ar ? 'مكافأة' : 'Reward';
  static String get loyaltyRewardCouponCost =>
      _ar ? 'تكلفة الاستبدال' : 'Redemption cost';
  static String get loyaltyRewardStockUnlimited =>
      _ar ? 'كمية غير محدودة' : 'Unlimited quantity';
  static String loyaltyRewardStockRemaining(int count) => _ar
      ? (count == 1 ? 'متاحة مرة واحدة' : 'متبقي $count')
      : (count == 1 ? '1 redemption left' : '$count redemptions left');
  static String get loyaltyRewardOutOfStock =>
      _ar ? 'نفدت الكمية' : 'Out of stock';
  static String loyaltyRewardRedemptions(int count) => _ar
      ? (count == 1 ? 'استُبدلت مرة واحدة' : 'استُبدلت $count مرات')
      : (count == 1 ? 'Redeemed once' : 'Redeemed $count times');
  static String get loyaltyRewardNeverRedeemed =>
      _ar ? 'لم تُستبدل بعد' : 'Never redeemed';
  static String get loyaltyRewardPaused => _ar ? 'متوقفة' : 'Paused';
  static String get loyaltyRewardActiveLabel => _ar ? 'نشطة' : 'Active';
  static String get loyaltyRewardUnavailable =>
      _ar ? 'الهدف غير متاح' : 'Target unavailable';
  static String get loyaltyRewardMenuTooltip =>
      _ar ? 'خيارات المكافأة' : 'Reward options';
  static String get loyaltyRewardEdit => _ar ? 'تعديل المكافأة' : 'Edit reward';
  static String get loyaltyRewardPause =>
      _ar ? 'إيقاف المكافأة' : 'Pause reward';
  static String get loyaltyRewardActivate =>
      _ar ? 'تفعيل المكافأة' : 'Activate reward';
  static String get loyaltyRewardDelete =>
      _ar ? 'حذف المكافأة' : 'Delete reward';
  static String get loyaltyRewardBasePriceLabel =>
      _ar ? 'سعر الهدف' : 'Target price';
  static String get loyaltyRewardStockLabel => _ar ? 'المخزون' : 'Stock';
  static String get loyaltyRewardDialogAddTitle =>
      _ar ? 'مكافأة جديدة' : 'New reward';
  static String get loyaltyRewardDialogEditTitle =>
      _ar ? 'تعديل المكافأة' : 'Edit reward';
  static String get loyaltyRewardTargetSection =>
      _ar ? 'نوع المكافأة والهدف' : 'Reward type and target';
  static String get loyaltyRewardTypeProduct => _ar ? 'منتج' : 'Product';
  static String get loyaltyRewardTypeBundle => _ar ? 'باقة' : 'Bundle';
  static String get loyaltyRewardTypePlan => _ar ? 'اشتراك' : 'Subscription';
  static String get loyaltyRewardProductHint => _ar
      ? 'يستبدل العميل هذا المنتج من تطبيق العميل مقابل النقاط المحددة.'
      : 'Customers redeem this product from the client app for the points you set.';
  static String get loyaltyRewardBundleHint => _ar
      ? 'يستبدل العميل الباقة كاملة وتُضاف منتجاتها إلى سلة الفرع مقابل النقاط المحددة.'
      : 'Customers redeem the whole bundle and its products are added to the branch cart for the points you set.';
  static String get loyaltyRewardPlanHint => _ar
      ? 'تُفعّل للعميل دورة اشتراك جديدة في هذا الاشتراك مقابل النقاط المحددة.'
      : 'Customers start a new cycle of this subscription plan for the points you set.';
  static String get loyaltyRewardTargetChoose =>
      _ar ? 'اختيار الهدف' : 'Choose target';
  static String get loyaltyRewardTargetChange =>
      _ar ? 'تغيير الهدف' : 'Change target';
  static String get loyaltyRewardTargetMissing =>
      _ar ? 'اختاري هدفًا للمكافأة.' : 'Choose a target for this reward.';
  static String get loyaltyRewardTargetPickerTitle =>
      _ar ? 'اختيار هدف المكافأة' : 'Choose reward target';
  static String get loyaltyRewardTargetSearchHint =>
      _ar ? 'ابحث بالاسم أو الكود...' : 'Search by name or code...';
  static String loyaltyRewardTargetAlreadyRewardPoints(int points) =>
      _ar ? 'مكافأة موجودة بـ $points نقطة' : 'Reward exists at $points points';
  static String get loyaltyRewardProductArchived =>
      _ar ? 'منتج مؤرشف' : 'Archived product';
  static String get loyaltyRewardPointsSection =>
      _ar ? 'النقاط والمخزون' : 'Points and stock';
  static String get loyaltyRewardPointsLabel =>
      _ar ? 'تكلفة المكافأة بالنقاط' : 'Reward cost in points';
  static String get loyaltyRewardPointsHint =>
      _ar ? 'مثال: 100' : 'For example 100';
  static String get loyaltyRewardPointsHelp => _ar
      ? 'عدد النقاط التي تُخصم من العميل عند استبدال المنتج.'
      : 'The number of points deducted when a customer redeems the product.';
  static String get loyaltyRewardStockLabelOptional =>
      _ar ? 'الكمية المتاحة (اختياري)' : 'Available quantity (optional)';
  static String get loyaltyRewardStockHint => _ar
      ? 'اتركيه فارغًا لكمية غير محدودة'
      : 'Leave empty for unlimited quantity';
  static String get loyaltyRewardStockHelp => _ar
      ? 'حددي عدد مرات الاستبدال المتاحة، أو اتركيه فارغًا بلا حد.'
      : 'Limit how many times the reward can be redeemed, or leave it empty for no limit.';
  static String get loyaltyRewardActiveTitle =>
      _ar ? 'المكافأة متاحة للعملاء' : 'Reward is available to customers';
  static String get loyaltyRewardActiveHelp => _ar
      ? 'عند الإيقاف تبقى المكافأة محفوظة ولا تظهر للعملاء.'
      : 'Pausing keeps the reward saved but hides it from customers.';
  static String get loyaltyRewardSaveAction =>
      _ar ? 'حفظ المكافأة' : 'Save reward';
  static String get loyaltyRewardSaving => _ar ? 'جارٍ الحفظ...' : 'Saving...';
  static String get loyaltyRewardSaved =>
      _ar ? 'تم حفظ المكافأة.' : 'The reward was saved.';
  static String get loyaltyRewardDeleted =>
      _ar ? 'تم حذف المكافأة.' : 'The reward was deleted.';
  static String get loyaltyRewardActivated =>
      _ar ? 'تم تفعيل المكافأة.' : 'The reward was activated.';
  static String get loyaltyRewardPausedSuccess =>
      _ar ? 'تم إيقاف المكافأة.' : 'The reward was paused.';
  static String get loyaltyRewardInvalidPoints => _ar
      ? 'أدخلي عدد نقاط أكبر من صفر.'
      : 'Enter a points cost greater than zero.';
  static String get loyaltyRewardInvalidStock => _ar
      ? 'أدخلي كمية صحيحة (صفر أو أكثر) أو اتركيها فارغة.'
      : 'Enter a valid quantity (zero or more), or leave it empty.';
  static String get loyaltyRewardDuplicateTarget => _ar
      ? 'هذا الهدف مضاف إلى مكافأة أخرى بالفعل. عدّلي المكافأة الحالية بدلًا من إضافة أخرى.'
      : 'This target already belongs to another reward. Edit that reward instead of adding a duplicate.';
  static String get loyaltyRewardInvalidTarget => _ar
      ? 'الهدف المحدد غير متاح. اختاري هدفًا آخر.'
      : 'The selected target is unavailable. Choose another target.';
  static String get loyaltyRewardNotFound =>
      _ar ? 'لم تعد هذه المكافأة موجودة.' : 'This reward no longer exists.';
  static String get loyaltyRewardSaveFailed => _ar
      ? 'تعذر حفظ المكافأة. حاولي مرة أخرى.'
      : 'The reward could not be saved. Please try again.';
  static String get loyaltyRewardActionFailed => _ar
      ? 'تعذر تحديث المكافأة. حاولي مرة أخرى.'
      : 'The reward could not be updated. Please try again.';
  static String get loyaltyRewardDeleteTitle =>
      _ar ? 'حذف المكافأة؟' : 'Delete this reward?';
  static String loyaltyRewardDeleteMessage(String name) => _ar
      ? 'سيتم حذف "$name" من كتالوج المكافآت. لا يمكن التراجع عن هذا الإجراء.'
      : '"$name" will be removed from the rewards catalogue. This cannot be undone.';
  static String get loyaltyRewardDeleteConfirm =>
      _ar ? 'نعم، احذفي المكافأة' : 'Yes, delete reward';
  static String get loyaltyRewardDeleteKeep =>
      _ar ? 'الاحتفاظ بالمكافأة' : 'Keep reward';
  static String get loyaltyRewardDeleteHasRedemptions => _ar
      ? 'لا يمكن حذف مكافأة استُبدلت من قبل. أوقفيها بدلًا من ذلك للحفاظ على سجل العملاء.'
      : 'A reward that has been redeemed cannot be deleted. Pause it instead to keep the customer history.';
  static String get loyaltyRewardTargetUnavailableCannotActivate => _ar
      ? 'لا يمكن تفعيل مكافأة لهدف غير متاح.'
      : 'A reward for an unavailable target cannot be activated.';
  static String get loyaltyLoadFailed => _ar
      ? 'تعذر تحميل بيانات الولاء. حاولي مرة أخرى.'
      : 'Loyalty data could not be loaded. Please try again.';
  static String get loyaltyProductsLoadFailed => _ar
      ? 'تعذر تحميل قائمة الأهداف.'
      : 'The target list could not be loaded.';
  static String get loyaltyProductsEmpty => _ar
      ? 'لا توجد منتجات أو باقات أو اشتراكات متاحة لإضافتها كمكافأة.'
      : 'There are no products, bundles or plans available to add as a reward.';
  static String get loyaltyNoTargetsFound =>
      _ar ? 'لا توجد نتائج مطابقة.' : 'No matching targets.';
  static String get loyaltyReadOnly => _ar
      ? 'لديك صلاحية عرض فقط لبيانات الولاء.'
      : 'You have view-only access to loyalty.';
  static String loyaltyActivityShowingNewest(int shown, int total) => _ar
      ? 'يتم عرض أحدث $shown من إجمالي $total حركة.'
      : 'Showing the newest $shown of $total movements.';
  static String get loyaltyMemberColumn => _ar ? 'العضو' : 'Member';
  static String get loyaltyBalanceColumn => _ar ? 'الرصيد' : 'Balance';
  static String get loyaltyLifetimeColumn =>
      _ar ? 'إجمالي المكتسب' : 'Lifetime';
  static String get loyaltyTierColumn => _ar ? 'المستوى' : 'Tier';
  static String get loyaltyLastActivityColumn =>
      _ar ? 'آخر نشاط' : 'Last activity';
  static String get loyaltyRedemptionsColumn =>
      _ar ? 'الاستبدالات' : 'Redemptions';
  static String get loyaltyMovementColumn => _ar ? 'الحركة' : 'Movement';
  static String get loyaltyPointsColumn => _ar ? 'النقاط' : 'Points';
  static String get loyaltyReasonColumn => _ar ? 'السبب' : 'Reason';
  static String get loyaltyReferenceColumn => _ar ? 'المرجع' : 'Reference';
  static String get loyaltyBalanceAfterColumn =>
      _ar ? 'الرصيد بعد' : 'Balance after';
  static String get loyaltyDateColumn => _ar ? 'التاريخ' : 'Date';
  static String get loyaltyTierBronze => _ar ? 'برونزي' : 'Bronze';
  static String get loyaltyTierSilver => _ar ? 'فضي' : 'Silver';
  static String get loyaltyTierGold => _ar ? 'ذهبي' : 'Gold';
  static String get loyaltyTierPlatinum => _ar ? 'بلاتيني' : 'Platinum';
  static String loyaltyOrderReference(String number) =>
      _ar ? 'طلب #$number' : 'Order #$number';
  static String loyaltyRewardReference(String name) =>
      _ar ? 'مكافأة: $name' : 'Reward: $name';
  static String get loyaltyNoReference => '—';
  static String loyaltyCupsCount(int count) => _ar
      ? (count == 1 ? 'كوب واحد' : '$count أكواب')
      : (count == 1 ? '1 cup' : '$count cups');

  static String get couponsDescription => _ar
      ? 'أنشئ حملات خصم واضبط شروطها وتابع أداءها من مكان واحد.'
      : 'Build discount campaigns, control their rules and track performance in one place.';
  static String get couponsNew => _ar ? 'كوبون جديد' : 'New coupon';
  static String get couponsReadOnly => _ar
      ? 'لديك صلاحية العرض فقط، وإدارة الكوبونات تحتاج صلاحية الإعدادات.'
      : 'View-only access. Managing coupons requires the settings permission.';
  static String get couponsLoadFailed => _ar
      ? 'تعذر تحميل الكوبونات. حاول مرة أخرى.'
      : 'Coupons could not be loaded. Please try again.';
  static String get couponsMetricActive =>
      _ar ? 'كوبونات تعمل الآن' : 'Live coupons';
  static String get couponsMetricExpiring =>
      _ar ? 'تنتهي خلال 7 أيام' : 'Expiring in 7 days';
  static String get couponsMetricRedemptions =>
      _ar ? 'مرات الاستخدام' : 'Redemptions';
  static String get couponsMetricDiscountGiven =>
      _ar ? 'قيمة الخصومات' : 'Discounts given';
  static String get couponsMetricActiveHint =>
      _ar ? 'متاحة للعملاء الآن' : 'Available to customers now';
  static String get couponsMetricExpiringHint =>
      _ar ? 'تحتاج مراجعة قريبة' : 'Needs a quick review';
  static String get couponsMetricRedemptionsHint =>
      _ar ? 'إجمالي استخدامات الكوبونات' : 'Across all coupons';
  static String get couponsMetricDiscountGivenHint =>
      _ar ? 'ما وفّره العملاء' : 'Saved by customers';
  static String get couponsStatusActive => _ar ? 'نشط' : 'Active';
  static String get couponsStatusExpiringSoon =>
      _ar ? 'ينتهي قريبًا' : 'Expiring soon';
  static String get couponsStatusScheduled => _ar ? 'مجدول' : 'Scheduled';
  static String get couponsStatusExhausted =>
      _ar ? 'اكتمل استخدامه' : 'Exhausted';
  static String get couponsStatusExpired => _ar ? 'منتهي' : 'Expired';
  static String get couponsStatusPaused => _ar ? 'متوقف' : 'Paused';
  static String get couponsFilter => _ar ? 'تصفية الكوبونات' : 'Filter coupons';
  static String get couponsFilterAll => _ar ? 'كل الكوبونات' : 'All coupons';
  static String get couponsSearchHint => _ar
      ? 'ابحث بالكود أو الاسم أو التصنيف…'
      : 'Search by code, title or category…';
  static String couponsFilterOption(String label, int count) =>
      '$label ($count)';
  static String get couponsTableCoupon => _ar ? 'الكوبون' : 'Coupon';
  static String get couponsTableDiscount => _ar ? 'الخصم' : 'Discount';
  static String get couponsTableScope => _ar ? 'نطاق التطبيق' : 'Applies to';
  static String get couponsTableUsage => _ar ? 'الاستخدام' : 'Usage';
  static String get couponsTableGiven => _ar ? 'الخصم الممنوح' : 'Given';
  static String get couponsTableWindow => _ar ? 'الصلاحية' : 'Validity';
  static String get couponsTableStatus => _ar ? 'الحالة' : 'Status';
  static String get couponsEmpty =>
      _ar ? 'لا توجد كوبونات بعد' : 'No coupons yet';
  static String get couponsEmptyHint => _ar
      ? 'أنشئ أول كوبون لجذب العملاء وزيادة الطلبات.'
      : 'Create your first coupon to attract customers and increase orders.';
  static String get couponsNoMatches => _ar
      ? 'لا توجد كوبونات مطابقة للبحث أو التصفية.'
      : 'No coupons match your search or filter.';
  static String get couponsCopyCode => _ar ? 'نسخ الكود' : 'Copy code';
  static String get couponsCodeCopied =>
      _ar ? 'تم نسخ كود الكوبون.' : 'Coupon code copied.';
  static String get couponsMenuTooltip =>
      _ar ? 'خيارات الكوبون' : 'Coupon actions';
  static String get couponsEdit => _ar ? 'تعديل الكوبون' : 'Edit coupon';
  static String get couponsPause => _ar ? 'إيقاف مؤقت' : 'Pause';
  static String get couponsActivate => _ar ? 'تفعيل' : 'Activate';
  static String get couponsDelete => _ar ? 'حذف' : 'Delete';
  static String get couponsDeleteTitle =>
      _ar ? 'حذف الكوبون؟' : 'Delete coupon?';
  static String couponsDeleteMessage(String code) => _ar
      ? 'سيتم حذف الكوبون «$code» نهائيًا، ولا يمكن التراجع عن هذا الإجراء.'
      : 'The coupon “$code” will be permanently deleted. This cannot be undone.';
  static String get couponsDeleteConfirm =>
      _ar ? 'حذف نهائي' : 'Delete permanently';
  static String get couponsDeleteHasRedemptions => _ar
      ? 'لا يمكن حذف كوبون استُخدم من قبل. أوقفه مؤقتًا للحفاظ على سجل الاستخدام.'
      : 'A coupon that has been redeemed cannot be deleted. Pause it to keep its history.';
  static String get couponsDeleteFailed => _ar
      ? 'تعذر حذف الكوبون. حاول مرة أخرى.'
      : 'The coupon could not be deleted. Please try again.';
  static String get couponsToggleFailed => _ar
      ? 'تعذر تحديث حالة الكوبون. حاول مرة أخرى.'
      : 'The coupon status could not be updated. Please try again.';
  static String couponsPausedToast(String code) =>
      _ar ? 'تم إيقاف «$code» مؤقتًا.' : '“$code” is now paused.';
  static String couponsActivatedToast(String code) =>
      _ar ? 'تم تفعيل «$code».' : '“$code” is now active.';
  static String couponsDeletedToast(String code) =>
      _ar ? 'تم حذف «$code».' : '“$code” was deleted.';
  static String get couponsNotFound =>
      _ar ? 'هذا الكوبون لم يعد موجودًا.' : 'This coupon no longer exists.';
  static String get couponsUnlimited => _ar ? 'بلا حد' : 'Unlimited';
  static String couponsPercentOff(String value) =>
      _ar ? 'خصم $value%' : '$value% off';
  static String couponsAmountOff(String value) =>
      _ar ? 'خصم $value' : '$value off';
  static String couponsMaxDiscount(String value) =>
      _ar ? 'حتى $value' : 'Up to $value';
  static String couponsMinOrder(String value) =>
      _ar ? 'الحد الأدنى للطلب $value' : 'Min. order $value';
  static String get couponsScopeAll => _ar ? 'كل المنتجات' : 'All products';
  static String get couponsScopeAllHint =>
      _ar ? 'ينطبق على كل منتجات المتجر' : 'Applies to the whole menu';
  static String couponsScopeCategories(int count) => _ar
      ? (count == 1 ? 'تصنيف واحد' : '$count تصنيفات')
      : (count == 1 ? '1 category' : '$count categories');
  static String couponsScopeProducts(int count) => _ar
      ? (count == 1 ? 'منتج واحد' : '$count منتجات')
      : (count == 1 ? '1 product' : '$count products');
  static String couponsUsageUsed(int count) => _ar
      ? (count == 1 ? 'استخدام واحد' : '$count استخدامات')
      : (count == 1 ? '1 use' : '$count uses');
  static String couponsUsageOf(int used, int limit) =>
      _ar ? '$used من $limit' : '$used of $limit';
  static String couponsRemaining(int count) =>
      _ar ? 'متبقي $count' : '$count left';
  static String couponsPerCustomer(int count) => _ar
      ? (count == 1 ? 'مرة واحدة لكل عميل' : '$count مرات لكل عميل')
      : (count == 1 ? 'Once per customer' : '$count per customer');
  static String get couponsNeverRedeemed =>
      _ar ? 'لم يُستخدم بعد' : 'Never redeemed';
  static String couponsLastUsed(String date) =>
      _ar ? 'آخر استخدام $date' : 'Last used $date';
  static String couponsUsedCount(int count) => _ar
      ? (count == 1 ? 'استخدام واحد' : '$count استخدامات')
      : (count == 1 ? '1 use' : '$count uses');
  static String get couponsNoEndDate =>
      _ar ? 'بلا تاريخ انتهاء' : 'No end date';
  static String couponsEndsOn(String date) =>
      _ar ? 'ينتهي $date' : 'Ends $date';
  static String couponsStartsOn(String date) =>
      _ar ? 'يبدأ $date' : 'Starts $date';
  static String get couponsExpiresToday => _ar ? 'ينتهي اليوم' : 'Ends today';
  static String get couponsExpiresTomorrow =>
      _ar ? 'ينتهي غدًا' : 'Ends tomorrow';
  static String couponsExpiresInDays(int days) =>
      _ar ? 'ينتهي خلال $days يوم' : 'Ends in $days days';
  static String couponsExpiredOn(String date) =>
      _ar ? 'انتهى $date' : 'Ended $date';
  static String couponsScheduledFor(String date) =>
      _ar ? 'يبدأ $date' : 'Starts $date';
  static String couponsWindowRange(String start, String end) =>
      _ar ? 'من $start إلى $end' : '$start → $end';
  static String couponsRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count كوبونًا'
      : 'Showing $from–$to of $count coupons';
  static String get couponsEditorCreate =>
      _ar ? 'إنشاء كوبون جديد' : 'Create a new coupon';
  static String get couponsEditorEdit =>
      _ar ? 'تعديل بيانات الكوبون' : 'Edit coupon details';
  static String get couponsEditorIntro => _ar
      ? 'اضبط التفاصيل وشروط الاستخدام، وستظهر المعاينة كما يراها العميل.'
      : 'Set the details and conditions; the preview shows exactly what customers see.';
  static String get couponsSectionIdentity =>
      _ar ? 'بيانات الكوبون' : 'Coupon details';
  static String get couponsSectionDiscount =>
      _ar ? 'قيمة الخصم' : 'Discount value';
  static String get couponsSectionScope => _ar ? 'نطاق التطبيق' : 'Applies to';
  static String get couponsSectionLimits =>
      _ar ? 'حدود الاستخدام' : 'Usage limits';
  static String get couponsSectionSchedule =>
      _ar ? 'جدولة الكوبون' : 'Schedule';
  static String get couponsCodeLabel => _ar ? 'كود الكوبون' : 'Coupon code';
  static String get couponsCodeHint =>
      _ar ? 'مثال: RAMADAN25' : 'e.g. RAMADAN25';
  static String get couponsCodeHelp => _ar
      ? 'من 3 إلى 32 حرفًا: حروف إنجليزية وأرقام وشرطة أو شرطة سفلية.'
      : '3–32 characters: letters, numbers, hyphen or underscore.';
  static String get couponsCodeGenerate => _ar ? 'توليد كود' : 'Generate code';
  static String get couponsTitleAr => _ar ? 'الاسم بالعربية' : 'Arabic title';
  static String get couponsTitleEn =>
      _ar ? 'الاسم بالإنجليزية' : 'English title';
  static String get couponsDescriptionAr =>
      _ar ? 'الوصف بالعربية (اختياري)' : 'Arabic description (optional)';
  static String get couponsDescriptionEn =>
      _ar ? 'الوصف بالإنجليزية (اختياري)' : 'English description (optional)';
  static String get couponsDiscountTypePercentage =>
      _ar ? 'نسبة مئوية' : 'Percentage';
  static String get couponsDiscountTypeFixed =>
      _ar ? 'مبلغ ثابت' : 'Fixed amount';
  static String get couponsDiscountValue =>
      _ar ? 'قيمة الخصم' : 'Discount value';
  static String get couponsMaxDiscountLabel =>
      _ar ? 'أقصى خصم (اختياري)' : 'Maximum discount (optional)';
  static String get couponsMaxDiscountHelp => _ar
      ? 'يحدّ الخصم النسبي بقيمة معينة.'
      : 'Caps a percentage discount at a set amount.';
  static String get couponsMinOrderLabel =>
      _ar ? 'أقل قيمة للطلب' : 'Minimum order';
  static String get couponsMinOrderHelp => _ar
      ? 'اتركه صفرًا ليُطبق على أي طلب.'
      : 'Leave at zero to apply to any order.';
  static String get couponsUsageLimitLabel =>
      _ar ? 'حد الاستخدام الإجمالي' : 'Total usage limit';
  static String get couponsUsageLimitHelp => _ar
      ? 'اتركه فارغًا ليصبح عدد الاستخدامات غير محدود.'
      : 'Leave empty to allow unlimited uses.';
  static String get couponsPerCustomerLabel =>
      _ar ? 'الحد لكل عميل' : 'Limit per customer';
  static String get couponsPerCustomerHelp => _ar
      ? 'أقصى عدد مرات يستطيع العميل الواحد استخدام الكوبون.'
      : 'The maximum number of times one customer can redeem it.';
  static String get couponsStartsAt => _ar ? 'يبدأ في' : 'Starts at';
  static String get couponsEndsAt => _ar ? 'ينتهي في' : 'Ends at';
  static String get couponsPickDate => _ar ? 'اختيار التاريخ' : 'Pick a date';
  static String get couponsClearDate => _ar ? 'مسح التاريخ' : 'Clear date';
  static String get couponsDateUnset => _ar ? 'غير محدد' : 'Not set';
  static String get couponsScopeCategoryOption =>
      _ar ? 'تصنيفات محددة' : 'Specific categories';
  static String get couponsScopeProductOption =>
      _ar ? 'منتجات محددة' : 'Specific products';
  static String get couponsChooseCategories =>
      _ar ? 'اختيار التصنيفات' : 'Choose categories';
  static String get couponsChooseProducts =>
      _ar ? 'اختيار المنتجات' : 'Choose products';
  static String get couponsChangeSelection =>
      _ar ? 'تغيير الاختيار' : 'Change selection';
  static String couponsSelectedCount(int count) =>
      _ar ? 'تم اختيار $count' : '$count selected';
  static String get couponsNoSelection =>
      _ar ? 'لم يتم اختيار أي عنصر بعد' : 'Nothing selected yet';
  static String get couponsPreviewTitle =>
      _ar ? 'معاينة العميل' : 'Customer preview';
  static String get couponsPreviewHint => _ar
      ? 'هكذا يظهر الكوبون في تطبيق العملاء.'
      : 'This is how the coupon appears in the customer app.';
  static String get couponsPreviewNoTitle =>
      _ar ? 'اسم الكوبون' : 'Coupon title';
  static String get couponsPreviewNoCode => 'CODE';
  static String get couponsPreviewDiscountLabel => _ar ? 'خصم' : 'OFF';
  static String get couponsScopeAllShort => _ar ? 'كل المتجر' : 'Entire store';
  static String get couponsScopeCategoriesShort =>
      _ar ? 'تصنيفات' : 'Categories';
  static String get couponsScopeProductsShort => _ar ? 'منتجات' : 'Products';
  static String get couponsSave => _ar ? 'حفظ الكوبون' : 'Save coupon';
  static String get couponsSaving => _ar ? 'جارٍ الحفظ...' : 'Saving...';
  static String get couponsSaveFailed => _ar
      ? 'تعذر حفظ الكوبون. حاول مرة أخرى.'
      : 'The coupon could not be saved. Please try again.';
  static String get couponsCreated =>
      _ar ? 'تم إنشاء الكوبون بنجاح.' : 'Coupon created.';
  static String get couponsUpdated =>
      _ar ? 'تم تحديث الكوبون بنجاح.' : 'Coupon updated.';
  static String get couponsActiveTitle =>
      _ar ? 'تشغيل الكوبون فورًا' : 'Make the coupon live';
  static String get couponsActiveHelp => _ar
      ? 'يمكن إيقافه مؤقتًا في أي وقت دون فقدان سجله.'
      : 'You can pause it anytime without losing its history.';
  static String get couponsErrorCode => _ar
      ? 'أدخل كودًا صحيحًا من 3 إلى 32 حرفًا.'
      : 'Enter a valid code of 3–32 characters.';
  static String get couponsErrorTitleAr =>
      _ar ? 'الاسم بالعربية مطلوب.' : 'Arabic title is required.';
  static String get couponsErrorTitleEn =>
      _ar ? 'الاسم بالإنجليزية مطلوب.' : 'English title is required.';
  static String get couponsErrorDiscount =>
      _ar ? 'أدخل قيمة خصم صحيحة.' : 'Enter a valid discount value.';
  static String get couponsErrorPercentage =>
      _ar ? 'نسبة الخصم يجب ألا تتجاوز 100%.' : 'Percentage cannot exceed 100.';
  static String get couponsErrorMaxDiscount => _ar
      ? 'أقصى خصم يجب أن يكون أكبر من صفر.'
      : 'Maximum discount must be greater than zero.';
  static String get couponsErrorMinOrder =>
      _ar ? 'أقل قيمة للطلب غير صحيحة.' : 'Minimum order is invalid.';
  static String get couponsErrorLimit =>
      _ar ? 'حدود الاستخدام غير صحيحة.' : 'Usage limits are invalid.';
  static String get couponsErrorPerCustomer => _ar
      ? 'الحد لكل عميل لا يمكن أن يزيد على الحد الإجمالي.'
      : 'The per-customer limit cannot exceed the total limit.';
  static String get couponsErrorWindow => _ar
      ? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البداية.'
      : 'The end date must be after the start date.';
  static String get couponsErrorScope =>
      _ar ? 'اختر عنصرًا واحدًا على الأقل.' : 'Choose at least one item.';
  static String get couponsErrorDuplicate => _ar
      ? 'هذا الكود مستخدم بالفعل. اختر كودًا آخر.'
      : 'This code is already in use. Choose another.';
  static String get couponsErrorNotFound =>
      _ar ? 'هذا الكوبون لم يعد موجودًا.' : 'This coupon no longer exists.';
  static String get couponsErrorPayload =>
      _ar ? 'تعذر حفظ البيانات. راجع الحقول.' : 'The data could not be saved.';
  static String get couponsErrorNumber =>
      _ar ? 'أدخل رقمًا صحيحًا.' : 'Enter a valid number.';
  static String get couponsPickerCategoriesTitle =>
      _ar ? 'اختيار التصنيفات' : 'Choose categories';
  static String get couponsPickerProductsTitle =>
      _ar ? 'اختيار المنتجات' : 'Choose products';
  static String get couponsPickerSearchCategories =>
      _ar ? 'ابحث في التصنيفات...' : 'Search categories...';
  static String get couponsPickerSearchProducts =>
      _ar ? 'ابحث باسم المنتج أو SKU...' : 'Search by product or SKU...';
  static String get couponsPickerEmpty =>
      _ar ? 'لا توجد عناصر متاحة.' : 'No items available.';
  static String get couponsPickerNoMatches =>
      _ar ? 'لا توجد نتائج مطابقة.' : 'No matches.';
  static String get couponsPickerSelectAll => _ar ? 'تحديد الكل' : 'Select all';
  static String get couponsPickerClear => _ar ? 'إلغاء التحديد' : 'Clear';
  static String get couponsPickerApply =>
      _ar ? 'تأكيد الاختيار' : 'Apply selection';
  static String get couponsInactive => _ar ? 'غير نشط' : 'Inactive';
  static String get couponsArchived => _ar ? 'مؤرشف' : 'Archived';

  // ---------- Reviews ----------
  static String get reviewsDescription => _ar
      ? 'راجعي آراء العملاء وتقييماتهم، وتابعي رضا العملاء، وتحكمي في ظهور كل تقييم على المتجر.'
      : 'Read customer feedback, track satisfaction, and control what appears in the storefront.';
  static String get reviewsReadOnly => _ar
      ? 'يمكنك عرض التقييمات فقط. تحتاج صلاحية مراجعة التقييمات للنشر أو الإخفاء أو الحذف.'
      : 'You can view reviews only. Publishing, hiding, or deleting requires the reviews moderation permission.';
  static String get reviewsMetricAverage =>
      _ar ? 'متوسط التقييم' : 'Average rating';
  static String get reviewsMetricTotal =>
      _ar ? 'إجمالي التقييمات' : 'Total reviews';
  static String reviewsMetricTotalHint(int published, int hidden) => _ar
      ? 'منشورة $published • مخفية $hidden'
      : '$published published • $hidden hidden';
  static String get reviewsMetricLow => _ar ? 'تقييمات منخفضة' : 'Low ratings';
  static String get reviewsMetricLowHint =>
      _ar ? 'نجمتان أو أقل' : 'Two stars or fewer';
  static String get reviewsMetricHidden =>
      _ar ? 'تقييمات مخفية' : 'Hidden reviews';
  static String get reviewsMetricHiddenHint =>
      _ar ? 'لا تظهر في المتجر' : 'Not shown in the store';
  static String reviewsBasedOn(int count) =>
      _ar ? 'بناءً على $count تقييم' : 'Based on $count reviews';
  static String get reviewsPublished => _ar ? 'منشور' : 'Published';
  static String get reviewsHidden => _ar ? 'مخفي' : 'Hidden';
  static String reviewsSatisfactionChip(String percent) =>
      _ar ? 'رضا العملاء $percent' : '$percent satisfaction';
  static String reviewsVerifiedCount(int count) =>
      _ar ? '$count شراء موثّق' : '$count verified purchases';
  static String reviewsThisMonthCount(int count) =>
      _ar ? '$count هذا الشهر' : '$count this month';
  static String get reviewsDistribution =>
      _ar ? 'توزيع التقييمات' : 'Rating distribution';
  static String get reviewsDistributionHint => _ar
      ? 'اختاري عدد النجوم لتصفية القائمة'
      : 'Select a star row to filter the list';
  static String reviewsFilterByStars(int rating) =>
      _ar ? 'عرض تقييمات $rating نجوم' : 'Show $rating-star reviews';
  static String reviewsStarsCount(int rating) {
    if (_ar) return rating == 1 ? 'نجمة واحدة' : '$rating نجوم';
    return rating == 1 ? '1 star' : '$rating stars';
  }

  static String get reviewsFilter => _ar ? 'تصفية' : 'Filter';
  static String get reviewsFilterAll => _ar ? 'الكل' : 'All reviews';
  static String get reviewsFilterPublished => _ar ? 'منشورة' : 'Published';
  static String get reviewsFilterHidden => _ar ? 'مخفية' : 'Hidden';
  static String get reviewsFilterLow => _ar ? 'منخفضة' : 'Low ratings';
  static String get reviewsFilterVerified => _ar ? 'موثّقة' : 'Verified';
  static String reviewsFilterOption(String label, int count) =>
      '$label ($count)';
  static String get reviewsTableReview => _ar ? 'التقييم' : 'Review';
  static String get reviewsTableProduct => _ar ? 'المنتج' : 'Product';
  static String get reviewsTableCustomer => _ar ? 'العميل' : 'Customer';
  static String get reviewsTablePurchase => _ar ? 'الشراء' : 'Purchase';
  static String get reviewsTableDate => _ar ? 'التاريخ' : 'Date';
  static String get reviewsTableStatus => _ar ? 'الحالة' : 'Status';
  static String get reviewsEmpty =>
      _ar ? 'لا توجد تقييمات بعد' : 'No reviews yet';
  static String get reviewsEmptyHint => _ar
      ? 'ستظهر هنا تقييمات العملاء فور إضافتها من المتجر.'
      : 'Customer reviews will appear here as soon as they are submitted.';
  static String get reviewsNoMatches =>
      _ar ? 'لا توجد تقييمات مطابقة' : 'No matching reviews';
  static String get reviewsUntitled =>
      _ar ? 'تقييم بدون عنوان' : 'Untitled review';
  static String get reviewsAnonymous => _ar ? 'عميل' : 'Customer';
  static String get reviewsVerified => _ar ? 'شراء موثّق' : 'Verified purchase';
  static String get reviewsUnverified => _ar ? 'بدون شراء' : 'Unverified';
  static String reviewsOrderNumber(String number) =>
      _ar ? 'طلب $number' : 'Order $number';
  static String get reviewsNoOrder =>
      _ar ? 'غير مرتبط بطلب' : 'No order linked';
  static String reviewsSku(String sku) => _ar ? 'رمز المنتج $sku' : 'SKU $sku';
  static String get reviewsMenuTooltip =>
      _ar ? 'خيارات التقييم' : 'Review actions';
  static String get reviewsViewDetails => _ar ? 'عرض التفاصيل' : 'View details';
  static String get reviewsPublish => _ar ? 'نشر التقييم' : 'Publish review';
  static String get reviewsHide => _ar ? 'إخفاء التقييم' : 'Hide review';
  static String get reviewsDelete => _ar ? 'حذف التقييم' : 'Delete review';
  static String get reviewsDeleteTitle => _ar ? 'حذف التقييم' : 'Delete review';
  static String reviewsDeleteMessage(String name) => _ar
      ? 'سيتم حذف تقييم $name نهائيًا ولا يمكن التراجع. هل تريد المتابعة؟'
      : 'The review by $name will be permanently deleted. Continue?';
  static String get reviewsDeleteConfirm => _ar ? 'حذف نهائي' : 'Delete';
  static String get reviewsDeleteFailed => _ar
      ? 'تعذر حذف التقييم. حاولي مرة أخرى.'
      : 'The review could not be deleted. Please try again.';
  static String get reviewsToggleFailed => _ar
      ? 'تعذر تحديث حالة التقييم. حاولي مرة أخرى.'
      : 'The review status could not be updated. Please try again.';
  static String reviewsPublishedToast(String name) =>
      _ar ? 'تم نشر تقييم $name.' : 'The review by $name is now published.';
  static String reviewsHiddenToast(String name) =>
      _ar ? 'تم إخفاء تقييم $name.' : 'The review by $name is now hidden.';
  static String reviewsDeletedToast(String name) =>
      _ar ? 'تم حذف تقييم $name.' : 'The review by $name was deleted.';
  static String get reviewsNotFound =>
      _ar ? 'هذا التقييم لم يعد موجودًا.' : 'This review no longer exists.';
  static String get reviewsDetailsTitle =>
      _ar ? 'تفاصيل التقييم' : 'Review details';
  static String reviewsDetailsSubtitle(String product) =>
      _ar ? 'تقييم على $product' : 'Review for $product';
  static String get reviewsDetailsComment => _ar ? 'نص التقييم' : 'Review text';
  static String get reviewsDetailsNoComment => _ar
      ? 'لم يكتب العميل نصًا لهذا التقييم.'
      : 'The customer did not write any text for this review.';
  static String get reviewsDetailsProduct => _ar ? 'المنتج' : 'Product';
  static String get reviewsDetailsCustomer => _ar ? 'العميل' : 'Customer';
  static String get reviewsDetailsPurchase => _ar ? 'عملية الشراء' : 'Purchase';
  static String get reviewsDetailsCreated =>
      _ar ? 'تاريخ الإضافة' : 'Submitted';
  static String get reviewsDetailsUpdated => _ar ? 'آخر تحديث' : 'Last updated';
  static String get reviewsDetailsNoOrder => _ar
      ? 'لم يُربط هذا التقييم بطلب، لذا يظهر كتقييم غير موثّق.'
      : 'This review is not linked to an order, so it appears as unverified.';
  static String get reviewsClearRating =>
      _ar ? 'إزالة تصفية النجوم' : 'Clear the star filter';
  static String reviewsRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count تقييمًا'
      : 'Showing $from–$to of $count reviews';

  // Notifications -----------------------------------------------------------
  static String get notificationsDescription => _ar
      ? 'تابع كل إشعارات العملاء، وأنشئ حملات جديدة، وتأكد من وصول الإشعارات إلى الهواتف عبر Firebase.'
      : 'Follow every customer notification, compose new campaigns, and verify that pushes reach phones through Firebase.';
  static String get notificationsReadOnly => _ar
      ? 'لديك صلاحية العرض فقط. إنشاء الإشعارات أو حذفها أو تغيير حالة القراءة يتطلب صلاحيات الإدارة.'
      : 'You can view notifications only. Composing, deleting, or changing read state requires admin permissions.';
  static String get notificationsCompose =>
      _ar ? 'إشعار جديد' : 'New notification';

  static String get notificationsMetricTotal =>
      _ar ? 'إجمالي الإشعارات' : 'Total notifications';
  static String notificationsMetricTotalHint(int today) =>
      _ar ? '$today اليوم' : '$today today';
  static String get notificationsMetricUnread => _ar ? 'غير مقروءة' : 'Unread';
  static String notificationsMetricUnreadHint(String percent) =>
      _ar ? '$percent% من الإجمالي' : '$percent% of all';
  static String get notificationsMetricAdminSent =>
      _ar ? 'أرسلتها الإدارة' : 'Sent by admins';
  static String notificationsMetricAdminSentHint(int campaigns) => _ar
      ? '$campaigns حملة'
      : campaigns == 1
      ? '1 campaign'
      : '$campaigns campaigns';
  static String get notificationsMetricPushRate =>
      _ar ? 'نجاح الإرسال للهاتف' : 'Push delivery rate';
  static String notificationsMetricPushHint(int sent, int failed) => _ar
      ? '$sent ناجح • $failed فاشل خلال 30 يومًا'
      : '$sent delivered • $failed failed in 30 days';
  static String get notificationsMetricNoPush =>
      _ar ? 'لا توجد محاولات' : 'No attempts yet';

  static String get notificationsPushHealthTitle =>
      _ar ? 'حالة إرسال الإشعارات' : 'Push delivery health';
  static String get notificationsPushHealthSubtitle => _ar
      ? 'فحص سلسلة الإرسال من قاعدة البيانات إلى Firebase Cloud Messaging.'
      : 'Checks the delivery chain from the database to Firebase Cloud Messaging.';
  static String get notificationsPushHealthy =>
      _ar ? 'جاهز للإرسال' : 'Ready to send';
  static String get notificationsPushWarning =>
      _ar ? 'يحتاج مراجعة' : 'Needs attention';
  static String get notificationsPushError => _ar ? 'غير مكتمل' : 'Incomplete';
  static String get notificationsPushRecheck =>
      _ar ? 'فحص مرة أخرى' : 'Check again';
  static String get notificationsPushSetup =>
      _ar ? 'دليل الإعداد' : 'Setup guide';
  static String get notificationsPushCheckVault =>
      _ar ? 'خزنة الأسرار' : 'Secrets vault';
  static String get notificationsPushCheckSecret =>
      _ar ? 'مفتاح الويب هوك' : 'Webhook secret';
  static String get notificationsPushCheckPgNet =>
      _ar ? 'امتداد pg_net' : 'pg_net extension';
  static String get notificationsPushCheckTrigger =>
      _ar ? 'مشغّل الإرسال' : 'Dispatch trigger';
  static String get notificationsPushCheckUrl =>
      _ar ? 'رابط دالة الإرسال' : 'Function URL';
  static String get notificationsPushCheckOk => _ar ? 'متصل' : 'Ready';
  static String get notificationsPushCheckMissing =>
      _ar ? 'غير مهيأ' : 'Missing';
  static String notificationsPushReachable(int count) =>
      _ar ? '$count عميل قابل للوصول' : '$count reachable customers';
  static String notificationsPushOptIn(int count) =>
      _ar ? '$count مفعّل للإشعارات' : '$count opted in';
  static String notificationsPushDevices(int android, int ios) =>
      _ar ? '$android أندرويد • $ios آيفون' : '$android Android • $ios iOS';
  static String notificationsPushLastSuccess(String date) =>
      _ar ? 'آخر نجاح: $date' : 'Last success: $date';
  static String notificationsPushLastWebhook(String status) =>
      _ar ? 'آخر استجابة: $status' : 'Last response: $status';
  static String get notificationsPushNoAttempts =>
      _ar ? 'لم تُسجل محاولات إرسال بعد.' : 'No push attempts recorded yet.';
  static String get notificationsPushLastError =>
      _ar ? 'آخر خطأ مسجل' : 'Last recorded error';
  static String get notificationsPushNoReachable => _ar
      ? 'لا يوجد عميل لديه جهاز مسجل ومفعّل للإشعارات، لذلك لن يصل Push حتى يسجل العملاء أجهزتهم.'
      : 'No customer has a registered device with push enabled, so nothing will arrive until customers register their devices.';
  static String notificationsPushHttpError(int status) => _ar
      ? 'استجابة غير ناجحة من دالة الإرسال (HTTP $status).'
      : 'The send function returned an unsuccessful response (HTTP $status).';
  static String get notificationsPushSecretHint => _ar
      ? 'أضف مفتاح push_webhook_secret في Vault.'
      : 'Add push_webhook_secret to the Vault.';
  static String get notificationsPushFunctionHint => _ar
      ? 'انشر دالة send-push واضبط رابطها في إعدادات التطبيق.'
      : 'Deploy the send-push function and set its URL in app settings.';

  static String get notificationsSetupTitle =>
      _ar ? 'إعداد إرسال الإشعارات' : 'Set up push delivery';
  static String get notificationsSetupSubtitle => _ar
      ? 'أكمل الخطوات التالية مرة واحدة لكل مشروع Supabase.'
      : 'Complete these steps once for each Supabase project.';
  static String get notificationsSetupIntro => _ar
      ? 'الإشعارات داخل التطبيق تعمل دائمًا. لكي يصل Push إلى الهاتف، يجب أن تتصل قاعدة البيانات بدالة send-push، وأن تمتلك الدالة حساب خدمة Firebase.'
      : 'In-app notifications always work. For a push to reach a phone, the database must reach the send-push function and the function must hold a Firebase service account.';
  static String get notificationsSetupStep1Title =>
      _ar ? '1. اضبط أسرار Vault' : '1. Set the Vault secrets';
  static String get notificationsSetupStep1Body => _ar
      ? 'أنشئ مفتاحًا سريًا قويًا وشاركه بين قاعدة البيانات ودالة الإرسال.'
      : 'Create a strong random secret and share it between the database and the send function.';
  static String get notificationsSetupStep2Title =>
      _ar ? '2. سجّل رابط الدالة' : '2. Register the function URL';
  static String get notificationsSetupStep2Body => _ar
      ? 'احفظ عنوان دالة send-push في إعدادات التطبيق حتى يعرف المشغّل أين يرسل.'
      : 'Store the send-push URL in app settings so the trigger knows where to post.';
  static String get notificationsSetupStep3Title => _ar
      ? '3. انشر الدالة وأسرارها'
      : '3. Deploy the function and its secrets';
  static String get notificationsSetupStep3Body => _ar
      ? 'استخدم نفس المفتاح في PUSH_WEBHOOK_SECRET، وأضف حساب خدمة Firebase في FIREBASE_SERVICE_ACCOUNT.'
      : 'Use the same secret for PUSH_WEBHOOK_SECRET and add the Firebase service account as FIREBASE_SERVICE_ACCOUNT.';
  static String get notificationsSetupStep4Title =>
      _ar ? '4. تحقق من الجاهزية' : '4. Verify readiness';
  static String get notificationsSetupStep4Body => _ar
      ? 'بعد كل خطوة ارجع إلى هذه الصفحة واضغط «فحص مرة أخرى». سيتحول المؤشر إلى جاهز عندما تكتمل السلسلة.'
      : 'After each step, return here and press "Check again". The indicator turns ready once the chain is complete.';
  static String get notificationsSetupNote => _ar
      ? 'لا تضع حساب الخدمة أو المفتاح السري داخل تطبيق الإدارة؛ يبقيان في Vault وأسرار Supabase فقط.'
      : 'Never put the service account or webhook secret inside the admin app; they belong in the Vault and Supabase secrets only.';
  static String get notificationsSetupCopied =>
      _ar ? 'تم نسخ الأمر' : 'Command copied';
  static String get notificationsSetupCopy =>
      _ar ? 'نسخ الأمر' : 'Copy command';

  static String get notificationsFilterType => _ar ? 'النوع' : 'Type';
  static String get notificationsFilterRead => _ar ? 'القراءة' : 'Read state';
  static String get notificationsFilterPush => _ar ? 'الإرسال' : 'Push';
  static String get notificationsFilterAllTypes =>
      _ar ? 'كل الأنواع' : 'All types';
  static String get notificationsFilterAllRead =>
      _ar ? 'كل الإشعارات' : 'All notifications';
  static String get notificationsFilterUnread => _ar ? 'غير مقروء' : 'Unread';
  static String get notificationsFilterReadOnly => _ar ? 'مقروء' : 'Read';
  static String get notificationsFilterAllPush =>
      _ar ? 'كل حالات الإرسال' : 'All push states';
  static String get notificationsFilterSent => _ar ? 'وصلت' : 'Delivered';
  static String get notificationsFilterFailed => _ar ? 'فشلت' : 'Failed';
  static String get notificationsFilterSkipped => _ar ? 'تم تخطيها' : 'Skipped';
  static String get notificationsFilterNoPush =>
      _ar ? 'بدون إرسال' : 'Not attempted';
  static String notificationsFilterOption(String label, int count) =>
      _ar ? '$label ($count)' : '$label ($count)';

  static String get notificationsTableNotification =>
      _ar ? 'الإشعار' : 'Notification';
  static String get notificationsTableCustomer => _ar ? 'العميل' : 'Customer';
  static String get notificationsTableType => _ar ? 'النوع' : 'Type';
  static String get notificationsTableSource => _ar ? 'المصدر' : 'Source';
  static String get notificationsTableDate => _ar ? 'التاريخ' : 'Date';
  static String get notificationsTableRead => _ar ? 'القراءة' : 'Read';
  static String get notificationsTablePush => _ar ? 'الإرسال' : 'Push';
  static String get notificationsMenuTooltip =>
      _ar ? 'إجراءات الإشعار' : 'Notification actions';

  static String get notificationsRead => _ar ? 'مقروء' : 'Read';
  static String get notificationsUnread => _ar ? 'غير مقروء' : 'Unread';
  static String get notificationsPushSent => _ar ? 'وصل' : 'Delivered';
  static String get notificationsPushFailed => _ar ? 'فشل' : 'Failed';
  static String get notificationsPushSkipped => _ar ? 'تم التخطي' : 'Skipped';
  static String get notificationsPushNone => _ar ? 'لم يُرسل' : 'Not sent';
  static String get notificationsUntitled =>
      _ar ? 'إشعار بدون عنوان' : 'Untitled notification';
  static String get notificationsNoBody =>
      _ar ? 'لا يوجد نص لهذا الإشعار.' : 'This notification has no body.';

  static String get notificationsTypeOrder => _ar ? 'الطلبات' : 'Orders';
  static String get notificationsTypePromo => _ar ? 'عروض' : 'Promotions';
  static String get notificationsTypeSystem => _ar ? 'النظام' : 'System';
  static String get notificationsTypeLoyalty => _ar ? 'الولاء' : 'Loyalty';
  static String get notificationsTypeSubscription =>
      _ar ? 'الاشتراكات' : 'Subscriptions';

  static String get notificationsSourceAutomatic =>
      _ar ? 'تلقائي' : 'Automatic';
  static String get notificationsSourceCampaign =>
      _ar ? 'حملة إدارية' : 'Admin campaign';
  static String get notificationsAudienceAll =>
      _ar ? 'كل العملاء' : 'All customers';
  static String get notificationsAudiencePushEnabled =>
      _ar ? 'مفعّلو الإشعارات' : 'Push enabled';
  static String get notificationsAudienceHasDevice =>
      _ar ? 'لديهم أجهزة' : 'Has a device';
  static String get notificationsAudienceCustomer =>
      _ar ? 'عميل محدد' : 'Specific customer';

  static String get notificationsEmpty =>
      _ar ? 'لا توجد إشعارات بعد' : 'No notifications yet';
  static String get notificationsEmptyHint => _ar
      ? 'ستظهر هنا إشعارات الطلبات والولاء والاشتراكات، وأي حملة ترسلها من هذه الصفحة.'
      : 'Order, loyalty and subscription notifications, plus every campaign you send, will appear here.';
  static String get notificationsNoMatches =>
      _ar ? 'لا توجد إشعارات مطابقة' : 'No matching notifications';
  static String notificationsRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count إشعارًا'
      : 'Showing $from–$to of $count notifications';

  static String get notificationsViewDetails =>
      _ar ? 'عرض التفاصيل' : 'View details';
  static String get notificationsMarkRead =>
      _ar ? 'تحديد كمقروء' : 'Mark as read';
  static String get notificationsMarkUnread =>
      _ar ? 'تحديد كغير مقروء' : 'Mark as unread';
  static String get notificationsResend =>
      _ar ? 'إعادة إرسال Push' : 'Resend push';
  static String get notificationsDelete =>
      _ar ? 'حذف الإشعار' : 'Delete notification';
  static String get notificationsDeleteTitle =>
      _ar ? 'حذف الإشعار' : 'Delete notification';
  static String notificationsDeleteMessage(String customer) => _ar
      ? 'سيُحذف هذا الإشعار نهائيًا من حساب $customer. لا يمكن التراجع عن الحذف.'
      : 'This notification will be permanently removed from $customer\'s account. This cannot be undone.';
  static String get notificationsDeleteConfirm => _ar ? 'حذف نهائي' : 'Delete';
  static String get notificationsDeleteFailed => _ar
      ? 'تعذر حذف الإشعار. حاول مرة أخرى.'
      : 'The notification could not be deleted. Please try again.';
  static String get notificationsDeletedToast =>
      _ar ? 'تم حذف الإشعار.' : 'The notification was deleted.';
  static String get notificationsNotFound => _ar
      ? 'هذا الإشعار لم يعد موجودًا.'
      : 'This notification no longer exists.';
  static String get notificationsToggleFailed => _ar
      ? 'تعذر تحديث حالة القراءة. حاول مرة أخرى.'
      : 'The read state could not be updated. Please try again.';
  static String get notificationsMarkedReadToast =>
      _ar ? 'تم تحديد الإشعار كمقروء.' : 'The notification was marked as read.';
  static String get notificationsMarkedUnreadToast => _ar
      ? 'تم تحديد الإشعار كغير مقروء.'
      : 'The notification was marked as unread.';
  static String get notificationsResendQueued => _ar
      ? 'تمت جدولة إعادة إرسال الإشعار إلى خدمة الدفع.'
      : 'The push was queued again for delivery.';
  static String get notificationsResendNotConfigured => _ar
      ? 'خدمة الدفع غير مهيأة، لذلك لم تُجدول إعادة الإرسال. راجع حالة الإرسال بالأعلى.'
      : 'Push delivery is not configured, so nothing was queued. Review the delivery health above.';
  static String get notificationsResendFailed => _ar
      ? 'تعذرت إعادة إرسال الإشعار. حاول مرة أخرى.'
      : 'The notification could not be resent. Please try again.';

  static String notificationsSendSuccess(int recipients, int pushReady) => _ar
      ? 'تم إرسال الإشعار إلى $recipients عميل، منهم $pushReady جاهز للاستلام عبر الدفع.'
      : 'Sent to $recipients customers; $pushReady of them are ready to receive the push.';
  static String get notificationsSendNoRecipients => _ar
      ? 'لا يوجد عملاء مطابقون لهذا الجمهور أو النوع. عدّل الجمهور أو النوع.'
      : 'No customers match this audience and type. Adjust the audience or type.';
  static String get notificationsSendCustomerNotFound => _ar
      ? 'العميل المحدد لم يعد موجودًا. اختر عميلًا آخر.'
      : 'The selected customer no longer exists. Choose another customer.';
  static String get notificationsSendFailed => _ar
      ? 'تعذر إرسال الإشعار. حاول مرة أخرى.'
      : 'The notification could not be sent. Please try again.';

  static String get notificationsDetailsTitle =>
      _ar ? 'تفاصيل الإشعار' : 'Notification details';
  static String notificationsDetailsSubtitle(String customer) =>
      _ar ? 'موجّه إلى $customer' : 'Addressed to $customer';
  static String get notificationsDetailsContent => _ar ? 'المحتوى' : 'Content';
  static String get notificationsDetailsArabic => _ar ? 'العربية' : 'Arabic';
  static String get notificationsDetailsEnglish =>
      _ar ? 'الإنجليزية' : 'English';
  static String get notificationsDetailsCustomer => _ar ? 'العميل' : 'Customer';
  static String get notificationsDetailsCampaign => _ar ? 'الحملة' : 'Campaign';
  static String get notificationsDetailsPush =>
      _ar ? 'حالة الإرسال للهاتف' : 'Push delivery';
  static String get notificationsDetailsPayload =>
      _ar ? 'بيانات إضافية' : 'Payload';
  static String get notificationsDetailsNoPayload => _ar
      ? 'لا توجد بيانات إضافية مرتبطة بهذا الإشعار.'
      : 'This notification has no extra payload.';
  static String get notificationsDetailsAuto => _ar
      ? 'أُنشئ تلقائيًا من أحداث النظام، وليس من حملة إدارية.'
      : 'Created automatically from system activity, not from an admin campaign.';
  static String notificationsDetailsRecipients(int count) => _ar
      ? 'وصلت الحملة إلى $count عميل.'
      : 'The campaign reached $count customers.';
  static String notificationsDetailsDelivered(int count) =>
      _ar ? 'تم التسليم: $count' : 'Delivered: $count';
  static String notificationsDetailsFailed(int count) =>
      _ar ? 'فشل: $count' : 'Failed: $count';
  static String notificationsDetailsInvalid(int count) =>
      _ar ? 'رموز غير صالحة: $count' : 'Invalid tokens: $count';
  static String notificationsDetailsSkipped(int count) =>
      _ar ? 'تم التخطي: $count' : 'Skipped: $count';
  static String notificationsDetailsLastAttempt(String date) =>
      _ar ? 'آخر محاولة: $date' : 'Last attempt: $date';
  static String get notificationsDetailsNoAttempt => _ar
      ? 'لم تُسجل محاولة إرسال لهذا الإشعار. قد يكون العميل لم يسجل جهازًا أو أن الإشعار أُنشئ قبل تهيئة الدفع.'
      : 'No push attempt was recorded. The customer may have no registered device, or the notification predates push setup.';
  static String get notificationsDetailsLastError =>
      _ar ? 'آخر خطأ' : 'Last error';
  static String get notificationsDetailsCreated => _ar ? 'أُنشئ في' : 'Created';
  static String get notificationsDetailsReadAt => _ar ? 'قُرئ في' : 'Read at';
  static String get notificationsDetailsNeverRead =>
      _ar ? 'لم يُقرأ بعد' : 'Not read yet';
  static String get notificationsDetailsRelated =>
      _ar ? 'الكيان المرتبط' : 'Related entity';
  static String get notificationsRelatedOrder => _ar ? 'طلب' : 'Order';
  static String get notificationsRelatedLoyalty => _ar ? 'الولاء' : 'Loyalty';
  static String get notificationsRelatedSubscription =>
      _ar ? 'اشتراك' : 'Subscription';
  static String get notificationsRelatedSystem => _ar ? 'النظام' : 'System';
  static String get notificationsDetailsResendHint => _ar
      ? 'إعادة الإرسال تنشئ محاولة Push جديدة لنفس السجل، بدون إنشاء إشعار مكرر.'
      : 'Resending queues a new push attempt for the same record without creating a duplicate notification.';

  static String get notificationsComposeTitle =>
      _ar ? 'إنشاء إشعار جديد' : 'Compose a notification';
  static String get notificationsComposeSubtitle => _ar
      ? 'يُنشأ سجل لكل عميل داخل التطبيق، ويُرسل Push لمن فعّل الإشعارات.'
      : 'One in-app record is created per customer, and a push is sent to everyone who enabled notifications.';
  static String get notificationsComposeType =>
      _ar ? 'نوع الإشعار' : 'Notification type';
  static String get notificationsComposeAudience =>
      _ar ? 'الجمهور' : 'Audience';
  static String get notificationsComposeTitleAr =>
      _ar ? 'العنوان بالعربية' : 'Title in Arabic';
  static String get notificationsComposeTitleEn =>
      _ar ? 'العنوان بالإنجليزية' : 'Title in English';
  static String get notificationsComposeBodyAr =>
      _ar ? 'النص بالعربية' : 'Body in Arabic';
  static String get notificationsComposeBodyEn =>
      _ar ? 'النص بالإنجليزية' : 'Body in English';
  static String get notificationsComposePayload =>
      _ar ? 'بيانات إضافية (JSON)' : 'Extra payload (JSON)';
  static String get notificationsComposePayloadHint => _ar
      ? 'اختياري: كائن JSON يُرفق بالإشعار، مثل {"deep_link":"app://offers"}.'
      : 'Optional JSON object attached to the notification, such as {"deep_link":"app://offers"}.';
  static String get notificationsComposePayloadInvalid => _ar
      ? 'أدخل كائن JSON صالحًا أو اترك الحقل فارغًا.'
      : 'Enter a valid JSON object, or leave the field empty.';
  static String get notificationsComposeCustomer =>
      _ar ? 'العميل المستهدف' : 'Target customer';
  static String get notificationsComposeCustomerSearch => _ar
      ? 'ابحث بالاسم أو البريد أو الهاتف...'
      : 'Search by name, email, or phone...';
  static String get notificationsComposeCustomerRequired => _ar
      ? 'اختر العميل الذي سيستلم الإشعار.'
      : 'Choose the customer who will receive the notification.';
  static String get notificationsComposeNoCustomers =>
      _ar ? 'لا يوجد عملاء مطابقون.' : 'No customers match this search.';
  static String get notificationsComposeCustomersFailed =>
      _ar ? 'تعذر تحميل العملاء.' : 'Customers could not be loaded.';
  static String get notificationsComposePushReady =>
      _ar ? 'Push مفعّل' : 'Push ready';
  static String get notificationsComposePushOff =>
      _ar ? 'بدون Push' : 'No push';
  static String get notificationsComposeEstimate =>
      _ar ? 'الوصول المتوقع' : 'Expected reach';
  static String notificationsComposeEstimateValue(int count) => _ar
      ? '$count عميل'
      : count == 1
      ? '1 customer'
      : '$count customers';
  static String notificationsComposeEstimatePush(int count) => _ar
      ? '$count منهم جاهز لاستلام Push'
      : '$count of them can receive a push';
  static String get notificationsComposeEstimateFailed => _ar
      ? 'تعذر حساب عدد العملاء.'
      : 'The audience size could not be calculated.';
  static String get notificationsComposeEstimateLoading =>
      _ar ? 'جارٍ الحساب...' : 'Calculating...';
  static String get notificationsComposeSelectCustomerFirst => _ar
      ? 'اختر عميلًا لعرض عدد المستلمين.'
      : 'Choose a customer to see the expected reach.';
  static String get notificationsComposeSend =>
      _ar ? 'إرسال الإشعار' : 'Send notification';
  static String get notificationsComposeSending =>
      _ar ? 'جارٍ الإرسال...' : 'Sending...';
  static String get notificationsComposePreview => _ar ? 'المعاينة' : 'Preview';
  static String get notificationsComposePreviewHint => _ar
      ? 'كما سيظهر في التطبيق بلغة الواجهة الحالية.'
      : 'How it will appear in the app in the current language.';
  static String get notificationsComposePreviewEmptyTitle =>
      _ar ? 'عنوان الإشعار' : 'Notification title';
  static String get notificationsComposePreviewEmptyBody =>
      _ar ? 'سيظهر نص الإشعار هنا.' : 'The notification body appears here.';
  static String get notificationsComposePreviewNow => _ar ? 'الآن' : 'Now';
  static String get notificationsComposeTooLongTitle => _ar
      ? 'العنوان أطول من 160 حرفًا.'
      : 'The title is longer than 160 characters.';
  static String get notificationsComposeTooLongBody => _ar
      ? 'النص أطول من 1000 حرف.'
      : 'The body is longer than 1000 characters.';

  static String get savedCards => _ar ? 'البطاقات المحفوظة' : 'Saved cards';
  static String get addresses => _ar ? 'العناوين' : 'Addresses';
  static String get rolesAndPermissions =>
      _ar ? 'الأدوار والصلاحيات' : 'Roles and permissions';
  static String get rolesDescription => _ar
      ? 'حدّدي صلاحيات كل دور في فريقك وتحكمي في الوصول لكل قسم.'
      : 'Define what each team role can access across the dashboard.';
  static String get rolesMetricTotal => _ar ? 'إجمالي الأدوار' : 'Total roles';
  static String get rolesMetricSystem => _ar ? 'أدوار النظام' : 'System roles';
  static String get rolesMetricCustom => _ar ? 'أدوار مخصصة' : 'Custom roles';
  static String get rolesMetricPermissions =>
      _ar ? 'صلاحيات ممنوحة' : 'Assigned permissions';
  static String get rolesFilterAll => _ar ? 'كل الأدوار' : 'All roles';
  static String get rolesFilterSystem => _ar ? 'أدوار النظام' : 'System roles';
  static String get rolesFilterCustom => _ar ? 'أدوار مخصصة' : 'Custom roles';
  static String get rolesNoMatches =>
      _ar ? 'لا توجد أدوار مطابقة لهذا البحث.' : 'No roles match this search.';
  static String get rolesEmptyFilter =>
      _ar ? 'لا توجد أدوار بهذا النوع.' : 'No roles of this type.';
  static String get rolesTableRole => _ar ? 'الدور' : 'Role';
  static String get rolesTableType => _ar ? 'النوع' : 'Type';
  static String get rolesTablePermissions => _ar ? 'الصلاحيات' : 'Permissions';
  static String get roleCode => _ar ? 'الكود' : 'Code';
  static String get roleCustom => _ar ? 'مخصص' : 'Custom';
  static String get rolesFilter => _ar ? 'تصفية الأدوار' : 'Filter roles';
  static String rolesRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count دورًا'
      : 'Showing $from–$to of $count roles';
  static String get roleNoPermissions =>
      _ar ? 'لا توجد صلاحيات ممنوحة' : 'No permissions granted';
  static String get roleManagePermissions =>
      _ar ? 'إدارة الصلاحيات' : 'Manage permissions';
  static String get roleViewPermissions =>
      _ar ? 'عرض الصلاحيات' : 'View permissions';
  static String rolePermissionsCount(int count) => count == 1
      ? _ar
            ? 'صلاحية واحدة'
            : '1 permission'
      : _ar
      ? '$count صلاحيات'
      : '$count permissions';
  static String permissionsFor(String name) =>
      _ar ? 'صلاحيات $name' : 'Permissions for $name';
  static String get permissionsDialogSubtitle => _ar
      ? 'حدّدي ما يستطيع هذا الدور أو الموظف الوصول إليه.'
      : 'Choose what this role or staff member can access.';
  static String get permissionsSearchHint =>
      _ar ? 'ابحث عن صلاحية...' : 'Search permissions...';
  static String get permissionsNoMatches =>
      _ar ? 'لا توجد صلاحيات مطابقة.' : 'No matching permissions.';
  static String permissionsGrantedCount(int count) =>
      _ar ? 'الممنوح: $count' : 'Granted: $count';
  static String get permissionsReadOnly => _ar
      ? 'لديك صلاحية العرض فقط، ولا يمكنك تعديل الصلاحيات.'
      : 'You have view-only access and cannot change permissions.';
  static String get permissionsLoadFailed => _ar
      ? 'تعذر تحميل قائمة الصلاحيات.'
      : 'Could not load the permission catalogue.';
  static String get permissionSaveFailed => _ar
      ? 'تعذر حفظ الصلاحية. حاولي مرة أخرى.'
      : 'The permission could not be saved. Please try again.';
  static String get auditLog => _ar ? 'سجل التدقيق' : 'Audit log';
  static String get auditLogDescription => _ar
      ? 'تابع كل عملية مهمة في متجرك: من قام بها، وأين، وما الذي تغيّر.'
      : 'Follow every important change in your store: who made it, where, and what changed.';
  static String get auditRefresh => _ar ? 'تحديث' : 'Refresh';
  static String get auditFilterDomain =>
      _ar ? 'تصفية حسب القسم' : 'Filter by area';
  static String get auditFilterAllDomains => _ar ? 'كل الأقسام' : 'All areas';
  static String get auditFilterCritical =>
      _ar ? 'الحساسة فقط' : 'Sensitive only';
  static String get auditSearchHint => _ar
      ? 'ابحث في الأحداث أو المنفّذ أو الفرع'
      : 'Search events, staff or branch';

  static String get auditMetricTotal => _ar ? 'إجمالي الأحداث' : 'Total events';
  static String auditMetricTotalHint(int week) =>
      _ar ? '$week حدثًا خلال آخر 7 أيام' : '$week events in the last 7 days';
  static String get auditMetricToday => _ar ? 'أحداث اليوم' : 'Today';
  static String auditMetricTodayHint(String latest) =>
      _ar ? 'آخر حدث: $latest' : 'Last event: $latest';
  static String get auditMetricCritical =>
      _ar ? 'أحداث حساسة' : 'Sensitive events';
  static String auditMetricCriticalHint(int total) =>
      _ar ? 'الإجمالي: $total' : 'All time: $total';
  static String auditMetricCriticalWeekHint(int week) =>
      _ar ? 'خلال آخر 7 أيام: $week' : 'Last 7 days: $week';
  static String get auditMetricActors =>
      _ar ? 'الموظفون النشطون' : 'Active staff';
  static String auditMetricActorsHint(int branches) =>
      _ar ? 'على $branches من الفروع' : 'Across $branches branches';
  static String get auditMetricNoActivity =>
      _ar ? 'لا نشاط بعد' : 'No activity yet';

  static String get auditEmpty =>
      _ar ? 'لا توجد أحداث مسجلة بعد.' : 'No activity recorded yet.';
  static String get auditEmptyHint => _ar
      ? 'ستظهر هنا كل عمليات الإنشاء والتعديل والحذف التي يقوم بها فريقك.'
      : 'Creations, edits and deletions made by your team will appear here.';
  static String get auditNoMatches =>
      _ar ? 'لا توجد أحداث مطابقة للبحث.' : 'No activity matches your search.';
  static String auditRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من أصل $count حدثًا'
      : 'Showing $from–$to of $count events';

  static String get auditTableEvent => _ar ? 'الحدث' : 'Event';
  static String get auditTableActor => _ar ? 'المنفّذ' : 'Performed by';
  static String get auditTableBranch => _ar ? 'الفرع' : 'Branch';
  static String get auditTableTime => _ar ? 'الوقت' : 'Time';
  static String get auditTableSensitivity => _ar ? 'الحساسية' : 'Sensitivity';
  static String get auditOpenDetails => _ar ? 'عرض التفاصيل' : 'View details';
  static String get auditCriticalBadge => _ar ? 'حساس' : 'Sensitive';
  static String get auditNormalBadge => _ar ? 'عادي' : 'Normal';
  static String get auditSystemActor => _ar ? 'النظام' : 'System';
  static String get auditUnknownActor => _ar ? 'غير معروف' : 'Unknown';
  static String get auditStaffRole => _ar ? 'موظف' : 'Staff';
  static String get auditUnknownAction =>
      _ar ? 'نشاط غير مصنّف' : 'Uncategorized activity';

  static String get auditDetailsTitle => _ar ? 'تفاصيل الحدث' : 'Event details';
  static String auditDetailsSubtitle(int id) =>
      _ar ? 'رقم الحدث #$id' : 'Event #$id';
  static String get auditDetailsActor => _ar ? 'المنفّذ' : 'Performed by';
  static String get auditDetailsWhen => _ar ? 'وقت الحدث' : 'When';
  static String get auditDetailsBranch => _ar ? 'الفرع' : 'Branch';
  static String get auditDetailsEntity => _ar ? 'العنصر' : 'Item';
  static String get auditDetailsEntityId => _ar ? 'معرّف العنصر' : 'Item ID';
  static String get auditDetailsNoBranch =>
      _ar ? 'غير مرتبط بفرع' : 'Not linked to a branch';
  static String get auditDetailsChanges =>
      _ar ? 'ما الذي تغيّر؟' : 'What changed?';
  static String get auditDetailsNoChanges => _ar
      ? 'لا توجد تفاصيل تغييرات مسجلة لهذا الحدث.'
      : 'No change details were recorded for this event.';
  static String get auditDetailsBefore => _ar ? 'قبل' : 'Before';
  static String get auditDetailsAfter => _ar ? 'بعد' : 'After';
  static String get auditDetailsTechnical =>
      _ar ? 'البيانات التقنية' : 'Technical data';
  static String get auditDetailsActionCode =>
      _ar ? 'كود العملية' : 'Action code';
  static String get auditDetailsEntityType => _ar ? 'نوع العنصر' : 'Item type';
  static String get auditDetailsRawValues =>
      _ar ? 'القيم الخام (JSON)' : 'Raw values (JSON)';
  static String get auditDetailsClose => _ar ? 'إغلاق' : 'Close';
  static String auditDetailsChangedFields(int count) =>
      _ar ? '$count تغييرات مسجلة' : '$count recorded changes';
  static String get auditDetailsNoValue => _ar ? '—' : '—';

  static String get auditValueHasImage => _ar ? 'توجد صورة' : 'Image set';
  static String get auditValueNoImage => _ar ? 'بدون صورة' : 'No image';
  static String get auditValueQueued => _ar ? 'تمت الجدولة' : 'Queued';
  static String get auditValueNotQueued =>
      _ar ? 'لم تتم الجدولة' : 'Not queued';
  static String get auditValueRead => _ar ? 'مقروء' : 'Read';
  static String get auditValueUnread => _ar ? 'غير مقروء' : 'Unread';
  static String auditSelectedCount(int count) =>
      _ar ? '$count عناصر محددة' : '$count selected items';
  static String get auditValueEmptyList => _ar ? 'لا عناصر' : 'No items';
  static String get auditValueTypePromo => _ar ? 'عرض ترويجي' : 'Promotion';
  static String get auditValueTypeSystem => _ar ? 'نظام' : 'System';
  static String get auditValueTypeLoyalty => _ar ? 'ولاء' : 'Loyalty';
  static String get auditValueTypeSubscription =>
      _ar ? 'اشتراك' : 'Subscription';
  static String get auditValueTypeOrder => _ar ? 'حالة طلب' : 'Order status';
  static String get auditValueAudienceAll =>
      _ar ? 'كل العملاء' : 'All customers';
  static String get auditValueAudiencePush =>
      _ar ? 'مفعّلو الإشعارات' : 'Push-enabled customers';
  static String get auditValueAudienceDevice =>
      _ar ? 'أصحاب الأجهزة' : 'Customers with devices';
  static String get auditValueAudienceCustomer =>
      _ar ? 'عميل محدد' : 'One customer';
  static String get auditValueAppliesAll =>
      _ar ? 'كل المنتجات' : 'All products';
  static String get auditValueAppliesCategory =>
      _ar ? 'تصنيفات محددة' : 'Specific categories';
  static String get auditValueAppliesProduct =>
      _ar ? 'منتجات محددة' : 'Specific products';
  static String get auditValueDiscountPercentage =>
      _ar ? 'نسبة مئوية' : 'Percentage';
  static String get auditValueDiscountFixed =>
      _ar ? 'مبلغ ثابت' : 'Fixed amount';
  static String get auditValueStockRestock => _ar ? 'توريد' : 'Restock';
  static String get auditValueStockAdjustment =>
      _ar ? 'تسوية جرد' : 'Adjustment';
  static String get auditValueStockWaste => _ar ? 'تالف' : 'Waste';
  static String get auditValueStockReturn => _ar ? 'مرتجع' : 'Return';

  static String get auditDomainCore =>
      _ar ? 'الفروع والإعدادات' : 'Branches & settings';
  static String get auditDomainOrders => _ar ? 'الطلبات' : 'Orders';
  static String get auditDomainCatalog => _ar ? 'المنتجات' : 'Catalog';
  static String get auditDomainMarketing =>
      _ar ? 'التسويق والعروض' : 'Marketing';
  static String get auditDomainLoyalty => _ar ? 'الولاء والنقاط' : 'Loyalty';
  static String get auditDomainSubscriptions =>
      _ar ? 'الاشتراكات' : 'Subscriptions';
  static String get auditDomainEngagement =>
      _ar ? 'الإشعارات والتقييمات' : 'Notifications & reviews';
  static String get auditDomainInventory => _ar ? 'المخزون' : 'Inventory';
  static String get auditDomainStaff => _ar ? 'فريق العمل' : 'Staff';
  static String get auditDomainPayments => _ar ? 'المدفوعات' : 'Payments';
  static String get auditDomainSecurity =>
      _ar ? 'الأمان والصلاحيات' : 'Security';
  static String get auditDomainOther => _ar ? 'أخرى' : 'Other';

  static String get auditEntityBranch => _ar ? 'فرع' : 'Branch';
  static String get auditEntityCoupon => _ar ? 'كوبون' : 'Coupon';
  static String get auditEntityReward => _ar ? 'مكافأة' : 'Reward';
  static String get auditEntityRule => _ar ? 'قاعدة نقاط' : 'Points rule';
  static String get auditEntityReview => _ar ? 'تقييم' : 'Review';
  static String get auditEntityNotification => _ar ? 'إشعار' : 'Notification';
  static String get auditEntityCampaign =>
      _ar ? 'حملة إشعارات' : 'Notification campaign';
  static String get auditEntityOrder => _ar ? 'طلب' : 'Order';
  static String get auditEntityStock => _ar ? 'مخزون' : 'Stock';
  static String get auditEntityStaff => _ar ? 'موظف' : 'Staff member';
  static String get auditEntityOther => _ar ? 'عنصر' : 'Item';

  static String get auditActionBranchCreate =>
      _ar ? 'إنشاء فرع' : 'Branch created';
  static String get auditActionBranchUpdate =>
      _ar ? 'تعديل بيانات فرع' : 'Branch updated';
  static String get auditActionBranchDelete =>
      _ar ? 'حذف فرع' : 'Branch deleted';
  static String get auditActionBranchActivate =>
      _ar ? 'تفعيل فرع' : 'Branch activated';
  static String get auditActionBranchDeactivate =>
      _ar ? 'إيقاف فرع' : 'Branch deactivated';
  static String get auditActionBranchImage =>
      _ar ? 'تحديث صورة فرع' : 'Branch image updated';
  static String get auditActionCouponCreate =>
      _ar ? 'إنشاء كوبون' : 'Coupon created';
  static String get auditActionCouponUpdate =>
      _ar ? 'تعديل كوبون' : 'Coupon updated';
  static String get auditActionCouponDelete =>
      _ar ? 'حذف كوبون' : 'Coupon deleted';
  static String get auditActionCouponActivate =>
      _ar ? 'تفعيل كوبون' : 'Coupon activated';
  static String get auditActionCouponPause =>
      _ar ? 'إيقاف كوبون مؤقتًا' : 'Coupon paused';
  static String get auditActionRewardCreate =>
      _ar ? 'إنشاء مكافأة' : 'Reward created';
  static String get auditActionRewardUpdate =>
      _ar ? 'تعديل مكافأة' : 'Reward updated';
  static String get auditActionRewardDelete =>
      _ar ? 'حذف مكافأة' : 'Reward deleted';
  static String get auditActionRewardActivate =>
      _ar ? 'تفعيل مكافأة' : 'Reward activated';
  static String get auditActionRewardPause =>
      _ar ? 'إيقاف مكافأة مؤقتًا' : 'Reward paused';
  static String get auditActionRuleCreate =>
      _ar ? 'إنشاء قاعدة نقاط' : 'Points rule created';
  static String get auditActionRuleUpdate =>
      _ar ? 'تعديل قاعدة نقاط' : 'Points rule updated';
  static String get auditActionReviewPublish =>
      _ar ? 'نشر تقييم' : 'Review published';
  static String get auditActionReviewHide =>
      _ar ? 'إخفاء تقييم' : 'Review hidden';
  static String get auditActionReviewDelete =>
      _ar ? 'حذف تقييم' : 'Review deleted';
  static String get auditActionNotificationSend =>
      _ar ? 'إرسال إشعار' : 'Notification sent';
  static String get auditActionNotificationResend =>
      _ar ? 'إعادة إرسال إشعار' : 'Notification resent';
  static String get auditActionNotificationRead =>
      _ar ? 'تغيير حالة قراءة إشعار' : 'Notification read state changed';
  static String get auditActionNotificationDelete =>
      _ar ? 'حذف إشعار' : 'Notification deleted';
  static String get auditActionOrderStatus =>
      _ar ? 'تحديث حالة طلب' : 'Order status updated';
  static String get auditActionStockAdjust =>
      _ar ? 'تعديل المخزون' : 'Stock adjusted';
  static String get auditActionStaffProvision =>
      _ar ? 'إضافة موظف' : 'Staff member added';

  static String get auditFieldCode => _ar ? 'الكود' : 'Code';
  static String get auditFieldNameAr => _ar ? 'الاسم بالعربية' : 'Arabic name';
  static String get auditFieldNameEn =>
      _ar ? 'الاسم بالإنجليزية' : 'English name';
  static String get auditFieldTitleAr =>
      _ar ? 'العنوان بالعربية' : 'Arabic title';
  static String get auditFieldTitleEn =>
      _ar ? 'العنوان بالإنجليزية' : 'English title';
  static String get auditFieldDescriptionAr =>
      _ar ? 'الوصف بالعربية' : 'Arabic description';
  static String get auditFieldDescriptionEn =>
      _ar ? 'الوصف بالإنجليزية' : 'English description';
  static String get auditFieldBody => _ar ? 'نص الرسالة' : 'Message body';
  static String get auditFieldAddressAr =>
      _ar ? 'العنوان بالعربية' : 'Arabic address';
  static String get auditFieldAddressEn =>
      _ar ? 'العنوان بالإنجليزية' : 'English address';
  static String get auditFieldCity => _ar ? 'المدينة' : 'City';
  static String get auditFieldDistrict => _ar ? 'الحي' : 'District';
  static String get auditFieldPhone => _ar ? 'الهاتف' : 'Phone';
  static String get auditFieldLatitude => _ar ? 'خط العرض' : 'Latitude';
  static String get auditFieldLongitude => _ar ? 'خط الطول' : 'Longitude';
  static String get auditFieldOpensAt => _ar ? 'وقت الفتح' : 'Opening time';
  static String get auditFieldClosesAt => _ar ? 'وقت الإغلاق' : 'Closing time';
  static String get auditFieldDiscountType =>
      _ar ? 'نوع الخصم' : 'Discount type';
  static String get auditFieldDiscountValue =>
      _ar ? 'قيمة الخصم' : 'Discount value';
  static String get auditFieldMaxDiscount =>
      _ar ? 'أقصى خصم' : 'Maximum discount';
  static String get auditFieldMinOrder =>
      _ar ? 'الحد الأدنى للطلب' : 'Minimum order';
  static String get auditFieldAppliesTo =>
      _ar ? 'نطاق الكوبون' : 'Coupon scope';
  static String get auditFieldUsageLimit =>
      _ar ? 'حد الاستخدام' : 'Usage limit';
  static String get auditFieldPerUser =>
      _ar ? 'حد الاستخدام للعميل' : 'Limit per customer';
  static String get auditFieldStartsAt => _ar ? 'تاريخ البداية' : 'Start date';
  static String get auditFieldEndsAt => _ar ? 'تاريخ الانتهاء' : 'End date';
  static String get auditFieldCategories =>
      _ar ? 'التصنيفات المحددة' : 'Selected categories';
  static String get auditFieldProducts =>
      _ar ? 'المنتجات المحددة' : 'Selected products';
  static String get auditFieldProduct => _ar ? 'المنتج' : 'Product';
  static String get auditFieldPointsCost =>
      _ar ? 'تكلفة النقاط' : 'Points cost';
  static String get auditFieldStockAvailable =>
      _ar ? 'المخزون المتاح' : 'Available stock';
  static String get auditFieldPublished => _ar ? 'حالة النشر' : 'Publish state';
  static String get auditFieldRead => _ar ? 'حالة القراءة' : 'Read state';
  static String get auditFieldType => _ar ? 'النوع' : 'Type';
  static String get auditFieldAudience => _ar ? 'الجمهور' : 'Audience';
  static String get auditFieldAudienceUser =>
      _ar ? 'العميل المستهدف' : 'Target customer';
  static String get auditFieldRecipients =>
      _ar ? 'عدد المستلمين' : 'Recipients';
  static String get auditFieldQueued => _ar ? 'حالة الإرسال' : 'Delivery state';
  static String get auditFieldUser => _ar ? 'المستخدم' : 'User';
  static String get auditFieldPointsRate =>
      _ar ? 'النقاط لكل ريال' : 'Points per riyal';
  static String get auditFieldPointValue => _ar ? 'قيمة النقطة' : 'Point value';
  static String get auditFieldBranch => _ar ? 'الفرع' : 'Branch';
  static String get auditFieldDelta => _ar ? 'كمية التعديل' : 'Quantity change';
  static String get auditFieldReason => _ar ? 'السبب' : 'Reason';
  static String get auditFieldResult => _ar ? 'النتيجة' : 'Result';
  static String get auditFieldRating => _ar ? 'التقييم' : 'Rating';
  static String get auditFieldComment => _ar ? 'التعليق' : 'Comment';
  static String get auditFieldNote => _ar ? 'ملاحظة' : 'Note';
  static String get auditFieldOther => _ar ? 'حقل إضافي' : 'Additional field';

  static String get branches => _ar ? 'الفروع' : 'Branches';
  static String get deliveryZones => _ar ? 'مناطق التوصيل' : 'Delivery zones';
  static String get content => _ar ? 'المحتوى' : 'Content';
  static String get appSettings => _ar ? 'إعدادات التطبيق' : 'App settings';
  static String get coupons => _ar ? 'الكوبونات' : 'Coupons';
  static String get banners => _ar ? 'البانرات' : 'Banners';
  static String get loyalty => _ar ? 'الولاء والنقاط' : 'Loyalty and points';
  static String get subscriptions => _ar ? 'الاشتراكات' : 'Subscriptions';
  static String get subscriptionPlans =>
      _ar ? 'باقات الاشتراكات' : 'Subscription plans';
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
  static String get searchSubscriptionPlansHint =>
      _ar ? 'ابحث باسم الباقة أو الكود...' : 'Search plans by name or code...';
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
      _ar ? 'إضافة صورة' : 'Add image or video';
  static String get selectProductCategory =>
      _ar ? 'اختر تصنيف المنتج' : 'Choose a product category';
  static String get selectLocalCategory =>
      _ar ? 'اختر تصنيف محلي' : 'Choose a local category';
  static String get localCategory => _ar ? 'تصنيف محلي' : 'Local category';
  static String get languageCode => 'AR';
  static String get currency => _ar ? 'ر.س' : 'SAR';
  static String get currencyCode => _ar ? 'العملة' : 'Currency';
  static String get amount => _ar ? 'المبلغ' : 'Amount';
  static String get productData => _ar ? 'بيانات المنتج' : 'Product data';
  static String get categoryData => _ar ? 'بيانات التصنيف' : 'Category data';
  static String get optionsAndQuantity =>
      _ar ? 'الخيارات والكمية' : 'Options and quantity';
  static String get addCategoryShort => _ar ? 'أضف تصنيفًا' : 'Add category';

  // ---------- Raw inventory ----------
  static String get inventorySubtitle => _ar
      ? 'المواد الخام وحدود إعادة الطلب وقيمة المخزون في كل فرع'
      : 'Raw materials, reorder levels and stock value across branches';
  static String get stockMovementsSubtitle => _ar
      ? 'سجل الاستلام والصرف والهالك والجرد مع الرصيد بعد كل حركة'
      : 'Receipts, issues, waste and counts with the balance after every movement';
  static String get addRawMaterial =>
      _ar ? 'مادة خام جديدة' : 'New raw material';
  static String get editRawMaterial =>
      _ar ? 'تعديل المادة الخام' : 'Edit raw material';
  static String get rawMaterialSearchHint =>
      _ar ? 'ابحث بالاسم أو الكود...' : 'Search by name or SKU...';
  static String get inventoryReadOnly => _ar
      ? 'لديك صلاحية عرض المخزون فقط. تواصل مع المالك لتسجيل الحركات أو تعديل المواد.'
      : 'You can view inventory only. Ask the owner to record movements or edit materials.';
  static String get rawMaterialsEmpty =>
      _ar ? 'لا توجد مواد خام بعد' : 'No raw materials yet';
  static String get rawMaterialsEmptyHint => _ar
      ? 'أضف أول مادة خام مثل حبوب البن أو الحليب أو الأكواب لبدء متابعة المخزون.'
      : 'Add your first raw material, such as coffee beans, milk or cups, to start tracking stock.';
  static String get rawMaterialsNoMatches =>
      _ar ? 'لا توجد مواد مطابقة' : 'No materials match';
  static String get rawMaterialsNoMatchesHint => _ar
      ? 'جرّب كلمة بحث أخرى أو أزل عوامل التصفية.'
      : 'Try another search or clear the filters.';
  static String get inventoryMetricTotal => _ar ? 'إجمالي المواد' : 'Materials';
  static String get inventoryMetricValue =>
      _ar ? 'قيمة المخزون' : 'Stock value';
  static String get inventoryMetricLow => _ar ? 'تحت حد الطلب' : 'Low stock';
  static String get inventoryMetricOut =>
      _ar ? 'نافد من المخزون' : 'Out of stock';
  static String inventoryMetricTotalHint(int categories, int branches) => _ar
      ? '$categories تصنيف • $branches فرع'
      : '$categories categories • $branches branches';
  static String get inventoryMetricValueHint =>
      _ar ? 'بسعر تكلفة آخر شراء' : 'At latest purchase cost';
  static String get inventoryMetricLowHint =>
      _ar ? 'تحتاج إعادة طلب' : 'Need reordering';
  static String inventoryMetricMovementHint(String latest) =>
      _ar ? 'آخر حركة: $latest' : 'Last movement: $latest';
  static String get inventoryMetricNoMovement =>
      _ar ? 'لا توجد حركات بعد' : 'No movements yet';
  static String get inventoryStatusOut => _ar ? 'نافد' : 'Out';
  static String get inventoryFilterStatus =>
      _ar ? 'حالة المخزون' : 'Stock status';
  static String get inventoryFilterAllStatuses =>
      _ar ? 'كل الحالات' : 'All statuses';
  static String get inventoryFilterAllCategories =>
      _ar ? 'كل التصنيفات' : 'All categories';
  static String get inventoryFilterAllBranches =>
      _ar ? 'كل الفروع' : 'All branches';
  static String get inventoryTableMaterial => _ar ? 'المادة' : 'Material';
  static String get inventoryTableOnHand => _ar ? 'المتوفر' : 'On hand';
  static String get inventoryTableReorder => _ar ? 'حد الطلب' : 'Reorder at';
  static String get inventoryTableValue => _ar ? 'القيمة' : 'Value';
  static String get inventoryTableLastMovement =>
      _ar ? 'آخر حركة' : 'Last movement';
  static String inventoryRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count مادة'
      : 'Showing $from–$to of $count materials';
  static String get inventoryNoMovement =>
      _ar ? 'لم تُسجل حركة' : 'No movements yet';
  static String get inventoryNoCategory => _ar ? 'بدون تصنيف' : 'Uncategorised';
  static String get materialDeleted =>
      _ar ? 'تم حذف المادة الخام' : 'Raw material deleted';
  static String get materialCreated =>
      _ar ? 'تمت إضافة المادة الخام' : 'Raw material added';
  static String get materialUpdated =>
      _ar ? 'تم تحديث المادة الخام' : 'Raw material updated';
  static String get materialDeleteTitle =>
      _ar ? 'حذف المادة الخام' : 'Delete raw material';
  static String materialDeleteMessage(String name) => _ar
      ? 'سيتم حذف «$name» نهائيًا. لا يمكن التراجع عن هذا الإجراء.'
      : '“$name” will be deleted permanently. This cannot be undone.';
  static String get materialSku => _ar ? 'كود المادة (SKU)' : 'Material SKU';
  static String get materialSkuHint =>
      _ar ? 'اختياري، مثال: BEANS-ARABICA' : 'Optional, e.g. BEANS-ARABICA';
  static String get materialCategoryHint => _ar
      ? 'مثال: حبوب البن، ألبان، تغليف'
      : 'e.g. Coffee beans, Dairy, Packaging';
  static String get materialUnitCost => _ar ? 'تكلفة الوحدة' : 'Unit cost';
  static String get materialUnitCostHint =>
      _ar ? 'تكلفة آخر شراء للوحدة' : 'Latest purchase cost per unit';
  static String get materialReorderLevel =>
      _ar ? 'حد إعادة الطلب' : 'Reorder level';
  static String get materialReorderHint => _ar
      ? 'ننبّهك عند وصول المخزون إلى هذا الحد'
      : 'You are alerted when stock reaches this level';
  static String get materialNotes => _ar ? 'ملاحظات' : 'Notes';
  static String get materialNotesHint => _ar
      ? 'ملاحظات داخلية عن التوريد أو التخزين'
      : 'Internal notes about supply or storage';
  static String get materialIdentity =>
      _ar ? 'بيانات المادة' : 'Material details';
  static String get materialUnitOfMeasure =>
      _ar ? 'وحدة القياس' : 'Unit of measure';
  static String get materialUnitLocked => _ar
      ? 'لا يمكن تغيير الوحدة بعد تسجيل حركات على هذه المادة.'
      : 'The unit cannot change after movements are recorded for this material.';
  static String get materialNeedsName =>
      _ar ? 'اكتب اسم المادة بالعربية' : 'Enter the Arabic material name';
  static String get materialSaveDuplicateSku =>
      _ar ? 'كود المادة مستخدم بالفعل' : 'This SKU is already used';
  static String get materialSaveInvalidSku => _ar
      ? 'الكود يجب أن يبدأ بحرف أو رقم، ويحتوي على حروف إنجليزية وأرقام ورموز . _ - فقط (حتى 40 حرفًا).'
      : 'The SKU must start with a letter or digit and may contain A–Z, 0–9, dot, underscore or hyphen (up to 40 characters).';
  static String get materialSaveInvalidCategory => _ar
      ? 'التصنيف أطول من المسموح (80 حرفًا)'
      : 'The category is longer than 80 characters';
  static String get materialSaveInvalidUnit =>
      _ar ? 'اختر وحدة قياس صحيحة' : 'Choose a valid unit of measure';
  static String get materialSaveInvalidCost =>
      _ar ? 'تكلفة الوحدة غير صحيحة' : 'The unit cost is invalid';
  static String get materialSaveInvalidReorder =>
      _ar ? 'حد إعادة الطلب غير صحيح' : 'The reorder level is invalid';
  static String get materialSaveInvalidNotes =>
      _ar ? 'الملاحظات أطول من المسموح' : 'The notes are too long';
  static String get materialSaveUnitLocked => _ar
      ? 'لا يمكن تغيير الوحدة بعد تسجيل حركات'
      : 'The unit is locked after movements are recorded';
  static String get materialSaveNotFound =>
      _ar ? 'المادة غير موجودة' : 'The material no longer exists';
  static String get materialSavePermissionDenied => _ar
      ? 'ليس لديك صلاحية تعديل المواد الخام'
      : 'You cannot edit raw materials';
  static String get materialSaveFailed => _ar
      ? 'تعذر حفظ المادة الخام، حاول مرة أخرى'
      : 'Could not save the raw material. Try again.';
  static String get materialDeleteBlockedMovements => _ar
      ? 'لا يمكن حذف مادة لها حركات مسجلة'
      : 'A material with recorded movements cannot be deleted';
  static String get materialDeleteBlockedStock => _ar
      ? 'لا يمكن حذف مادة ما زال لها مخزون'
      : 'A material with stock on hand cannot be deleted';
  static String get materialDeleteInUse =>
      _ar ? 'المادة مستخدمة في وصفة أو باقة' : 'The material is in use';
  static String get materialMutationFailed => _ar
      ? 'تعذر تنفيذ الإجراء، حاول مرة أخرى'
      : 'The action could not be completed. Try again.';
  static String get stockMovementAction =>
      _ar ? 'تسجيل حركة' : 'Record movement';
  static String get stockMovementTitle =>
      _ar ? 'تسجيل حركة مخزون' : 'Record stock movement';
  static String get stockMovementSubtitle =>
      _ar ? 'استلام أو صرف أو هالك أو جرد' : 'Receipt, issue, waste or count';
  static String get movementReceipt => _ar ? 'استلام' : 'Receipt';
  static String get movementIssue => _ar ? 'صرف' : 'Issue';
  static String get movementWaste => _ar ? 'هالك' : 'Waste';
  static String get movementCount => _ar ? 'جرد' : 'Count';
  static String get movementTypeLabel => _ar ? 'نوع الحركة' : 'Movement type';
  static String get movementBranch => _ar ? 'الفرع' : 'Branch';
  static String get movementMaterial => _ar ? 'المادة الخام' : 'Raw material';
  static String get movementMaterialSearch => _ar
      ? 'ابحث عن مادة بالاسم أو الكود...'
      : 'Search materials by name or SKU...';
  static String get movementNoMaterials =>
      _ar ? 'لا توجد مواد خام مطابقة' : 'No matching raw materials';
  static String get movementQuantity => _ar ? 'الكمية' : 'Quantity';
  static String get movementCountedQuantity =>
      _ar ? 'الكمية بعد الجرد' : 'Counted quantity';
  static String get movementQuantityHint =>
      _ar ? 'أدخل الكمية' : 'Enter the quantity';
  static String get movementUnitCost =>
      _ar ? 'تكلفة الوحدة (اختياري)' : 'Unit cost (optional)';
  static String get movementReferenceHint =>
      _ar ? 'رقم الفاتورة أو طلب الشراء' : 'Invoice or purchase order number';
  static String get movementNoteHint =>
      _ar ? 'سبب الحركة أو أي تفاصيل إضافية' : 'Reason or extra details';
  static String get movementCurrentStock =>
      _ar ? 'المخزون الحالي' : 'Current stock';
  static String get movementSelectBranch =>
      _ar ? 'اختر الفرع أولًا' : 'Choose a branch first';
  static String get movementNeedsBranch =>
      _ar ? 'اختر الفرع' : 'Choose a branch';
  static String get movementNeedsMaterial =>
      _ar ? 'اختر المادة الخام' : 'Choose a raw material';
  static String get movementNeedsQuantity =>
      _ar ? 'أدخل كمية أكبر من صفر' : 'Enter a quantity greater than zero';
  static String get movementInvalidCost =>
      _ar ? 'تكلفة الوحدة غير صحيحة' : 'The unit cost is invalid';
  static String get movementInsufficientStock => _ar
      ? 'الكمية أكبر من المخزون المتاح'
      : 'The quantity is larger than the stock on hand';
  static String get movementNoChange => _ar
      ? 'الكمية المطابقة للرصيد الحالي لا تسجل حركة'
      : 'A count equal to the current balance records no change';
  static String get movementInvalidBranch => _ar
      ? 'الفرع غير متاح لحسابك'
      : 'This branch is not available to your account';
  static String get movementMaterialNotFound =>
      _ar ? 'المادة غير موجودة أو تم حذفها' : 'The material no longer exists';
  static String get movementPermissionDenied => _ar
      ? 'ليس لديك صلاحية تسجيل حركات المخزون'
      : 'You cannot record stock movements';
  static String get movementFailed => _ar
      ? 'تعذر تسجيل الحركة، حاول مرة أخرى'
      : 'Could not record the movement. Try again.';
  static String get movementRecorded =>
      _ar ? 'تم تسجيل حركة المخزون' : 'Stock movement recorded';
  static String get movementNoBranches =>
      _ar ? 'لا توجد فروع متاحة لحسابك' : 'No branches are available';
  static String get movementSave => _ar ? 'تسجيل الحركة' : 'Record movement';
  static String get movementSaving => _ar ? 'جارٍ التسجيل...' : 'Recording...';
  static String get stockMovementsMetricTotal =>
      _ar ? 'إجمالي الحركات' : 'Movements';
  static String get stockMovementsMetricReceipts =>
      _ar ? 'حركات الاستلام' : 'Receipts';
  static String get stockMovementsMetricIssues =>
      _ar ? 'حركات الصرف' : 'Issues';
  static String get stockMovementsMetricWaste => _ar ? 'الهالك' : 'Waste';
  static String stockMovementsMetricTotalHint(int counts, int actors) =>
      _ar ? '$counts جرد • $actors منفذ' : '$counts counts • $actors people';
  static String stockMovementsMetricReceiptsHint(String value) =>
      _ar ? 'بقيمة $value' : 'Worth $value';
  static String stockMovementsMetricIssuesHint(String value) =>
      _ar ? 'بقيمة $value' : 'Worth $value';
  static String stockMovementsMetricWasteHint(String value) =>
      _ar ? 'خسارة $value' : '$value lost';
  static String get stockMovementsMetricNoActivity =>
      _ar ? 'لا توجد حركات في الفترة' : 'No movements in this period';
  static String get stockPeriodLabel => _ar ? 'الفترة' : 'Period';
  static String get stockPeriodAll => _ar ? 'كل الفترات' : 'All time';
  static String get stockPeriodWeek => _ar ? 'آخر 7 أيام' : 'Last 7 days';
  static String get stockPeriodMonth => _ar ? 'آخر 30 يومًا' : 'Last 30 days';
  static String get stockMovementTypeFilter =>
      _ar ? 'نوع الحركة' : 'Movement type';
  static String get stockMovementAllTypes => _ar ? 'كل الأنواع' : 'All types';
  static String get stockMovementsTableMovement => _ar ? 'الحركة' : 'Movement';
  static String get stockMovementsTableBranch => _ar ? 'الفرع' : 'Branch';
  static String get stockMovementsTableQuantity => _ar ? 'التغيير' : 'Change';
  static String get stockMovementsTableBalance =>
      _ar ? 'الرصيد بعد' : 'Balance after';
  static String get stockMovementsTableValue => _ar ? 'القيمة' : 'Value';
  static String get stockMovementsTableActor => _ar ? 'المنفذ' : 'Recorded by';
  static String stockMovementsRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count حركة'
      : 'Showing $from–$to of $count movements';
  static String get stockMovementsEmpty =>
      _ar ? 'لا توجد حركات مخزون' : 'No stock movements yet';
  static String get stockMovementsEmptyHint => _ar
      ? 'ابدأ بتسجيل استلام أو صرف لأول مادة خام.'
      : 'Start by recording a receipt or issue for a raw material.';
  static String get stockMovementsNoMatches =>
      _ar ? 'لا توجد حركات مطابقة' : 'No movements match';
  static String get stockMovementsNoMatchesHint => _ar
      ? 'جرّب تغيير النوع أو الفترة أو مسح عوامل التصفية.'
      : 'Try another type or period, or clear the filters.';
  static String get stockMovementDetailsTitle =>
      _ar ? 'تفاصيل الحركة' : 'Movement details';
  static String get stockMovementSystemActor => _ar ? 'النظام' : 'System';
  static String get stockMovementNoReference =>
      _ar ? 'بدون مرجع' : 'No reference';
  static String get stockMovementQuantityChange =>
      _ar ? 'مقدار التغيير' : 'Quantity change';
  static String get stockMovementBalanceAfter =>
      _ar ? 'الرصيد بعد الحركة' : 'Balance after';
  static String get stockMovementValue =>
      _ar ? 'قيمة الحركة' : 'Movement value';
  static String get stockMovementDateTime =>
      _ar ? 'التاريخ والوقت' : 'Date and time';
  static String get stockMovementUnitCost => _ar ? 'تكلفة الوحدة' : 'Unit cost';
  static String get stockMovementsSearchHint =>
      _ar ? 'ابحث بالمادة أو المرجع...' : 'Search by material or reference...';
  static String get stockMovementsReadOnly => _ar
      ? 'لديك صلاحية عرض حركات المخزون فقط. تواصل مع المالك لتسجيل الحركات.'
      : 'You can view stock movements only. Ask the owner to record movements.';
  static String get stockMovementNote => _ar ? 'ملاحظة' : 'Note';
  static String get stockMovementNoNote => _ar ? 'لا توجد ملاحظة' : 'No note';
  static String get inventoryUnitKg => _ar ? 'كجم' : 'kg';
  static String get inventoryUnitGram => _ar ? 'جم' : 'g';
  static String get inventoryUnitLiter => _ar ? 'لتر' : 'L';
  static String get inventoryUnitMilliliter => _ar ? 'مل' : 'mL';
  static String get inventoryUnitPiece => _ar ? 'قطعة' : 'pc';
  static String get inventoryUnitPack => _ar ? 'عبوة' : 'pack';
  static String get inventoryUnitBox => _ar ? 'كرتونة' : 'box';
  static String get inventoryUnitBag => _ar ? 'كيس' : 'bag';
  static String get inventoryUnitBottle => _ar ? 'زجاجة' : 'bottle';
  static String get inventoryUnitCan => _ar ? 'علبة' : 'can';
  static String get auditActionMaterialCreate =>
      _ar ? 'إضافة مادة خام' : 'Raw material added';
  static String get auditActionMaterialUpdate =>
      _ar ? 'تعديل مادة خام' : 'Raw material updated';
  static String get auditActionMaterialDelete =>
      _ar ? 'حذف مادة خام' : 'Raw material deleted';
  static String get auditEntityMaterial => _ar ? 'مادة خام' : 'Raw material';
  static String get auditFieldSku => _ar ? 'كود المادة' : 'SKU';
  static String get auditFieldUnit => _ar ? 'وحدة القياس' : 'Unit';
  static String get auditFieldUnitCost => _ar ? 'تكلفة الوحدة' : 'Unit cost';
  static String get auditFieldReorderLevel =>
      _ar ? 'حد إعادة الطلب' : 'Reorder level';
  static String get auditFieldMaterial => _ar ? 'المادة' : 'Material';
  static String get auditFieldQuantity => _ar ? 'الكمية' : 'Quantity';
  static String get auditFieldBalance => _ar ? 'الرصيد' : 'Balance';
  static String get auditFieldReference => _ar ? 'المرجع' : 'Reference';
  static String get auditValueStockReceipt => _ar ? 'استلام' : 'Receipt';
  static String get auditValueStockIssue => _ar ? 'صرف' : 'Issue';
  static String get auditValueStockCount => _ar ? 'جرد' : 'Count';
  static String get auditActionKitchenTicketUpdate =>
      _ar ? 'تحديث تذكرة مطبخ' : 'Kitchen ticket updated';
  static String get auditActionKitchenItemUpdate =>
      _ar ? 'تحديث صنف في المطبخ' : 'Kitchen item updated';
  static String get auditDomainKitchen => _ar ? 'المطبخ' : 'Kitchen';
  static String get auditEntityKitchenTicket =>
      _ar ? 'تذكرة مطبخ' : 'Kitchen ticket';
  static String get auditFieldItem => _ar ? 'الصنف' : 'Item';

  // ---------- Kitchen ----------
  static String get kitchen => _ar ? 'المطبخ' : 'Kitchen';
  static String get kitchenSubtitle => _ar
      ? 'شاشة مباشرة تصل إليها الطلبات لحظة طلبها، من التحضير حتى التسليم.'
      : 'A live screen that receives every order the moment it is placed, from preparation to handoff.';
  static String get searchKitchenHint => _ar
      ? 'ابحث برقم الطلب أو العميل أو الصنف...'
      : 'Search by order, customer or item...';
  static String get kitchenLive => _ar ? 'مباشر' : 'Live';
  static String get kitchenReadOnly => _ar
      ? 'لديك صلاحية مشاهدة المطبخ فقط. تواصل مع المالك لبدء التحضير أو تسليم الطلبات.'
      : 'You can view the kitchen only. Ask the owner to start or complete tickets.';
  static String get kitchenUpdatedNow => _ar ? 'محدّث الآن' : 'Updated now';
  static String kitchenUpdatedAt(String time) =>
      _ar ? 'آخر تحديث $time' : 'Updated $time';
  static String kitchenCompletedTodayValue(int count) =>
      _ar ? '$count مكتمل اليوم' : '$count completed today';
  static String get kitchenColumnQueued => _ar ? 'طلبات جديدة' : 'New orders';
  static String get kitchenColumnPreparing => _ar ? 'قيد التحضير' : 'Preparing';
  static String get kitchenColumnReady =>
      _ar ? 'جاهزة للتسليم' : 'Ready to serve';
  static String get kitchenColumnCompleted => _ar ? 'تم التسليم' : 'Handed off';
  static String get kitchenEmptyColumn =>
      _ar ? 'لا توجد طلبات هنا' : 'No tickets here';
  static String get kitchenEmptyTitle =>
      _ar ? 'المطبخ هادئ الآن' : 'The kitchen is all caught up';
  static String get kitchenEmptyHint => _ar
      ? 'ستظهر الطلبات الجديدة هنا لحظة وصولها.'
      : 'New orders appear here the moment they arrive.';
  static String get kitchenNoMatches =>
      _ar ? 'لا توجد طلبات مطابقة' : 'No matching tickets';
  static String get kitchenNoMatchesHint => _ar
      ? 'جرّب رقم طلب آخر أو غيّر الفرع.'
      : 'Try another order number or switch the branch.';
  static String get kitchenAllBranches => _ar ? 'كل الفروع' : 'All branches';
  static String get kitchenFilterBranch =>
      _ar ? 'تصفية حسب الفرع' : 'Filter by branch';
  static String get kitchenMetricQueued => _ar ? 'في الانتظار' : 'Waiting';
  static String get kitchenMetricPreparing => _ar ? 'قيد التحضير' : 'Preparing';
  static String get kitchenMetricReady =>
      _ar ? 'جاهز للتسليم' : 'Ready to serve';
  static String get kitchenMetricLate => _ar ? 'متأخرة' : 'Late';
  static String get kitchenMetricQueuedHint =>
      _ar ? 'بانتظار بدء التحضير' : 'Waiting to start';
  static String get kitchenMetricPreparingHint =>
      _ar ? 'على شاشة المطبخ الآن' : 'On the kitchen screen now';
  static String get kitchenMetricReadyHint =>
      _ar ? 'بانتظار التسليم' : 'Waiting for handoff';
  static String get kitchenMetricLateHint =>
      _ar ? 'أكثر من 15 دقيقة' : 'Older than 15 minutes';
  static String kitchenOldestWait(int minutes) =>
      _ar ? 'أقدم طلب منذ $minutes د' : 'Oldest waiting ${minutes}m';
  static String kitchenAveragePrep(int minutes) =>
      _ar ? 'متوسط التحضير $minutes د' : 'Average prep ${minutes}m';
  static String get kitchenSourceOnline => _ar ? 'أونلاين' : 'Online';
  static String get kitchenSourcePos => _ar ? 'نقطة البيع' : 'POS';
  static String get kitchenDineIn => _ar ? 'داخل الفرع' : 'Dine in';
  static String kitchenTable(String number) =>
      _ar ? 'طاولة $number' : 'Table $number';
  static String get kitchenWalkIn => _ar ? 'عميل مباشر' : 'Walk-in';
  static String get kitchenStatusQueued => _ar ? 'جديدة' : 'New';
  static String get kitchenStatusCompleted => _ar ? 'تم التسليم' : 'Handed off';
  static String get kitchenItemPending => _ar ? 'بانتظار البدء' : 'Not started';
  static String get kitchenItemReady => _ar ? 'جاهز' : 'Ready';
  static String kitchenItemsProgress(int ready, int total) =>
      _ar ? '$ready من $total جاهز' : '$ready of $total ready';
  static String get kitchenItemMarkReady =>
      _ar ? 'تحديد الصنف كجاهز' : 'Mark item as ready';
  static String get kitchenItemMarkPending =>
      _ar ? 'إلغاء جاهزية الصنف' : 'Mark item as not ready';
  static String get kitchenNoItems => _ar ? 'لا توجد أصناف' : 'No items';
  static String get kitchenCustomerNote =>
      _ar ? 'ملاحظة العميل' : 'Customer note';
  static String get kitchenStart => _ar ? 'بدء التحضير' : 'Start preparing';
  static String get kitchenMarkReady => _ar ? 'جاهز للتسليم' : 'Mark ready';
  static String get kitchenComplete => _ar ? 'تم التسليم' : 'Complete';
  static String get kitchenRecall => _ar ? 'استرجاع' : 'Recall';
  static String get kitchenRecallHint =>
      _ar ? 'إعادة الطلب إلى قيد التحضير' : 'Return the ticket to preparation';
  static String get kitchenNow => _ar ? 'الآن' : 'now';
  static String kitchenElapsedMinutes(int minutes) =>
      _ar ? '$minutes د' : '${minutes}m';
  static String kitchenElapsedHours(int hours, int minutes) => minutes <= 0
      ? (_ar ? '$hours س' : '${hours}h')
      : (_ar ? '$hours س $minutes د' : '${hours}h ${minutes}m');
  static String get kitchenLate => _ar ? 'متأخر' : 'Late';
  static String kitchenHandedOffAt(String time) =>
      _ar ? 'سُلّم $time' : 'Handed off $time';
  static String get kitchenTicketStarted =>
      _ar ? 'بدأ تحضير الطلب' : 'Preparation started';
  static String get kitchenTicketReadyMessage =>
      _ar ? 'الطلب جاهز للتسليم' : 'Order is ready';
  static String get kitchenTicketCompletedMessage =>
      _ar ? 'تم تسليم الطلب' : 'Order handed off';
  static String get kitchenTicketRecalledMessage =>
      _ar ? 'تم استرجاع الطلب إلى التحضير' : 'Ticket returned to preparation';
  static String get kitchenActionFailed => _ar
      ? 'تعذر تحديث الطلب. حاول مرة أخرى.'
      : 'The ticket could not be updated. Try again.';
  static String get kitchenPermissionDenied => _ar
      ? 'ليست لديك صلاحية إدارة المطبخ.'
      : 'You do not have permission to manage the kitchen.';
  static String get kitchenTicketNotFoundMessage =>
      _ar ? 'لم يعد هذا الطلب موجودًا.' : 'This ticket no longer exists.';
  static String get kitchenInvalidTransitionMessage => _ar
      ? 'تغيّرت حالة الطلب. حدّث اللوحة وحاول مرة أخرى.'
      : 'The ticket changed. Refresh the board and try again.';

  // ---------- Dining floor: tables, rooms and reservations ----------
  static String get tables => _ar ? 'الصالة والطاولات' : 'Tables & rooms';
  static String get tablesSubtitle => _ar
      ? 'رتّب الطاولات والغرف الخاصة، وسجّل حجوزات الضيوف، وتابع الإشغال لحظة بلحظة.'
      : 'Arrange tables and private rooms, book guests and follow occupancy live.';
  static String get tablesReadOnly => _ar
      ? 'يمكنك عرض الصالة والحجوزات، لكن التعديل يتطلب صلاحية إدارة الطاولات.'
      : 'You can view the floor and bookings, but changes need the manage-tables permission.';
  static String get tablesMetricTotal =>
      _ar ? 'إجمالي الطاولات' : 'Total tables';
  static String get tablesMetricTotalHint =>
      _ar ? 'طاولات وغرف نشطة' : 'Active tables and rooms';
  static String get tablesMetricAvailable => _ar ? 'متاحة' : 'Available';
  static String get tablesMetricAvailableHint =>
      _ar ? 'جاهزة لاستقبال الضيوف' : 'Ready for guests';
  static String get tablesMetricOccupied => _ar ? 'مشغولة' : 'Occupied';
  static String get tablesMetricOccupiedHint =>
      _ar ? 'عليها طلبات مفتوحة' : 'With open orders';
  static String get tablesMetricReserved => _ar ? 'محجوزة' : 'Reserved';
  static String get tablesMetricReservedHint =>
      _ar ? 'محجوزة أو جالسون الآن' : 'Booked or seated now';
  static String get tablesMetricTodayReservations =>
      _ar ? 'حجوزات اليوم' : "Today's bookings";
  static String get tablesMetricTodayReservationsHint =>
      _ar ? 'مؤكدة وجالسة' : 'Confirmed and seated';
  static String get tablesSearchHint => _ar
      ? 'ابحث باسم الطاولة أو الضيف أو رقم الطلب'
      : 'Search by table, guest or order number';
  static String get tablesFilterArea => _ar ? 'المنطقة' : 'Area';
  static String get tablesAreaAll => _ar ? 'كل المناطق' : 'All areas';
  static String get tablesAreaHall => _ar ? 'الصالة' : 'Hall';
  static String get tablesAreaTerrace => _ar ? 'التراس' : 'Terrace';
  static String get tablesAreaPrivateRoom => _ar ? 'غرف خاصة' : 'Private rooms';
  static String get tablesAreaOther => _ar ? 'أخرى' : 'Other';
  static String get tablesFilterBranch =>
      _ar ? 'تصفية حسب الفرع' : 'Filter by branch';
  static String get tablesViewTables => _ar ? 'الطاولات' : 'Tables';
  static String get tablesViewReservations => _ar ? 'الحجوزات' : 'Bookings';
  static String tablesCount(int count) =>
      _ar ? '$count طاولة' : (count == 1 ? '1 table' : '$count tables');
  static String tablesReservationsCount(int count) =>
      _ar ? '$count حجز' : (count == 1 ? '1 booking' : '$count bookings');
  static String get addTable => _ar ? 'إضافة طاولة' : 'Add table';
  static String get editTable => _ar ? 'تعديل الطاولة' : 'Edit table';
  static String get addReservation => _ar ? 'حجز جديد' : 'New booking';
  static String get editReservation => _ar ? 'تعديل الحجز' : 'Edit booking';
  static String get tablesEmptyTitle =>
      _ar ? 'لا توجد طاولات بعد' : 'No tables yet';
  static String get tablesEmptyHint => _ar
      ? 'أضف أول طاولة أو غرفة خاصة لتبدأ إدارة الصالة.'
      : 'Add the first table or private room to start running the floor.';
  static String get tablesNoMatches =>
      _ar ? 'لا توجد طاولة مطابقة' : 'No matching table';
  static String get tablesNoMatchesHint => _ar
      ? 'جرّب اسمًا آخر أو امسح عوامل التصفية.'
      : 'Try another name or clear the filters.';
  static String get tablesReservationsEmpty =>
      _ar ? 'لا توجد حجوزات' : 'No bookings';
  static String get tablesReservationsEmptyHint => _ar
      ? 'سجّل حجز ضيف جديد وسيظهر هنا مع حالته.'
      : 'Create a guest booking and it will appear here with its status.';
  static String get tablesReservationsNoMatches =>
      _ar ? 'لا توجد حجوزات مطابقة' : 'No matching bookings';
  static String get tablesReservationsNoMatchesHint => _ar
      ? 'جرّب اسمًا أو رقمًا آخر، أو غيّر المنطقة.'
      : 'Try another name or number, or change the area.';
  static String get tablesPanelTitle => _ar ? 'الحجوزات' : 'Bookings';
  static String get tablesPanelSubtitle =>
      _ar ? 'اليوم والقادمة' : 'Today and upcoming';
  static String get tablesNoOpenReservations =>
      _ar ? 'لا توجد حجوزات قادمة' : 'No upcoming bookings';
  static String get tablesNoOpenReservationsHint => _ar
      ? 'ستظهر هنا حجوزات اليوم والأيام القادمة.'
      : "Today's and upcoming bookings will appear here.";
  static String get tablesReservationHistory =>
      _ar ? 'سجل اليوم' : "Today's history";
  static String get tablesReservationNoHistory =>
      _ar ? 'لا يوجد سجل منتهٍ اليوم' : 'No finished bookings today';
  static String tableCapacity(int count) =>
      _ar ? 'تتسع لـ $count' : 'Seats $count';
  static String tableGuests(int count) =>
      _ar ? '$count ضيوف' : (count == 1 ? '1 guest' : '$count guests');
  static String tableStatusReservedAt(String time) =>
      _ar ? 'محجوزة $time' : 'Booked $time';
  static String tableNextReservation(String time) =>
      _ar ? 'الحجز القادم $time' : 'Next booking $time';
  static String tableOrderOpen(String number) =>
      _ar ? 'طلب #$number مفتوح' : 'Order #$number open';
  static String get tableStatusAvailable => _ar ? 'متاحة' : 'Available';
  static String get tableStatusReserved => _ar ? 'محجوزة' : 'Reserved';
  static String get tableStatusSeated => _ar ? 'جالسون' : 'Seated';
  static String get tableStatusOccupied => _ar ? 'مشغولة' : 'Occupied';
  static String get tableStatusInactive => _ar ? 'متوقفة' : 'Inactive';
  static String get tableMenuTooltip =>
      _ar ? 'خيارات الطاولة' : 'Table options';
  static String get tableBookAction => _ar ? 'حجز' : 'Book';
  static String get tableOpenReservation => _ar ? 'فتح الحجز' : 'Open booking';
  static String get tableDeactivate =>
      _ar ? 'إيقاف الطاولة' : 'Deactivate table';
  static String get tableActivate => _ar ? 'تفعيل الطاولة' : 'Activate table';
  static String tableDeactivateQuestion(String name) => _ar
      ? 'إيقاف «$name» سيخفيها من نقطة البيع. هل تريد المتابعة؟'
      : 'Deactivating “$name” hides it from the point of sale. Continue?';
  static String tableDeleteQuestion(String name) => _ar
      ? 'حذف «$name» نهائيًا؟ لا يمكن التراجع عن هذا الإجراء.'
      : 'Delete “$name” permanently? This cannot be undone.';
  static String get tableDeleteTitle => _ar ? 'حذف الطاولة' : 'Delete table';
  static String get tableDeactivateTitle =>
      _ar ? 'إيقاف الطاولة' : 'Deactivate table';
  static String get tableInUseMessage => _ar
      ? 'الطاولة عليها طلب أو حجز نشط. أنهِ الطلب أو الحجز أولًا.'
      : 'The table has an open order or active booking. Finish it first.';
  static String get tableHasHistoryMessage => _ar
      ? 'لا يمكن حذف طاولة لها سجل طلبات أو حجوزات. أوقفها بدلًا من ذلك.'
      : 'A table with order or booking history cannot be deleted. Deactivate it instead.';
  static String get tableNotFoundMessage =>
      _ar ? 'لم تعد هذه الطاولة موجودة.' : 'This table no longer exists.';
  static String get tableMutationFailed => _ar
      ? 'تعذر تحديث الطاولة. حاول مرة أخرى.'
      : 'The table could not be updated. Try again.';
  static String get tableName => _ar ? 'اسم الطاولة' : 'Table name';
  static String get tableNameHint =>
      _ar ? 'مثال: T1 أو غرفة 2' : 'e.g. T1 or Room 2';
  static String get tableNameRequired =>
      _ar ? 'اسم الطاولة مطلوب.' : 'The table name is required.';
  static String get tableArea => _ar ? 'المنطقة' : 'Area';
  static String get tableCapacityField =>
      _ar ? 'السعة (عدد الضيوف)' : 'Capacity (guests)';
  static String get tableCapacityRange =>
      _ar ? 'من 1 إلى 40 ضيفًا.' : 'Between 1 and 40 guests.';
  static String get tableSortOrder => _ar ? 'ترتيب العرض' : 'Display order';
  static String get tableNote => _ar ? 'ملاحظة (اختياري)' : 'Note (optional)';
  static String get tableNoteHint =>
      _ar ? 'مثال: قريبة من النافذة' : 'e.g. near the window';
  static String get tableActiveLabel =>
      _ar ? 'الطاولة مفعّلة في نقطة البيع' : 'Table is active at the POS';
  static String get tableEditorSubtitle => _ar
      ? 'حدّد اسم الطاولة ومنطقتها وسعتها.'
      : 'Set the table name, area and capacity.';
  static String get tableCreated => _ar ? 'تمت إضافة الطاولة.' : 'Table added.';
  static String get tableUpdated =>
      _ar ? 'تم تحديث الطاولة.' : 'Table updated.';
  static String get tableActivated =>
      _ar ? 'تم تفعيل الطاولة.' : 'Table activated.';
  static String get tableDeactivated =>
      _ar ? 'تم إيقاف الطاولة.' : 'Table deactivated.';
  static String get tableDeleted => _ar ? 'تم حذف الطاولة.' : 'Table deleted.';
  static String get tableSaveFailed => _ar
      ? 'تعذر حفظ الطاولة. تحقق من البيانات وحاول مرة أخرى.'
      : 'The table could not be saved. Check the details and try again.';
  static String get tableDuplicateName => _ar
      ? 'يوجد طاولة أخرى بالاسم نفسه في هذا الفرع.'
      : 'Another table in this branch already uses that name.';
  static String get tablePermissionDenied => _ar
      ? 'ليست لديك صلاحية إدارة الطاولات.'
      : 'You do not have permission to manage tables.';
  static String get reservationGuestName => _ar ? 'اسم الضيف' : 'Guest name';
  static String get reservationGuestNameHint =>
      _ar ? 'مثال: أحمد محمد' : 'e.g. Ahmed Mohamed';
  static String get reservationGuestNameRequired =>
      _ar ? 'اسم الضيف مطلوب.' : 'The guest name is required.';
  static String get reservationPhone => _ar ? 'رقم الهاتف' : 'Phone number';
  static String get reservationPhoneHint => _ar ? 'اختياري' : 'Optional';
  static String get reservationParty => _ar ? 'عدد الضيوف' : 'Guests';
  static String get reservationPartyRange =>
      _ar ? 'من 1 إلى 40 ضيفًا.' : 'Between 1 and 40 guests.';
  static String get reservationDate => _ar ? 'التاريخ' : 'Date';
  static String get reservationTime => _ar ? 'الوقت' : 'Time';
  static String get reservationDuration => _ar ? 'المدة' : 'Duration';
  static String get reservationTable => _ar ? 'الطاولة' : 'Table';
  static String get reservationTableRequired =>
      _ar ? 'اختر طاولة للحجز.' : 'Choose a table for the booking.';
  static String get reservationNote => _ar ? 'ملاحظة' : 'Note';
  static String get reservationNoteHint =>
      _ar ? 'مناسبة أو طلبات خاصة' : 'Occasion or special requests';
  static String get reservationEditorSubtitle => _ar
      ? 'سجّل بيانات الضيف وموعد الحجز والطاولة.'
      : 'Record the guest, the time and the table.';
  static String get reservationDateRequired =>
      _ar ? 'اختر تاريخ الحجز.' : 'Choose the booking date.';
  static String get reservationTimeRequired =>
      _ar ? 'اختر وقت الحجز.' : 'Choose the booking time.';
  static String get reservationDatePast =>
      _ar ? 'لا يمكن حجز وقت في الماضي.' : 'A booking cannot be in the past.';
  static String get reservationCreated =>
      _ar ? 'تم تسجيل الحجز.' : 'Booking created.';
  static String get reservationUpdated =>
      _ar ? 'تم تحديث الحجز.' : 'Booking updated.';
  static String get reservationOverlap => _ar
      ? 'هذا الوقت يتعارض مع حجز آخر على الطاولة.'
      : 'That time overlaps another booking on the table.';
  static String get reservationPartyTooLarge => _ar
      ? 'عدد الضيوف أكبر من سعة الطاولة.'
      : 'The party is larger than the table capacity.';
  static String get reservationClosed => _ar
      ? 'لا يمكن تعديل حجز مكتمل أو ملغي.'
      : 'A completed or cancelled booking cannot be edited.';
  static String get reservationSeatedTableLocked => _ar
      ? 'لا يمكن نقل حجز جالس إلى طاولة أخرى.'
      : 'A seated booking cannot move to another table.';
  static String get reservationInvalidTime =>
      _ar ? 'اختر وقتًا صالحًا للحجز.' : 'Choose a valid booking time.';
  static String get reservationTableUnavailable => _ar
      ? 'هذه الطاولة غير متاحة للحجز.'
      : 'That table is not available for booking.';
  static String get reservationSaveFailed => _ar
      ? 'تعذر حفظ الحجز. تحقق من البيانات وحاول مرة أخرى.'
      : 'The booking could not be saved. Check the details and try again.';
  static String get reservationNotFound =>
      _ar ? 'لم يعد هذا الحجز موجودًا.' : 'This booking no longer exists.';
  static String get reservationStatusInvalid => _ar
      ? 'لا يمكن تنفيذ هذا الإجراء على حالة الحجز الحالية.'
      : 'That action is not possible from the current booking status.';
  static String get reservationTableBusy => _ar
      ? 'الطاولة مشغولة بطلب مفتوح. أنهِ الطلب أولًا.'
      : 'The table has an open order. Finish the order first.';
  static String get reservationActionFailed => _ar
      ? 'تعذر تحديث الحجز. حاول مرة أخرى.'
      : 'The booking could not be updated. Try again.';
  static String get reservationSeat => _ar ? 'تسجيل الجلوس' : 'Seat guest';
  static String get reservationComplete =>
      _ar ? 'إنهاء الحجز' : 'Complete booking';
  static String get reservationCancel => _ar ? 'إلغاء الحجز' : 'Cancel booking';
  static String get reservationNoShow => _ar ? 'لم يحضر' : 'No-show';
  static String get reservationSeatTitle =>
      _ar ? 'تسجيل جلوس الضيف' : 'Seat the guest';
  static String reservationSeatQuestion(String name, String table) => _ar
      ? 'تسجيل جلوس $name على طاولة $table؟'
      : 'Seat $name at table $table?';
  static String get reservationCompleteTitle =>
      _ar ? 'إنهاء الحجز' : 'Complete the booking';
  static String reservationCompleteQuestion(String name) => _ar
      ? 'إنهاء حجز $name وتحرير الطاولة؟'
      : 'Complete $name’s booking and free the table?';
  static String get reservationCancelTitle =>
      _ar ? 'إلغاء الحجز' : 'Cancel the booking';
  static String reservationCancelQuestion(String name) => _ar
      ? 'إلغاء حجز $name؟ سيُحرر الموعد للضيوف الآخرين.'
      : 'Cancel $name’s booking? The slot will open for other guests.';
  static String get reservationNoShowTitle =>
      _ar ? 'تسجيل عدم الحضور' : 'Record a no-show';
  static String reservationNoShowQuestion(String name) => _ar
      ? 'تسجيل عدم حضور $name وإلغاء الحجز؟'
      : 'Record $name as a no-show and cancel the booking?';
  static String get reservationSeatedToast =>
      _ar ? 'تم تسجيل جلوس الضيف.' : 'The guest is seated.';
  static String get reservationCompletedToast =>
      _ar ? 'تم إنهاء الحجز.' : 'Booking completed.';
  static String get reservationCancelledToast =>
      _ar ? 'تم إلغاء الحجز.' : 'Booking cancelled.';
  static String get reservationNoShowToast =>
      _ar ? 'تم تسجيل عدم الحضور.' : 'No-show recorded.';
  static String get reservationSeatTooEarly => _ar
      ? 'لا يمكن تسجيل الجلوس قبل موعد الحجز بأكثر من ساعتين.'
      : 'A guest cannot be seated more than two hours before the booking.';
  static String get reservationStatusConfirmed => _ar ? 'مؤكد' : 'Confirmed';
  static String get reservationStatusSeated => _ar ? 'جالس' : 'Seated';
  static String get reservationStatusCompleted => _ar ? 'مكتمل' : 'Completed';
  static String get reservationStatusCancelled => _ar ? 'ملغي' : 'Cancelled';
  static String get reservationStatusNoShow => _ar ? 'لم يحضر' : 'No-show';
  static String tableReservationFor(String table) =>
      _ar ? 'طاولة $table' : 'Table $table';
  static String reservationTimeRange(String start, String end) =>
      '$start – $end';
  static String reservationOrderLinked(String number) =>
      _ar ? 'طلب #$number' : 'Order #$number';
  static String get reservationOrderAttached =>
      _ar ? 'مرتبط بطلب مفتوح' : 'Linked to an open order';
  static String get reservationMenuTooltip =>
      _ar ? 'خيارات الحجز' : 'Booking options';
  static String get reservationDuration30 => _ar ? '30 دقيقة' : '30 minutes';
  static String get reservationDuration60 => _ar ? 'ساعة' : '1 hour';
  static String get reservationDuration90 => _ar ? 'ساعة ونصف' : '1.5 hours';
  static String get reservationDuration120 => _ar ? 'ساعتان' : '2 hours';
  static String get reservationDuration180 => _ar ? '3 ساعات' : '3 hours';
  static String get tablesLoadFailed =>
      _ar ? 'تعذر تحميل الصالة.' : 'The floor could not be loaded.';
  static String get tablesPermissionDenied => _ar
      ? 'ليست لديك صلاحية عرض الصالة والطاولات.'
      : 'You do not have permission to view the floor.';
  static String get tablesNoBranch => _ar
      ? 'لا يوجد فرع متاح لعرض الصالة.'
      : 'No branch is available for the floor.';

  // ---------- Point of sale ----------
  static String get pos => _ar ? 'نقطة البيع' : 'Point of sale';
  static String get posSubtitle => _ar
      ? 'سجّل طلبات الكاشير وأرسلها إلى المطبخ فورًا.'
      : 'Take counter orders and send them to the kitchen instantly.';
  static String get posSearchHint =>
      _ar ? 'ابحث باسم الصنف أو الكود' : 'Search by name or SKU';
  static String get posAllCategories => _ar ? 'كل الأصناف' : 'All products';
  static String get posFilterCategory =>
      _ar ? 'تصفية بالأقسام' : 'Filter by category';
  static String get posNoMenuTitle =>
      _ar ? 'لا توجد أصناف متاحة' : 'No products available';
  static String get posNoMenuHint => _ar
      ? 'أضف أصنافًا نشطة إلى الكتالوج واربطها بهذا الفرع لتبدأ البيع.'
      : 'Add active products to the catalog and price them for this branch to start selling.';
  static String get posNoMatches =>
      _ar ? 'لا يوجد صنف مطابق' : 'No matching product';
  static String get posNoMatchesHint => _ar
      ? 'جرّب كلمة أخرى أو امسح البحث.'
      : 'Try another word or clear the search.';
  static String get posSoldOut => _ar ? 'نفدت الكمية' : 'Sold out';
  static String get posUnavailable => _ar ? 'غير متاح' : 'Unavailable';
  static String posInCart(int count) =>
      _ar ? 'في السلة: $count' : 'In cart: $count';
  static String posStockRemaining(int count) =>
      _ar ? 'المتبقي: $count' : 'Left: $count';
  static String posDiscountLabel(String percent) =>
      _ar ? 'خصم $percent٪' : '$percent% off';
  static String get posAddToCart => _ar ? 'أضف إلى السلة' : 'Add to cart';
  static String get posAddedToCart =>
      _ar ? 'تمت الإضافة إلى السلة' : 'Added to the cart';
  static String get posCartTitle => _ar ? 'الطلب الحالي' : 'Current order';
  static String get posCartEmptyTitle =>
      _ar ? 'السلة فارغة' : 'The cart is empty';
  static String get posCartEmptyHint => _ar
      ? 'اختر صنفًا من القائمة لبدء طلب جديد.'
      : 'Pick a product from the menu to start a new order.';
  static String get posClearCart => _ar ? 'تفريغ' : 'Clear';
  static String get posClearCartQuestion =>
      _ar ? 'هل تريد تفريغ السلة بالكامل؟' : 'Remove everything from the cart?';
  static String get posRemove => _ar ? 'حذف' : 'Remove';
  static String get posIncreaseQuantity =>
      _ar ? 'زيادة الكمية' : 'Increase quantity';
  static String get posDecreaseQuantity =>
      _ar ? 'تقليل الكمية' : 'Decrease quantity';
  static String get posItemNote => _ar ? 'ملاحظة الصنف' : 'Item note';
  static String get posItemNoteHint => _ar ? 'مثال: بدون سكر' : 'e.g. no sugar';
  static String get posOrderNote => _ar ? 'ملاحظة الطلب' : 'Order note';
  static String get posOrderNoteHint =>
      _ar ? 'أي تعليمات للمطبخ أو الكاشير' : 'Any instructions for the kitchen';
  static String get posFulfillment => _ar ? 'نوع الطلب' : 'Fulfillment';
  static String get posDineIn => _ar ? 'داخل الفرع' : 'Dine in';
  static String get posPickup => _ar ? 'استلام من الفرع' : 'Pickup';
  static String get posTable => _ar ? 'الطاولة' : 'Table';
  static String get posTableHint =>
      _ar ? 'اختر طاولة من الصالة' : 'Pick a table from the floor';
  static String get posTableOptionalHint => _ar
      ? 'اختياري: اختر الطاولة إن كان الطلب داخل الصالة.'
      : 'Optional: pick the table when the order is served in the hall.';
  static String get posChooseTable => _ar ? 'اختيار الطاولة' : 'Choose a table';
  static String get posChangeTable => _ar ? 'تغيير' : 'Change';
  static String get posTablePickerTitle =>
      _ar ? 'اختر طاولة' : 'Choose a table';
  static String get posTablePickerSubtitle => _ar
      ? 'الطاولات الفعلية لهذا الفرع وحالتها الآن.'
      : "This branch's real tables and their live status.";
  static String get posTableSearchHint =>
      _ar ? 'ابحث باسم الطاولة' : 'Search by table name';
  static String get posNoTables =>
      _ar ? 'لا توجد طاولات في هذا الفرع' : 'No tables at this branch';
  static String get posNoTablesHint => _ar
      ? 'أضف الطاولات والغرف من صفحة الصالة والطاولات.'
      : 'Add tables and rooms from the Tables & rooms page.';
  static String get posNoAvailableTables =>
      _ar ? 'لا توجد طاولات متاحة الآن' : 'No tables are free right now';
  static String get posNoAvailableTablesHint => _ar
      ? 'كل الطاولات مشغولة أو محجوزة. يمكنك تسجيل جلوس ضيف محجوز من البطاقة.'
      : 'Every table is occupied or booked. You can seat a booked guest from their card.';
  static String get posNoTableMatches =>
      _ar ? 'لا توجد طاولات بهذا الاسم' : 'No tables match this search';
  static String get posNoTableMatchesHint => _ar
      ? 'جرّب اسمًا آخر أو امسح البحث.'
      : 'Try another name or clear the search.';
  static String get posTableSeatedHint => _ar
      ? 'الضيف جالس، يمكنك فتح الطلب الآن.'
      : 'The guest is seated — you can open their order.';
  static String get posClearTable => _ar ? 'إزالة الطاولة' : 'Remove table';
  static String get posTablesLoadFailed => _ar
      ? 'تعذر تحميل طاولات الفرع.'
      : 'The branch tables could not be loaded.';
  static String get posTableUnavailableCheckout => _ar
      ? 'الطاولة لم تعد متاحة. اختر طاولة أخرى.'
      : 'The table is no longer available. Choose another table.';
  static String posTableOrderOpen(String number) =>
      _ar ? 'طلب #$number' : 'Order #$number';
  static String posTableReservedFor(String name, String time) =>
      _ar ? '$name • $time' : '$name • $time';
  static String get posTableOccupiedHint =>
      _ar ? 'عليها طلب مفتوح' : 'Has an open order';
  static String get posSeatGuestToast =>
      _ar ? 'تم تسجيل جلوس الضيف.' : 'The guest is seated.';
  static String get posSeatGuestFailed =>
      _ar ? 'تعذر تسجيل جلوس الضيف.' : 'The guest could not be seated.';
  static String get posTableSelectedHint => _ar
      ? 'سيُربط الطلب بهذه الطاولة ويظهر على الفاتورة.'
      : 'The order will be linked to this table and shown on the receipt.';
  static String get posSelectTableFirst => _ar
      ? 'اختر طاولة قبل تأكيد الطلب.'
      : 'Choose a table before confirming the order.';

  static String get posPayment => _ar ? 'طريقة الدفع' : 'Payment method';
  static String get posPayCash => _ar ? 'كاش' : 'Cash';
  static String get posPayCard => _ar ? 'شبكة' : 'Card';
  static String get posPaySplit => _ar ? 'كاش + شبكة' : 'Cash + card';
  static String get posSplitHint => _ar
      ? 'أدخل أحد المبلغين وسيُحسب الآخر تلقائيًا من إجمالي الفاتورة.'
      : 'Enter either amount; the other is calculated from the order total.';
  static String get posSplitCashLabel => _ar ? 'المدفوع كاش' : 'Cash portion';
  static String get posSplitCardLabel => _ar ? 'المدفوع شبكة' : 'Card portion';
  static String get posSplitAmountRequired => _ar
      ? 'المبلغ المدفوع كاش يجب أن يكون أكبر من صفر.'
      : 'The cash portion must be greater than zero.';
  static String get posSplitCardRequired => _ar
      ? 'المبلغ المدفوع شبكة يجب أن يكون أكبر من صفر.'
      : 'The card portion must be greater than zero.';
  static String get posSplitUnavailable => _ar
      ? 'الدفع المختلط يحتاج توفر طريقتي كاش وشبكة.'
      : 'Split payment needs both cash and card methods.';
  static String get posSplitInvalidMessage => _ar
      ? 'راجع مبلغ الدفع المختلط قبل تأكيد الطلب.'
      : 'Review the split payment before confirming the order.';
  static String get posSubtotal => _ar ? 'المجموع الفرعي' : 'Subtotal';
  static String get posBeforeDiscount =>
      _ar ? 'الإجمالي قبل الخصم' : 'Total before discount';
  static String get posDiscount => _ar ? 'الخصم' : 'Discount';
  static String get posAfterDiscount =>
      _ar ? 'الإجمالي بعد الخصم' : 'Total after discount';
  static String get posTax => _ar ? 'الضريبة' : 'Tax';
  static String get posVatIncluded =>
      _ar ? 'ضريبة القيمة المضافة (مشمولة)' : 'VAT (included)';
  static String get posTaxIncludedNote =>
      _ar ? 'الأسعار شاملة ضريبة القيمة المضافة.' : 'Prices include VAT.';
  static String get posTotal => _ar ? 'الإجمالي' : 'Total';
  static String get posPlaceOrder => _ar ? 'تأكيد الطلب' : 'Confirm order';
  static String get posKitchenReceiptNote => _ar
      ? 'الطلب ظهر الآن في شاشة المطبخ.'
      : 'The order is now on the kitchen screen.';
  static String get posPlacingOrder =>
      _ar ? 'جارٍ إرسال الطلب...' : 'Placing order...';
  static String get posOrderSent =>
      _ar ? 'وصل الطلب إلى المطبخ.' : 'The order reached the kitchen.';
  static String get posReceiptTitle =>
      _ar ? 'تم تسجيل الطلب' : 'Order recorded';
  static String get posReceiptSubtitle => _ar
      ? 'أرسل الطلب إلى المطبخ ويمكنك طباعة الفاتورة الضريبية الآن.'
      : 'The order is in the kitchen. You can print the tax invoice now.';
  static String get posReceiptPaymentMethod =>
      _ar ? 'طريقة الدفع' : 'Payment method';
  static String get posReceiptTime => _ar ? 'الوقت' : 'Time';
  static String get posPrintReceipt =>
      _ar ? 'طباعة الفاتورة الضريبية' : 'Print tax invoice';
  static String get posTaxInvoiceTitle =>
      _ar ? 'فاتورة ضريبية مبسطة' : 'Simplified tax invoice';
  static String get posTaxInvoiceTitleAlt =>
      _ar ? 'Simplified tax invoice' : 'فاتورة ضريبية مبسطة';
  static String get posReceiptDocumentTitle => posTaxInvoiceTitle;
  static String get posReceiptThanks => _ar ? 'شكرًا لزيارتكم' : 'Thank you';
  static String get posItems => _ar ? 'الأصناف' : 'Items';
  static String get posPrice => _ar ? 'السعر' : 'Price';
  static String get posReceiptPrintFailed =>
      _ar ? 'تعذر فتح نافذة الطباعة.' : 'Could not open the print window.';
  static String get posNewOrder => _ar ? 'طلب جديد' : 'New order';
  static String get posSeller => _ar ? 'البائع' : 'Seller';
  static String get posSellerAddress => _ar ? 'عنوان البائع' : 'Seller address';
  static String get posSellerVatNumber => _ar ? 'الرقم الضريبي' : 'VAT number';
  static String get posInvoiceNumber => _ar ? 'رقم الفاتورة' : 'Invoice number';
  static String get posInvoiceDateTime =>
      _ar ? 'تاريخ ووقت الفاتورة' : 'Invoice date and time';
  static String get posTaxableAmount =>
      _ar ? 'المبلغ الخاضع للضريبة' : 'Taxable amount';
  static String get posVatAmount =>
      _ar ? 'مبلغ ضريبة القيمة المضافة' : 'VAT amount';
  static String get posVatRate =>
      _ar ? 'نسبة ضريبة القيمة المضافة' : 'VAT rate';
  static String posVatRateValue(String rate) =>
      _ar ? 'ضريبة القيمة المضافة ($rate%)' : 'VAT ($rate%)';
  static String get posInvoiceQrCaption => _ar
      ? 'رمز التحقق الإلكتروني (QR) — امسحه للتحقق من الفاتورة.'
      : 'Electronic verification QR — scan to verify the invoice.';
  static String get posTaxInvoiceBadge => _ar ? 'فاتورة ضريبية' : 'Tax invoice';
  static String get posTaxInvoiceCompliance => _ar
      ? 'فاتورة ضريبية مبسطة وفق متطلبات هيئة الزكاة والضريبة والجمارك — المرحلة الأولى.'
      : 'Simplified tax invoice meeting ZATCA Phase 1 requirements.';
  static String get posVatNumberMissing => _ar
      ? 'لا يمكن إصدار فاتورة ضريبية قبل تسجيل الرقم الضريبي واسم البائع القانوني للفرع. أضفهما من صفحة الفروع ثم أعد المحاولة.'
      : 'A tax invoice cannot be issued before the branch VAT number and legal seller name are registered. Add them from the branches page and try again.';
  static String get posTaxInvoiceNotIssued =>
      _ar ? 'لم تُطبع الفاتورة الضريبية' : 'Tax invoice not printed';
  static String get posPaymentRequired =>
      _ar ? 'اختر طريقة الدفع أولًا.' : 'Choose a payment method first.';
  static String get posBranchMissing => _ar
      ? 'لا يوجد فرع متاح لنقطة البيع.'
      : 'No branch is available for the point of sale.';
  static String get posEmptyCartMessage => _ar
      ? 'أضف صنفًا واحدًا على الأقل إلى السلة.'
      : 'Add at least one product to the cart.';
  static String get posPermissionDenied => _ar
      ? 'ليست لديك صلاحية استخدام نقطة البيع.'
      : 'You do not have permission to use the point of sale.';
  static String get posStockUnavailable => _ar
      ? 'الكمية المطلوبة أكبر من المخزون المتاح. راجع السلة.'
      : 'The requested quantity is more than the available stock. Review the cart.';
  static String get posProductUnavailable => _ar
      ? 'أحد الأصناف لم يعد متاحًا لهذا الفرع. حدّث القائمة.'
      : 'A product is no longer available at this branch. Refresh the menu.';
  static String get posBranchUnavailable => _ar
      ? 'الفرع لم يعد متاحًا. حدّث الصفحة.'
      : 'The branch is no longer available. Refresh the page.';
  static String get posPaymentUnavailable => _ar
      ? 'طريقة الدفع لم تعد متاحة. اختر طريقة أخرى.'
      : 'That payment method is no longer available. Choose another.';
  static String get posInvalidOrder => _ar
      ? 'تعذر قبول الطلب. راجع البيانات وحاول مرة أخرى.'
      : 'The order was rejected. Review it and try again.';
  static String get posConflict => _ar
      ? 'تعارض الطلب مع محاولة سابقة. حاول مرة أخرى.'
      : 'The order conflicted with a previous attempt. Try again.';
  static String get posCheckoutFailed => _ar
      ? 'تعذر إرسال الطلب. حاول مرة أخرى.'
      : 'The order could not be sent. Try again.';
  static String get posLoadFailed => _ar
      ? 'تعذر تحميل قائمة نقطة البيع.'
      : 'Could not load the point-of-sale menu.';
  static String get posNoBranchTitle =>
      _ar ? 'لا يوجد فرع مهيأ' : 'No branch configured';
  static String get posNoBranchHint => _ar
      ? 'أضف فرعًا نشطًا أولًا لتشغيل نقطة البيع.'
      : 'Add an active branch before using the point of sale.';
  static String get posOptionsTitle => _ar ? 'خيارات الصنف' : 'Product options';
  static String get posOptionsHint => _ar
      ? 'اختر الخيارات المناسبة قبل الإضافة.'
      : 'Choose the right options before adding.';
  static String get posRequiredBadge => _ar ? 'مطلوب' : 'Required';
  static String get posOptionalBadge => _ar ? 'اختياري' : 'Optional';
  static String get posSelectRequiredOptions => _ar
      ? 'أكمل الخيارات المطلوبة أولًا.'
      : 'Complete the required options first.';
  static String get posSelectOne => _ar ? 'اختر خيارًا واحدًا' : 'Choose one';
  static String posSelectUpTo(int max) =>
      _ar ? 'حتى $max اختيارات' : 'Up to $max choices';
  static String get posQuantity => _ar ? 'الكمية' : 'Quantity';
  static String posCartCount(int count) =>
      _ar ? 'السلة ($count)' : 'Cart ($count)';
  static String get posViewCart => _ar ? 'عرض السلة' : 'View cart';
  static String get posCustomer => _ar ? 'العميل' : 'Customer';
  static String get posCustomerTitle =>
      _ar ? 'اختيار العميل' : 'Select a customer';
  static String get posCustomerSubtitle => _ar
      ? 'ابحث عن عميل مسجل أو أضف عميلًا جديدًا للطلب.'
      : 'Search a registered customer or add a new one to this order.';
  static String get posCustomerSearchHint => _ar
      ? 'ابحث بالاسم أو رقم الهاتف أو البريد'
      : 'Search by name, phone or email';
  static String get posCustomerNone => _ar ? 'بدون عميل' : 'No customer';
  static String get posCustomerNoneHint => _ar
      ? 'الطلب غير مرتبط بعميل مسجل.'
      : 'The order is not linked to a customer.';
  static String get posCustomerChoose =>
      _ar ? 'اختيار / إضافة' : 'Select / add';
  static String get posCustomerChange => _ar ? 'تغيير' : 'Change';
  static String get posCustomerRemove =>
      _ar ? 'إزالة العميل' : 'Remove customer';
  static String get posCustomerRegistered =>
      _ar ? 'عميل مسجل' : 'Registered customer';
  static String get posCustomerWalkIn =>
      _ar ? 'عميل نقطة البيع' : 'Counter customer';
  static String get posCustomerVip => _ar ? 'VIP' : 'VIP';
  static String posCustomerOrders(int count) =>
      _ar ? '$count طلب' : '$count orders';
  static String get posCustomerSearchTab => _ar ? 'بحث' : 'Search';
  static String get posCustomerAddTab => _ar ? 'عميل جديد' : 'New customer';
  static String get posCustomerName => _ar ? 'اسم العميل' : 'Customer name';
  static String get posCustomerNameHint =>
      _ar ? 'مثال: أحمد محمد' : 'e.g. Ahmed Mohamed';
  static String get posCustomerPhone => _ar ? 'رقم الهاتف' : 'Phone number';
  static String get posCustomerPhoneHint => _ar
      ? 'اختياري، للتعرف على العميل'
      : 'Optional, helps identify the customer';
  static String get posCustomerEmail =>
      _ar ? 'البريد الإلكتروني' : 'Email address';
  static String get posCustomerEmailHint => _ar ? 'اختياري' : 'Optional';
  static String get posCustomerNote =>
      _ar ? 'ملاحظة عن العميل' : 'Customer note';
  static String get posCustomerNoteHint =>
      _ar ? 'تفضيلات أو ملاحظات للفريق' : 'Preferences or notes for the team';
  static String get posCustomerNameRequired =>
      _ar ? 'اسم العميل مطلوب.' : 'The customer name is required.';
  static String get posCustomerSave =>
      _ar ? 'حفظ واختيار العميل' : 'Save and select';
  static String get posCustomerSaving => _ar ? 'جارٍ الحفظ...' : 'Saving...';
  static String get posCustomerNoResults =>
      _ar ? 'لا يوجد عميل مطابق' : 'No matching customer';
  static String get posCustomerNoResultsHint => _ar
      ? 'جرّب رقمًا أو اسمًا آخر، أو أضف عميلًا جديدًا.'
      : 'Try another name or number, or add a new customer.';
  static String get posCustomerEmpty =>
      _ar ? 'لا يوجد عملاء بعد' : 'No customers yet';
  static String get posCustomerEmptyHint => _ar
      ? 'أضف أول عميل من نقطة البيع لربط الطلبات به.'
      : 'Add the first counter customer to link orders to them.';
  static String get posCustomerLoadFailed =>
      _ar ? 'تعذر تحميل العملاء.' : 'Could not load customers.';
  static String get posCustomerPermissionDenied => _ar
      ? 'ليست لديك صلاحية الوصول إلى العملاء.'
      : 'You do not have permission to access customers.';
  static String get posCustomerInvalid => _ar
      ? 'تحقق من بيانات العميل وحاول مرة أخرى.'
      : 'Check the customer details and try again.';
  static String get posCustomerCreateFailed =>
      _ar ? 'تعذر حفظ العميل.' : 'Could not save the customer.';
  static String get posCustomerReused => _ar
      ? 'يوجد عميل بهذا الرقم بالفعل، تم اختياره.'
      : 'A customer with this phone already exists and was selected.';
  static String get posCustomerUnavailable => _ar
      ? 'لم يعد العميل المحدد متاحًا. اختر عميلًا آخر أو أزله.'
      : 'The selected customer is no longer available. Choose another or remove them.';
  static String get posCustomerWalkInHint => _ar
      ? 'عميل الكاشير يُحفظ في سجل نقطة البيع ولا يملك حسابًا في التطبيق.'
      : 'A counter customer is saved in the POS directory without an app account.';
  static String posPrepMinutes(int minutes) =>
      _ar ? 'خلال $minutes دقيقة' : 'Ready in $minutes min';
  static String posPrepTimeShort(int minutes) =>
      _ar ? '$minutes د' : '$minutes min';

  // ---------- POS cashier shifts ----------
  static String get posShift => _ar ? 'وردية الكاشير' : 'Cashier shift';
  static String get posShiftActive => _ar ? 'الوردية مفتوحة' : 'Shift open';
  static String get posShiftClosed => _ar ? 'الدرج مقفل' : 'Drawer closed';
  static String get posShiftUnavailableShort =>
      _ar ? 'غير متاحة' : 'Unavailable';
  static String posShiftSince(String time) =>
      _ar ? 'مفتوحة منذ $time' : 'Open since $time';
  static String get posShiftUnknownHint => _ar
      ? 'تعذر قراءة حالة الوردية. يمكنك متابعة البيع وسيتم التحقق من الدرج عند تأكيد الطلب.'
      : 'The shift status could not be read. You can keep selling; the drawer is checked when the order is confirmed.';
  static String get posShiftTitle =>
      _ar ? 'وردية الكاشير والدرج' : 'Cashier shift & drawer';
  static String get posShiftSubtitle => _ar
      ? 'متابعة مبيعات الوردية وحركة النقد وتقفيل الدرج.'
      : 'Track this shift\u2019s sales, cash movements and drawer close.';
  static String get posShiftOpenedBy => _ar ? 'فتحها' : 'Opened by';
  static String get posShiftClosedBy => _ar ? 'أقفلها' : 'Closed by';
  static String get posShiftOpenedAt => _ar ? 'وقت الفتح' : 'Opened at';
  static String get posShiftClosedAt => _ar ? 'وقت الإقفال' : 'Closed at';
  static String get posShiftOpeningFloat =>
      _ar ? 'رصيد البداية' : 'Opening float';
  static String get posShiftCashSales => _ar ? 'مبيعات نقدية' : 'Cash sales';
  static String get posShiftCardSales => _ar ? 'مبيعات بطاقة' : 'Card sales';
  static String get posShiftSalesTotal =>
      _ar ? 'إجمالي المبيعات' : 'Sales total';
  static String get posShiftOrders => _ar ? 'عدد الطلبات' : 'Orders';
  static String get posShiftCashIn => _ar ? 'نقد وارد' : 'Cash in';
  static String get posShiftCashOut => _ar ? 'نقد صادر' : 'Cash out';
  static String get posShiftExpectedCash =>
      _ar ? 'النقد المتوقع في الدرج' : 'Expected cash';
  static String get posShiftCountedCash =>
      _ar ? 'النقد المعدود' : 'Counted cash';
  static String get posShiftVariance => _ar ? 'الفرق' : 'Variance';
  static String get posShiftShort => _ar ? 'عجز' : 'Short';
  static String get posShiftOver => _ar ? 'زيادة' : 'Over';
  static String get posShiftBalanced => _ar ? 'مطابق' : 'Balanced';
  static String get posShiftRecordMovement =>
      _ar ? 'تسجيل حركة نقدية' : 'Record cash movement';
  static String get posShiftCashInAction => _ar ? 'إيداع نقدي' : 'Cash in';
  static String get posShiftCashOutAction => _ar ? 'سحب نقدي' : 'Cash out';
  static String get posShiftMovementKind =>
      _ar ? 'نوع الحركة' : 'Movement type';
  static String get posShiftMovementAmount => _ar ? 'المبلغ' : 'Amount';
  static String get posShiftMovementReason => _ar ? 'السبب' : 'Reason';
  static String get posShiftMovementReasonHint => _ar
      ? 'مثال: فكة للدرج، شراء مستلزمات، إيداع بنكي'
      : 'e.g. drawer change, supplies, bank deposit';
  static String get posShiftMovementSave =>
      _ar ? 'تسجيل الحركة' : 'Record movement';
  static String get posShiftMovements => _ar ? 'حركات النقد' : 'Cash movements';
  static String get posShiftNoMovements => _ar
      ? 'لا توجد حركات نقدية في هذه الوردية.'
      : 'No cash movements in this shift.';
  static String get posShiftNetCash =>
      _ar ? 'صافي حركة النقد' : 'Net cash movement';
  static String get posShiftCloseDrawer => _ar ? 'تقفيل الدرج' : 'Close drawer';
  static String get posShiftCloseTitle =>
      _ar ? 'تقفيل الوردية والدرج' : 'Close shift & drawer';
  static String get posShiftCloseSubtitle => _ar
      ? 'عدّ النقد الفعلي في الدرج وأدخل المبلغ لإقفال الوردية.'
      : 'Count the actual drawer cash and enter it to close the shift.';
  static String get posShiftCountPrompt =>
      _ar ? 'النقد المعدود' : 'Counted cash';
  static String get posShiftCountHint => _ar
      ? 'أدخل المبلغ الفعلي الموجود في الدرج.'
      : 'Enter the actual cash in the drawer.';
  static String get posShiftCloseNote => _ar ? 'ملاحظة الإقفال' : 'Close note';
  static String get posShiftCloseNoteHint => _ar
      ? 'اختياري: اشرح أي فرق في الدرج.'
      : 'Optional: explain any drawer difference.';
  static String get posShiftConfirmClose =>
      _ar ? 'تأكيد التقفيل' : 'Confirm close';
  static String get posShiftClosing => _ar ? 'جارٍ التقفيل...' : 'Closing...';
  static String get posShiftVarianceHint => _ar
      ? 'أدخل النقد المعدود لعرض الفرق.'
      : 'Enter the counted cash to see the variance.';
  static String get posShiftVarianceShort =>
      _ar ? 'يوجد عجز في الدرج.' : 'The drawer is short.';
  static String get posShiftVarianceOver =>
      _ar ? 'يوجد زيادة في الدرج.' : 'The drawer is over.';
  static String get posShiftVarianceBalanced => _ar
      ? 'الدرج مطابق للنقد المتوقع.'
      : 'The drawer matches the expected cash.';
  static String get posShiftRequiredMessage => _ar
      ? 'افتح وردية الكاشير أولًا لإتمام البيع.'
      : 'Open a cashier shift before checkout.';
  static String get posShiftPermissionDenied => _ar
      ? 'ليست لديك صلاحية إدارة ورديات الكاشير.'
      : 'You do not have permission to manage cashier shifts.';
  static String get posShiftNotFound =>
      _ar ? 'وردية الكاشير غير موجودة.' : 'The cashier shift was not found.';
  static String get posShiftAlreadyClosed =>
      _ar ? 'الوردية مقفلة بالفعل.' : 'The shift is already closed.';
  static String get posShiftInvalid => _ar
      ? 'تحقق من بيانات الوردية وحاول مرة أخرى.'
      : 'Check the shift details and try again.';
  static String get posShiftFailed =>
      _ar ? 'تعذر إكمال عملية الوردية.' : 'The shift operation failed.';
  static String get posShiftLoadFailed =>
      _ar ? 'تعذر تحميل حالة الوردية.' : 'Could not load the shift.';
  static String get posShiftOpenTitle =>
      _ar ? 'فتح وردية جديدة' : 'Open a new shift';
  static String get posShiftOpenSubtitle => _ar
      ? 'أدخل رصيد النقد الافتتاحي في الدرج ثم ابدأ البيع.'
      : 'Enter the drawer opening cash, then start selling.';
  static String get posShiftOpeningFloatHint => '0.00';
  static String get posShiftOpenConfirm => _ar ? 'فتح الوردية' : 'Open shift';
  static String get posShiftOpening => _ar ? 'جارٍ الفتح...' : 'Opening...';
  static String get posShiftNote => _ar ? 'ملاحظة' : 'Note';
  static String get posShiftOpenNoteHint => _ar
      ? 'اختياري: رقم الدرج أو ملاحظة بداية اليوم.'
      : 'Optional: drawer number or start-of-day note.';
  static String get posShiftOpenedToast =>
      _ar ? 'تم فتح وردية الكاشير.' : 'Cashier shift opened.';
  static String get posShiftAlreadyOpenToast => _ar
      ? 'توجد وردية مفتوحة بالفعل لهذا الفرع.'
      : 'A shift is already open for this branch.';
  static String get posShiftMovementSaved =>
      _ar ? 'تم تسجيل الحركة النقدية.' : 'Cash movement recorded.';
  static String get posShiftClosedToast =>
      _ar ? 'تم تقفيل الوردية.' : 'Shift closed.';
  static String get posShiftHistory => _ar ? 'ورديات سابقة' : 'Shift history';
  static String get posShiftHistoryEmpty =>
      _ar ? 'لا توجد ورديات مقفلة بعد.' : 'No closed shifts yet.';
  static String get posShiftHistoryEmptyHint => _ar
      ? 'ستظهر الورديات هنا بعد تقفيل أول درج.'
      : 'Shifts appear here after the first drawer close.';
  static String get posShiftHistoryLoadFailed =>
      _ar ? 'تعذر تحميل سجل الورديات.' : 'Could not load the shift history.';
  static String get posShiftLoadMore => _ar ? 'تحميل المزيد' : 'Load more';
  static String get posShiftReport => _ar ? 'تقرير الوردية' : 'Shift report';
  static String get posShiftReportZ => _ar ? 'تقرير Z' : 'Z report';
  static String get posShiftStatusOpen => _ar ? 'مفتوحة' : 'Open';
  static String get posShiftStatusClosed => _ar ? 'مقفلة' : 'Closed';
  static String get posShiftNoActive => _ar
      ? 'لا توجد وردية مفتوحة. افتح الدرج لبدء البيع.'
      : 'No shift is open. Open the drawer to start selling.';
  static String get posShiftCashDrawer => _ar ? 'درج النقد' : 'Cash drawer';
  static String get posShiftFrom => _ar ? 'من' : 'From';
  static String get posShiftTo => _ar ? 'إلى' : 'To';
  static String get posShiftTotal => _ar ? 'الإجمالي' : 'Total';
  static String get posShiftDifference =>
      _ar ? 'الفرق في الدرج' : 'Drawer variance';
  static String get posShiftOpenAction => _ar ? 'فتح الدرج' : 'Open drawer';
  static String get posShiftOpenHint => _ar
      ? 'ابدأ الوردية برصيد الدرج الافتتاحي.'
      : 'Start the shift with the drawer float.';
  static String get posShiftDetails => _ar ? 'تفاصيل الوردية' : 'Shift details';
  static String get posShiftShowHistory =>
      _ar ? 'عرض الورديات السابقة' : 'View shift history';

  // ---------- Brand panel ----------
  static String get brandTitle => _ar
      ? 'نظام إدارة متكامل للمقاهي والمطاعم'
      : 'A complete management system for cafes and restaurants';
  static String get brandDescription => _ar
      ? 'تابع الطلبات والمخزون والعملاء والموظفين والتقارير من لوحة تحكم واحدة بتصميم احترافي وسريع الاستجابة.'
      : 'Track orders, inventory, customers, staff and reports from a single professional dashboard that adapts to every screen.';
  static String get add => _ar ? 'إضافة' : 'Add';
  static String get addBanner => _ar ? 'إضافة بانر' : 'Add banner';
  static String get addBranch => _ar ? 'إضافة فرع' : 'Add branch';
  static String get addBundle => _ar ? 'إضافة باقة' : 'Add bundle';
  static String get addDeliveryZone =>
      _ar ? 'إضافة منطقة توصيل' : 'Add delivery zone';
  static String get addImage => _ar ? 'إضافة صورة' : 'Add image';
  static String get addZone => _ar ? 'إضافة منطقة' : 'Add zone';
  static String get adjustments => _ar ? 'التعديلات' : 'Adjustments';
  static String get allergens => _ar ? 'مسببات الحساسية' : 'Allergens';
  static String get allStatuses => _ar ? 'كل الحالات' : 'All statuses';
  static String get applyToAllImages =>
      _ar ? 'تطبيق على كل الصور' : 'Apply to all images';
  static String get applyToAllImagesConfirm => _ar
      ? 'هل تريد تطبيق هذه التعديلات على كل الصور؟'
      : 'Apply these changes to every image?';
  static String get applyToThisImage =>
      _ar ? 'تطبيق على هذه الصورة' : 'Apply to this image';
  static String get beforeAfter => _ar ? 'قبل وبعد' : 'Before and after';
  static String get vip => 'VIP';
  static String get blacklist => _ar ? 'قائمة الحظر' : 'Blacklist';
  static String get adminNotes => _ar ? 'ملاحظات الإدارة' : 'Admin notes';
  static String get registeredAt => _ar ? 'تاريخ التسجيل' : 'Registered at';
  static String get customerAddressesLabel =>
      _ar ? 'عناوين العميل' : 'Customer addresses';
  static String get customerOrdersLabel =>
      _ar ? 'طلبات العميل' : 'Customer orders';
  static String get customerSubscriptionsLabel =>
      _ar ? 'اشتراكات العميل' : 'Customer subscriptions';
  static String get branchAddress => _ar ? 'عنوان الفرع' : 'Branch address';
  static String get branchCode => _ar ? 'كود الفرع' : 'Branch code';
  static String get branchDeliveryDescription =>
      _ar ? 'إعدادات توصيل الفرع' : 'Branch delivery settings';
  static String get branchLabel => _ar ? 'الفرع' : 'Branch';
  static String get branchLocationNeeded => _ar
      ? 'حدد موقع الفرع على الخريطة.'
      : 'Set the branch location on the map.';
  static String get branchLocationUnavailable => _ar
      ? 'تعذر تحديد موقع الفرع.'
      : 'The branch location could not be determined.';
  static String get branchNeedsCode =>
      _ar ? 'أدخل كود الفرع.' : 'Enter a branch code.';
  static String get branchNeedsName =>
      _ar ? 'أدخل اسم الفرع.' : 'Enter a branch name.';
  static String get branchPhone => _ar ? 'هاتف الفرع' : 'Branch phone';
  static String get branchesDescription => _ar
      ? 'أنشئ الفروع وتحكم في مواقعها وساعات العمل والتوصيل والتسعير من مكان واحد.'
      : 'Create branches and control their locations, opening hours, delivery coverage and pricing from one place.';
  static String get branchesReadOnly => _ar
      ? 'لديك صلاحية العرض فقط، ولا يمكنك تعديل الفروع.'
      : 'You have view-only access and cannot change branches.';
  static String get branchesFilterAll => _ar ? 'كل الفروع' : 'All branches';
  static String get branchesFilterNeedsSetup =>
      _ar ? 'تحتاج إعداد' : 'Needs setup';
  static String get branchesFilterLabel =>
      _ar ? 'تصفية الفروع' : 'Filter branches';
  static String get branchesTableBranch => _ar ? 'الفرع' : 'Branch';
  static String get branchesTableContact => _ar ? 'التواصل' : 'Contact';
  static String get branchesTableOperations => _ar ? 'العمليات' : 'Operations';
  static String get branchesTableCoverage => _ar ? 'التغطية' : 'Coverage';
  static String get branchesTableStatus => _ar ? 'الحالة' : 'Status';
  static String get branchesMetricTotal =>
      _ar ? 'إجمالي الفروع' : 'Total branches';
  static String get branchesMetricOrders =>
      _ar ? 'طلبات آخر ٣٠ يومًا' : 'Orders in the last 30 days';
  static String get branchesMetricZones =>
      _ar ? 'مناطق التوصيل النشطة' : 'Active delivery zones';
  static String get branchesNoMatches => _ar
      ? 'لا توجد فروع مطابقة للبحث أو الفلتر.'
      : 'No branches match the search or filter.';
  static String get branchesNoMatchesHint => _ar
      ? 'جرّب اسمًا أو كودًا آخر، أو امسح الفلاتر.'
      : 'Try another name or code, or clear the filters.';
  static String get branchesEmptyHint => _ar
      ? 'أضف أول فرع لتظهر هنا مؤشراته التشغيلية.'
      : 'Add your first branch to see its operational numbers here.';
  static String get branchesNoOrders =>
      _ar ? 'لا توجد طلبات بعد' : 'No orders yet';
  static String get branchesMissingLocation =>
      _ar ? 'الموقع ناقص' : 'Missing location';
  static String get branchesNoCoverage => _ar ? 'لا توجد تغطية' : 'No coverage';
  static String get branchesNoPhone => _ar ? 'لا يوجد هاتف' : 'No phone';
  static String get branchesHoursNotSet =>
      _ar ? 'ساعات العمل غير محددة' : 'Hours not set';
  static String get branchesStaff => _ar ? 'الموظفون' : 'Staff';
  static String get branchesZones => _ar ? 'مناطق التوصيل' : 'Delivery zones';
  static String get branchesOrdersShort => _ar ? 'طلب' : 'orders';
  static String get branchesStaffShort => _ar ? 'موظف' : 'staff';
  static String get branchesZonesShort => _ar ? 'منطقة' : 'zones';
  static String get branchesMetricActive =>
      _ar ? 'الفروع النشطة' : 'Active branches';
  static String get branchesMetricOrdersCaption =>
      _ar ? 'بدون الطلبات الملغاة' : 'Excluding cancelled orders';
  static String get branchesMetricZonesCaption =>
      _ar ? 'مرتبطة بالفروع النشطة' : 'Linked to active branches';
  static String get branchesNeedsSetupTitle =>
      _ar ? 'فروع تحتاج إعداد' : 'Branches needing setup';
  static String get branchesNeedsSetupHint => _ar
      ? 'أكمل موقع الفرع أو اربطه بمنطقة توصيل ليستقبل الطلبات.'
      : 'Set the branch location or link a delivery zone so it can receive orders.';
  static String get branchesSetupAction =>
      _ar ? 'عرض الفروع' : 'Review branches';
  static String get branchesLastOrder => _ar ? 'آخر طلب' : 'Last order';
  static String get branchesMenuTooltip =>
      _ar ? 'إجراءات الفرع' : 'Branch actions';
  static String get branchesImageAction =>
      _ar ? 'صورة الفرع' : 'Branch picture';
  static String get branchActivate => _ar ? 'تفعيل الفرع' : 'Activate branch';
  static String get branchDeactivate =>
      _ar ? 'إيقاف الفرع' : 'Deactivate branch';
  static String get branchDeactivateTitle =>
      _ar ? 'إيقاف الفرع' : 'Deactivate branch';
  static String get branchDeleteTitle => _ar ? 'حذف الفرع' : 'Delete branch';
  static String get branchClearLocation =>
      _ar ? 'إزالة الموقع' : 'Clear location';
  static String get branchLocation =>
      _ar ? 'الموقع على الخريطة' : 'Location on the map';
  static String get branchHoursHint =>
      _ar ? 'مثال: 09:00' : 'For example: 09:00';
  static String get branchCreated =>
      _ar ? 'تم إنشاء الفرع.' : 'The branch was created.';
  static String get branchUpdated =>
      _ar ? 'تم تحديث الفرع.' : 'The branch was updated.';
  static String get branchDeleted =>
      _ar ? 'تم حذف الفرع.' : 'The branch was deleted.';
  static String get branchActivated =>
      _ar ? 'تم تفعيل الفرع.' : 'The branch is now active.';
  static String get branchDeactivated =>
      _ar ? 'تم إيقاف الفرع.' : 'The branch is now inactive.';
  static String get branchSaveFailed => _ar
      ? 'تعذر حفظ الفرع. حاول مرة أخرى.'
      : 'The branch could not be saved. Please try again.';
  static String get branchSaveDuplicateCode => _ar
      ? 'كود الفرع مستخدم بالفعل. اختر كودًا آخر.'
      : 'That branch code is already in use. Choose another one.';
  static String get branchSaveInvalidCode => _ar
      ? 'الكود يقبل الحروف الإنجليزية والأرقام والشرطة والشرطة السفلية فقط (حتى ٢٤ حرفًا).'
      : 'The code may only contain English letters, numbers, hyphens and underscores (up to 24 characters).';
  static String get branchNeedsAddress =>
      _ar ? 'أدخل عنوان الفرع.' : 'Enter the branch address.';
  static String get branchInvalidHours => _ar
      ? 'حدد ساعتي الفتح والإغلاق معًا، على أن تسبق الفتح الإغلاق.'
      : 'Set both opening and closing times, with opening before closing.';
  static String get branchInvalidLocation => _ar
      ? 'أدخل خط عرض وخط طول صحيحين، أو اتركهما فارغين.'
      : 'Enter a valid latitude and longitude, or leave both empty.';
  static String get branchInvalidVatNumber => _ar
      ? 'الرقم الضريبي يجب أن يكون ١٥ رقمًا يبدأ وينتهي بالرقم ٣.'
      : 'The VAT number must be 15 digits starting and ending with 3.';
  static String get branchInvalidLegalName => _ar
      ? 'اسم البائع القانوني طويل جدًا (الحد ٢٠٠ حرف).'
      : 'The legal seller name is too long (200 characters max).';
  static String get branchTaxInvoiceSection =>
      _ar ? 'بيانات الفاتورة الضريبية' : 'Tax invoice details';
  static String get branchLegalName =>
      _ar ? 'الاسم القانوني للبائع' : 'Legal seller name';
  static String get branchVatNumber =>
      _ar ? 'الرقم الضريبي (VAT)' : 'VAT number';
  static String get branchTaxInvoiceHint => _ar
      ? 'تُطبع هذه البيانات على فاتورة الزكاة والدخل ورمز QR. اتركها فارغة إن لم تكن متاحة بعد.'
      : 'These details appear on the ZATCA tax invoice and its QR code. Leave them empty if not available yet.';
  static String get branchNoBrand => _ar
      ? 'لا توجد علامة تجارية مرتبطة بالنظام.'
      : 'No brand is configured for this store.';
  static String get branchNotFound => _ar
      ? 'الفرع غير موجود. حدّث الصفحة وحاول مرة أخرى.'
      : 'The branch no longer exists. Refresh the page and try again.';
  static String get branchPermissionDenied => _ar
      ? 'ليس لديك صلاحية لتعديل الفروع.'
      : 'You do not have permission to change branches.';
  static String get branchHasOrders => _ar
      ? 'لا يمكن حذف فرع له طلبات. أوقفه بدلًا من حذفه.'
      : 'A branch with orders cannot be deleted. Deactivate it instead.';
  static String get branchHasUsage => _ar
      ? 'لا يمكن حذف فرع له سجل استخدام اشتراكات. أوقفه بدلًا من حذفه.'
      : 'A branch with subscription usage cannot be deleted. Deactivate it instead.';
  static String get branchHasStaff => _ar
      ? 'لا يمكن حذف فرع مسند إليه موظفون. انقل الموظفين أولًا.'
      : 'A branch with assigned staff cannot be deleted. Move the staff first.';
  static String get branchLastActive => _ar
      ? 'لا يمكن إيقاف أو حذف آخر فرع نشط.'
      : 'The last active branch cannot be deactivated or deleted.';
  static String get branchInUse => _ar
      ? 'الفرع مرتبط ببيانات تشغيلية ولا يمكن حذفه.'
      : 'The branch is linked to operational data and cannot be deleted.';
  static String get branchInvalidImageUrl => _ar
      ? 'رابط الصورة يجب أن يبدأ بـ http أو https.'
      : 'The image URL must start with http or https.';
  static String get branchMutationFailed => _ar
      ? 'تعذر تنفيذ العملية. حاول مرة أخرى.'
      : 'The action could not be completed. Please try again.';
  static String get brightness => _ar ? 'السطوع' : 'Brightness';
  static String get calories => _ar ? 'السعرات الحرارية' : 'Calories';
  static String get cartDetailsTitle => _ar ? 'تفاصيل السلة' : 'Cart details';
  static String get cartStatusAbandoned => _ar ? 'سلة متروكة' : 'Abandoned';
  static String get cartStatusActive => _ar ? 'سلة نشطة' : 'Active';
  static String get centerLatitude => _ar ? 'خط عرض المركز' : 'Center latitude';
  static String get centerLongitude =>
      _ar ? 'خط طول المركز' : 'Center longitude';
  static String get changePaymentStatus =>
      _ar ? 'تغيير حالة الدفع' : 'Change payment status';
  static String get changeStatus =>
      _ar ? 'تغيير حالة الطلب' : 'Change order status';
  static String get clearFilters => _ar ? 'مسح عوامل التصفية' : 'Clear filters';
  static String get clearSelection => _ar ? 'مسح التحديد' : 'Clear selection';
  static String get close => _ar ? 'إغلاق' : 'Close';
  static String get closesAt => _ar ? 'وقت الإغلاق' : 'Closes at';
  static String get contrast => _ar ? 'التباين' : 'Contrast';
  static String get couldNotSaveProduct => _ar
      ? 'تعذر حفظ المنتج. حاول مرة أخرى.'
      : 'The product could not be saved. Please try again.';
  static String get createdCategories =>
      _ar ? 'التصنيفات المُنشأة' : 'Categories created';
  static String get createdProducts =>
      _ar ? 'المنتجات المُنشأة' : 'Products created';
  static String get customerInfoTitle =>
      _ar ? 'بيانات العميل' : 'Customer details';
  static String get deleteImage => _ar ? 'حذف الصورة' : 'Delete image';
  static String get deleteImageConfirm =>
      _ar ? 'هل تريد حذف هذه الصورة؟' : 'Delete this image?';
  static String get deleteSelectedProducts =>
      _ar ? 'حذف المنتجات المحددة' : 'Delete selected products';
  static String get deliveryDistance => _ar ? 'المسافة' : 'Distance';
  static String get deliveryFee => _ar ? 'رسوم التوصيل' : 'Delivery fee';
  static String get deliveryFeeAmount =>
      _ar ? 'قيمة رسوم التوصيل' : 'Delivery fee amount';
  static String get deliveryFeeMethod =>
      _ar ? 'طريقة حساب رسوم التوصيل' : 'Delivery fee method';
  static String get deliveryFeePerKm =>
      _ar ? 'رسوم التوصيل لكل كيلومتر' : 'Delivery fee per kilometer';
  static String get deliveryLocation =>
      _ar ? 'موقع التوصيل' : 'Delivery location';
  static String get deliveryRadiusKm =>
      _ar ? 'نطاق التوصيل (كم)' : 'Delivery radius (km)';
  static String get directDistanceFeeHint => _ar
      ? 'تُحسب الرسوم حسب المسافة المباشرة بين الفرع وعنوان التوصيل.'
      : 'The fee is based on the direct distance between the branch and the delivery address.';
  static String get discount => _ar ? 'الخصم' : 'Discount';
  static String get discountEndDate =>
      _ar ? 'تاريخ انتهاء الخصم' : 'Discount end date';
  static String get discountPercentage =>
      _ar ? 'نسبة الخصم' : 'Discount percentage';
  static String get discountStartDate =>
      _ar ? 'تاريخ بدء الخصم' : 'Discount start date';
  static String get discountStatusActive => _ar ? 'ساري' : 'Active';
  static String get discountStatusExpired => _ar ? 'منتهي' : 'Expired';
  static String get discountStatusNotActive => _ar ? 'غير مفعّل' : 'Inactive';
  static String get discountStatusScheduled => _ar ? 'مجدول' : 'Scheduled';
  static String get downloadSampleFile =>
      _ar ? 'تنزيل ملف نموذجي' : 'Download sample file';
  static String get downloadSampleFileHint => _ar
      ? 'نزّل الملف النموذجي واملأه ثم ارفعه مرة أخرى.'
      : 'Download the sample file, fill it in, then upload it again.';
  static String get editBanner => _ar ? 'تعديل البانر' : 'Edit banner';
  static String get editBranch => _ar ? 'تعديل الفرع' : 'Edit branch';
  static String get editBranchLocation =>
      _ar ? 'تعديل موقع الفرع' : 'Edit branch location';
  static String get editBundle => _ar ? 'تعديل الباقة' : 'Edit bundle';
  static String get editImage => _ar ? 'تعديل الصورة' : 'Edit image';
  static String get editZone => _ar ? 'تعديل المنطقة' : 'Edit zone';
  static String get estimatedDelivery =>
      _ar ? 'وقت التوصيل المتوقع' : 'Estimated delivery';
  static String get estimatedDeliveryMinutes =>
      _ar ? 'وقت التوصيل المتوقع (دقيقة)' : 'Estimated delivery (minutes)';
  static String get exportExcel => _ar ? 'تصدير Excel' : 'Export Excel';
  static String get exporting => _ar ? 'جارٍ التصدير' : 'Exporting';
  static String get exportSuccess =>
      _ar ? 'تم التصدير بنجاح' : 'Exported successfully';
  static String get exposure => _ar ? 'التعريض' : 'Exposure';
  static String get failedProducts =>
      _ar ? 'منتجات فشل حفظها' : 'Products that failed to save';
  static String get feePerKilometer =>
      _ar ? 'الرسوم لكل كيلومتر' : 'Fee per kilometer';
  static String get filters => _ar ? 'عوامل التصفية' : 'Filters';
  static String get fixedDeliveryFee =>
      _ar ? 'رسوم توصيل ثابتة' : 'Fixed delivery fee';
  static String get flipHorizontal => _ar ? 'قلب أفقي' : 'Flip horizontally';
  static String get flipVertical => _ar ? 'قلب رأسي' : 'Flip vertically';
  static String get freeDelivery => _ar ? 'توصيل مجاني' : 'Free delivery';
  static String get freeDeliveryMinimum =>
      _ar ? 'الحد الأدنى للتوصيل المجاني' : 'Minimum for free delivery';
  static String get fulfillmentDelivery => _ar ? 'توصيل' : 'Delivery';
  static String get fulfillmentFilter => _ar ? 'نوع الطلب' : 'Order type';
  static String get fulfillmentInfoTitle =>
      _ar ? 'طريقة الاستلام' : 'Fulfillment';
  static String get fulfillmentPickup => _ar ? 'استلام من الفرع' : 'Pickup';
  static String get grandTotal => _ar ? 'الإجمالي النهائي' : 'Grand total';
  static String get highlights => _ar ? 'أبرز المزايا' : 'Highlights';
  static String get hours => _ar ? 'الساعات' : 'Hours';
  static String get imageActionFailed => _ar
      ? 'تعذر تنفيذ العملية على الصورة. حاول مرة أخرى.'
      : 'The image action failed. Please try again.';
  static String get imageActionForbidden => _ar
      ? 'ليست لديك صلاحية تعديل الصورة.'
      : 'You do not have permission to change the image.';
  static String get imageAlignment => _ar ? 'محاذاة الصورة' : 'Image alignment';
  static String get imageCouldNotBeOpened =>
      _ar ? 'تعذر فتح الصورة.' : 'The image could not be opened.';
  static String get imageCouldNotBeSaved =>
      _ar ? 'تعذر حفظ الصورة.' : 'The image could not be saved.';
  static String get imageFit => _ar ? 'طريقة ملء الصورة' : 'Image fit';
  static String get imageScope => _ar ? 'نطاق التعديل' : 'Image scope';
  static String get imageSettings => _ar ? 'إعدادات الصورة' : 'Image settings';
  static String get imageSettingsMissing =>
      _ar ? 'إعدادات الصورة غير متاحة.' : 'Image settings are unavailable.';
  static String get imageSource => _ar ? 'مصدر الصورة' : 'Image source';
  static String get importExcel => _ar ? 'استيراد Excel' : 'Import Excel';
  static String get importing => _ar ? 'جارٍ الاستيراد' : 'Importing';
  static String get importSummary => _ar ? 'ملخص الاستيراد' : 'Import summary';
  static String get intensity => _ar ? 'الشدة' : 'Intensity';
  static String get invalidDeliveryZoneFields =>
      _ar ? 'تحقق من بيانات منطقة التوصيل.' : 'Check the delivery zone fields.';
  static String get invalidDiscountPercentage =>
      _ar ? 'نسبة الخصم غير صالحة.' : 'Enter a valid discount percentage.';
  static String get invalidDiscountRange => _ar
      ? 'تاريخ نهاية الخصم يجب أن يكون بعد تاريخ البداية.'
      : 'The discount end date must be after the start date.';
  static String get invalidExcelFile => _ar
      ? 'الملف المحدد غير صالح. استخدم ملف Excel النموذجي.'
      : 'The selected file is invalid. Use the Excel sample file.';
  static String get invalidPerKmFee =>
      _ar ? 'رسوم الكيلومتر غير صالحة.' : 'Enter a valid fee per kilometer.';
  static String get invalidPrepTime =>
      _ar ? 'وقت التحضير غير صالح.' : 'Enter a valid preparation time.';
  static String get invalidRows =>
      _ar ? 'صفوف تحتوي على أخطاء' : 'Rows with errors';
  static String get itemsTitle => _ar ? 'العناصر' : 'Items';
  static String get locationPermissionDenied => _ar
      ? 'تم رفض إذن الوصول إلى الموقع. فعّله من إعدادات المتصفح أو الجهاز.'
      : 'Location permission was denied. Enable it in the browser or device settings.';
  static String get manageBranchPricing =>
      _ar ? 'إدارة تسعير الفروع' : 'Manage branch pricing';
  static String get manageDelivery => _ar ? 'إدارة التوصيل' : 'Manage delivery';
  static String get maxDeliveryFee =>
      _ar ? 'أقصى رسوم توصيل' : 'Maximum delivery fee';
  static String get minimumOrder => _ar ? 'الحد الأدنى للطلب' : 'Minimum order';
  static String get minutes => _ar ? 'دقائق' : 'minutes';
  static String get noAddresses => _ar ? 'لا توجد عناوين' : 'No addresses';
  static String get noBranchDeliveryZones => _ar
      ? 'لا توجد مناطق توصيل لهذا الفرع.'
      : 'No delivery zones for this branch.';
  static String get noBranchesFound =>
      _ar ? 'لا توجد فروع مطابقة.' : 'No matching branches.';
  static String get noCartsFound =>
      _ar ? 'لا توجد سلال مطابقة.' : 'No matching carts.';
  static String get noCartsYet => _ar ? 'لا توجد سلال بعد.' : 'No carts yet.';
  static String get noCartItems =>
      _ar ? 'لا توجد عناصر في هذه السلة.' : 'This cart has no items.';
  static String get noDeliveryAddress =>
      _ar ? 'لم يُحدَّد عنوان للتوصيل' : 'No delivery address was provided';
  static String get noImagesYet => _ar ? 'لا توجد صور بعد.' : 'No images yet.';
  static String get noOrders => _ar ? 'لا توجد طلبات' : 'No orders';
  static String get noOrdersForFilter => _ar
      ? 'لا توجد طلبات تطابق عوامل التصفية.'
      : 'No orders match the selected filters.';
  static String get noOrderItems =>
      _ar ? 'لا توجد عناصر في هذا الطلب.' : 'This order has no items.';
  static String get noPaymentsFound =>
      _ar ? 'لا توجد مدفوعات مطابقة.' : 'No matching payments.';
  static String get noPaymentsYet =>
      _ar ? 'لا توجد مدفوعات بعد.' : 'No payments yet.';
  static String get noProductsYet =>
      _ar ? 'لا توجد منتجات بعد.' : 'No products yet.';
  static String get noSubscriptions =>
      _ar ? 'لا توجد اشتراكات' : 'No subscriptions';
  static String get opensAt => _ar ? 'وقت الفتح' : 'Opens at';
  static String get orderCannotBeEdited =>
      _ar ? 'لا يمكن تعديل هذا الطلب.' : 'This order can no longer be edited.';
  static String get orderPlacedAt => _ar ? 'تاريخ الطلب' : 'Order date';
  static String get paidAt => _ar ? 'تاريخ الدفع' : 'Paid at';
  static String get refundedAt => _ar ? 'تاريخ الاسترداد' : 'Refunded at';
  static String get reference => _ar ? 'المرجع' : 'Reference';
  static String get paymentCard => _ar ? 'بطاقة' : 'Card';
  static String get paymentInfoTitle =>
      _ar ? 'الدفع والإجماليات' : 'Payment and totals';
  static String get paymentMethod => _ar ? 'طريقة الدفع' : 'Payment method';
  static String get paymentMethodCash => _ar ? 'نقدًا' : 'Cash';
  static String get paymentStatusAuthorized => _ar ? 'مصرّح بها' : 'Authorized';
  static String get paymentStatusFailed => _ar ? 'فشل الدفع' : 'Payment failed';
  static String get paymentStatusFilter =>
      _ar ? 'حالة الدفع' : 'Payment status';
  static String get paymentStatusLabelTitle =>
      _ar ? 'حالة الدفع' : 'Payment status';
  static String get paymentStatusPaid => _ar ? 'مدفوع' : 'Paid';
  static String get paymentStatusPending =>
      _ar ? 'الدفع قيد الانتظار' : 'Payment pending';
  static String get paymentStatusRefunded => _ar ? 'مسترد' : 'Refunded';
  static String get paymentStatusUnpaid => _ar ? 'غير مدفوع' : 'Unpaid';
  static String get paymentStatusVoided => _ar ? 'ملغاة' : 'Voided';
  static String get prepTime => _ar ? 'وقت التحضير' : 'Preparation time';
  static String get prepUnit =>
      _ar ? 'وحدة وقت التحضير' : 'Preparation time unit';
  static String get prepValue =>
      _ar ? 'قيمة وقت التحضير' : 'Preparation time value';
  static String get priceAfterDiscount =>
      _ar ? 'السعر بعد الخصم' : 'Price after discount';
  static String get primary => _ar ? 'أساسية' : 'Primary';
  static String get productImages => _ar ? 'صور المنتج' : 'Product images';
  static String get productNeedsCategory =>
      _ar ? 'اختر تصنيفًا للمنتج.' : 'Choose a category for the product.';
  static String get productNeedsName =>
      _ar ? 'أدخل اسم المنتج.' : 'Enter a product name.';
  static String get productWasAdded =>
      _ar ? 'تمت إضافة المنتج.' : 'The product was added.';
  static String get provider => _ar ? 'مزوّد الخدمة' : 'Provider';
  static String get published => _ar ? 'منشور' : 'Published';
  static String get quantity => _ar ? 'الكمية' : 'Quantity';
  static String get redo => _ar ? 'إعادة' : 'Redo';
  static String get removeItem => _ar ? 'إزالة العنصر' : 'Remove item';
  static String get removeItemConfirm => _ar
      ? 'هل تريد إزالة هذا العنصر من الطلب؟'
      : 'Remove this item from the order?';
  static String get removeItemUnavailable =>
      _ar ? 'لا يمكن إزالة هذا العنصر.' : 'This item cannot be removed.';
  static String get replaceImage => _ar ? 'استبدال الصورة' : 'Replace image';
  static String get resetImage => _ar ? 'إعادة ضبط الصورة' : 'Reset image';
  static String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get rowsCount => _ar ? 'عدد الصفوف' : 'Rows';
  static String get saturation => _ar ? 'التشبع' : 'Saturation';
  static String get saveProductFirst =>
      _ar ? 'احفظ المنتج أولًا.' : 'Save the product first.';
  static String get savingImage =>
      _ar ? 'جارٍ حفظ الصورة...' : 'Saving the image...';
  static String get seconds => _ar ? 'ثوانٍ' : 'seconds';
  static String get selectProduct => _ar ? 'اختر منتجًا' : 'Select a product';
  static String get setPrimaryImage =>
      _ar ? 'تعيين كصورة أساسية' : 'Set as primary image';
  static String get shadows => _ar ? 'الظلال' : 'Shadows';
  static String get sharpness => _ar ? 'الحدّة' : 'Sharpness';
  static String get statusFilter => _ar ? 'حالة الطلب' : 'Order status';
  static String get subtotal => _ar ? 'المجموع الفرعي' : 'Subtotal';
  static String get tax => _ar ? 'الضريبة' : 'Tax';
  static String get undo => _ar ? 'تراجع' : 'Undo';
  static String get unknownCustomer =>
      _ar ? 'عميل غير معروف' : 'Unknown customer';
  static String get browserPreview =>
      _ar ? 'معاينة المتصفح' : 'Browser preview';
  static String get androidEmulator =>
      _ar ? 'محاكي أندرويد' : 'Android emulator';
  static String autoRenewAndBonus(bool autoRenew, String bonus) => _ar
      ? 'التجديد التلقائي: ${autoRenew ? 'نعم' : 'لا'}  •  المكافأة: $bonus'
      : 'Auto renew: ${autoRenew ? 'Yes' : 'No'}  •  Bonus: $bonus';
  static String get updatedAt => _ar ? 'آخر تحديث' : 'Last updated';
  static String get updatedCategories =>
      _ar ? 'التصنيفات المحدّثة' : 'Categories updated';
  static String get updatedProducts =>
      _ar ? 'المنتجات المحدّثة' : 'Products updated';
  static String get uploadFromDevice =>
      _ar ? 'رفع من الجهاز' : 'Upload from device';
  static String get uploadingImage =>
      _ar ? 'جارٍ رفع الصورة...' : 'Uploading the image...';
  static String get useGeneralDiscount =>
      _ar ? 'استخدام الخصم العام' : 'Use the general discount';
  static String get useImageLink =>
      _ar ? 'استخدام رابط صورة' : 'Use an image link';
  static String get useTotal => _ar ? 'استخدام الإجمالي' : 'Use total';
  static String get verifiedByServer =>
      _ar ? 'تم التحقق بواسطة الخادم' : 'Verified by the server';
  static String get warmth => _ar ? 'الدفء' : 'Warmth';
  static String get zoneMapTapHint => _ar
      ? 'اضغط على الخريطة لإضافة نقاط المنطقة.'
      : 'Tap the map to add zone points.';
  static String get zoneNameArabic =>
      _ar ? 'اسم المنطقة بالعربية' : 'Zone name (Arabic)';
  static String get zoneNameEnglish =>
      _ar ? 'اسم المنطقة بالإنجليزية' : 'Zone name (English)';
  static String get zoneSharedBranchNotice => _ar
      ? 'هذه المنطقة مشتركة مع فرع آخر.'
      : 'This zone is shared with another branch.';
  static String get zoomIn => _ar ? 'تكبير' : 'Zoom in';
  static String get zoomOut => _ar ? 'تصغير' : 'Zoom out';

  // ---------- Shared form labels ----------
  static String get title => _ar ? 'العنوان' : 'Title';
  static String get subtitle => _ar ? 'العنوان الفرعي' : 'Subtitle';
  static String get description => _ar ? 'الوصف' : 'Description';
  static String get ctaLabel => _ar ? 'نص زر الإجراء' : 'CTA label';
  static String get targetType => _ar ? 'نوع الهدف' : 'Target type';
  static String get targetProduct => _ar ? 'المنتج المستهدف' : 'Target product';
  static String get targetCategory =>
      _ar ? 'التصنيف المستهدف' : 'Target category';
  static String get targetUrl => _ar ? 'رابط الهدف' : 'Target URL';
  static String get productLabel => _ar ? 'منتج' : 'Product';
  static String get none => _ar ? 'بدون' : 'None';
  static String get url => _ar ? 'رابط' : 'URL';
  static String get titleRequired =>
      _ar ? 'العنوان مطلوب.' : 'Title is required.';
  static String get nameRequired => _ar ? 'الاسم مطلوب.' : 'Name is required.';
  static String get imageRequired =>
      _ar ? 'الصورة مطلوبة.' : 'Image is required.';
  static String get imageIsEmpty =>
      _ar ? 'الصورة فارغة.' : 'The image is empty.';
  static String get imageCouldNotBeRead =>
      _ar ? 'تعذر قراءة الصورة.' : 'The image could not be read.';
  static String couldNotDeleteCategory(String error) =>
      _ar ? 'تعذر حذف التصنيف: $error' : 'Could not delete category: $error';
  static String get categoryDeleteBlockedByProducts => _ar
      ? 'لا يمكن حذف التصنيف لاحتوائه على منتجات. انقل المنتجات إلى تصنيف آخر أو احذفها أولًا.'
      : 'This category still holds products. Move them to another category or delete them first.';
  static String get categoryNotFound => _ar
      ? 'التصنيف غير موجود أو تم حذفه بالفعل.'
      : 'The category no longer exists.';
  static String couldNotUpdateCategory(String error) =>
      _ar ? 'تعذر تحديث التصنيف: $error' : 'Could not update category: $error';
  static String couldNotGetLocation(String error) =>
      _ar ? 'تعذر تحديد الموقع: $error' : 'Could not get location: $error';
  static String get imageTooLarge =>
      _ar ? 'حجم الصورة أكبر من 5 ميجابايت.' : 'The image is bigger than 5 MB.';
  static String get imageMustBeFormat => _ar
      ? 'يجب أن تكون الصورة بصيغة JPG أو PNG أو WEBP.'
      : 'The image must be a JPG, a PNG or a WEBP file.';
  static String get imageUrlMissing =>
      _ar ? 'رابط الصورة مطلوب.' : 'The image needs a URL.';
  static String get imagePrimaryFailed => _ar
      ? 'تعذر تعيين الصورة كصورة أساسية.'
      : 'The image was not made the primary one.';
  static String get productNotSaved =>
      _ar ? 'لم يتم حفظ المنتج.' : 'The product was not saved.';
  static String get categoryNotCreated =>
      _ar ? 'لم يتم إنشاء التصنيف.' : 'The category was not created.';
  static String get categoryNotUpdated =>
      _ar ? 'لم يتم تحديث التصنيف.' : 'The category was not updated.';
  static String get noWorksheet =>
      _ar ? 'الملف لا يحتوي على ورقة عمل.' : 'The workbook has no worksheet.';
  static String missingExcelColumn(String column) => _ar
      ? 'الملف لا يحتوي على عمود "$column".'
      : 'The file is missing the "$column" column.';
  static String get excelArabicNameRequired =>
      _ar ? 'الاسم بالعربية مطلوب.' : 'Name (Arabic) is required.';
  static String get excelEnglishNameRequired =>
      _ar ? 'الاسم بالإنجليزية مطلوب.' : 'Name (English) is required.';
  static String get excelBasePriceRequired =>
      _ar ? 'السعر الأساسي مطلوب.' : 'Base Price is required.';
  static String get excelBasePriceNegative => _ar
      ? 'السعر الأساسي لا يمكن أن يكون سالبًا.'
      : 'Base Price cannot be negative.';
  static String excelCategoryNotFound(String category) => _ar
      ? 'التصنيف "$category" غير موجود.'
      : 'Category "$category" not found.';
  static String get duplicateSkuOrSlug =>
      _ar ? 'رمز SKU أو الرابط المختصر مكرر' : 'Duplicate SKU or slug';
  static String get notAllProductsLoaded => _ar
      ? 'تعذر تحميل جميع المنتجات المطابقة. حاول مرة أخرى.'
      : 'Not all matching products could be loaded. Please try again.';
  static String get catalogueUnreachable => _ar
      ? 'تعذر الوصول إلى الكتالوج. حاول مرة أخرى.'
      : 'The catalogue could not be reached. Please try again.';
  static String get duplicateCategoryName =>
      _ar ? 'اسم التصنيف مكرر' : 'Duplicate category name';
  static String get networkError => _ar ? 'خطأ في الشبكة' : 'Network error';
  static String get permissionDenied =>
      _ar ? 'تم رفض الإذن' : 'Permission denied';
  static String get databaseError =>
      _ar ? 'خطأ في قاعدة البيانات' : 'Database error';
  static String get imageFormats =>
      _ar ? 'JPG أو PNG أو WEBP' : 'JPG, PNG or WEBP';
  static String get enterAddressManually =>
      _ar ? 'أدخل العنوان يدويًا' : 'Enter address manually';
  static String get reset => _ar ? 'إعادة الضبط' : 'Reset';
  static String get systemRole => _ar ? 'نظام' : 'System';
  static String get addAtLeastOneComponent =>
      _ar ? 'أضف مكوّنًا واحدًا على الأقل.' : 'Add at least one component.';
  static String get bundlePrice => _ar ? 'سعر الباقة' : 'Bundle price';
  static String get bundlePriceHint => _ar
      ? 'اتركه فارغًا لاستخدام مجموع المكوّنات'
      : 'Leave empty for sum of components';
  static String get bundleComponents =>
      _ar ? 'مكوّنات الباقة' : 'Bundle components';
  static String get addComponent => _ar ? 'إضافة مكوّن' : 'Add component';
  static String get noComponentsAdded =>
      _ar ? 'لم تُضف مكوّنات بعد.' : 'No components added yet.';
  static String componentsTotal(String amount) =>
      _ar ? 'إجمالي المكوّنات: $amount' : 'Components total: $amount';
  static String get noBannersFound =>
      _ar ? 'لا توجد بانرات.' : 'No banners found.';
  static String get noBundlesFound =>
      _ar ? 'لا توجد باقات.' : 'No bundles found.';
  static String get noBundlesYet =>
      _ar ? 'لا توجد باقات بعد.' : 'No bundles yet.';
  static String get noRolesFound => _ar ? 'لا توجد أدوار.' : 'No roles found.';
  static String get noSubscriptionsFound =>
      _ar ? 'لا توجد اشتراكات.' : 'No subscriptions found.';

  // ---------- Android emulator preview ----------
  static String get emulatorPreviewTitle =>
      _ar ? 'معاينة محاكي أندرويد' : 'Android emulator preview';
  static String get emulatorPreviewDescription => _ar
      ? 'معاينة مباشرة لمحاكي أندرويد. شغّل الجسر على هذا الجهاز ثم اتصل.'
      : 'Live Android emulator preview. Run the bridge on this PC, then connect.';
  static String get emulatorConnected =>
      _ar ? 'المحاكي متصل' : 'Emulator connected';
  static String get emulatorDisconnected =>
      _ar ? 'المحاكي غير متصل' : 'Emulator disconnected';
  static String get reloadSavedAppData =>
      _ar ? 'إعادة تحميل بيانات التطبيق المحفوظة' : 'Reload saved app data';
  static String get homeScreen => _ar ? 'الرئيسية' : 'Home';
  static String get typeIntoApp =>
      _ar ? 'الكتابة داخل التطبيق' : 'Type into the app';
  static String get send => _ar ? 'إرسال' : 'Send';
  static String get typeIntoAppButton =>
      _ar ? 'اكتب داخل التطبيق' : 'Type into app';
  static String get connectRealEmulator =>
      _ar ? 'اربط المحاكي الحقيقي' : 'Connect the real emulator';
  static String get emulatorBridgeHint => _ar
      ? 'يحتاج المتصفح إلى جسر محلي للوصول إلى محاكي أندرويد. شغّل هذا المساعد على الجهاز نفسه:'
      : 'The browser needs a local bridge to reach Android Emulator. Run this helper on the same PC:';
  static String get bridgeTokenLabel => _ar
      ? 'رمز الجسر من نافذة المساعد'
      : 'Bridge token from the helper window';
  static String get bridgeTokenHint => _ar
      ? 'الصق الرمز الذي يعرضه المساعد'
      : 'Paste the token shown by the helper';
  static String get connecting => _ar ? 'جارٍ الاتصال...' : 'Connecting...';
  static String get connectToEmulator =>
      _ar ? 'الاتصال بالمحاكي' : 'Connect to emulator';
  static String get emulatorStepSave => _ar
      ? 'احفظ تغييراتك في تطبيق الإدارة.'
      : 'Save your changes in the admin app.';
  static String get emulatorStepReload => _ar
      ? 'اختر إعادة التحميل لتحميل البيانات المحفوظة.'
      : 'Select Reload to load the saved data.';
  static String get emulatorStepInteract => _ar
      ? 'اضغط أو اسحب على شاشة الهاتف لاستخدام التطبيق.'
      : 'Tap or swipe on the phone screen to use the app.';
  static String get emulatorBridgeNote => _ar
      ? 'يستمع الجسر على هذا الجهاز فقط ويتطلب Android SDK وAVD مثبتًا.'
      : 'The bridge listens on this PC only and requires Android SDK and an installed AVD.';
  static String kilometers(String value) => _ar ? '$value كم' : '$value km';
  static String perKilometer(String amount) =>
      _ar ? '$amount/كم' : '$amount/km';
  static String get loadingEmulatorScreen =>
      _ar ? 'جارٍ تحميل شاشة المحاكي' : 'Loading emulator screen';
  static String get startBridgeThenConnect =>
      _ar ? 'شغّل الجسر ثم اتصل' : 'Start the bridge, then connect';
  static String get bridgeNotReady =>
      _ar ? 'الجسر غير جاهز.' : 'The bridge is not ready.';
  static String bridgeRequestFailed(int statusCode) => _ar
      ? 'فشل طلب الجسر (رمز $statusCode).'
      : 'Bridge request failed ($statusCode).';
  static String branchActiveZoneCount(int count) =>
      _ar ? 'مناطق التوصيل النشطة ($count)' : 'Active delivery zones ($count)';
  static String branchDeliverySettings(String branchName) =>
      _ar ? 'إعدادات توصيل $branchName' : 'Delivery settings for $branchName';
  static String branchPricingFor(String branchName) =>
      _ar ? 'تسعير $branchName' : 'Pricing for $branchName';
  static String branchesCount(int count) =>
      _ar ? '$count فرعًا' : '$count branches';
  static String branchesOrdersValue(int count) =>
      _ar ? '$count طلب' : '$count orders';
  static String branchesStaffValue(int count) =>
      _ar ? '$count موظف' : '$count staff';
  static String branchesZonesValue(int count) =>
      _ar ? '$count منطقة' : '$count zones';
  static String branchesMetricActiveCaption(int active, int total) =>
      _ar ? '$active من $total مفعل' : '$active of $total active';
  static String branchesMetricStaffCaption(int count) =>
      _ar ? 'الموظفون المسندون: $count' : 'Staff assigned: $count';
  static String branchesRowsLabel(int from, int to, int count) => _ar
      ? 'عرض $from–$to من $count فرعًا'
      : 'Showing $from–$to of $count branches';
  static String branchesNeedsSetupBanner(int count) => _ar
      ? '$count فرعًا يحتاج إعداد الموقع أو التغطية.'
      : '$count branches need a location or delivery coverage.';
  static String branchesFilterOption(String label, int count) =>
      '$label ($count)';
  static String branchDeactivateConfirm(String name) => _ar
      ? 'سيتم إيقاف "$name" ولن يستقبل طلبات جديدة. هل تريد المتابعة؟'
      : '"$name" will stop receiving new orders. Continue?';
  static String bundlesCount(int count) =>
      _ar ? '$count باقة' : '$count bundles';
  static String bundleComponentsCount(int count) => count == 1
      ? _ar
            ? 'مكوّن واحد'
            : '1 component'
      : _ar
      ? '$count مكوّنات'
      : '$count components';
  static String cartItemsCount(int count) =>
      _ar ? '$count عنصرًا' : '$count items';
  static String cartStatusLabel(String code) =>
      _ar ? 'حالة سلة غير معروفة ($code)' : 'Unknown cart status ($code)';
  static String deleteProductsConfirm(int count) => _ar
      ? 'سيتم حذف $count منتجًا نهائيًا. هل تريد المتابعة؟'
      : 'This will permanently delete $count products. Continue?';
  static String ordersCount(int count) => _ar ? '$count طلب' : '$count orders';
  static String orderItemsCount(int count) =>
      _ar ? '$count عناصر' : '$count items';
  static String paymentStatusLabel(String status) => switch (status) {
    'unpaid' => paymentStatusUnpaid,
    'pending' => paymentStatusPending,
    'paid' || 'captured' => paymentStatusPaid,
    'authorized' => paymentStatusAuthorized,
    'failed' => paymentStatusFailed,
    'refunded' => paymentStatusRefunded,
    'voided' => paymentStatusVoided,
    _ => status,
  };
  static String productsDeleted(int count) =>
      _ar ? 'تم حذف $count منتجًا' : '$count products deleted';
  static String productsDeletePartial(int count) => _ar
      ? 'تعذر حذف $count منتجًا. بقيت محددة لتتمكن من المحاولة مجددًا.'
      : 'Could not delete $count products. They remain selected so you can retry.';
  static String selectAllProducts(int count) => _ar
      ? 'تحديد كل المنتجات المطابقة ($count)'
      : 'Select all matching products ($count)';
  static String selectedProductsCount(int count) =>
      _ar ? 'تم تحديد $count' : '$count selected';

  // ---------- Bulk actions ----------
  static String selectedCountLabel(int count) =>
      _ar ? 'تم تحديد $count' : '$count selected';
  static String get deleteSelectedCategories =>
      _ar ? 'حذف التصنيفات المحددة' : 'Delete selected categories';
  static String get deleteSelectedBundles =>
      _ar ? 'حذف الباقات المحددة' : 'Delete selected bundles';
  static String deleteCategoriesConfirm(int count) => _ar
      ? 'سيتم حذف $count تصنيفًا نهائيًا. هل تريد المتابعة؟'
      : 'This will permanently delete $count categories. Continue?';
  static String deleteBundlesConfirm(int count) => _ar
      ? 'سيتم حذف $count باقة نهائيًا. هل تريد المتابعة؟'
      : 'This will permanently delete $count bundles. Continue?';
  static String categoriesDeleted(int count) =>
      _ar ? 'تم حذف $count تصنيفًا' : '$count categories deleted';
  static String bundlesDeleted(int count) =>
      _ar ? 'تم حذف $count باقة' : '$count bundles deleted';
  static String get bundleDeleteBlockedByReward => _ar
      ? 'لا يمكن حذف الباقة لأنها مرتبطة بعرض ولاء. احذف العرض أو غيّر هدفه أولًا.'
      : 'This bundle is used by a loyalty reward. Remove the reward or change its target first.';
  static String get bundleNotFound => _ar
      ? 'الباقة غير موجودة أو تم حذفها بالفعل.'
      : 'The bundle no longer exists.';
  static String categoriesDeletePartial(int count) => _ar
      ? 'تعذر حذف $count تصنيفًا. بقيت محددة لتتمكن من المحاولة مجددًا.'
      : 'Could not delete $count categories. They remain selected so you can retry.';
  static String bundlesDeletePartial(int count) => _ar
      ? 'تعذر حذف $count باقة. بقيت محددة لتتمكن من المحاولة مجددًا.'
      : 'Could not delete $count bundles. They remain selected so you can retry.';
  static String selectAllCategories(int count) => _ar
      ? 'تحديد كل التصنيفات المطابقة ($count)'
      : 'Select all matching categories ($count)';
  static String selectAllBundles(int count) => _ar
      ? 'تحديد كل الباقات المطابقة ($count)'
      : 'Select all matching bundles ($count)';

  // ---------- Customer preview ----------
  static String get customerPreview =>
      _ar ? 'معاينة تطبيق العميل' : 'Customer preview';
  static String get customerPreviewHint =>
      _ar ? 'معاينة تطبيق العميل' : 'Preview the customer app';
  static String get previewDraftMode =>
      _ar ? 'معاينة - الوضع التجريبي' : 'Preview - draft mode';
  static String get previewPublishedMode =>
      _ar ? 'معاينة - المنشور' : 'Preview - published';
  static String get previewRefresh => _ar ? 'تحديث' : 'Refresh';
  static String get previewResetDraft =>
      _ar ? 'إعادة ضبط المسودة' : 'Reset draft';
  static String get previewSaveDraft => _ar ? 'حفظ المسودة' : 'Save draft';
  static String get previewPublish => _ar ? 'نشر' : 'Publish';
  static String get previewViewport => _ar ? 'مقاس العرض' : 'Viewport';
  static String get previewScreen => _ar ? 'الشاشة' : 'Screen';
  static String get previewCustomerAppUrl =>
      _ar ? 'رابط تطبيق العميل' : 'Customer app URL';
  static String get previewPrimaryColor =>
      _ar ? 'اللون الأساسي' : 'Primary color';
  static String get previewSecondaryColor =>
      _ar ? 'اللون الثانوي' : 'Secondary color';
  static String get previewBackgroundColor =>
      _ar ? 'لون الخلفية' : 'Background color';
  static String get previewSurfaceColor => _ar ? 'لون الأسطح' : 'Surface color';
  static String get previewUnsupported => _ar
      ? 'المعاينة متاحة في نسخ الويب فقط.'
      : 'Preview is available on web builds.';
  static String get previewLoading =>
      _ar ? 'جارٍ تحميل معاينة تطبيق العميل...' : 'Loading customer preview...';
  static String get previewError => _ar
      ? 'تعذر تحميل معاينة تطبيق العميل.'
      : 'Unable to load the customer preview.';
}
