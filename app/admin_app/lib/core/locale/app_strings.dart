import 'package:admin_app/core/locale/app_locale.dart';

/// Every user-visible admin string in one place.
///
/// Each getter reads the current [AppLocale] at build time, so toggling the
/// language rebuilds the whole tree and every label flips together.
class S {
  S._();

  static bool get _ar => AppLocale.instance.isArabic;

  static String get appName => _ar ? 'ط¥ط¯ط§ط±ط© ط§ظ„ظ‚ظ‡ظˆط©' : 'Coffee Admin';
  static String get admin => _ar ? 'ط§ظ„ط¥ط¯ط§ط±ط©' : 'Admin';

  // ---------- Sidebar ----------
  static String get signOut => _ar ? 'طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬' : 'Sign out';
  static String get owner => _ar ? 'ط§ظ„ظ…ط§ظ„ظƒ' : 'Owner';
  static String get staff => _ar ? 'ظ…ظˆط¸ظپ' : 'Staff';

  // ---------- Destinations ----------
  static String get dashboard => _ar ? 'ظ„ظˆط­ط© ط§ظ„طھط­ظƒظ…' : 'Dashboard';
  static String get orders => _ar ? 'ط§ظ„ط·ظ„ط¨ط§طھ' : 'Orders';
  static String get products => _ar ? 'ط§ظ„ظ…ظ†طھط¬ط§طھ' : 'Products';
  static String get categories => _ar ? 'ط§ظ„طھطµظ†ظٹظپط§طھ' : 'Categories';
  static String get inventory => _ar ? 'ط§ظ„ظ…ط®ط²ظˆظ†' : 'Inventory';
  static String get customers => _ar ? 'ط§ظ„ط¹ظ…ظ„ط§ط،' : 'Customers';
  static String get staffLabel => _ar ? 'ط§ظ„ظ…ظˆط¸ظپظˆظ†' : 'Staff';
  static String get role => _ar ? 'ط§ظ„ط¯ظˆط±' : 'Role';
  static String get settings => _ar ? 'ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ' : 'Settings';

  // ---------- App bar ----------
  static String get search => _ar ? 'ط¨ط­ط«' : 'Search';
  static String get language => _ar ? 'ط§ظ„ظ„ط؛ط©' : 'Language';
  static String get theme => _ar ? 'ط§ظ„ظ…ط¸ظ‡ط±' : 'Theme';
  static String get menu => _ar ? 'ط§ظ„ظ‚ط§ط¦ظ…ط©' : 'Menu';
  static String get clearSearch => _ar ? 'ظ…ط³ط­ ط§ظ„ط¨ط­ط«' : 'Clear search';

  // ---------- Per-page search hints ----------
  static String get searchDashboardHint => _ar
      ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط·ظ„ط¨ط§طھ ظˆط§ظ„ط¹ظ…ظ„ط§ط،...'
      : 'Search orders and customers...';
  static String get searchOrdersHint => _ar
      ? 'ط§ط¨ط­ط« ط¨ط±ظ‚ظ… ط§ظ„ط·ظ„ط¨ ط£ظˆ ط§ظ„ط¹ظ…ظٹظ„...'
      : 'Search by order number or customer...';
  static String get searchProductsHint =>
      _ar ? 'ط§ط¨ط­ط« ط¹ظ† ظ…ظ†طھط¬...' : 'Search products...';
  static String get searchCategoriesHint =>
      _ar ? 'ط§ط¨ط­ط« ط¹ظ† طھطµظ†ظٹظپ...' : 'Search categories...';
  static String get searchInventoryHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ظ…ط®ط²ظˆظ†...' : 'Search inventory...';
  static String get searchCustomersHint =>
      _ar ? 'ط§ط¨ط­ط« ط¹ظ† ط¹ظ…ظٹظ„...' : 'Search customers...';
  static String get searchStaffHint =>
      _ar ? 'ط§ط¨ط­ط« ط¹ظ† ظ…ظˆط¸ظپ...' : 'Search staff...';
  static String get searchSettingsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ...' : 'Search settings...';
  static String get searchDefaultHint => _ar ? 'ط§ط¨ط­ط«...' : 'Search...';

  // ---------- Dashboard ----------
  static String get welcomeBack =>
      _ar ? 'ظ…ط±ط­ط¨ظ‹ط§ ط¨ط¹ظˆط¯طھظƒ' : 'Welcome back';
  static String welcomeBackName(String name) =>
      _ar ? 'ظ…ط±ط­ط¨ظ‹ط§ ط¨ط¹ظˆط¯طھظƒطŒ $name.' : 'Welcome back, $name.';
  static String get todayOrders =>
      _ar ? 'ط·ظ„ط¨ط§طھ ط§ظ„ظٹظˆظ…' : "Today's orders";
  static String get todayRevenue =>
      _ar ? 'ط¥ظٹط±ط§ط¯ط§طھ ط§ظ„ظٹظˆظ…' : "Today's revenue";
  static String get activeOrders =>
      _ar ? 'ط§ظ„ط·ظ„ط¨ط§طھ ط§ظ„ظ†ط´ط·ط©' : 'Active orders';
  static String get activeProducts =>
      _ar ? 'ط§ظ„ظ…ظ†طھط¬ط§طھ ط§ظ„ظ†ط´ط·ط©' : 'Active products';
  static String get customersLabel => _ar ? 'ط§ظ„ط¹ظ…ظ„ط§ط،' : 'Customers';
  static String get activeBranches =>
      _ar ? 'ط§ظ„ظپط±ظˆط¹ ط§ظ„ظ†ط´ط·ط©' : 'Active branches';
  static String get recentOrders =>
      _ar ? 'ط£ط­ط¯ط« ط§ظ„ط·ظ„ط¨ط§طھ' : 'Recent orders';
  static String get noOrdersYet =>
      _ar ? 'ظ„ط§ طھظˆط¬ط¯ ط·ظ„ط¨ط§طھ ط¨ط¹ط¯.' : 'No orders yet.';
  static String get refresh => _ar ? 'طھط­ط¯ظٹط«' : 'Refresh';
  static String get totalOrdersToDate => _ar
      ? 'ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ط·ظ„ط¨ط§طھ ط­طھظ‰ ط§ظ„ط¢ظ†'
      : 'Total orders to date';
  static String get noDashboardMetrics => _ar
      ? 'ط¯ظˆط±ظƒ ظ„ط§ ظٹطھط¶ظ…ظ† ظ…ظ‚ط§ظٹظٹط³ ظ„ظˆط­ط© ط§ظ„طھط­ظƒظ….'
      : 'Your role does not include dashboard metrics.';
  static String get couldNotLoadDashboard => _ar
      ? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ظ„ظˆط­ط© ط§ظ„طھط­ظƒظ…'
      : 'Could not load dashboard';
  static String get tryAgain => _ar ? 'ط­ط§ظˆظ„ ظ…ط±ط© ط£ط®ط±ظ‰' : 'Try again';
  static String get delivery => _ar ? 'طھظˆطµظٹظ„' : 'Delivery';
  static String get pickup => _ar ? 'ط§ط³طھظ„ط§ظ…' : 'Pickup';

  // ---------- Coming soon ----------
  static String get comingSoon => _ar ? 'ظ‚ط±ظٹط¨ظ‹ط§' : 'Coming soon';

  // ---------- Auth / login ----------
  static String get staffSignIn =>
      _ar ? 'طھط³ط¬ظٹظ„ ط¯ط®ظˆظ„ ط§ظ„ظ…ظˆط¸ظپظٹظ†' : 'Staff sign in';
  static String get staffSignInSubtitle => _ar
      ? 'ط§ط³طھط®ط¯ظ… ط­ط³ط§ط¨ ط§ظ„ظ…ظˆط¸ظپ ط§ظ„ط®ط§طµ ط¨ظƒ ظ„ظ„ظˆطµظˆظ„ ط¥ظ„ظ‰ ظ„ظˆط­ط© ط§ظ„طھط­ظƒظ….'
      : 'Use your staff account to access the dashboard.';
  static String get email =>
      _ar ? 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ' : 'Email';
  static String get password => _ar ? 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±' : 'Password';
  static String get signIn => _ar ? 'طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„' : 'Sign in';
  static String get emailRequired => _ar
      ? 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظ…ط·ظ„ظˆط¨.'
      : 'Email is required.';
  static String get validEmail => _ar
      ? 'ط£ط¯ط®ظ„ ط¨ط±ظٹط¯ظ‹ط§ ط¥ظ„ظƒطھط±ظˆظ†ظٹظ‹ط§ طµط­ظٹط­ظ‹ط§.'
      : 'Enter a valid email.';
  static String get passwordRequired =>
      _ar ? 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظ…ط·ظ„ظˆط¨ط©.' : 'Password is required.';
  static String get manageBrandSubtitle => _ar
      ? 'ط£ط¯ط± ط§ظ„ط·ظ„ط¨ط§طھ ظˆط§ظ„ظ‚ط§ط¦ظ…ط© ظˆط§ظ„ظپط±ظˆط¹ ظˆط§ظ„ظ…ظˆط¸ظپظٹظ† ظپظٹ ظ…ظƒط§ظ† ظˆط§ط­ط¯.'
      : 'Manage orders, catalog, branches and staff in one place.';

  // ---------- Sign out dialog ----------
  static String get signOutTitle =>
      _ar ? 'طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬' : 'Sign out';
  static String get signOutMessage => _ar
      ? 'ظ‡ظ„ ط£ظ†طھ ظ…طھط£ظƒط¯ ط£ظ†ظƒ طھط±ظٹط¯ طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬طں'
      : 'Are you sure you want to sign out?';
  static String get cancel => _ar ? 'ط¥ظ„ط؛ط§ط،' : 'Cancel';

  // ---------- Catalog ----------
  static String get all => _ar ? 'ط§ظ„ظƒظ„' : 'All';

  // Actions
  static String get addCategory =>
      _ar ? 'ط¥ط¶ط§ظپط© طھطµظ†ظٹظپ' : 'Add category';
  static String get editCategory =>
      _ar ? 'طھط¹ط¯ظٹظ„ ط§ظ„طھطµظ†ظٹظپ' : 'Edit category';
  static String get addProduct => _ar ? 'ط¥ط¶ط§ظپط© ظ…ظ†طھط¬' : 'Add product';
  static String get editProduct =>
      _ar ? 'طھط¹ط¯ظٹظ„ ط§ظ„ظ…ظ†طھط¬' : 'Edit product';
  static String get save => _ar ? 'ط­ظپط¸' : 'Save';
  static String get edit => _ar ? 'طھط¹ط¯ظٹظ„' : 'Edit';
  static String get delete => _ar ? 'ط­ط°ظپ' : 'Delete';
  static String get archive => _ar ? 'ط£ط±ط´ظپط©' : 'Archive';
  static String get restore => _ar ? 'ط§ط³طھط¹ط§ط¯ط©' : 'Restore';

  // Fields
  static String get image => _ar ? 'ط§ظ„طµظˆط±ط©' : 'Image';
  static String get name => _ar ? 'ط§ظ„ط§ط³ظ…' : 'Name';
  static String get nameAr =>
      _ar ? 'ط§ظ„ط§ط³ظ… ط¨ط§ظ„ط¹ط±ط¨ظٹط©' : 'Name (Arabic)';
  static String get nameEn =>
      _ar ? 'ط§ظ„ط§ط³ظ… ط¨ط§ظ„ط¥ظ†ط¬ظ„ظٹط²ظٹط©' : 'Name (English)';
  static String get slug => _ar ? 'ط§ظ„ط±ط§ط¨ط·' : 'Slug';
  static String get category => _ar ? 'ط§ظ„طھطµظ†ظٹظپ' : 'Category';
  static String get categoryFilter =>
      _ar ? 'طھطµظ†ظٹظپ ط§ظ„ظ…ظ†طھط¬' : 'Product category';
  static String get sku => _ar ? 'ظƒظˆط¯ ط§ظ„ظ…ظ†طھط¬' : 'SKU';
  static String get price => _ar ? 'ط§ظ„ط³ط¹ط±' : 'Price';
  static String get compareAtPrice =>
      _ar ? 'ط§ظ„ط³ط¹ط± ط§ظ„ظ…ظ‚ط§ط±ظ†' : 'Compare at price';
  static String get prepMinutes =>
      _ar ? 'ط¯ظ‚ظٹظ‚ط© ط§ظ„طھط­ط¶ظٹط±' : 'Prep minutes';
  static String get featured => _ar ? 'ظ…ظ…ظٹط²' : 'Featured';
  static String get isFeatured =>
      _ar ? 'ظ…ظ†طھط¬ ظ…ظ…ظٹط²' : 'Featured product';
  static String get status => _ar ? 'ط§ظ„ط­ط§ظ„ط©' : 'Status';
  static String get active => _ar ? 'ظ…ظپط¹ظ„' : 'Active';
  static String get inactive => _ar ? 'ظ…ط¹ط·ظ„' : 'Inactive';
  static String get archived => _ar ? 'ظ…ط¤ط±ط´ظپ' : 'Archived';
  static String get actions => _ar ? 'ط¹ظ…ظ„ظٹط§طھ' : 'Actions';
  static String get iconKey => _ar ? 'ظ…ظپطھط§ط­ ط§ظ„ط£ظٹظ‚ظˆظ†ط©' : 'Icon key';
  static String get imageUrl => _ar ? 'ط±ط§ط¨ط· ط§ظ„طµظˆط±ط©' : 'Image URL';
  static String get descriptionAr =>
      _ar ? 'ط§ظ„ظˆطµظپ ط¨ط§ظ„ط¹ط±ط¨ظٹط©' : 'Description (Arabic)';
  static String get descriptionEn =>
      _ar ? 'ط§ظ„ظˆطµظپ ط¨ط§ظ„ط¥ظ†ط¬ظ„ظٹط²ظٹط©' : 'Description (English)';
  static String get sortOrder => _ar ? 'طھط±طھظٹط¨ ط§ظ„ط¹ط±ط¶' : 'Sort order';
  static String get isActive => _ar ? 'ظ…ظپط¹ظ„' : 'Active';
  static String get parent =>
      _ar ? 'ط§ظ„طھطµظ†ظٹظپ ط§ظ„ط£ظ…' : 'Parent category';

  // Validation
  static String get requiredField =>
      _ar ? 'ظ‡ط°ط§ ط§ظ„ط­ظ‚ظ„ ظ…ط·ظ„ظˆط¨' : 'This field is required';
  static String get invalidPrice =>
      _ar ? 'ط³ط¹ط± ط؛ظٹط± طµط§ظ„ط­' : 'Invalid price';
  static String get invalidNumber =>
      _ar ? 'ط±ظ‚ظ… ط؛ظٹط± طµط§ظ„ط­' : 'Invalid number';
  static String get compareAtMustBeHigher => _ar
      ? 'ظٹط¬ط¨ ط£ظ† ظٹظƒظˆظ† ط§ظ„ط³ط¹ط± ط§ظ„ظ…ظ‚ط§ط±ظ† ط£ط¹ظ„ظ‰ ظ…ظ† ط§ظ„ط³ط¹ط± ط§ظ„ط£ط³ط§ط³ظٹ'
      : 'Compare-at price must be higher than the base price';

  // Empty states
  static String get noCategoriesFound =>
      _ar ? 'ظ„ط§ طھظˆط¬ط¯ طھطµظ†ظٹظپط§طھ ظ…ط·ط§ط¨ظ‚ط©' : 'No categories found';
  static String get noProductsFound =>
      _ar ? 'ظ„ط§ طھظˆط¬ط¯ ظ…ظ†طھط¬ط§طھ ظ…ط·ط§ط¨ظ‚ط©' : 'No products found';

  // Messages
  static String get saved => _ar ? 'طھظ… ط§ظ„ط­ظپط¸' : 'Saved';
  static String get deleted => _ar ? 'طھظ… ط§ظ„ط­ط°ظپ' : 'Deleted';
  static String get couldNotLoadCategories => _ar
      ? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط§ظ„طھطµظ†ظٹظپط§طھ'
      : 'Could not load categories';
  static String get couldNotLoadProducts =>
      _ar ? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط§ظ„ظ…ظ†طھط¬ط§طھ' : 'Could not load products';

  static String categoriesCount(int count) => count == 1
      ? _ar
            ? 'طھطµظ†ظٹظپ ظˆط§ط­ط¯'
            : '1 category'
      : _ar
      ? '$count طھطµظ†ظٹظپط§طھ'
      : '$count categories';

  static String productsCount(int count) => count == 1
      ? _ar
            ? 'ظ…ظ†طھط¬ ظˆط§ط­ط¯'
            : '1 product'
      : _ar
      ? '$count ظ…ظ†طھط¬ط§طھ'
      : '$count products';

  static String deleteCategoryConfirm(String name) => _ar
      ? 'ظ‡ظ„ ط£ظ†طھ ظ…طھط£ظƒط¯ ط£ظ†ظƒ طھط±ظٹط¯ ط­ط°ظپ ط§ظ„طھطµظ†ظٹظپ "$name"طں'
      : 'Are you sure you want to delete the category "$name"?';

  static String deleteProductConfirm(String name) => _ar
      ? 'ظ‡ظ„ ط£ظ†طھ ظ…طھط£ظƒط¯ ط£ظ†ظƒ طھط±ظٹط¯ ط­ط°ظپ ط§ظ„ظ…ظ†طھط¬ "$name"طں'
      : 'Are you sure you want to delete the product "$name"?';

  // ---------- Customers ----------
  static String get noCustomersFound =>
      _ar ? 'ظ„ط§ ظٹظˆط¬ط¯ ط¹ظ…ظ„ط§ط،' : 'No customers yet';
  static String get customerName =>
      _ar ? 'ط§ط³ظ… ط§ظ„ط¹ظ…ظٹظ„' : 'Customer name';
  static String get emailAddress =>
      _ar ? 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ' : 'Email';
  static String get phone => _ar ? 'ط§ظ„ظ‡ط§طھظپ' : 'Phone';
  static String get ordersCountLabel =>
      _ar ? 'ط¹ط¯ط¯ ط§ظ„ط·ظ„ط¨ط§طھ' : 'Orders';
  static String get totalSpent =>
      _ar ? 'ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ط¥ظ†ظپط§ظ‚' : 'Total spent';
  static String get lastOrder => _ar ? 'ط¢ط®ط± ط·ظ„ط¨' : 'Last order';
  static String get editCustomerTitle =>
      _ar ? 'طھط¹ط¯ظٹظ„ ط§ظ„ط¹ظ…ظٹظ„' : 'Edit customer';
  static String get fullName => _ar ? 'ط§ظ„ط§ط³ظ… ط§ظ„ظƒط§ظ…ظ„' : 'Full name';

  static String customersCount(int count) => count == 1
      ? _ar
            ? 'ط¹ظ…ظٹظ„ ظˆط§ط­ط¯'
            : '1 customer'
      : _ar
      ? '$count ط¹ظ…ظ„ط§ط،'
      : '$count customers';

  // ---------- Inventory ----------
  static String get noInventoryItems => _ar
      ? 'ظ„ط§ طھظˆط¬ط¯ ط£طµظ†ط§ظپ ظپظٹ ط§ظ„ظ…ط®ط²ظˆظ†'
      : 'No inventory items';
  static String get productName => _ar ? 'ط§ط³ظ… ط§ظ„ظ…ظ†طھط¬' : 'Product';
  static String get currentStock =>
      _ar ? 'ط§ظ„ظ…ط®ط²ظˆظ† ط§ظ„ط­ط§ظ„ظٹ' : 'Current stock';
  static String get minStock => _ar ? 'ط§ظ„ط­ط¯ ط§ظ„ط£ط¯ظ†ظ‰' : 'Min stock';
  static String get unit => _ar ? 'ط§ظ„ظˆط­ط¯ط©' : 'Unit';
  static String get lowStock => _ar ? 'ظ…ظ†ط®ظپط¶' : 'Low';
  static String get inStock => _ar ? 'ظ…طھظˆظپط±' : 'In stock';
  static String get editStockTitle =>
      _ar ? 'طھط¹ط¯ظٹظ„ ط§ظ„ظ…ط®ط²ظˆظ†' : 'Edit stock';

  static String inventoryCount(int count) => count == 1
      ? _ar
            ? 'طµظ†ظپ ظˆط§ط­ط¯'
            : '1 item'
      : _ar
      ? '$count ط£طµظ†ط§ظپ'
      : '$count items';

  static String lowStockCount(int count) => count == 1
      ? _ar
            ? 'طµظ†ظپ ظ…ظ†ط®ظپط¶'
            : '1 low stock item'
      : _ar
      ? '$count ط£طµظ†ط§ظپ ظ…ظ†ط®ظپط¶ط©'
      : '$count low stock items';

  // ---------- Orders ----------
  static String get noOrdersFound =>
      _ar ? 'ظ„ط§ طھظˆط¬ط¯ ط·ظ„ط¨ط§طھ' : 'No orders yet';
  static String get orderNumber => _ar ? 'ط±ظ‚ظ… ط§ظ„ط·ظ„ط¨' : 'Order number';
  static String get customer => _ar ? 'ط§ظ„ط¹ظ…ظٹظ„' : 'Customer';
  static String get total => _ar ? 'ط§ظ„ظ…ط¬ظ…ظˆط¹' : 'Total';
  static String get fulfillmentType =>
      _ar ? 'ظ†ظˆط¹ ط§ظ„طھظˆطµظٹظ„' : 'Delivery type';
  static String get date => _ar ? 'ط§ظ„طھط§ط±ظٹط®' : 'Date';
  static String get statusPending =>
      _ar ? 'ظ‚ظٹط¯ ط§ظ„ط§ظ†طھط¸ط§ط±' : 'Pending';
  static String get statusConfirmed => _ar ? 'ظ…ط¤ظƒط¯' : 'Confirmed';
  static String get statusPreparing =>
      _ar ? 'ظ‚ظٹط¯ ط§ظ„طھط­ط¶ظٹط±' : 'Preparing';
  static String get statusReady => _ar ? 'ط¬ط§ظ‡ط²' : 'Ready';
  static String get statusOutForDelivery =>
      _ar ? 'ظپظٹ ط·ط±ظٹظ‚ظ‡ ظ„ظ„طھظˆطµظٹظ„' : 'Out for delivery';
  static String get statusCompleted => _ar ? 'ظ…ظƒطھظ…ظ„' : 'Completed';
  static String get statusCancelled => _ar ? 'ظ…ظ„ط؛ظٹ' : 'Cancelled';

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
  static String get noStaffFound =>
      _ar ? 'ظ„ط§ ظٹظˆط¬ط¯ ظ…ظˆط¸ظپظٹظ†' : 'No staff members';
  static String get staffName => _ar ? 'ط§ط³ظ… ط§ظ„ظ…ظˆط¸ظپ' : 'Staff name';
  static String get roleColumn => _ar ? 'ط§ظ„ط¯ظˆط±' : 'Role';
  static String get roleManager => _ar ? 'ظ…ط¯ظٹط±' : 'Manager';
  static String get roleCashier => _ar ? 'ظƒط§ط´ظٹط±' : 'Cashier';
  static String get activeStatus => _ar ? 'ظ†ط´ط·' : 'Active';
  static String get inactiveStatus => _ar ? 'ط؛ظٹط± ظ†ط´ط·' : 'Inactive';
  static String get editStaffTitle =>
      _ar ? 'طھط¹ط¯ظٹظ„ ط§ظ„ظ…ظˆط¸ظپ' : 'Edit staff';
  static String get roleHint =>
      _ar ? 'ط§ظ„ط¯ظˆط± (owner/staff/manager)' : 'Role (owner/staff/manager)';

  static String staffCount(int count) => count == 1
      ? _ar
            ? 'ظ…ظˆط¸ظپ ظˆط§ط­ط¯'
            : '1 staff member'
      : _ar
      ? '$count ظ…ظˆط¸ظپظٹظ†'
      : '$count staff members';

  static String activeStaffCount(int count) => count == 1
      ? _ar
            ? 'ظ…ظˆط¸ظپ ظ†ط´ط·'
            : '1 active staff member'
      : _ar
      ? '$count ظ…ظˆط¸ظپظٹظ† ظ†ط´ط·ظٹظ†'
      : '$count active staff members';

  static String deleteOrderConfirm(String orderNumber) => _ar
      ? 'ظ‡ظ„ ط£ظ†طھ ظ…طھط£ظƒط¯ ط£ظ†ظƒ طھط±ظٹط¯ ط­ط°ظپ ط§ظ„ط·ظ„ط¨ "$orderNumber"طں'
      : 'Are you sure you want to delete the order "$orderNumber"?';

  // ---------- Load errors ----------
  static String get couldNotLoadCustomers =>
      _ar ? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط§ظ„ط¹ظ…ظ„ط§ط،' : 'Could not load customers';
  static String get couldNotLoadInventory =>
      _ar ? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط§ظ„ظ…ط®ط²ظˆظ†' : 'Could not load inventory';
  static String get couldNotLoadOrders =>
      _ar ? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط§ظ„ط·ظ„ط¨ط§طھ' : 'Could not load orders';
  static String get couldNotLoadStaff =>
      _ar ? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط§ظ„ظ…ظˆط¸ظپظٹظ†' : 'Could not load staff';

  // ---------- Settings ----------
  static String get preferences => _ar ? 'ط§ظ„طھظپط¶ظٹظ„ط§طھ' : 'Preferences';
  static String get changePassword =>
      _ar ? 'طھط؛ظٹظٹط± ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±' : 'Change password';
  static String get currentPassword =>
      _ar ? 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط­ط§ظ„ظٹط©' : 'Current password';
  static String get newPassword =>
      _ar ? 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط¬ط¯ظٹط¯ط©' : 'New password';
  static String get confirmNewPassword => _ar
      ? 'طھط£ظƒظٹط¯ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط¬ط¯ظٹط¯ط©'
      : 'Confirm new password';
  static String get themeSystem => _ar ? 'ط§ظ„ظ†ط¸ط§ظ…' : 'System';
  static String get themeLight => _ar ? 'ظپط§طھط­' : 'Light';
  static String get themeDark => _ar ? 'ط¯ط§ظƒظ†' : 'Dark';
  static String get arabicLabel => _ar ? 'ط§ظ„ط¹ط±ط¨ظٹط©' : 'Arabic';
  static String get englishLabel => _ar ? 'ط§ظ„ط¥ظ†ط¬ظ„ظٹط²ظٹط©' : 'English';
  static String get statusActive => _ar ? 'ظ†ط´ط·' : 'Active';
  static String get more => _ar ? 'ط§ظ„ظ…ط²ظٹط¯' : 'More';
  static String get viewTable => _ar ? 'ط¹ط±ط¶ ظƒط¬ط¯ظˆظ„' : 'Table view';
  static String get viewCards => _ar ? 'ط¹ط±ط¶ ظƒظƒط±ظˆطھ' : 'Card view';
  static String get sectionManagement => _ar ? 'ط§ظ„ط¥ط¯ط§ط±ط©' : 'Management';
  static String get sectionSettings =>
      _ar ? 'ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ ط§ظ„ط¹ط§ظ…ط©' : 'General settings';
  static String get sectionOperations =>
      _ar ? 'ط§ظ„ط¹ظ…ظ„ظٹط§طھ' : 'Operations';
  static String get sectionPeople =>
      _ar ? 'ط§ظ„ط£ط´ط®ط§طµ ظˆط§ظ„ظپط±ظˆط¹' : 'People and branches';
  static String get sectionContent =>
      _ar ? 'ط§ظ„ظ…ط­طھظˆظ‰ ظˆط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ' : 'Content and settings';
  static String get sectionGrowth =>
      _ar ? 'ط§ظ„ظ†ظ…ظˆ ظˆط§ظ„طھظپط§ط¹ظ„' : 'Growth and engagement';

  // ---------- Feature placeholders ----------
  static String get soonBadge => _ar ? 'ظ‚ط±ظٹط¨ط§ظ‹' : 'Soon';
  static String get featureNotBuilt => _ar
      ? 'ظ‡ط°ظ‡ ط§ظ„ظ…ظٹط²ط© ظ…ظˆط¬ظˆط¯ط© ظپظٹ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ ظ„ظƒظ†ظ‡ط§ ظ„ظ… طھظڈط¨ظ†ظژ ط¨ط¹ط¯ ظپظٹ ظ„ظˆط­ط© ط§ظ„طھط­ظƒظ….'
      : 'This feature exists in the database but is not built in the dashboard yet.';
  static String get databaseTables =>
      _ar ? 'ط¬ط¯ط§ظˆظ„ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ' : 'Database tables';
  static String get noDatabaseTables => _ar
      ? 'ظ„ط§ طھظˆط¬ط¯ ط¬ط¯ط§ظˆظ„ ظ…ط±طھط¨ط·ط© ظ…ط¨ط§ط´ط±ط©.'
      : 'No directly related tables.';

  static String get bundles => _ar ? 'ط§ظ„ط¨ط§ظ‚ط§طھ' : 'Bundles';
  static String get branchPricing =>
      _ar ? 'طھط³ط¹ظٹط± ط§ظ„ظپط±ظˆط¹' : 'Branch pricing';
  static String get carts => _ar ? 'ط³ظ„ط© ط§ظ„ظ…ط´طھط±ظٹط§طھ' : 'Carts';
  static String get stockMovements =>
      _ar ? 'ط­ط±ظƒط© ط§ظ„ظ…ط®ط²ظˆظ†' : 'Stock movements';
  static String get payments => _ar ? 'ط§ظ„ظ…ط¯ظپظˆط¹ط§طھ' : 'Payments';
  static String get savedCards =>
      _ar ? 'ط§ظ„ط¨ط·ط§ظ‚ط§طھ ط§ظ„ظ…ط­ظپظˆط¸ط©' : 'Saved cards';
  static String get addresses => _ar ? 'ط§ظ„ط¹ظ†ط§ظˆظٹظ†' : 'Addresses';
  static String get rolesAndPermissions =>
      _ar ? 'ط§ظ„ط£ط¯ظˆط§ط± ظˆط§ظ„طµظ„ط§ط­ظٹط§طھ' : 'Roles and permissions';
  static String get auditLog => _ar ? 'ط³ط¬ظ„ ط§ظ„طھط¯ظ‚ظٹظ‚' : 'Audit log';
  static String get branches => _ar ? 'ط§ظ„ظپط±ظˆط¹' : 'Branches';
  static String get deliveryZones =>
      _ar ? 'ظ…ظ†ط§ط·ظ‚ ط§ظ„طھظˆطµظٹظ„' : 'Delivery zones';
  static String get content => _ar ? 'ط§ظ„ظ…ط­طھظˆظ‰' : 'Content';
  static String get appSettings =>
      _ar ? 'ط¥ط¹ط¯ط§ط¯ط§طھ ط§ظ„طھط·ط¨ظٹظ‚' : 'App settings';
  static String get coupons => _ar ? 'ط§ظ„ظƒظˆط¨ظˆظ†ط§طھ' : 'Coupons';
  static String get banners => _ar ? 'ط§ظ„ط¨ط§ظ†ط±ط§طھ' : 'Banners';
  static String get loyalty =>
      _ar ? 'ط§ظ„ظˆظ„ط§ط، ظˆط§ظ„ظ†ظ‚ط§ط·' : 'Loyalty and points';
  static String get subscriptions =>
      _ar ? 'ط§ظ„ط§ط´طھط±ط§ظƒط§طھ' : 'Subscriptions';
  static String get reviews => _ar ? 'ط§ظ„طھظ‚ظٹظٹظ…ط§طھ' : 'Reviews';
  static String get notifications =>
      _ar ? 'ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ' : 'Notifications';
  static String get favorites => _ar ? 'ط§ظ„ظ…ظپط¶ظ„ط©' : 'Favorites';
  static String get customerWebsites =>
      _ar ? 'ظ…ظˆط§ظ‚ط¹ ط§ظ„ط¹ظ…ظ„ط§ط،' : 'Customer websites';
  static String get aiKnowledge =>
      _ar ? 'ظ…ط¹ط±ظپط© ط§ظ„ظ…ط³ط§ط¹ط¯ ط§ظ„ط°ظƒظٹ' : 'Assistant knowledge';

  static String get searchBundlesHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط¨ط§ظ‚ط§طھ...' : 'Search bundles...';
  static String get searchPricingHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„طھط³ط¹ظٹط±...' : 'Search pricing...';
  static String get searchCartsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط³ظ„ط§ظ„...' : 'Search carts...';
  static String get searchStockMovementsHint => _ar
      ? 'ط§ط¨ط­ط« ظپظٹ ط­ط±ظƒط© ط§ظ„ظ…ط®ط²ظˆظ†...'
      : 'Search stock movements...';
  static String get searchPaymentsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ظ…ط¯ظپظˆط¹ط§طھ...' : 'Search payments...';
  static String get searchSavedCardsHint => _ar
      ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط¨ط·ط§ظ‚ط§طھ ط§ظ„ظ…ط­ظپظˆط¸ط©...'
      : 'Search saved cards...';
  static String get searchAddressesHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط¹ظ†ط§ظˆظٹظ†...' : 'Search addresses...';
  static String get searchRolesHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط£ط¯ظˆط§ط±...' : 'Search roles...';
  static String get searchAuditLogHint => _ar
      ? 'ط§ط¨ط­ط« ظپظٹ ط³ط¬ظ„ ط§ظ„طھط¯ظ‚ظٹظ‚...'
      : 'Search the audit log...';
  static String get searchBranchesHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ظپط±ظˆط¹...' : 'Search branches...';
  static String get searchDeliveryZonesHint => _ar
      ? 'ط§ط¨ط­ط« ظپظٹ ظ…ظ†ط§ط·ظ‚ ط§ظ„طھظˆطµظٹظ„...'
      : 'Search delivery zones...';
  static String get searchContentHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ظ…ط­طھظˆظ‰...' : 'Search content...';
  static String get searchAppSettingsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ...' : 'Search settings...';
  static String get searchCouponsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ظƒظˆط¨ظˆظ†ط§طھ...' : 'Search coupons...';
  static String get searchBannersHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط¨ط§ظ†ط±ط§طھ...' : 'Search banners...';
  static String get searchLoyaltyHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ظˆظ„ط§ط،...' : 'Search loyalty...';
  static String get searchSubscriptionsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط§ط´طھط±ط§ظƒط§طھ...' : 'Search subscriptions...';
  static String get searchReviewsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„طھظ‚ظٹظٹظ…ط§طھ...' : 'Search reviews...';
  static String get searchNotificationsHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ...' : 'Search notifications...';
  static String get searchFavoritesHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ط§ظ„ظ…ظپط¶ظ„ط©...' : 'Search favorites...';
  static String get searchWebsitesHint =>
      _ar ? 'ط§ط¨ط­ط« ظپظٹ ظ…ظˆط§ظ‚ط¹ ط§ظ„ط¹ظ…ظ„ط§ط،...' : 'Search websites...';
  static String get searchAiKnowledgeHint => _ar
      ? 'ط§ط¨ط­ط« ظپظٹ ظ…ط¹ط±ظپط© ط§ظ„ظ…ط³ط§ط¹ط¯...'
      : 'Search assistant knowledge...';
  static String get newBadge => _ar ? 'ط¬ط¯ظٹط¯' : 'New';
  static String get changeImage =>
      _ar ? 'طھط؛ظٹظٹط± ط§ظ„طµظˆط±ط©' : 'Change image';
  static String get addImageOrVideo =>
      _ar ? 'ط¥ط¶ط§ظپط© طµظˆط±ط© ط£ظˆ ظپظٹط¯ظٹظˆ' : 'Add image or video';
  static String get selectProductCategory =>
      _ar ? 'ط§ط®طھط± طھطµظ†ظٹظپ ط§ظ„ظ…ظ†طھط¬' : 'Choose a product category';
  static String get selectLocalCategory =>
      _ar ? 'ط§ط®طھط± طھطµظ†ظٹظپ ظ…ط­ظ„ظٹ' : 'Choose a local category';
  static String get localCategory =>
      _ar ? 'طھطµظ†ظٹظپ ظ…ط­ظ„ظٹ' : 'Local category';
  static String get languageCode => 'AR';
  static String get currency => _ar ? 'ط±.ط³' : 'SAR';
  static String get productData =>
      _ar ? 'ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…ظ†طھط¬' : 'Product data';
  static String get categoryData =>
      _ar ? 'ط¨ظٹط§ظ†ط§طھ ط§ظ„طھطµظ†ظٹظپ' : 'Category data';
  static String get optionsAndQuantity =>
      _ar ? 'ط§ظ„ط®ظٹط§ط±ط§طھ ظˆط§ظ„ظƒظ…ظٹط©' : 'Options and quantity';
  static String get addCategoryShort =>
      _ar ? 'ط§ط¶ظپ طھطµظ†ظٹظپ' : 'Add category';

  // ---------- Brand panel ----------
  static String get brandTitle => _ar
      ? 'ظ†ط¸ط§ظ… ط¥ط¯ط§ط±ط© ظ…طھظƒط§ظ…ظ„ ظ„ظ„ظ…ظ‚ط§ظ‡ظٹ ظˆط§ظ„ظ…ط·ط§ط¹ظ…'
      : 'A complete management system for cafs and restaurants';
  static String get brandDescription => _ar
      ? 'طھط§ط¨ط¹ ط§ظ„ط·ظ„ط¨ط§طھ ظˆط§ظ„ظ…ط®ط²ظˆظ† ظˆط§ظ„ط¹ظ…ظ„ط§ط، ظˆط§ظ„ظ…ظˆط¸ظپظٹظ† ظˆط§ظ„طھظ‚ط§ط±ظٹط± ظ…ظ† ظ„ظˆط­ط© طھط­ظƒظ… ظˆط§ط­ط¯ط© ط¨طھطµظ…ظٹظ… ط§ط­طھط±ط§ظپظٹ ظˆط³ط±ظٹط¹ ط§ظ„ط§ط³طھط¬ط§ط¨ط©.'
      : 'Track orders, inventory, customers, staff and reports from a single professional dashboard that adapts to every screen.';
  static String get add => 'add';
  static String get addBanner => 'addBanner';
  static String get addBranch => 'addBranch';
  static String get addBundle => 'addBundle';
  static String get addDeliveryZone => 'addDeliveryZone';
  static String get addImage => 'addImage';
  static String get addZone => 'addZone';
  static String get adjustments => 'adjustments';
  static String get adminNotes => 'adminNotes';
  static String get allergens => 'allergens';
  static String get allStatuses => 'allStatuses';
  static String get applyToAllImages => 'applyToAllImages';
  static String get applyToAllImagesConfirm => 'applyToAllImagesConfirm';
  static String get applyToThisImage => 'applyToThisImage';
  static String get beforeAfter => 'beforeAfter';
  static String get blacklist => 'blacklist';
  static String get branchAddress => 'branchAddress';
  static String get branchCode => 'branchCode';
  static String get branchDeliveryDescription => 'branchDeliveryDescription';
  static String get branchLabel => 'branchLabel';
  static String get branchLocationNeeded => 'branchLocationNeeded';
  static String get branchLocationUnavailable => 'branchLocationUnavailable';
  static String get branchNeedsCode => 'branchNeedsCode';
  static String get branchNeedsName => 'branchNeedsName';
  static String get branchPhone => 'branchPhone';
  static String get brightness => 'brightness';
  static String get calories => 'calories';
  static String get cartDetailsTitle => 'cartDetailsTitle';
  static String get cartStatusAbandoned => 'cartStatusAbandoned';
  static String get cartStatusActive => 'cartStatusActive';
  static String get centerLatitude => 'centerLatitude';
  static String get centerLongitude => 'centerLongitude';
  static String get changePaymentStatus => 'changePaymentStatus';
  static String get changeStatus => 'changeStatus';
  static String get clearFilters => 'clearFilters';
  static String get clearSelection => 'clearSelection';
  static String get close => 'close';
  static String get closesAt => 'closesAt';
  static String get contrast => 'contrast';
  static String get couldNotSaveProduct => 'couldNotSaveProduct';
  static String get createdCategories => 'createdCategories';
  static String get createdProducts => 'createdProducts';
  static String get customerAddressesLabel => 'customerAddressesLabel';
  static String get customerInfoTitle => 'customerInfoTitle';
  static String get customerOrdersLabel => 'customerOrdersLabel';
  static String get customerSubscriptionsLabel => 'customerSubscriptionsLabel';
  static String get deleteImage => 'deleteImage';
  static String get deleteImageConfirm => 'deleteImageConfirm';
  static String get deleteSelectedProducts => 'deleteSelectedProducts';
  static String get deliveryDistance => 'deliveryDistance';
  static String get deliveryFee => 'deliveryFee';
  static String get deliveryFeeAmount => 'deliveryFeeAmount';
  static String get deliveryFeeMethod => 'deliveryFeeMethod';
  static String get deliveryFeePerKm => 'deliveryFeePerKm';
  static String get deliveryLocation => 'deliveryLocation';
  static String get deliveryRadiusKm => 'deliveryRadiusKm';
  static String get directDistanceFeeHint => 'directDistanceFeeHint';
  static String get discount => 'discount';
  static String get discountEndDate => 'discountEndDate';
  static String get discountPercentage => 'discountPercentage';
  static String get discountStartDate => 'discountStartDate';
  static String get discountStatusActive => 'discountStatusActive';
  static String get discountStatusExpired => 'discountStatusExpired';
  static String get discountStatusNotActive => 'discountStatusNotActive';
  static String get discountStatusScheduled => 'discountStatusScheduled';
  static String get downloadSampleFile => 'downloadSampleFile';
  static String get downloadSampleFileHint => 'downloadSampleFileHint';
  static String get editBanner => 'editBanner';
  static String get editBranch => 'editBranch';
  static String get editBranchLocation => 'editBranchLocation';
  static String get editBundle => 'editBundle';
  static String get editImage => 'editImage';
  static String get editZone => 'editZone';
  static String get estimatedDelivery => 'estimatedDelivery';
  static String get estimatedDeliveryMinutes => 'estimatedDeliveryMinutes';
  static String get exportExcel => 'exportExcel';
  static String get exporting => 'exporting';
  static String get exportSuccess => 'exportSuccess';
  static String get exposure => 'exposure';
  static String get failedProducts => 'failedProducts';
  static String get feePerKilometer => 'feePerKilometer';
  static String get filters => 'filters';
  static String get fixedDeliveryFee => 'fixedDeliveryFee';
  static String get flipHorizontal => 'flipHorizontal';
  static String get flipVertical => 'flipVertical';
  static String get freeDelivery => 'freeDelivery';
  static String get freeDeliveryMinimum => 'freeDeliveryMinimum';
  static String get fulfillmentDelivery => 'fulfillmentDelivery';
  static String get fulfillmentFilter => 'fulfillmentFilter';
  static String get fulfillmentInfoTitle => 'fulfillmentInfoTitle';
  static String get fulfillmentPickup => 'fulfillmentPickup';
  static String get grandTotal => 'grandTotal';
  static String get highlights => 'highlights';
  static String get hours => 'hours';
  static String get imageActionFailed => 'imageActionFailed';
  static String get imageActionForbidden => 'imageActionForbidden';
  static String get imageAlignment => 'imageAlignment';
  static String get imageCouldNotBeOpened => 'imageCouldNotBeOpened';
  static String get imageCouldNotBeSaved => 'imageCouldNotBeSaved';
  static String get imageFit => 'imageFit';
  static String get imageScope => 'imageScope';
  static String get imageSettings => 'imageSettings';
  static String get imageSettingsMissing => 'imageSettingsMissing';
  static String get imageSource => 'imageSource';
  static String get importExcel => 'importExcel';
  static String get importing => 'importing';
  static String get importSummary => 'importSummary';
  static String get intensity => 'intensity';
  static String get invalidDeliveryZoneFields => 'invalidDeliveryZoneFields';
  static String get invalidDiscountPercentage => 'invalidDiscountPercentage';
  static String get invalidDiscountRange => 'invalidDiscountRange';
  static String get invalidExcelFile => 'invalidExcelFile';
  static String get invalidPerKmFee => 'invalidPerKmFee';
  static String get invalidPrepTime => 'invalidPrepTime';
  static String get invalidRows => 'invalidRows';
  static String get itemsTitle => 'itemsTitle';
  static String get locationPermissionDenied => 'locationPermissionDenied';
  static String get manageBranchPricing => 'manageBranchPricing';
  static String get manageDelivery => 'manageDelivery';
  static String get maxDeliveryFee => 'maxDeliveryFee';
  static String get minimumOrder => 'minimumOrder';
  static String get minutes => 'minutes';
  static String get noAddresses => 'noAddresses';
  static String get noBranchDeliveryZones => 'noBranchDeliveryZones';
  static String get noBranchesFound => 'noBranchesFound';
  static String get noCartsFound => 'noCartsFound';
  static String get noDeliveryAddress => 'noDeliveryAddress';
  static String get noImagesYet => 'noImagesYet';
  static String get noOrders => 'noOrders';
  static String get noOrdersForFilter => 'noOrdersForFilter';
  static String get noPaymentsFound => 'noPaymentsFound';
  static String get noProductsYet => 'noProductsYet';
  static String get noSubscriptions => 'noSubscriptions';
  static String get opensAt => 'opensAt';
  static String get orderCannotBeEdited => 'orderCannotBeEdited';
  static String get orderPlacedAt => 'orderPlacedAt';
  static String get paidAt => 'paidAt';
  static String get paymentCard => 'paymentCard';
  static String get paymentInfoTitle => 'paymentInfoTitle';
  static String get paymentMethod => 'paymentMethod';
  static String get paymentMethodCash => 'paymentMethodCash';
  static String get paymentStatusFailed => 'paymentStatusFailed';
  static String get paymentStatusFilter => 'paymentStatusFilter';
  static String get paymentStatusLabelTitle => 'paymentStatusLabelTitle';
  static String get paymentStatusPaid => 'paymentStatusPaid';
  static String get paymentStatusPending => 'paymentStatusPending';
  static String get paymentStatusRefunded => 'paymentStatusRefunded';
  static String get paymentStatusUnpaid => 'paymentStatusUnpaid';
  static String get prepTime => 'prepTime';
  static String get prepUnit => 'prepUnit';
  static String get prepValue => 'prepValue';
  static String get priceAfterDiscount => 'priceAfterDiscount';
  static String get primary => 'primary';
  static String get productImages => 'productImages';
  static String get productNeedsCategory => 'productNeedsCategory';
  static String get productNeedsName => 'productNeedsName';
  static String get productWasAdded => 'productWasAdded';
  static String get provider => 'provider';
  static String get published => 'published';
  static String get quantity => 'quantity';
  static String get redo => 'redo';
  static String get registeredAt => 'registeredAt';
  static String get removeItem => 'removeItem';
  static String get removeItemConfirm => 'removeItemConfirm';
  static String get removeItemUnavailable => 'removeItemUnavailable';
  static String get replaceImage => 'replaceImage';
  static String get resetImage => 'resetImage';
  static String get retry => 'retry';
  static String get rowsCount => 'rowsCount';
  static String get saturation => 'saturation';
  static String get saveProductFirst => 'saveProductFirst';
  static String get savingImage => 'savingImage';
  static String get seconds => 'seconds';
  static String get selectProduct => 'selectProduct';
  static String get setPrimaryImage => 'setPrimaryImage';
  static String get shadows => 'shadows';
  static String get sharpness => 'sharpness';
  static String get statusFilter => 'statusFilter';
  static String get subtotal => 'subtotal';
  static String get tax => 'tax';
  static String get undo => 'undo';
  static String get unknownCustomer => 'unknownCustomer';
  static String get updatedAt => 'updatedAt';
  static String get updatedCategories => 'updatedCategories';
  static String get updatedProducts => 'updatedProducts';
  static String get uploadFromDevice => 'uploadFromDevice';
  static String get uploadingImage => 'uploadingImage';
  static String get useGeneralDiscount => 'useGeneralDiscount';
  static String get useImageLink => 'useImageLink';
  static String get useTotal => 'useTotal';
  static String get verifiedByServer => 'verifiedByServer';
  static String get vip => 'vip';
  static String get warmth => 'warmth';
  static String get zoneMapTapHint => 'zoneMapTapHint';
  static String get zoneNameArabic => 'zoneNameArabic';
  static String get zoneNameEnglish => 'zoneNameEnglish';
  static String get zoneSharedBranchNotice => 'zoneSharedBranchNotice';
  static String get zoomIn => 'zoomIn';
  static String get zoomOut => 'zoomOut';
  static String branchActiveZoneCount([dynamic a, dynamic b, dynamic c]) =>
      'branchActiveZoneCount';
  static String branchDeliverySettings([dynamic a, dynamic b, dynamic c]) =>
      'branchDeliverySettings';
  static String branchPricingFor([dynamic a, dynamic b, dynamic c]) =>
      'branchPricingFor';
  static String branchesCount(int count) => '$count branches';
  static String bundlesCount(int count) => '$count bundles';
  static String cartItemsCount(int count) => '$count items';
  static String cartStatusLabel([dynamic a, dynamic b, dynamic c]) =>
      'cartStatusLabel';
  static String deleteProductsConfirm(int count) =>
      'This will permanently delete $count products. Continue?';
  static String ordersCount(int count) => '$count orders';
  static String paymentStatusLabel(String status) => switch (status) {
    'unpaid' => paymentStatusUnpaid,
    'pending' => paymentStatusPending,
    'paid' => paymentStatusPaid,
    'failed' => paymentStatusFailed,
    'refunded' => paymentStatusRefunded,
    _ => status,
  };
  static String productsDeleted(int count) => '$count products deleted';
  static String productsDeletePartial(int count) =>
      'Could not delete $count products. They remain selected so you can retry.';
  static String selectAllProducts(int count) =>
      'Select all matching products ($count)';
  static String selectedProductsCount(int count) =>
      '$count selected';

  // ---------- Customer preview ----------
  static String get customerPreview => 'Customer preview';
  static String get customerPreviewHint => 'Preview the customer app';
  static String get previewDraftMode => 'Preview - draft mode';
  static String get previewPublishedMode => 'Preview - published';
  static String get previewRefresh => 'Refresh';
  static String get previewResetDraft => 'Reset draft';
  static String get previewSaveDraft => 'Save draft';
  static String get previewPublish => 'Publish';
  static String get previewViewport => 'Viewport';
  static String get previewScreen => 'Screen';
  static String get previewCustomerAppUrl => 'Customer app URL';
  static String get previewPrimaryColor => 'Primary color';
  static String get previewSecondaryColor => 'Secondary color';
  static String get previewBackgroundColor => 'Background color';
  static String get previewSurfaceColor => 'Surface color';
  static String get previewUnsupported => 'Preview is available on web builds.';
  static String get previewLoading => 'Loading customer preview...';
  static String get previewError => 'Unable to load the customer preview.';
}