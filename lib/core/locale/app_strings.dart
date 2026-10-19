import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/location/data/model/location_failure.dart';

/// Every user-visible string in one place.
///
/// Each getter reads the current [AppLocale] at build time, so toggling the
/// language rebuilds the whole tree (see `AnimatedBuilder` in `main.dart`)
/// and every label أ¢â‚¬â€‌ including database-driven screens أ¢â‚¬â€‌ flips together.
/// Database *content* (names, descriptions) stays in the models; everything
/// around it lives here.
class S {
  S._();

  static bool get _ar => AppLocale.instance.isArabic;

  static String get appName => _ar ? 'ط¸â€ ط¸ظ¹ط¸ث† ط¸ئ’ط¸ث†ط¸ظ¾ط¸ظ¹' : 'New Coffee';

  // ---------- Common ----------
  static String get retry => _ar ? 'ط·آ¥ط·آ¹ط·آ§ط·آ¯ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ­ط·آ§ط¸ث†ط¸â€‍ط·آ©' : 'Retry';
  static String get cancel => _ar ? 'ط·آ¥ط¸â€‍ط·ط›ط·آ§ط·طŒ' : 'Cancel';
  static String get locationPermissionTitle => _ar
      ? 'ط·آ§ط¸â€‍ط·آ³ط¸â€¦ط·آ§ط·آ­ ط·آ¨ط·آ§ط¸â€‍ط¸ث†ط·آµط¸ث†ط¸â€‍ ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹'
      : 'Allow location access';
  static String get locationPermissionBody => _ar
      ? 'ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط¸â€‍ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ ط·ع¾ط·آ­ط·آ³ط¸ظ¹ط¸â€  ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط¸ث†ط·آ§ط¸â€‍ط·آ®ط·آ¯ط¸â€¦ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط·ع¾ط·آ¨ط·آ·ط·آ© ط·آ¨ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹. ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€ ط¸ئ’ ط·آ§ط¸â€‍ط¸â€¦ط·ع¾ط·آ§ط·آ¨ط·آ¹ط·آ© ط·آ¨ط·آ¯ط¸ث†ط¸â€  ط¸â€¦ط¸â€ ط·آ­ ط·آ§ط¸â€‍ط·آ¥ط·آ°ط¸â€ .'
      : 'Location can improve delivery and location-related features. You can continue without granting permission.';
  static String get enableLocation => _ar ? 'ط·ع¾ط¸ظ¾ط·آ¹ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹' : 'Enable location';
  static String get notNow => _ar ? 'ط¸â€‍ط¸ظ¹ط·آ³ ط·آ§ط¸â€‍ط·آ¢ط¸â€ ' : 'Not now';
  static String get locationPermissionDenied => _ar
      ? 'ط·ع¾ط¸â€¦ ط·آ±ط¸ظ¾ط·آ¶ ط·آ§ط¸â€‍ط·آ¥ط·آ°ط¸â€ . ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€ ط¸ئ’ ط·ع¾ط¸ظ¾ط·آ¹ط¸ظ¹ط¸â€‍ط¸â€، ط¸â€‍ط·آ§ط·آ­ط¸â€ڑط¸â€¹ط·آ§ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط·آ¥ط·آ¹ط·آ¯ط·آ§ط·آ¯ط·آ§ط·ع¾.'
      : 'Permission denied. You can enable it later in settings.';
  static String get ok => _ar ? 'ظ…ظˆط§ظپظ‚' : 'OK';
  static String get submit => _ar ? 'ط·آ¥ط·آ±ط·آ³ط·آ§ط¸â€‍' : 'Submit';
  static String get save => _ar ? 'ط·آ­ط¸ظ¾ط·آ¸' : 'Save';
  static String get apply => _ar ? 'ط·ع¾ط·آ·ط·آ¨ط¸ظ¹ط¸â€ڑ' : 'Apply';
  static String get confirm => _ar ? 'ط·ع¾ط·آ£ط¸ئ’ط¸ظ¹ط·آ¯' : 'Confirm';
  static String get change => _ar ? 'ط·ع¾ط·ط›ط¸ظ¹ط¸ظ¹ط·آ±' : 'Change';
  static String get back => _ar ? 'ط·آ±ط·آ¬ط¸ث†ط·آ¹' : 'Back';
  static String get verify => _ar ? 'ط·ع¾ط·آ­ط¸â€ڑط¸â€ڑ' : 'Verify';
  static String get total => _ar ? 'ط·آ§ط¸â€‍ط·آ¥ط·آ¬ط¸â€¦ط·آ§ط¸â€‍ط¸ظ¹' : 'Total';
  static String get subtotal => _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط·آ¬ط¸â€¦ط¸ث†ط·آ¹ ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹ط¸ظ¹' : 'Subtotal';
  static String get deliveryFee => _ar ? 'ط·آ±ط·آ³ط¸ث†ط¸â€¦ ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍' : 'Delivery Fee';
  static String get discount => _ar ? 'ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦' : 'Discount';
  static String get couponDiscount => _ar ? 'ط·آ®ط·آµط¸â€¦ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¨ط¸ث†ط¸â€ ' : 'Coupon discount';
  static String get required => _ar ? 'ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨' : 'Required';

  // ---------- Navigation ----------
  static String get navHome => _ar ? 'ط·آ§ط¸â€‍ط·آ±ط·آ¦ط¸ظ¹ط·آ³ط¸ظ¹ط·آ©' : 'Home';
  static String get navCategories => _ar ? 'ط·آ§ط¸â€‍ط·ع¾ط·آµط¸â€ ط¸ظ¹ط¸ظ¾ط·آ§ط·ع¾' : 'Categories';
  static String get navCart => _ar ? 'ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : 'Cart';
  static String get navFavorites => _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط¸ظ¾ط·آ¶ط¸â€‍ط·آ©' : 'Favorites';
  static String get navSettings => _ar ? 'ط·آ§ط¸â€‍ط·آ¥ط·آ¹ط·آ¯ط·آ§ط·آ¯ط·آ§ط·ع¾' : 'Settings';

  // ---------- Home ----------
  static String get homeQuestion =>
      _ar ? 'ط¸â€¦ط·آ§ط·آ°ط·آ§ ط·ع¾ط·آ±ط¸ظ¹ط·آ¯ ط·آ§ط¸â€‍ط¸ظ¹ط¸ث†ط¸â€¦ط·ع؛' : 'What would you like today?';
  static String get categories => _ar ? 'ط·آ§ط¸â€‍ط·ع¾ط·آµط¸â€ ط¸ظ¹ط¸ظ¾ط·آ§ط·ع¾' : 'Categories';
  static String get category => _ar ? 'ط·آ§ط¸â€‍ط·ع¾ط·آµط¸â€ ط¸ظ¹ط¸ظ¾' : 'Category';
  static String get seeAll => _ar ? 'ط·آ¹ط·آ±ط·آ¶ ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍' : 'See all';
  static String get viewMore => _ar ? 'ط·آ¹ط·آ±ط·آ¶ ط·آ§ط¸â€‍ط¸â€¦ط·آ²ط¸ظ¹ط·آ¯' : 'View more';
  static String get popular => _ar ? 'ط·آ§ط¸â€‍ط·آ£ط¸ئ’ط·آ«ط·آ± ط·آ·ط¸â€‍ط·آ¨ط¸â€¹ط·آ§' : 'Popular';
  static String get youMayLike => _ar ? 'ط¸â€ڑط·آ¯ ط¸ظ¹ط·آ¹ط·آ¬ط·آ¨ط¸ئ’' : 'You may like';
  static String get recommendations => _ar ? 'ط·ع¾ط·آ±ط·آ´ط¸ظ¹ط·آ­ط·آ§ط·ع¾ ط¸â€‍ط¸ئ’' : 'Recommendations';
  static String get hotDayPicks =>
      _ar ? 'ط·آ§ط·آ®ط·ع¾ط¸ظ¹ط·آ§ط·آ±ط·آ§ط·ع¾ ط¸â€¦ط¸â€ ط·آ¹ط·آ´ط·آ© ط¸â€‍ط¸ظ¹ط¸ث†ط¸â€¦ ط·آ­ط·آ§ط·آ±' : 'Cool picks for a warm day';
  static String get coldDayPicks =>
      _ar ? 'ط·آ§ط·آ®ط·ع¾ط¸ظ¹ط·آ§ط·آ±ط·آ§ط·ع¾ ط·آ¯ط·آ§ط¸ظ¾ط·آ¦ط·آ© ط¸â€‍ط¸ظ¹ط¸ث†ط¸â€¦ ط·آ¨ط·آ§ط·آ±ط·آ¯' : 'Warm picks for a chilly day';
  static String get bundles => _ar ? 'ط·آ§ط¸â€‍ط·آ¨ط·آ§ط¸â€ڑط·آ§ط·ع¾' : 'Bundles';
  static String get goodMorning => _ar ? 'ط·آµط·آ¨ط·آ§ط·آ­ ط·آ§ط¸â€‍ط·آ®ط¸ظ¹ط·آ±' : 'Good Morning';
  static String get goodAfternoon => _ar ? 'ط¸â€¦ط·آ³ط·آ§ط·طŒ ط·آ§ط¸â€‍ط·آ®ط¸ظ¹ط·آ±' : 'Good Afternoon';
  static String get goodEvening => _ar ? 'ط¸â€¦ط·آ³ط·آ§ط·طŒ ط·آ§ط¸â€‍ط·آ®ط¸ظ¹ط·آ±' : 'Good Evening';
  static String get homeLoadError =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آµط¸ظ¾ط·آ­ط·آ© ط·آ§ط¸â€‍ط·آ±ط·آ¦ط¸ظ¹ط·آ³ط¸ظ¹ط·آ©' : 'Could not load the home page';
  static String get noProductsFound =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾' : 'No products found';
  static String get tryAgainLater => _ar ? 'ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€‍ط·آ§ط·آ­ط¸â€ڑط¸â€¹ط·آ§' : 'Try again later';

  // ---------- Search & filters ----------
  static String get search => _ar ? 'ط·آ¨ط·آ­ط·آ«' : 'Search';
  static String get searchHint =>
      _ar ? 'ط·آ§ط·آ¨ط·آ­ط·آ« ط·آ¹ط¸â€  ط·آ§ط¸â€‍ط¸â€ڑط¸â€،ط¸ث†ط·آ©...' : 'Search coffee...';
  static String get searchPromptTitle =>
      _ar ? 'ط·آ§ط·آ¨ط·آ­ط·آ« ط·آ¹ط¸â€  ط¸â€¦ط·آ§ ط·ع¾ط·آ±ط¸ظ¹ط·آ¯' : 'Search for what you crave';
  static String get searchPromptHint => _ar
      ? 'ط·آ§ط¸ئ’ط·ع¾ط·آ¨ ط·آ§ط·آ³ط¸â€¦ ط¸â€¦ط·آ´ط·آ±ط¸ث†ط·آ¨ ط·آ£ط¸ث† ط·آ­ط¸â€‍ط¸ث†أ¢â‚¬آ¦ ط¸â€¦ط·آ«ط·آ§ط¸â€‍: ط¸â€‍ط·آ§ط·ع¾ط¸ظ¹ط¸â€،ط·إ’ ط¸ئ’ط·آ§ط·آ¨ط·ع¾ط·آ´ط¸ظ¹ط¸â€ ط¸ث†'
      : 'Type a drink or dessertأ¢â‚¬آ¦ e.g. latte, cappuccino';
  static String get searchFailed => _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ§ط¸â€‍ط·آ¨ط·آ­ط·آ«' : 'Search failed';
  static String get noResults => _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط¸â€ ط·ع¾ط·آ§ط·آ¦ط·آ¬' : 'No results found';
  static String get tryDifferentKeyword =>
      _ar ? 'ط·آ¬ط·آ±ط¸â€کط·آ¨ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ£ط¸ث† ط¸ظ¾ط¸â€‍ط·آ§ط·ع¾ط·آ± ط¸â€¦ط·آ®ط·ع¾ط¸â€‍ط¸ظ¾ط·آ©' : 'Try a different keyword or filters';
  static String get filters => _ar ? 'ط·آ§ط¸â€‍ط¸ظ¾ط¸â€‍ط·آ§ط·ع¾ط·آ±' : 'Filters';
  static String get sortBy => _ar ? 'ط·ع¾ط·آ±ط·ع¾ط¸ظ¹ط·آ¨ ط·آ­ط·آ³ط·آ¨' : 'Sort by';
  static String get priceRange => _ar ? 'ط¸â€ ط·آ·ط·آ§ط¸â€ڑ ط·آ§ط¸â€‍ط·آ³ط·آ¹ط·آ±' : 'Price range';
  static String get all => _ar ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍' : 'All';
  static String get reset => _ar ? 'ط·آ¥ط·آ¹ط·آ§ط·آ¯ط·آ© ط·ع¾ط·آ¹ط¸ظ¹ط¸ظ¹ط¸â€ ' : 'Reset';

  // ---------- Categories tab ----------
  static String get noCategories =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·ع¾ط·آµط¸â€ ط¸ظ¹ط¸ظ¾ط·آ§ط·ع¾ ط·آ¨ط·آ¹ط·آ¯' : 'No categories yet';
  static String get categoriesSoon => _ar
      ? 'ط·آ³ط·ع¾ط·آ¸ط¸â€،ط·آ± ط·آ§ط¸â€‍ط·ع¾ط·آµط¸â€ ط¸ظ¹ط¸ظ¾ط·آ§ط·ع¾ ط¸â€،ط¸â€ ط·آ§ ط·آ¹ط¸â€ ط·آ¯ ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·ع¾ط¸â€،ط·آ§'
      : 'Categories will appear here once they are added';
  static String get noProductsYet =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾ ط·آ¨ط·آ¹ط·آ¯' : 'No products yet';
  static String productsIn(String label) => _ar
      ? 'ط·آ³ط·ع¾ط·آ¸ط¸â€،ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾ ط¸ظ¾ط¸ظ¹ $label ط¸â€،ط¸â€ ط·آ§'
      : 'Products in $label will appear here';
  static String get couldNotLoadCategories =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·ع¾ط·آµط¸â€ ط¸ظ¹ط¸ظ¾ط·آ§ط·ع¾' : 'Could not load categories';

  // ---------- Product details ----------
  static String get productDetails => _ar ? 'ط·ع¾ط¸ظ¾ط·آ§ط·آµط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬' : 'Product Details';
  static String get totalPrice => _ar ? 'ط·آ§ط¸â€‍ط·آ³ط·آ¹ط·آ± ط·آ§ط¸â€‍ط·آ¥ط·آ¬ط¸â€¦ط·آ§ط¸â€‍ط¸ظ¹' : 'Total Price';
  static String get addToCart => _ar ? 'ط·آ£ط·آ¶ط¸ظ¾ ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : 'Add to Cart';
  static String get unavailable => _ar ? 'ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط¸ث†ط¸ظ¾ط·آ±' : 'Unavailable';
  static String get quantity => _ar ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸â€¦ط¸ظ¹ط·آ©' : 'Quantity';
  static String get goesWellWith => _ar ? 'ط¸ظ¹ط·ع¾ط¸â€¦ط·آ§ط·آ´ط¸â€° ط¸â€¦ط·آ¹ط¸â€،' : 'Goes well with';
  static String get addedToCart =>
      _ar ? 'ط·ع¾ط¸â€¦ط·ع¾ ط·آ§ط¸â€‍ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : 'Added to cart';
  static String get adding => _ar ? 'ط·آ¬ط·آ§ط·آ±ط¸ع† ط·آ§ط¸â€‍ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ©...' : 'Adding...';
  static String get added => _ar ? 'ط·ع¾ط¸â€¦ط·ع¾ ط·آ§ط¸â€‍ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ©' : 'Added';
  static String get failedToAddToCart =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ§ط¸â€‍ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : 'Could not add to cart';
  static String addedProductToCart(String name) =>
      _ar ? 'ط·ع¾ط¸â€¦ط·ع¾ ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© $name ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : '$name added to cart';
  static String get unavailableNow => _ar
      ? 'ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ®ط¸ظ¹ط·آ§ط·آ± ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط¸ث†ط¸ظ¾ط·آ± ط·آ­ط·آ§ط¸â€‍ط¸ظ¹ط¸â€¹ط·آ§'
      : 'This combination is not available right now';
  static String chooseOption(String name) =>
      _ar ? 'ط¸ظ¹ط·آ¬ط·آ¨ ط·آ§ط·آ®ط·ع¾ط¸ظ¹ط·آ§ط·آ± $name' : 'Please choose $name';
  static String maxOption(int max, String name) => _ar
      ? 'ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€ ط¸ئ’ ط·آ§ط·آ®ط·ع¾ط¸ظ¹ط·آ§ط·آ± $max ط¸ظ¾ط¸â€ڑط·آ· ط¸â€¦ط¸â€  $name'
      : 'You can pick at most $max for $name';

  // ---------- Cart ----------
  static String get cart => _ar ? 'ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : 'Cart';
  static String get cartEmpty => _ar ? 'ط·آ³ط¸â€‍ط·ع¾ط¸ئ’ ط¸ظ¾ط·آ§ط·آ±ط·ط›ط·آ©' : 'Your cart is empty';
  static String get cartEmptyHint => _ar
      ? 'ط·آ£ط·آ¶ط¸ظ¾ ط¸â€ڑط¸â€،ط¸ث†ط·ع¾ط¸ئ’ ط·آ§ط¸â€‍ط¸â€¦ط¸ظ¾ط·آ¶ط¸â€‍ط·آ© ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط¸â€ڑط·آ§ط·آ¦ط¸â€¦ط·آ©'
      : 'Add your favorite coffee from the menu';
  static String get subTotal => _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط·آ¬ط¸â€¦ط¸ث†ط·آ¹ ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹ط¸ظ¹' : 'Sub-Total';
  static String get totalCost => _ar ? 'ط·آ§ط¸â€‍ط·ع¾ط¸ئ’ط¸â€‍ط¸ظ¾ط·آ© ط·آ§ط¸â€‍ط·آ¥ط·آ¬ط¸â€¦ط·آ§ط¸â€‍ط¸ظ¹ط·آ©' : 'Total Cost';
  static String get promoCode => _ar ? 'ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦' : 'Promo Code';
static String get clearPromoCode =>
      _ar ? 'ط¸â€¦ط·آ³ط·آ­ ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦' : 'Clear promo code';
  static String get proceedToCheckout =>
      _ar ? 'ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Proceed to Checkout';
  static String removedFromCart(String name) =>
      _ar ? 'ط·ع¾ط¸â€¦ط·ع¾ ط·آ¥ط·آ²ط·آ§ط¸â€‍ط·آ© $name' : 'Removed $name';
  static String get undo => _ar ? 'ط·ع¾ط·آ±ط·آ§ط·آ¬ط·آ¹' : 'Undo';

  // ---------- Checkout ----------
  static String get checkout => _ar ? 'ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹' : 'Checkout';
  static String get pickupBranch => _ar ? 'ط¸ظ¾ط·آ±ط·آ¹ ط·آ§ط¸â€‍ط·آ§ط·آ³ط·ع¾ط¸â€‍ط·آ§ط¸â€¦' : 'Pickup Branch';
  static String get shippingAddress =>
      _ar ? 'ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€  ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍' : 'Shipping Address';
  static String get orderList => _ar ? 'ط¸â€ڑط·آ§ط·آ¦ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Order List';
  static String get continueToPayment =>
      _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط·ع¾ط·آ§ط·آ¨ط·آ¹ط·آ© ط¸â€‍ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹' : 'Continue to Payment';
  static String get confirmPayment => _ar ? 'ط·ع¾ط·آ£ط¸ئ’ط¸ظ¹ط·آ¯ ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹' : 'Confirm Payment';
  static String get orderFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.' : 'Could not place the order. Please try again.';
  static String get addAddressName =>
      _ar ? 'ط¸â€¦ط¸â€  ط¸ظ¾ط·آ¶ط¸â€‍ط¸ئ’ ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ§ط·آ³ط¸â€¦ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ ' : 'Please enter an address name';
  static String get addAddressLocation =>
      _ar ? 'ط¸â€¦ط¸â€  ط¸ظ¾ط·آ¶ط¸â€‍ط¸ئ’ ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ئ’' : 'Please enter your location';
  static String get enterLocation => _ar ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ئ’' : 'Enter your location';
  static String get eReceipt => _ar ? 'ط·آ§ط¸â€‍ط·آ¥ط¸ظ¹ط·آµط·آ§ط¸â€‍' : 'E-Receipt';
  static String get noReceipt => _ar ? 'ط¸â€‍ط·آ§ ط¸ظ¹ط¸ث†ط·آ¬ط·آ¯ ط·آ¥ط¸ظ¹ط·آµط·آ§ط¸â€‍ ط·آ¨ط·آ¹ط·آ¯' : 'No receipt yet';
  static String get receiptHint => _ar
      ? 'ط·آ³ط¸ظ¹ط·آ¸ط¸â€،ط·آ± ط·آ¥ط¸ظ¹ط·آµط·آ§ط¸â€‍ ط·آ·ط¸â€‍ط·آ¨ط¸ئ’ ط·آ§ط¸â€‍ط·آ£ط·آ®ط¸ظ¹ط·آ± ط¸â€،ط¸â€ ط·آ§'
      : 'Your latest order receipt will appear here';
  static String get goToMain => _ar ? 'ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ±ط·آ¦ط¸ظ¹ط·آ³ط¸ظ¹ط·آ©' : 'Go to main page';
  static String get useCurrentLocation =>
      _ar ? 'ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط·آ§ط¸â€¦ ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ظ¹ ط·آ§ط¸â€‍ط·آ­ط·آ§ط¸â€‍ط¸ظ¹' : 'Use my current location';
  static String get locationUnavailable => _ar
      ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ¯ ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ئ’. ط·ع¾ط·آ£ط¸ئ’ط·آ¯ ط¸â€¦ط¸â€  ط·ع¾ط¸ظ¾ط·آ¹ط¸ظ¹ط¸â€‍ ط·آ®ط·آ¯ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ ط·آ£ط¸ث† ط·آ­ط·آ¯ط¸â€کط·آ¯ ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط·آ§ط¸â€  ط·آ¹ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ®ط·آ±ط¸ظ¹ط·آ·ط·آ©.'
      : "Couldn't get your location. Turn location services on, or pick a spot on the map.";

  /// Why a position could not be used.
  ///
  /// Each case needs a different action from the customer, so they are separate
  /// strings rather than one shared apology. The permanently-denied case in
  /// particular: the system dialog will never appear again, so only Settings
  /// can fix it أ¢â‚¬â€‌ which is why the UI offers a button to open them.
  static String locationFailed(LocationFailure failure) => switch (failure) {
    LocationFailure.servicesDisabled => _ar
        ? 'ط·آ®ط·آ¯ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ ط¸â€¦ط·ط›ط¸â€‍ط¸â€ڑط·آ©. ط·آ´ط·ط›ط¸â€کط¸â€‍ط¸â€،ط·آ§ ط·آ«ط¸â€¦ ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.'
        : 'Location is off. Turn it on and try again.',
    LocationFailure.permissionDenied => _ar
        ? 'ط·آ§ط¸â€‍ط·ع¾ط·آ·ط·آ¨ط¸ظ¹ط¸â€ڑ ط¸ظ¹ط·آ­ط·ع¾ط·آ§ط·آ¬ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ ط¸â€‍ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ¯ ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ ط¸ئ’.'
        : 'The app needs location permission to find your address.',
    LocationFailure.permissionPermanentlyDenied => _ar
        ? 'ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ ط¸â€¦ط·آ±ط¸ظ¾ط¸ث†ط·آ¶ط·آ© ط¸â€ ط¸â€،ط·آ§ط·آ¦ط¸ظ¹ط¸â€¹ط·آ§. ط¸ظ¾ط·آ¹ط¸â€کط¸â€‍ط¸â€،ط·آ§ ط¸â€¦ط¸â€  ط·آ¥ط·آ¹ط·آ¯ط·آ§ط·آ¯ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·ع¾ط·آ·ط·آ¨ط¸ظ¹ط¸â€ڑ.'
        : 'Location permission is permanently denied. Enable it in app settings.',
    LocationFailure.timeout => _ar
        ? 'ط¸â€¦ط·آ§ ط¸â€ڑط·آ¯ط·آ±ط¸â€ ط·آ§ط·آ´ ط¸â€ ط·آ­ط·آ¯ط·آ¯ ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ئ’ ط¸ظ¾ط¸ظ¹ ط·آ§ط¸â€‍ط¸ث†ط¸â€ڑط·ع¾ ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·آ§ط·آ³ط·آ¨. ط·آ¬ط·آ±ط¸â€کط·آ¨ ط¸â€¦ط¸ئ’ط·آ§ط¸â€ ط¸â€¹ط·آ§ ط¸â€¦ط¸ظ¾ط·ع¾ط¸ث†ط·آ­ط¸â€¹ط·آ§.'
        : "We couldn't fix your position in time. Try somewhere more open.",
    LocationFailure.unavailable => _ar
        ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ¯ ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ئ’ ط·آ­ط·آ§ط¸â€‍ط¸ظ¹ط¸â€¹ط·آ§. ط·آ­ط·آ¯ط¸â€کط·آ¯ ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط·آ§ط¸â€  ط·آ¹ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ®ط·آ±ط¸ظ¹ط·آ·ط·آ© ط¸ظ¹ط·آ¯ط¸ث†ط¸ظ¹ط¸â€¹ط·آ§.'
        : 'Could not get your position. Pick a spot on the map.',
  };

  /// Opens the app's settings page, for the one case that only Settings fixes.
  static String get openSettings => _ar ? 'ط¸ظ¾ط·ع¾ط·آ­ ط·آ§ط¸â€‍ط·آ¥ط·آ¹ط·آ¯ط·آ§ط·آ¯ط·آ§ط·ع¾' : 'Open settings';
  static String get searchLocation =>
      _ar ? 'ط·آ§ط·آ¨ط·آ­ط·آ« ط·آ¹ط¸â€  ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ئ’' : 'Search your location';
  static String get addressNameHint =>
      _ar ? 'ط·آ§ط·آ³ط¸â€¦ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€  (ط¸â€¦ط·آ«ط·آ§ط¸â€‍: ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·آ²ط¸â€‍)' : 'Address name (e.g. Home)';
  static String get totalToPay => _ar ? 'ط·آ§ط¸â€‍ط·آ¥ط·آ¬ط¸â€¦ط·آ§ط¸â€‍ط¸ظ¹ ط¸â€‍ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹' : 'Total to pay';
  static String get paymentSuccess =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹ ط·آ¨ط¸â€ ط·آ¬ط·آ§ط·آ­!' : 'Payment Successful!';
  static String get thankYouPurchase =>
      _ar ? 'ط·آ´ط¸ئ’ط·آ±ط¸â€¹ط·آ§ ط¸â€‍ط·آ´ط·آ±ط·آ§ط·آ¦ط¸ئ’.' : 'Thank you for your purchase.';
  static String get viewEReceipt => _ar ? 'ط·آ¹ط·آ±ط·آ¶ ط·آ§ط¸â€‍ط·آ¥ط¸ظ¹ط·آµط·آ§ط¸â€‍' : 'View E-Receipt';
  static String get fulfillmentMethod =>
      _ar ? 'ط·آ·ط·آ±ط¸ظ¹ط¸â€ڑط·آ© ط·آ§ط¸â€‍ط·آ§ط·آ³ط·ع¾ط¸â€‍ط·آ§ط¸â€¦' : 'Fulfillment Method';
  static String get pickupMethod => _ar ? 'ط·آ§ط·آ³ط·ع¾ط¸â€‍ط·آ§ط¸â€¦ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹' : 'Pickup';
  static String get deliveryMethod => _ar ? 'ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍' : 'Delivery';
  static String get deliveryZone => _ar ? 'ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ© ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍' : 'Delivery Zone';
  static String get selectDeliveryZone =>
      _ar ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ© ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍' : 'Select a delivery zone';
  static String get deliveryUnavailable => _ar
      ? 'ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط·آ§ط·آ­ ط¸â€‍ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹ط·إ’ ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط¸â€‍ط·آ§ط·آ³ط·ع¾ط¸â€‍ط·آ§ط¸â€¦ ط·آ£ط¸ث† ط·ط›ط¸ظ¹ط¸â€کط·آ± ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹.'
      : 'Delivery is unavailable for this branch. Choose pickup or another branch.';
  static String get deliveryAddressRequired => _ar
      ? 'ط·آ£ط·آ¶ط¸ظ¾ ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€  ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط¸â€‍ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨.'
      : 'Add a delivery address to place the order.';
  static String get deliveryZoneRequired =>
      _ar ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ© ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍.' : 'Select a delivery zone.';
  static String get deliveryMinimumNotMet => _ar
      ? 'ط¸â€ڑط¸ظ¹ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ© ط·آ£ط¸â€ڑط¸â€‍ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط·آ­ط·آ¯ ط·آ§ط¸â€‍ط·آ£ط·آ¯ط¸â€ ط¸â€° ط¸â€‍ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط¸ظ¾ط¸ظ¹ ط¸â€،ط·آ°ط¸â€، ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ©.'
      : 'Your cart is below the delivery minimum for this zone.';
  static String get deliveryUnavailableError => _ar
      ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط¸â€¦ط¸â€ ط·آ§ط·آ·ط¸â€ڑ ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ¬ط·آ¯ط·آ¯ط¸â€¹ط·آ§ ط·آ£ط¸ث† ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط¸â€‍ط·آ§ط·آ³ط·ع¾ط¸â€‍ط·آ§ط¸â€¦.'
      : "Couldn't load delivery zones. Try again or choose pickup.";
  static String get deliveryChoosePickup =>
      _ar ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط¸â€‍ط·آ§ط·آ³ط·ع¾ط¸â€‍ط·آ§ط¸â€¦ ط¸â€‍ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨.' : 'Choose pickup to continue.';

  // ---------- Delivery areas ----------
  static String get deliveryOutOfZone => _ar
      ? 'ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ© ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط·آ¯ط¸ظ¹ ط¸â€¦ط·آ´ ط·آ¨ط¸â€ ط·ط›ط·آ·ط¸ظ¹ط¸â€،ط·آ§. ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط·آ³ط·ع¾ط¸â€‍ط·آ§ط¸â€¦ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹ط·إ’ ط·آ£ط¸ث† ط·ط›ط¸ظ¹ط¸â€کط·آ± ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€  ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍.'
      : "We don't deliver to this address. Choose pickup from the branch, or change your delivery address.";
  static String get deliveryOutOfZoneShort => _ar
      ? 'ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط·آ§ط·آ­ ط¸â€‍ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ '
      : 'Delivery is not available for this address';
  static String get deliveryZoneFromAddress => _ar
      ? 'ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ© ط·آ­ط·آ³ط·آ¨ ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ ط¸ئ’'
      : 'Area from your address';
  static String get deliveryChooseZoneManually => _ar
      ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ© ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط¸ظ¹ط·آ¯ط¸ث†ط¸ظ¹ط¸â€¹ط·آ§'
      : 'Choose the delivery area manually';
  static String get deliveryZoneAutoUnavailable => _ar
      ? 'ط¸â€¦ط·آ§ ط¸â€ڑط·آ¯ط·آ±ط¸â€ ط·آ§ط·آ´ ط¸â€ ط·آ­ط·آ¯ط·آ¯ ط¸â€¦ط¸â€ ط·آ·ط¸â€ڑط·آ© ط¸â€¦ط¸ث†ط¸â€ڑط·آ¹ط¸ئ’. ط·آ§ط·آ®ط·ع¾ط·آ±ط¸â€،ط·آ§ ط¸ظ¹ط·آ¯ط¸ث†ط¸ظ¹ط¸â€¹ط·آ§.'
      : "We couldn't match your location to an area. Pick one manually.";
  static String get deliveryFreeOver => _ar
      ? 'ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط¸â€¦ط·آ¬ط·آ§ط¸â€ ط¸ظ¹ ط¸â€‍ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط¸ظ¾ط¸ث†ط¸â€ڑ'
      : 'Free delivery over';
  static String get deliveryPerKm => _ar ? 'ط·آ­ط·آ³ط·آ¨ ط·آ§ط¸â€‍ط¸â€¦ط·آ³ط·آ§ط¸ظ¾ط·آ©' : 'By distance';
  static String get deliveryFlatFee => _ar ? 'ط·آ±ط·آ³ط¸ث†ط¸â€¦ ط·آ«ط·آ§ط·آ¨ط·ع¾ط·آ©' : 'Flat fee';
  static String get deliveryAlwaysFree => _ar ? 'ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط¸â€¦ط·آ¬ط·آ§ط¸â€ ط¸ظ¹' : 'Free delivery';
  static String deliveryDistanceAway(double km) => _ar
      ? 'ط¸ظ¹ط·آ¨ط·آ¹ط·آ¯ $km ط¸ئ’ط¸â€¦ ط·آ¹ط¸â€  ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹'
      : '$km km from the branch';
  static String get couponAppliesTo => _ar ? 'ط¸ظ¹ط¸â€ ط·آ·ط·آ¨ط¸â€ڑ ط·آ¹ط¸â€‍ط¸â€°' : 'Applies to';
  static String get couponAppliesToAll => _ar
      ? 'ط¸ظ¹ط¸â€ ط·آ·ط·آ¨ط¸â€ڑ ط·آ¹ط¸â€‍ط¸â€° ط¸ئ’ط¸â€‍ ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾'
      : 'Applies to everything in your cart';
  /// A scoped coupon discounts only the eligible items, so the figure is a
  /// percentage of those items and not of the whole basket.
  static String get couponScopeDiscountNote => _ar
      ? 'ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦ ط·آ¹ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ¤ط¸â€،ط¸â€‍ط·آ© ط¸ظ¾ط¸â€ڑط·آ·ط·إ’ ط¸â€¦ط·آ´ ط·آ¹ط¸â€‍ط¸â€° ط¸ئ’ط¸â€‍ ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©'
      : 'The discount applies to the eligible items only, not to your whole cart';
  static String get couponEligibleInCart => _ar
      ? 'ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ¤ط¸â€،ط¸â€‍ط·آ© ط¸ظ¾ط¸ظ¹ ط·آ³ط¸â€‍ط·ع¾ط¸ئ’'
      : 'Eligible items in your cart';
  static String get couponDiscountBreakdown => _ar
      ? 'ط·ع¾ط¸ظ¾ط·آµط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦'
      : 'Discount breakdown';
  static String get subTotalDiscounted => _ar ? 'ط·آ¥ط·آ¬ط¸â€¦ط·آ§ط¸â€‍ط¸ظ¹ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦' : 'Total discount';
  static String get lineDiscount => _ar ? 'ط·آ®ط·آµط¸â€¦ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ³ط·آ·ط·آ±' : 'Line discount';
  static String get originalPrice => _ar ? 'ط·آ§ط¸â€‍ط·آ³ط·آ¹ط·آ± ط·آ§ط¸â€‍ط·آ£ط·آµط¸â€‍ط¸ظ¹' : 'Original price';
  static String get discountedPrice => _ar ? 'ط·آ§ط¸â€‍ط·آ³ط·آ¹ط·آ± ط·آ¨ط·آ¹ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦' : 'Price after discount';
  static String get couponBreakdown => _ar ? 'ط·ع¾ط¸ظ¾ط·آµط¸ظ¹ط¸â€‍ ط·آ®ط·آµط¸â€¦ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¨ط¸ث†ط¸â€ ' : 'Coupon discount breakdown';
  static String get setDefaultCard => _ar ? 'ط·ع¾ط·آ¹ط¸ظ¹ط¸ظ¹ط¸â€  ط¸ئ’ط·آ§ط¸ظ¾ط·ع¾ط·آ±ط·آ§ط·آ¶ط¸ظ¹ط·آ©' : 'Set as default';
  static String get defaultCardBadge => _ar ? 'ط·آ§ط¸ظ¾ط·ع¾ط·آ±ط·آ§ط·آ¶ط¸ظ¹ط·آ©' : 'Default';
  static String get payWithSavedCard => _ar
      ? 'ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹ ط·آ¨ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط¸â€¦ط·آ­ط¸ظ¾ط¸ث†ط·آ¸ط·آ©'
      : 'Pay with a saved card';
  static String get chooseSavedCard => _ar ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©' : 'Choose a card';
  static String get noCardsSaved => _ar
      ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ§ط·ع¾ ط¸â€¦ط·آ­ط¸ظ¾ط¸ث†ط·آ¸ط·آ©'
      : 'No saved cards yet';
  static String get cardExpires => _ar ? 'ط·ع¾ط¸â€ ط·ع¾ط¸â€،ط¸ظ¹ ط¸ظ¾ط¸ظ¹' : 'Expires';
  static String get couponLineNotIncluded => _ar
      ? 'ط¸â€¦ط·آ´ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ¤ط¸â€،ط¸â€‍ط·آ©'
      : 'Not an eligible item';
  static String get couponScopeCategories => _ar ? 'ط·آ§ط¸â€‍ط·آ£ط¸â€ڑط·آ³ط·آ§ط¸â€¦' : 'categories';
  static String get couponScopeProducts => _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾' : 'products';

  // ---------- Coupon rejection reasons ----------
  /// Why the server refused a coupon, named precisely.
  ///
  /// [scopeLabel] names what the coupon *would* have applied to, which is the
  /// part a customer actually needs: "this is an espresso coupon" explains
  /// itself, "does not apply to your items" does not. An empty label falls back
  /// to the generic wording.
  ///
  /// [legacyMessage] is the human-readable string older deployments return
  /// instead of a reason code, and is only consulted when [reasonCode] is
  /// absent or unrecognised.
  static String couponRejectedReason(
    String reasonCode,
    String scopeLabel, {
    String legacyMessage = '',
  }) => switch (reasonCode.trim()) {
        'not_found' => _ar ? 'ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦ ط·ط›ط¸ظ¹ط·آ± ط·آµط·آ­ط¸ظ¹ط·آ­' : 'That coupon code is not valid',
        'expired' => _ar ? 'ط·آ§ط¸â€ ط·ع¾ط¸â€،ط·ع¾ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯' : 'This coupon has expired',
        'min_order_not_met' => _ar
            ? 'ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ ط¸â€‍ط¸â€¦ ط¸ظ¹ط·آµط¸â€‍ ط¸â€‍ط¸â€‍ط·آ­ط·آ¯ ط·آ§ط¸â€‍ط·آ£ط·آ¯ط¸â€ ط¸â€° ط·آ§ط¸â€‍ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨ ط¸â€‍ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯'
            : "Your order is below this coupon's minimum",
        'fully_used' => _ar
            ? 'ط·ع¾ط¸â€¦ ط·آ§ط·آ³ط·ع¾ط¸â€ ط¸ظ¾ط·آ§ط·آ¯ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯'
            : 'This coupon has been fully claimed',
        'user_limit_reached' => _ar
            ? 'ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط¸â€¦ط·ع¾ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط·آ¨ط·آ§ط¸â€‍ط·آ­ط·آ¯ ط·آ§ط¸â€‍ط¸â€¦ط·آ³ط¸â€¦ط¸ث†ط·آ­ ط¸â€‍ط¸ئ’'
            : 'You have already used this coupon the allowed number of times',
        'scope_category_no_match' => scopeLabel.isEmpty
            ? _ar
                  ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط¸â€¦ط·آ®ط·آµط·آµ ط¸â€‍ط·آ£ط¸â€ڑط·آ³ط·آ§ط¸â€¦ ط¸â€¦ط·آ­ط·آ¯ط·آ¯ط·آ© ط¸â€¦ط·آ´ ط¸ظ¾ط¸ظ¹ ط·آ³ط¸â€‍ط·ع¾ط¸ئ’'
                  : 'This coupon is limited to certain categories, none of which are in your cart'
            : _ar
            ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط¸â€¦ط·آ®ط·آµط·آµ ط¸â€‍ط¸â‚¬$scopeLabelط·إ’ ط¸ث†ط·آ¯ط¸â€، ط¸â€¦ط·آ´ ط¸â€¦ط¸ث†ط·آ¬ط¸ث†ط·آ¯ ط¸ظ¾ط¸ظ¹ ط·آ³ط¸â€‍ط·ع¾ط¸ئ’'
            : "This coupon is limited to $scopeLabel, which is not in your cart",
        'scope_product_no_match' => scopeLabel.isEmpty
            ? _ar
                  ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط¸â€¦ط·آ®ط·آµط·آµ ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾ ط¸â€¦ط·آ­ط·آ¯ط·آ¯ط·آ© ط¸â€¦ط·آ´ ط¸ظ¾ط¸ظ¹ ط·آ³ط¸â€‍ط·ع¾ط¸ئ’'
                  : 'This coupon is limited to certain products, none of which are in your cart'
            : _ar
            ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط¸â€¦ط·آ®ط·آµط·آµ ط¸â€‍ط¸â‚¬$scopeLabelط·إ’ ط¸ث†ط·آ¯ط¸â€، ط¸â€¦ط·آ´ ط¸â€¦ط¸ث†ط·آ¬ط¸ث†ط·آ¯ ط¸ظ¾ط¸ظ¹ ط·آ³ط¸â€‍ط·ع¾ط¸ئ’'
            : "This coupon is limited to $scopeLabel, which is not in your cart",
        // Legacy bridges and older deployments answer with a message rather than
        // a reason code; fall back to translating that.
        _ => couponRejected(
          legacyMessage.trim().isNotEmpty ? legacyMessage : reasonCode,
        ),
      };

  // ---------- Orders ----------
  static String get myOrders => _ar ? 'ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ط¸ظ¹' : 'My Orders';
  static String get orderDetails => _ar ? 'ط·ع¾ط¸ظ¾ط·آ§ط·آµط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Order Details';
  static String get orderStatus => _ar ? 'ط·آ­ط·آ§ط¸â€‍ط·آ© ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Order Status';
  static String get noOrders => _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط¸â€،ط¸â€ ط·آ§' : 'No orders here';
  static String get signInToSeeOrders =>
      _ar ? 'ط·آ³ط·آ¬ط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍ ط¸â€‍ط·آ±ط·آ¤ط¸ظ¹ط·آ© ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ط¸ئ’' : 'Sign in to see your orders';
  static String get orderHistoryAccount =>
      _ar ? 'ط·آ³ط·آ¬ط¸â€‍ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط¸ظ¹ط·آ®ط·آµ ط·آ­ط·آ³ط·آ§ط·آ¨ط¸ئ’' : 'Order history belongs to your account';
  static String get couldNotLoadOrders =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾' : 'Could not load orders';
  static String get tryAgain => _ar ? 'ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ¬ط·آ¯ط·آ¯ط¸â€¹ط·آ§' : 'Try again';
  static String get ordersEmptyHint => _ar
      ? 'ط·آ³ط·ع¾ط·آ¸ط¸â€،ط·آ± ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ط¸ئ’ ط·آ¨ط¸â€،ط·آ°ط¸â€، ط·آ§ط¸â€‍ط·آ­ط·آ§ط¸â€‍ط·آ© ط¸â€،ط¸â€ ط·آ§'
      : 'Your orders in this status will appear here';
  static String get cancelOrder => _ar ? 'ط·آ¥ط¸â€‍ط·ط›ط·آ§ط·طŒ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Cancel Order';
  static String get orderCancelled =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·آ¥ط¸â€‍ط·ط›ط·آ§ط·طŒ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Order cancelled';
  static String cancelFailed(String error) =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ§ط¸â€‍ط·آ¥ط¸â€‍ط·ط›ط·آ§ط·طŒ: $error' : 'Could not cancel: $error';
  static String get trackingId => _ar ? 'ط·آ±ط¸â€ڑط¸â€¦ ط·آ§ط¸â€‍ط·ع¾ط·ع¾ط·آ¨ط·آ¹' : 'Tracking ID';
  static String orderNumber(String number) =>
      _ar ? 'ط·آ·ط¸â€‍ط·آ¨ ط·آ±ط¸â€ڑط¸â€¦ $number' : 'Order #$number';
  static String get placed => _ar ? 'ط·ع¾ط¸â€¦ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Placed';
  static String get itemsCount => _ar ? 'ط·آ¹ط·آ¯ط·آ¯ ط·آ§ط¸â€‍ط·آ£ط·آµط¸â€ ط·آ§ط¸ظ¾' : 'Items count';
  static String get trackOrder => _ar ? 'ط·ع¾ط·ع¾ط·آ¨ط·آ¹ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Track Order';
  static String get leaveReview => _ar ? 'ط¸â€ڑط¸ظ¹ط¸â€کط¸â€¦ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨' : 'Leave Review';
  static String get addBundleToCart =>
      _ar ? 'ط·آ£ط·آ¶ط¸ظ¾ ط·آ§ط¸â€‍ط·آ¨ط·آ§ط¸â€ڑط·آ© ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : 'Add Bundle to Cart';
  static String redeemedReward(String name) =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·آ§ط·آ³ط·ع¾ط·آ¨ط·آ¯ط·آ§ط¸â€‍ $name' : 'Redeemed $name';
  static String get howIsOrder => _ar ? 'ط¸ئ’ط¸ظ¹ط¸ظ¾ ط¸ئ’ط·آ§ط¸â€  ط·آ·ط¸â€‍ط·آ¨ط¸ئ’ط·ع؛' : 'How is your order?';
  static String get overallRating =>
      _ar ? 'ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦ط¸ئ’ ط·آ§ط¸â€‍ط·آ¹ط·آ§ط¸â€¦' : 'Your overall rating';
  static String get addReview =>
      _ar ? 'ط·آ£ط·آ¶ط¸ظ¾ ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦ط¸â€¹ط·آ§ ط¸â€¦ط¸ظ¾ط·آµط¸â€‍ط¸â€¹ط·آ§' : 'Add detailed review';
  static String get reviewHint =>
      _ar ? 'ط·آ§ط¸ئ’ط·ع¾ط·آ¨ ط·آ±ط·آ£ط¸ظ¹ط¸ئ’ ط¸â€،ط¸â€ ط·آ§...' : 'Write your review here...';
  static String get selectRating =>
      _ar ? 'ط¸â€¦ط¸â€  ط¸ظ¾ط·آ¶ط¸â€‍ط¸ئ’ ط·آ§ط·آ®ط·ع¾ط·آ± ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦ط¸â€¹ط·آ§' : 'Please select a rating';
  static String get reviewSubmitted =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·آ¥ط·آ±ط·آ³ط·آ§ط¸â€‍ ط·آ§ط¸â€‍ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦ ط·آ¨ط¸â€ ط·آ¬ط·آ§ط·آ­' : 'Review submitted successfully';
  static String get history => _ar ? 'ط·آ§ط¸â€‍ط·آ³ط·آ¬ط¸â€‍' : 'History';

  // ---------- Favorites ----------
  static String get favorites => _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط¸ظ¾ط·آ¶ط¸â€‍ط·آ©' : 'Favorites';
  static String get noFavorites =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط¸â€¦ط¸ظ¾ط·آ¶ط¸â€‍ط·آ© ط·آ¨ط·آ¹ط·آ¯' : 'No favorites yet';
  static String get favoritesHint => _ar
      ? 'ط·آ§ط·آ¶ط·ط›ط·آ· ط·آ§ط¸â€‍ط¸â€ڑط¸â€‍ط·آ¨ ط·آ¹ط¸â€‍ط¸â€° ط·آ£ط¸ظ¹ ط¸â€ڑط¸â€،ط¸ث†ط·آ© ط¸â€‍ط·آ­ط¸ظ¾ط·آ¸ط¸â€،ط·آ§ ط¸â€،ط¸â€ ط·آ§'
      : 'Tap the heart on any coffee to save it here';

  // ---------- Bundles ----------
  static String get noBundles => _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ¨ط·آ§ط¸â€ڑط·آ§ط·ع¾ ط·آ¨ط·آ¹ط·آ¯' : 'No bundles yet';
  static String get bundlesHint => _ar
      ? 'ط·آ³ط·ع¾ط·آ¸ط¸â€،ط·آ± ط·آ§ط¸â€‍ط·آ¨ط·آ§ط¸â€ڑط·آ§ط·ع¾ ط¸â€،ط¸â€ ط·آ§ ط·آ¹ط¸â€ ط·آ¯ ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·ع¾ط¸â€،ط·آ§'
      : 'Bundles will appear here once they are added';
  static String get bundlePrice => _ar ? 'ط·آ³ط·آ¹ط·آ± ط·آ§ط¸â€‍ط·آ¨ط·آ§ط¸â€ڑط·آ©' : 'Bundle price';
  static String get originalTotal => _ar ? 'ط·آ§ط¸â€‍ط·آ¥ط·آ¬ط¸â€¦ط·آ§ط¸â€‍ط¸ظ¹ ط·آ§ط¸â€‍ط·آ£ط·آµط¸â€‍ط¸ظ¹' : 'Original total';
  static String get youSave => _ar ? 'ط·آ£ط¸â€ ط·ع¾ ط·ع¾ط¸ث†ط¸ظ¾ط·آ±' : 'You save';
  static String get whatsInside => _ar ? 'ط¸â€¦ط·آ­ط·ع¾ط¸ث†ط¸ظ¹ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ¨ط·آ§ط¸â€ڑط·آ©' : "What's inside";
  static String addedBundleToCart(String title) =>
      _ar ? 'ط·ع¾ط¸â€¦ط·ع¾ ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© $title ط·آ¥ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ©' : '$title added to cart';
  static String bundleNote(String title) =>
      _ar ? 'ط·آ¨ط·آ§ط¸â€ڑط·آ©: $title' : 'Bundle: $title';

  // ---------- Loyalty ----------
  static String get loyaltyPoints => _ar ? 'ط¸â€ ط¸â€ڑط·آ§ط·آ· ط·آ§ط¸â€‍ط¸ث†ط¸â€‍ط·آ§ط·طŒ' : 'Loyalty Points';
  static String points(int value) => _ar ? '$value ط¸â€ ط¸â€ڑط·آ·ط·آ©' : '$value points';
  static String get pointsWord => _ar ? 'ط¸â€ ط¸â€ڑط·آ·ط·آ©' : 'points';
  static String get redeem => _ar ? 'ط·آ§ط·آ³ط·ع¾ط·آ¨ط·آ¯ط·آ§ط¸â€‍' : 'Redeem';
  static String get locked => _ar ? 'ط¸â€¦ط·ط›ط¸â€‍ط¸â€ڑ' : 'Locked';
  static String get keepCollectingToUnlock =>
      _ar ? 'ط¸ث†ط·آ§ط·آµط¸â€‍ ط·آ§ط¸â€‍ط·آ¬ط¸â€¦ط·آ¹ ط¸â€‍ط¸ظ¾ط·ع¾ط·آ­ ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط·آ§ط¸ظ¾ط·آ¢ط·ع¾' : 'Keep collecting to unlock rewards';
  static String get yourPointsUnlock =>
      _ar ? 'ط¸â€ ط¸â€ڑط·آ§ط·آ·ط¸ئ’ ط·ع¾ط¸ظ¾ط·ع¾ط·آ­' : 'Your points unlock';
  static String get keepCollecting => _ar ? 'ط¸ث†ط·آ§ط·آµط¸â€‍ ط·آ§ط¸â€‍ط·آ¬ط¸â€¦ط·آ¹' : 'Keep collecting';
  static String get yourBalance => _ar ? 'ط·آ±ط·آµط¸ظ¹ط·آ¯ط¸ئ’' : 'Your Balance';
  static String get guestWalletDevice =>
      _ar ? 'ط¸â€¦ط·آ­ط¸ظ¾ط·آ¸ط·آ© ط·آ§ط¸â€‍ط·آ¶ط¸ظ¹ط¸ظ¾ ط·آ¹ط¸â€‍ط¸â€° ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ¬ط¸â€،ط·آ§ط·آ²' : 'Guest wallet on this device';
  static String lifetimePoints(String tier, int points) =>
      _ar ? '$tier ط¢آ· $points ط¸â€ ط¸â€ڑط·آ·ط·آ© ط·ع¾ط·آ±ط·آ§ط¸ئ’ط¸â€¦ط¸ظ¹ط·آ©' : '$tier ط¢آ· $points lifetime points';
  static String get bestOffers =>
      _ar ? 'ط·آ£ط¸ظ¾ط·آ¶ط¸â€‍ ط·آ§ط¸â€‍ط·آ¹ط·آ±ط¸ث†ط·آ¶ ط¸â€‍ط¸ئ’' : 'Best offers for you';
  static String get loyaltyRewardNote => _ar ? 'ط¸â€¦ط¸ئ’ط·آ§ط¸ظ¾ط·آ£ط·آ© ط¸ث†ط¸â€‍ط·آ§ط·طŒ' : 'Loyalty reward';
  static String get notEnoughPoints =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط¸â€ ط¸â€ڑط·آ§ط·آ· ط¸ئ’ط·آ§ط¸ظ¾ط¸ظ¹ط·آ© ط·آ¨ط·آ¹ط·آ¯' : 'Not enough points yet';
  static String earnRate(String formatted, String currencyCode) => _ar
      ? 'ط·آ§ط¸ئ’ط·آ³ط·آ¨ $formatted ط¸â€ ط¸â€ڑط·آ·ط·آ© ط¸â€‍ط¸ئ’ط¸â€‍ 1 $currencyCode ط¸ظ¾ط¸ظ¹ ط¸ئ’ط¸â€‍ ط·آ·ط¸â€‍ط·آ¨'
      : 'Earn $formatted points per 1 $currencyCode on every order';
  static String get earnRateUnavailable =>
      _ar ? 'ط¸â€¦ط·آ¹ط·آ¯ط¸â€‍ ط·آ§ط¸â€‍ط¸ئ’ط·آ³ط·آ¨ ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط¸ث†ط¸ظ¾ط·آ±' : 'Earn rate unavailable';

  static String get authEmailNotConfirmed =>
      _ar ? 'ظٹط±ط¬ظ‰ طھط£ظƒظٹط¯ ط¨ط±ظٹط¯ظƒ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظ‚ط¨ظ„ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„.' : 'Please confirm your email address before signing in.';

  static String get authTooManyRequests =>
      _ar ? 'ط¹ط¯ط¯ ظƒط¨ظٹط± ظ…ظ† ط§ظ„ظ…ط­ط§ظˆظ„ط§طھ. ظٹط±ط¬ظ‰ ط§ظ„ط§ظ†طھط¸ط§ط± ظ‚ظ„ظٹظ„ط§.' : 'Too many attempts. Please wait a moment and try again.';
  // ---------- Coupons ----------
  static String get coupon => _ar ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¨ط¸ث†ط¸â€ ' : 'Coupon';
  static String get copyCode => _ar ? 'ط¸â€ ط·آ³ط·آ® ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯' : 'Copy Code';
  static String get noCoupons =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط¸ئ’ط¸ث†ط·آ¨ط¸ث†ط¸â€ ط·آ§ط·ع¾ ط·آ­ط·آ§ط¸â€‍ط¸ظ¹ط¸â€¹ط·آ§' : 'No coupons right now';
  static String couponsLoadError(String error) =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¨ط¸ث†ط¸â€ ط·آ§ط·ع¾: $error' : 'Could not load coupons: $error';
  static String get couponCheckFailed => _ar
      ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ§ط¸â€‍ط·ع¾ط·آ­ط¸â€ڑط¸â€ڑ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¨ط¸ث†ط¸â€  ط¸â€‍ط¸â€‍ط¸â€¦ط·آ±ط·آ© ط·آ§ط¸â€‍ط·آ­ط·آ§ط¸â€‍ط¸ظ¹ط·آ©. ط·آ­ط·آ¯ط¸â€کط·آ« ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ© ط¸ث†ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ¬ط·آ¯ط·آ¯ط¸â€¹ط·آ§.'
      : "Couldn't verify the coupon for the current cart. Refresh and try again.";
  static String codeCopied(String code) =>
      _ar ? 'ط·ع¾ط¸â€¦ ط¸â€ ط·آ³ط·آ® ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ $code' : 'Code $code copied';

  // ---------- Payment & cards ----------
  static String get payment => _ar ? 'ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹' : 'Payment';
  static String get paymentMethod => _ar ? 'ط·آ·ط·آ±ط¸ظ¹ط¸â€ڑط·آ© ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹' : 'Payment Method';
  static String get addCard => _ar ? 'ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©' : 'Add Card';
  static String get cardHolder => _ar ? 'ط·آ§ط·آ³ط¸â€¦ ط·آ§ط¸â€‍ط·آ­ط·آ§ط¸â€¦ط¸â€‍' : 'CARD HOLDER';
  static String get expires => _ar ? 'ط·ع¾ط¸â€ ط·ع¾ط¸â€،ط¸ظ¹ ط¸ظ¾ط¸ظ¹' : 'EXPIRES';
  static String get cardAdded =>
      _ar ? 'ط·ع¾ط¸â€¦ط·ع¾ ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط·آ¨ط¸â€ ط·آ¬ط·آ§ط·آ­' : 'Card added successfully';
  static String get creditDebitCard =>
      _ar ? 'ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط·آ§ط·آ¦ط·ع¾ط¸â€¦ط·آ§ط¸â€ ط¸ظ¹ط·آ© / ط¸â€¦ط·آ¯ط¸â€°' : 'Credit & Debit Card';
  static String get morePaymentOptions =>
      _ar ? 'ط·آ®ط¸ظ¹ط·آ§ط·آ±ط·آ§ط·ع¾ ط·آ¯ط¸ظ¾ط·آ¹ ط·آ£ط·آ®ط·آ±ط¸â€°' : 'More Payment Options';
  static String get noSavedCards =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ§ط·ع¾ ط¸â€¦ط·آ­ط¸ظ¾ط¸ث†ط·آ¸ط·آ© ط·آ¨ط·آ¹ط·آ¯' : 'No saved cards yet';
  static String get yourName => _ar ? 'ط·آ§ط·آ³ط¸â€¦ط¸ئ’' : 'YOUR NAME';
  static String get saveCard => _ar ? 'ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©' : 'Save Card';
  static String get cardHolderRequired =>
      _ar ? 'ط·آ§ط·آ³ط¸â€¦ ط·آ­ط·آ§ط¸â€¦ط¸â€‍ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨' : 'Card holder name is required';
  static String get validCardNumber =>
      _ar ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ±ط¸â€ڑط¸â€¦ ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط·آµط·آ­ط¸ظ¹ط·آ­ط¸â€¹ط·آ§' : 'Enter a valid card number';
  static String get invalidDate => _ar ? 'ط·ع¾ط·آ§ط·آ±ط¸ظ¹ط·آ® ط·ط›ط¸ظ¹ط·آ± ط·آµط·آ§ط¸â€‍ط·آ­' : 'Invalid date';
  static String get cardBrandFallback => _ar ? 'ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©' : 'CARD';
  /// The name printed on the card. "Card holder" reads as the role; "Card holder
  /// name" reads as a form field asking for something else.
static String get cardHolderName =>
      _ar ? 'حامل البطاقة' : 'Card Holder';
  static String get cardNumber => _ar ? 'ط·آ±ط¸â€ڑط¸â€¦ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©' : 'Card Number';
  static String get expiryFormatHint =>
      _ar ? 'ط·آ´ط¸â€،ط·آ±/ط·آ³ط¸â€ ط·آ©' : 'MM/YY';
  static String cvvHint(int digits) =>
      _ar ? 'ط·آ§ط¸â€‍ط·آ±ط¸â€¦ط·آ² ($digits ط·آ£ط·آ±ط¸â€ڑط·آ§ط¸â€¦)' : 'CVV ($digits digits)';
  static String invalidCvvLength(int digits) => _ar
      ? 'ط·آ§ط¸â€‍ط·آ±ط¸â€¦ط·آ² ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط¸ث†ط¸â€کط¸â€  ط¸â€¦ط¸â€  $digits ط·آ£ط·آ±ط¸â€ڑط·آ§ط¸â€¦ ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨'
      : 'CVV must be $digits digits';
  static String get invalidCvv => _ar ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ±ط¸â€¦ط·آ² ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط·آ¨ط·آ´ط¸ئ’ط¸â€‍ ط·آµط·آ­ط¸ظ¹ط·آ­' : 'Enter a valid CVV';
  static String get cardExpired =>
      _ar ? 'ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط¸â€¦ط¸â€ ط·ع¾ط¸â€،ط¸ظ¹ط·آ© ط·آ§ط¸â€‍ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ©' : 'This card has expired';
  static String get savingCard =>
      _ar ? 'ط·آ¬ط·آ§ط·آ±ط¸ع† ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©...' : 'Saving card...';
  static String get saveCardFailed => _ar
      ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.'
      : 'Could not save the card. Please try again.';
  static String get cardDeclined => _ar
      ? 'ط¸â€‍ط¸â€¦ ط¸ظ¹ط·ع¾ط¸â€¦ ط¸â€ڑط·آ¨ط¸ث†ط¸â€‍ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©. ط·ع¾ط·آ­ط¸â€ڑط¸â€ڑ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط·آ£ط¸ث† ط·آ¬ط·آ±ط¸â€کط·آ¨ ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.'
      : "Your card wasn't accepted. Check the details or try another card.";
  static String get cardSaveNotAllowed => _ar
      ? 'ط·آ³ط·آ¬ط¸â€کط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍ ط¸â€‍ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ§ط·ع¾.'
      : 'Sign in to save cards.';
  /// The card provider is not reachable at all أ¢â‚¬â€‌ a build/deploy problem.
  ///
  /// Deliberately not "try again later": retrying cannot fix a function that
  /// was never deployed, and that wording is what hid this in the first place.
  static String get cardSavingNotConfigured => _ar
      ? 'ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ§ط·ع¾ ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط·آ§ط·آ­ ط·آ­ط·آ§ط¸â€‍ط¸ظ¹ط·آ§ط¸â€¹. ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·آ§ط¸â€‍ط¸â€¦ط·آ­ط·آ§ط¸ث†ط¸â€‍ط·آ© ط¸â€‍ط·آ§ط·آ­ط¸â€ڑط·آ§ط¸â€¹ ط·آ£ط¸ث† ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آ§ط·آµط¸â€‍ ط¸â€¦ط·آ¹ط¸â€ ط·آ§.'
      : 'Saving cards is unavailable right now. Please try again later or contact us.';
  static String get addNewCard =>
      _ar ? '+ ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط·آ¬ط·آ¯ط¸ظ¹ط·آ¯ط·آ©' : '+ Add new card';
  static String get paymentProcessing => _ar
      ? 'ط·آ¬ط·آ§ط·آ±ط¸ع† ط·ع¾ط¸â€ ط¸ظ¾ط¸ظ¹ط·آ° ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹. ط·آ³ط¸â€ ط¸ث†ط·آ§ط¸ظ¾ط¸ظ¹ط¸ئ’ ط·آ¨ط·آ§ط¸â€‍ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ«.'
      : 'Payment is being processed. We will update you soon.';
  static String get paymentFailed => _ar
      ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.'
      : 'Payment could not be completed. Please try again.';
  static String get invalidCardDetails =>
      _ar ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ© ط·آµط·آ­ط¸ظ¹ط·آ­ط·آ©' : 'Please enter valid card details';
  static String get tokenizationFailed => _ar
      ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·آ­ط¸ظ¾ط·آ¸ ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ¨ط·آ·ط·آ§ط¸â€ڑط·آ©. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.'
      : 'Could not save the card details. Please try again.';
  static String get paymentNotCompleted =>
      _ar ? 'ط¸â€‍ط¸â€¦ ط¸ظ¹ط·ع¾ط¸â€¦ ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹.' : 'Payment was not completed.';
  static String get paymentVerificationFailed => _ar
      ? 'ط¸ظ¾ط·آ´ط¸â€‍ ط·آ§ط¸â€‍ط·ع¾ط·آ­ط¸â€ڑط¸â€ڑ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹.' : 'Payment verification failed.';
  static String get paymentRetryLater => _ar
      ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.'
      : 'Payment failed. Please try again.';

  // ---------- Auth ----------
  static String get signIn => _ar ? 'ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍' : 'Sign In';
  static String get signUp => _ar ? 'ط·آ¥ط¸â€ ط·آ´ط·آ§ط·طŒ ط·آ­ط·آ³ط·آ§ط·آ¨' : 'Sign Up';
  static String get orSignUpWith => _ar ? 'ط·آ£ط¸ث† ط·آ³ط·آ¬ط¸â€‍ ط·آ¹ط·آ¨ط·آ±' : 'Or sign up with';
  static String get orSignInWith => _ar ? 'ط·آ£ط¸ث† ط·آ§ط·آ¯ط·آ®ط¸â€‍ ط·آ¹ط·آ¨ط·آ±' : 'Or sign in with';
  static String get dontHaveAccount =>
      _ar ? 'ط¸â€‍ط¸ظ¹ط·آ³ ط¸â€‍ط·آ¯ط¸ظ¹ط¸ئ’ ط·آ­ط·آ³ط·آ§ط·آ¨ط·ع؛ ' : "Don't have an account? ";
  static String get didntReceiveCode =>
      _ar ? 'ط¸â€‍ط¸â€¦ ط¸ظ¹ط·آµط¸â€‍ط¸ئ’ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ط·ع؛ ' : "Didn't receive the code? ";
  static String get resend => _ar ? 'ط·آ¥ط·آ¹ط·آ§ط·آ¯ط·آ© ط·آ¥ط·آ±ط·آ³ط·آ§ط¸â€‍' : 'Resend';
  static String get codeSent =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·آ¥ط·آ±ط·آ³ط·آ§ط¸â€‍ ط¸ئ’ط¸ث†ط·آ¯ ط·آ¬ط·آ¯ط¸ظ¹ط·آ¯' : 'A new code has been sent';
  static String get resetPassword =>
      _ar ? 'ط·آ¥ط·آ¹ط·آ§ط·آ¯ط·آ© ط·ع¾ط·آ¹ط¸ظ¹ط¸ظ¹ط¸â€  ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±' : 'Reset Password';
  static String get sendCode => _ar ? 'ط·آ¥ط·آ±ط·آ³ط·آ§ط¸â€‍ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯' : 'Send Code';
  static String get sendResetLink =>
      _ar ? 'ط·آ¥ط·آ±ط·آ³ط·آ§ط¸â€‍ ط·آ±ط·آ§ط·آ¨ط·آ· ط·آ§ط¸â€‍ط·ع¾ط·آ¹ط¸ظ¹ط¸ظ¹ط¸â€ ' : 'Send Reset Link';
  static String get letsGetStarted => _ar ? 'ط¸â€‍ط¸â€ ط·آ¨ط·آ¯ط·آ£' : "Let's Get Started";
  static String get yourCoffee => _ar ? 'ط¸â€ڑط¸â€،ط¸ث†ط·ع¾ط¸ئ’' : 'Your Coffee';
  static String get yourMoment =>
      _ar ? 'ط¸â€‍ط·آ­ط·آ¸ط·ع¾ط¸ئ’ط·إ’ ط·آ¹ط¸â€‍ط¸â€° ط·آ·ط·آ±ط¸ظ¹ط¸â€ڑط·ع¾ط¸ئ’' : 'Your Moment, Your Way';
  static String get welcomeDescription => _ar
      ? 'ط·آ§ط¸ئ’ط·ع¾ط·آ´ط¸ظ¾ ط¸â€ڑط¸â€،ط¸ث†ط·ع¾ط¸ئ’ ط·آ§ط¸â€‍ط¸â€¦ط¸ظ¾ط·آ¶ط¸â€‍ط·آ© ط¸ث†ط·آ§ط·آ¬ط·آ¹ط¸â€‍ ط¸ئ’ط¸â€‍ ط¸â€‍ط·آ­ط·آ¸ط·آ© ط·آ£ط·آ¬ط¸â€¦ط¸â€‍ط·إ’ ط¸ئ’ط¸ث†ط·آ¨ط¸â€¹ط·آ§ ط·آ¨ط·آ¹ط·آ¯ ط¸ئ’ط¸ث†ط·آ¨.'
      : 'Discover your favorite coffee and make every moment a little more special, one cup at a time.';
  static String get continueWithPhone =>
      _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط·ع¾ط·آ§ط·آ¨ط·آ¹ط·آ© ط·آ¨ط·آ±ط¸â€ڑط¸â€¦ ط·آ§ط¸â€‍ط¸â€،ط·آ§ط·ع¾ط¸ظ¾' : 'Continue with phone number';
  static String get continueWithGoogle =>
      _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط·ع¾ط·آ§ط·آ¨ط·آ¹ط·آ© ط·آ¨ط·آ­ط·آ³ط·آ§ط·آ¨ ط·آ¬ط¸ث†ط·آ¬ط¸â€‍' : 'Continue with Google';
  static String get forgotPasswordQ =>
      _ar ? 'ط¸â€ ط·آ³ط¸ظ¹ط·ع¾ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±ط·ع؛' : 'Forget your password?';
  static String get emailRequired =>
      _ar ? 'ط·آ§ط¸â€‍ط·آ¨ط·آ±ط¸ظ¹ط·آ¯ ط·آ§ط¸â€‍ط·آ¥ط¸â€‍ط¸ئ’ط·ع¾ط·آ±ط¸ث†ط¸â€ ط¸ظ¹ ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨' : 'Email is required';
  static String get nameRequired => _ar ? 'ط·آ§ط¸â€‍ط·آ§ط·آ³ط¸â€¦ ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨' : 'Name is required';
  static String get passwordRequired =>
      _ar ? 'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ± ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨ط·آ©' : 'Password is required';
  static String get passwordsNoMatch =>
      _ar ? 'ط¸ئ’ط¸â€‍ط¸â€¦ط·ع¾ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ± ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط·آ·ط·آ§ط·آ¨ط¸â€ڑط·ع¾ط¸ظ¹ط¸â€ ' : 'Passwords do not match';
  static String get createAccountSubtitle =>
      _ar ? 'ط·آ£ط¸â€ ط·آ´ط·آ¦ ط·آ­ط·آ³ط·آ§ط·آ¨ط¸ئ’ ط¸â€‍ط¸â€‍ط·آ¨ط·آ¯ط·طŒ' : 'Create your account to get started';
  static String get emailHint => _ar ? 'ط·آ§ط¸â€‍ط·آ¨ط·آ±ط¸ظ¹ط·آ¯ ط·آ§ط¸â€‍ط·آ¥ط¸â€‍ط¸ئ’ط·ع¾ط·آ±ط¸ث†ط¸â€ ط¸ظ¹' : 'Email';
  static String get nameHint => _ar ? 'ط·آ§ط¸â€‍ط·آ§ط·آ³ط¸â€¦' : 'Name';
  static String get passwordHint => _ar ? 'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±' : 'Password';
  static String get confirmPasswordHint =>
      _ar ? 'ط·ع¾ط·آ£ط¸ئ’ط¸ظ¹ط·آ¯ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±' : 'Confirm Password';
  static String get newPasswordHint => _ar ? 'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط¸â€¦ط·آ±ط¸ث†ط·آ± ط·آ¬ط·آ¯ط¸ظ¹ط·آ¯ط·آ©' : 'New Password';
  static String get phoneHint => _ar ? 'ط·آ±ط¸â€ڑط¸â€¦ ط·آ§ط¸â€‍ط¸â€،ط·آ§ط·ع¾ط¸ظ¾' : 'Phone number';
  static String get alreadyHaveAccount =>
      _ar ? 'ط¸â€‍ط·آ¯ط¸ظ¹ط¸ئ’ ط·آ­ط·آ³ط·آ§ط·آ¨ ط·آ¨ط·آ§ط¸â€‍ط¸ظ¾ط·آ¹ط¸â€‍ط·ع؛ ' : 'Already have an account? ';
  static String get enterNewPassword => _ar
      ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ± ط·آ§ط¸â€‍ط·آ¬ط·آ¯ط¸ظ¹ط·آ¯ط·آ© ط·آ¨ط·آ§ط¸â€‍ط·آ£ط·آ³ط¸ظ¾ط¸â€‍'
      : 'Enter your new password below';
  static String get forgetPassword =>
      _ar ? 'ط¸â€ ط·آ³ط¸ظ¹ط·ع¾ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±' : 'Forget Password';
  static String get signInWithPhone =>
      _ar ? 'ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍ ط·آ¨ط·آ§ط¸â€‍ط¸â€،ط·آ§ط·ع¾ط¸ظ¾' : 'Sign In with Phone';
  static String get rememberPasswordQ =>
      _ar ? 'ط·ع¾ط·آ°ط¸ئ’ط·آ±ط·ع¾ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±ط·ع؛ ' : 'Remember your password? ';
  static String get verificationCode =>
      _ar ? 'ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·ع¾ط·آ­ط¸â€ڑط¸â€ڑ' : 'Verification Code';
  static String get enterSixDigitCode => _ar
      ? 'ط¸â€¦ط¸â€  ط¸ظ¾ط·آ¶ط¸â€‍ط¸ئ’ ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط¸ث†ط¸â€  ط¸â€¦ط¸â€  6 ط·آ£ط·آ±ط¸â€ڑط·آ§ط¸â€¦'
      : 'Please enter the 6-digit code';
  static String get validPhoneNumber =>
      _ar ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ±ط¸â€ڑط¸â€¦ ط¸â€،ط·آ§ط·ع¾ط¸ظ¾ ط·آµط·آ­ط¸ظ¹ط·آ­ط¸â€¹ط·آ§' : 'Enter a valid phone number';
  static String get phoneRequired =>
      _ar ? 'ط·آ±ط¸â€ڑط¸â€¦ ط·آ§ط¸â€‍ط¸â€،ط·آ§ط·ع¾ط¸ظ¾ ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨' : 'Phone number is required';

  // ---------- Profile ----------
  static String get yourProfile => _ar ? 'ط·آ­ط·آ³ط·آ§ط·آ¨ط¸ئ’' : 'Your Profile';
  static String get help => _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط·آ³ط·آ§ط·آ¹ط·آ¯ط·آ©' : 'Help';
  static String get privacyPolicy => _ar ? 'ط·آ³ط¸ظ¹ط·آ§ط·آ³ط·آ© ط·آ§ط¸â€‍ط·آ®ط·آµط¸ث†ط·آµط¸ظ¹ط·آ©' : 'Privacy Policy';
static String get defaultAddress => _ar ? 'ط·آ§ط¸ظ¾ط·ع¾ط·آ±ط·آ§ط·آ¶ط¸ظ¹' : 'Default';
  static String get setDefaultAddress => _ar ? 'ط·ع¾ط·آ¹ط¸ظ¹ط¸ظ¹ط¸â€  ط¸ئ’ط·آ§ط¸ظ¾ط·ع¾ط·آ±ط·آ§ط·آ¶ط¸ظ¹' : 'Set as default';
  static String get editAddress => _ar ? 'ط·ع¾ط·آ¹ط·آ¯ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ ' : 'Edit address';
  static String get logOut => _ar ? 'ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ®ط·آ±ط¸ث†ط·آ¬' : 'Log Out';
  static String get confirmLogout => _ar ? 'ط¸â€ ط·آ¹ط¸â€¦ط·إ’ ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ®ط·آ±ط¸ث†ط·آ¬' : 'Yes, Logout';
  static String get logoutConfirm => _ar
      ? 'ط¸â€،ط¸â€‍ ط·آ£ط¸â€ ط·ع¾ ط¸â€¦ط·ع¾ط·آ£ط¸ئ’ط·آ¯ ط¸â€¦ط¸â€  ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ®ط·آ±ط¸ث†ط·آ¬ط·ع؛'
      : 'Are you sure you want to log out ?';
  /// Shown when the client sign-out itself fails. The customer stays signed in
  /// and the sign-out can be retried.
  static String get logoutFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ®ط·آ±ط¸ث†ط·آ¬. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.' : 'Could not sign you out. Please try again.';
  static String get faqTitle =>
      _ar ? 'ط·آ§ط¸â€‍ط·آ£ط·آ³ط·آ¦ط¸â€‍ط·آ© ط·آ§ط¸â€‍ط·آ´ط·آ§ط·آ¦ط·آ¹ط·آ©' : 'Frequently asked questions';
  static String get profilePicture =>
      _ar ? 'ط·آ§ط¸â€‍ط·آµط¸ث†ط·آ±ط·آ© ط·آ§ط¸â€‍ط·آ´ط·آ®ط·آµط¸ظ¹ط·آ©' : 'Profile Picture';
  static String get fullNameHint => _ar ? 'ط·آ§ط¸â€‍ط·آ§ط·آ³ط¸â€¦ ط·آ§ط¸â€‍ط¸ئ’ط·آ§ط¸â€¦ط¸â€‍' : 'Full Name';
  static String get firstNameHint => _ar ? 'ط·آ§ط¸â€‍ط·آ§ط·آ³ط¸â€¦ ط·آ§ط¸â€‍ط·آ£ط¸ث†ط¸â€‍' : 'First Name';
  static String get lastNameHint => _ar ? 'ط·آ§ط¸â€‍ط·آ§ط·آ³ط¸â€¦ ط·آ§ط¸â€‍ط·آ£ط·آ®ط¸ظ¹ط·آ±' : 'Last Name';
  static String get profileUpdateFailed => _ar ? 'ط¸ظ¾ط·آ´ط¸â€‍ ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ« ط·آ§ط¸â€‍ط¸â€¦ط¸â€‍ط¸ظ¾ ط·آ§ط¸â€‍ط·آ´ط·آ®ط·آµط¸ظ¹' : 'Profile update failed';
  static String get phoneNumberHint => _ar ? 'ط·آ±ط¸â€ڑط¸â€¦ ط·آ§ط¸â€‍ط¸â€،ط·آ§ط·ع¾ط¸ظ¾' : 'Phone Number';
  static String get profileUpdated =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ« ط·آ§ط¸â€‍ط·آ­ط·آ³ط·آ§ط·آ¨ ط·آ¨ط¸â€ ط·آ¬ط·آ§ط·آ­' : 'Profile updated successfully';
  static String get chooseFromGallery =>
      _ar ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط¸â€¦ط·آ¹ط·آ±ط·آ¶' : 'Choose from gallery';
  static String get takePhoto => _ar ? 'ط·آ§ط¸â€‍ط·ع¾ط¸â€ڑط·آ· ط·آµط¸ث†ط·آ±ط·آ©' : 'Take a photo';
  static String get imagePickerFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط¸ظ¾ط·ع¾ط·آ­ ط·آ§ط·آ®ط·ع¾ط¸ظ¹ط·آ§ط·آ± ط·آ§ط¸â€‍ط·آµط¸ث†ط·آ±' : "Couldn't open the image picker";
  static String get photoUploadFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آµط¸ث†ط·آ±ط·آ©. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.' : "Couldn't save the photo. Please try again.";
  static String get photoFormatUnsupported => _ar
      ? 'ط·آµط¸ظ¹ط·ط›ط·آ© ط·آ§ط¸â€‍ط·آµط¸ث†ط·آ±ط·آ© ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·آ¯ط·آ¹ط¸ث†ط¸â€¦ط·آ©. ط·آ§ط·آ®ط·ع¾ط·آ± ط·آµط¸ث†ط·آ±ط·آ© ط·آ¨ط·آµط¸ظ¹ط·ط›ط·آ© ط¸â€¦ط·آ¯ط·آ¹ط¸ث†ط¸â€¦ط·آ©.'
      : 'That image format is not supported. Choose a JPG, PNG or WebP image.';
  static String get photoSaveFailed => _ar
      ? 'ط·ع¾ط¸â€¦ ط·آ±ط¸ظ¾ط·آ¹ ط·آ§ط¸â€‍ط·آµط¸ث†ط·آ±ط·آ© ط¸â€‍ط¸ئ’ط¸â€  ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ±ط·آ¨ط·آ·ط¸â€،ط·آ§ ط·آ¨ط·آ§ط¸â€‍ط·آ­ط·آ³ط·آ§ط·آ¨.'
      : 'The photo was uploaded but could not be linked to your account.';
  static String get photoLoadFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آµط¸ث†ط·آ±ط·آ©' : "Couldn't load the photo";
  static String get language => _ar ? 'ط·آ§ط¸â€‍ط¸â€‍ط·ط›ط·آ©' : 'Language';
  static String languageValue(bool arabic) =>
      arabic ? 'ط·آ§ط¸â€‍ط¸â€‍ط·ط›ط·آ©: ط·آ§ط¸â€‍ط·آ¹ط·آ±ط·آ¨ط¸ظ¹ط·آ©' : 'Language: English';
  static String get arabicLanguage => _ar ? 'ط·آ§ط¸â€‍ط·آ¹ط·آ±ط·آ¨ط¸ظ¹ط·آ©' : 'Arabic';
  static String get englishLanguage => _ar ? 'ط·آ§ط¸â€‍ط·آ¥ط¸â€ ط·آ¬ط¸â€‍ط¸ظ¹ط·آ²ط¸ظ¹ط·آ©' : 'English';
  static String get myAddresses => _ar ? 'ط·آ¹ط¸â€ ط·آ§ط¸ث†ط¸ظ¹ط¸â€ ط¸ظ¹' : 'My Addresses';
  static String get noAddresses =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ¹ط¸â€ ط·آ§ط¸ث†ط¸ظ¹ط¸â€  ط¸â€¦ط·آ­ط¸ظ¾ط¸ث†ط·آ¸ط·آ© ط·آ¨ط·آ¹ط·آ¯' : 'No saved addresses yet';
  static String get addressesHint => _ar
      ? 'ط·آ£ط·آ¶ط¸ظ¾ ط·آ¹ط¸â€ ط·آ§ط¸ث†ط¸ظ¹ط¸â€ ط¸ئ’ ط¸â€‍ط·آ¥ط·ع¾ط¸â€¦ط·آ§ط¸â€¦ ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط·آ¥ط¸â€‍ط¸ظ¹ط¸â€،ط·آ§ ط·آ¨ط·آ´ط¸ئ’ط¸â€‍ ط·آ£ط·آ³ط·آ±ط·آ¹'
      : 'Add your addresses to check out delivery faster';
  static String get delete => _ar ? 'ط·آ­ط·آ°ط¸ظ¾' : 'Delete';
  static String get deleteAddress => _ar ? 'ط·آ­ط·آ°ط¸ظ¾ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ ' : 'Delete address';
  static String get deleteAddressConfirm => _ar
      ? 'ط¸â€،ط¸â€‍ ط·ع¾ط·آ±ط¸ظ¹ط·آ¯ ط·آ­ط·آ°ط¸ظ¾ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ ط·ع؛'
      : 'Do you want to delete this address?';
  static String get addressSaveFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ . ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.' : 'Could not save the address. Please try again.';
  static String get addressDeleteFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·آ­ط·آ°ط¸ظ¾ ط·آ§ط¸â€‍ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€ . ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.' : 'Could not delete the address. Please try again.';

  // ---------- Help / FAQ / policy ----------
  static String faqsLoadError(String error) =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ£ط·آ³ط·آ¦ط¸â€‍ط·آ©: $error' : 'Could not load FAQs: $error';
  static String get noFaqs => _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ£ط·آ³ط·آ¦ط¸â€‍ط·آ© ط¸â€¦ط·ع¾ط·آ§ط·آ­ط·آ©' : 'No FAQs available';
  static String policyLoadError(String error) =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ³ط¸ظ¹ط·آ§ط·آ³ط·آ©: $error' : 'Could not load policy: $error';
  static String get policyUnavailable =>
      _ar ? 'ط·آ³ط¸ظ¹ط·آ§ط·آ³ط·آ© ط·آ§ط¸â€‍ط·آ®ط·آµط¸ث†ط·آµط¸ظ¹ط·آ© ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط¸ث†ط¸ظ¾ط·آ±ط·آ©.' : 'Privacy policy unavailable.';

  // ---------- Notifications ----------
  static String get notifications => _ar ? 'ط·آ§ط¸â€‍ط·آ¥ط·آ´ط·آ¹ط·آ§ط·آ±ط·آ§ط·ع¾' : 'Notifications';
  static String get signInForNotifications =>
      _ar ? 'ط·آ³ط·آ¬ط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍ ط¸â€‍ط·آ±ط·آ¤ط¸ظ¹ط·آ© ط·آ§ط¸â€‍ط·آ¥ط·آ´ط·آ¹ط·آ§ط·آ±ط·آ§ط·ع¾' : 'Sign in to see notifications';
  static String get orderUpdatesAccount => _ar
      ? 'ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ«ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط·ع¾ط·آµط¸â€‍ ط·آ¥ط¸â€‍ط¸â€° ط·آ­ط·آ³ط·آ§ط·آ¨ط¸ئ’'
      : 'Order updates arrive in your account';
  static String get couldNotLoadNotifications =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط·آ± ط·ع¾ط·آ­ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ¥ط·آ´ط·آ¹ط·آ§ط·آ±ط·آ§ط·ع¾' : 'Could not load notifications';
  static String get noNotifications =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ¥ط·آ´ط·آ¹ط·آ§ط·آ±ط·آ§ط·ع¾ ط·آ¨ط·آ¹ط·آ¯' : 'No notifications yet';
  static String get notificationsHint =>
      _ar ? 'ط·آ³ط·ع¾ط·آ¸ط¸â€،ط·آ± ط·ع¾ط·آ­ط·آ¯ط¸ظ¹ط·آ«ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط¸â€،ط¸â€ ط·آ§' : 'Order updates will appear here';
  static String get skip => _ar ? 'ط·ع¾ط·آ®ط·آ·ط¸ظ¹' : 'Skip';

  // ---------- Banners ----------
  static String enjoyReward(String name) =>
      _ar ? 'ط·آ§ط·آ³ط·ع¾ط¸â€¦ط·ع¾ط·آ¹ ط·آ¨ط¸â‚¬ $name!' : 'Enjoy your $name!';

  // ---------- Assistant ----------
  static String get askAnything => _ar ? 'ط·آ§ط·آ³ط·آ£ط¸â€‍ط¸â€ ط¸ظ¹ ط·آ£ط¸ظ¹ ط·آ´ط¸ظ¹ط·طŒط·ع؛' : 'Ask me anything?';
  static String get assistantTitle => _ar ? 'ط¸â€¦ط·آ³ط·آ§ط·آ¹ط·آ¯ ط·آ§ط¸â€‍ط¸â€ڑط¸â€،ط¸ث†ط·آ©' : 'Coffee Assistant';
  static String get open => _ar ? 'ط¸ظ¾ط·ع¾ط·آ­' : 'Open';

  // ---------- Branch ----------
  static String get chooseBranch => _ar ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹' : 'Choose branch';

  // ---------- Onboarding ----------
  static String get noSlides =>
      _ar ? 'ط¸â€‍ط·آ§ ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط·آ´ط·آ±ط·آ§ط·آ¦ط·آ­ ط·ع¾ط·آ¹ط·آ±ط¸ظ¹ط¸ظ¾ط¸ظ¹ط·آ©' : 'No onboarding slides';

  // ---------- Auth screens ----------
  static String get welcomeBackSubtitle => _ar
      ? 'ط·آ£ط¸â€،ط¸â€‍ط¸â€¹ط·آ§ ط·آ¨ط·آ¹ط¸ث†ط·آ¯ط·ع¾ط¸ئ’ط·إ’ ط¸ئ’ط¸â€ ط·آ§ ط¸â€ ط¸â€ ط·ع¾ط·آ¸ط·آ±ط¸ئ’'
      : "Hi welcome back, you've been missed";
  static String get createAccountTitle => _ar ? 'ط·آ­ط·آ³ط·آ§ط·آ¨ ط·آ¬ط·آ¯ط¸ظ¹ط·آ¯' : 'Create Account';
  static String get forgotPasswordSubtitle => _ar
      ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ¨ط·آ±ط¸ظ¹ط·آ¯ط¸ئ’ ط·آ§ط¸â€‍ط·آ¥ط¸â€‍ط¸ئ’ط·ع¾ط·آ±ط¸ث†ط¸â€ ط¸ظ¹ ط¸ث†ط·آ³ط¸â€ ط·آ±ط·آ³ط¸â€‍ ط¸â€‍ط¸ئ’ ط·آ±ط·آ§ط·آ¨ط·آ· ط·آ¥ط·آ¹ط·آ§ط·آ¯ط·آ© ط·آ§ط¸â€‍ط·ع¾ط·آ¹ط¸ظ¹ط¸ظ¹ط¸â€ '
      : "Enter your email and we'll send you a link to reset your password";
  static String get phoneAuthSubtitle => _ar
      ? 'ط·آ£ط·آ¯ط·آ®ط¸â€‍ ط·آ±ط¸â€ڑط¸â€¦ ط¸â€،ط·آ§ط·ع¾ط¸ظ¾ط¸ئ’ ط¸ث†ط·آ³ط¸â€ ط·آ±ط·آ³ط¸â€‍ ط¸â€‍ط¸ئ’ ط¸ئ’ط¸ث†ط·آ¯ ط·ع¾ط·آ­ط¸â€ڑط¸â€ڑ'
      : "Enter your phone number and we'll send you a verification code";
  static String otpSentTo(String phone) => _ar
      ? 'ط·آ£ط·آ±ط·آ³ط¸â€‍ط¸â€ ط·آ§ ط¸ئ’ط¸ث†ط·آ¯ط¸â€¹ط·آ§ ط¸â€¦ط¸ئ’ط¸ث†ط¸â€ ط¸â€¹ط·آ§ ط¸â€¦ط¸â€  6 ط·آ£ط·آ±ط¸â€ڑط·آ§ط¸â€¦ ط·آ¥ط¸â€‍ط¸â€° $phone'
      : 'We sent a 6-digit code to $phone';

  // Auth failures. The provider's own English never reaches the customer.
  static String get authInvalidCredentials => _ar
      ? 'ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍ ط·ط›ط¸ظ¹ط·آ± ط·آµط·آ­ط¸ظ¹ط·آ­ط·آ©ط·إ’ ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·آ§ط¸â€‍ط·ع¾ط·آ­ط¸â€ڑط¸â€ڑ ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط·آ¥ط¸ظ¹ط¸â€¦ط¸ظ¹ط¸â€‍ ط¸ث†ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±'
      : 'Wrong email or password. Please check and try again.';
  static String get authUserNotFound => _ar
      ? 'ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ¥ط¸ظ¹ط¸â€¦ط¸ظ¹ط¸â€‍ ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·آ³ط·آ¬ط¸â€‍ط·إ’ ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·آ¥ط¸â€ ط·آ´ط·آ§ط·طŒ ط·آ­ط·آ³ط·آ§ط·آ¨ ط·آ£ط¸ث†ط¸â€‍ط¸â€¹ط·آ§'
      : 'This email is not registered. Please sign up first.';
  static String get authUserDisabled => _ar
      ? 'ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ­ط·آ³ط·آ§ط·آ¨ ط¸â€¦ط·آ¹ط·آ·ط¸â€کط¸â€‍ط·إ’ ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آ§ط·آµط¸â€‍ ط¸â€¦ط·آ¹ ط·آ§ط¸â€‍ط·آ¯ط·آ¹ط¸â€¦'
      : 'This account is disabled. Please contact support.';
  static String get authEmailInUse => _ar
      ? 'ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ¥ط¸ظ¹ط¸â€¦ط¸ظ¹ط¸â€‍ ط¸â€¦ط·آ³ط·آ¬ط¸â€‍ ط·آ¨ط·آ§ط¸â€‍ط¸ظ¾ط·آ¹ط¸â€‍ط·إ’ ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍ ط·آ£ط¸ث† ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط·آ§ط¸â€¦ ط·آ¥ط¸ظ¹ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آ¢ط·آ®ط·آ±'
      : 'This email is already registered. Sign in or use another email.';
  static String get authWeakPassword => _ar
      ? 'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ± ط·آ¶ط·آ¹ط¸ظ¹ط¸ظ¾ط·آ©ط·إ’ ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط·آ§ط¸â€¦ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط¸â€¦ط·آ±ط¸ث†ط·آ± ط·آ£ط·آ·ط¸ث†ط¸â€‍ ط¸ث†ط·آ£ط¸ئ’ط·آ«ط·آ± ط·آ£ط¸â€¦ط·آ§ط¸â€ ط¸â€¹ط·آ§'
      : 'Password is too weak. Please use a longer, stronger password.';
  static String get authInvalidEmail =>
      _ar ? 'ط·آ¥ط¸ظ¹ط¸â€¦ط¸ظ¹ط¸â€‍ ط·ط›ط¸ظ¹ط·آ± ط·آµط·آ­ط¸ظ¹ط·آ­ط·إ’ ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·آ¥ط·آ¯ط·آ®ط·آ§ط¸â€‍ ط·آ¥ط¸ظ¹ط¸â€¦ط¸ظ¹ط¸â€‍ ط·آµط·آ­ط¸ظ¹ط·آ­' : 'Enter a valid email address.';
  static String get authFailed =>
      _ar ? 'ط·آ­ط·آ¯ط·آ« ط·آ®ط·آ·ط·آ£ ط·آ£ط·آ«ط¸â€ ط·آ§ط·طŒ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍. ط·آ­ط·آ§ط¸ث†ط¸â€‍ ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.' : 'Something went wrong signing in. Please try again.';
  static String get authUnexpected =>
      _ar ? 'ط·آ­ط·آ¯ط·آ« ط·آ®ط·آ·ط·آ£ ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط¸ث†ط¸â€ڑط·آ¹ط·إ’ ط·آ¨ط·آ±ط·آ¬ط·آ§ط·طŒ ط·آ§ط¸â€‍ط¸â€¦ط·آ­ط·آ§ط¸ث†ط¸â€‍ط·آ© ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€°.' : 'Something unexpected happened. Please try again.';
  static String get signUpEmailVerification => _ar
      ? 'طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨. ظٹط±ط¬ظ‰ ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† ط¨ط±ظٹط¯ظƒ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ.'
      : 'Account created. Please check your email to verify your account.';
  static String get passwordResetEmailSent => _ar
      ? 'ط¥ط°ط§ ظƒط§ظ† ط§ظ„ط¨ط±ظٹط¯ ظ…ط³ط¬ظ„ط§ظ‹طŒ ظپط³ظ†ط±ط³ظ„ ط±ط§ط¨ط·ط§ظ‹ ظ„ط¥ط¹ط§ط¯ط© طھط¹ظٹظٹظ† ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±.'
      : 'If that email is registered, we sent a password reset link.';
  static String get passwordResetSuccess => _ar
      ? 'طھظ… طھط­ط¯ظٹط« ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±.'
      : 'Your password has been updated.';
  // ---------- Coupons ----------
  static String get couponApplied =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·ع¾ط·آ·ط·آ¨ط¸ظ¹ط¸â€ڑ ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦' : 'Coupon applied';
  static String get invalidCouponCode =>
      _ar ? 'ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦ ط·ط›ط¸ظ¹ط·آ± ط·آµط·آ§ط¸â€‍ط·آ­' : 'Invalid coupon code';

  /// Why the server refused a coupon.
  ///
  /// `validate_coupon` answers with fixed English codes. Showing those raw put
  /// English sentences أ¢â‚¬â€‌ and no explanation أ¢â‚¬â€‌ in an Arabic checkout, which read
  /// as the coupon silently vanishing.
  static String couponRejected(String code) => switch (code.trim()) {
    'code not valid' => _ar ? 'ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦ ط·ط›ط¸ظ¹ط·آ± ط·آµط·آ­ط¸ظ¹ط·آ­' : 'That coupon code is not valid',
    'code expired' => _ar
        ? 'ط·آ§ط¸â€ ط·ع¾ط¸â€،ط·ع¾ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯'
        : 'This coupon has expired',
    'minimum order not reached' => _ar
        ? 'ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ ط¸â€‍ط¸â€¦ ط¸ظ¹ط·آµط¸â€‍ ط¸â€‍ط¸â€‍ط·آ­ط·آ¯ ط·آ§ط¸â€‍ط·آ£ط·آ¯ط¸â€ ط¸â€° ط·آ§ط¸â€‍ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨ ط¸â€‍ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯'
        : 'Your order is below this coupon\'s minimum',
    'code fully used' => _ar
        ? 'ط·ع¾ط¸â€¦ ط·آ§ط·آ³ط·ع¾ط¸â€ ط¸ظ¾ط·آ§ط·آ¯ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯'
        : 'This coupon has been fully claimed',
    'you already used this code' => _ar
        ? 'ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط¸â€¦ط·ع¾ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط·آ¨ط·آ§ط¸â€‍ط·آ­ط·آ¯ ط·آ§ط¸â€‍ط¸â€¦ط·آ³ط¸â€¦ط¸ث†ط·آ­ ط¸â€‍ط¸ئ’'
        : 'You have already used this coupon the allowed number of times',
    'code does not apply to your items' => _ar
        ? 'ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€ ط·آ·ط·آ¨ط¸â€ڑ ط·آ¹ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ط·آ§ط·ع¾ ط¸ظ¾ط¸ظ¹ ط·آ³ط¸â€‍ط·ع¾ط¸ئ’'
        : 'This coupon does not apply to the items in your cart',
    _ => _ar ? 'ط¸ئ’ط¸ث†ط·آ¯ ط·آ§ط¸â€‍ط·آ®ط·آµط¸â€¦ ط·ط›ط¸ظ¹ط·آ± ط·آµط·آ§ط¸â€‍ط·آ­' : 'Invalid coupon code',
  };

  static String couponUsesLeft(int count) => _ar
      ? 'ط¸â€¦ط·ع¾ط·آ¨ط¸â€ڑط¸ظ¹ $count ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط·آ§ط¸â€¦'
      : count == 1
      ? '1 use left'
      : '$count uses left';
  static String get couponNoUsesLeft => _ar
      ? 'ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط¸â€¦ط·ع¾ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¯ ط·آ¨ط·آ§ط¸â€‍ط·آ­ط·آ¯ ط·آ§ط¸â€‍ط¸â€¦ط·آ³ط¸â€¦ط¸ث†ط·آ­'
      : 'You have used up this coupon';
  static String get couponAppliedBadge =>
      _ar ? 'ط¸â€¦ط·آ·ط·آ¨ط¸â€کط¸â€ڑ ط·آ¹ط¸â€‍ط¸â€° ط·آ·ط¸â€‍ط·آ¨ط¸ئ’' : 'Applied to your order';

  // ---------- Menu / product ----------
  static String get readMore => _ar ? 'ط·آ§ط¸â€ڑط·آ±ط·آ£ ط·آ§ط¸â€‍ط¸â€¦ط·آ²ط¸ظ¹ط·آ¯' : 'Read more';
  static String get readLess => _ar ? 'ط·آ§ط¸â€ڑط·آ±ط·آ£ ط·آ£ط¸â€ڑط¸â€‍' : 'Read less';
  static String get productUnavailable =>
      _ar ? 'ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط·آ§ط·آ­' : 'Product unavailable';
  static String get productNoLongerAvailable => _ar
      ? 'ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ ط¸â€‍ط¸â€¦ ط¸ظ¹ط·آ¹ط·آ¯ ط¸â€¦ط·ع¾ط·آ§ط·آ­ط¸â€¹ط·آ§'
      : 'This product is no longer available';

  // ---------- Orders ----------
  static String quantityLabel(int quantity) =>
      _ar ? 'ط·آ§ط¸â€‍ط¸ئ’ط¸â€¦ط¸ظ¹ط·آ©: $quantity' : 'Qty: $quantity';
  static String get liveStatusFailed =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ°ط¸â€کط·آ± ط·آ¬ط¸â€‍ط·آ¨ ط·آ­ط·آ§ط¸â€‍ط·آ© ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ ط¸â€¦ط·آ¨ط·آ§ط·آ´ط·آ±ط·آ©' : 'Could not load live status';
  static String get removedProduct =>
      _ar ? 'ط¸â€¦ط¸â€ ط·ع¾ط·آ¬ ط¸â€¦ط·آ­ط·آ°ط¸ث†ط¸ظ¾' : 'Removed product';
  static String get addNewShippingAddress =>
      _ar ? '+ ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط·آ© ط·آ¹ط¸â€ ط¸ث†ط·آ§ط¸â€  ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ ط·آ¬ط·آ¯ط¸ظ¹ط·آ¯' : '+ Add new shipping address';

  // ---------- Checkout ----------
  static String get selectBranchBeforePaying => _ar
      ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹ ط¸â€ڑط·آ¨ط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹.'
      : 'Select a branch before paying.';
  static String loyaltyPointsEarned(int points) => _ar
      ? 'ط¸â€‍ط¸â€ڑط·آ¯ ط¸ئ’ط·آ³ط·آ¨ط·ع¾ $points ط¸â€ ط¸â€ڑط·آ·ط·آ© ط¸ث†ط¸â€‍ط·آ§ط·طŒ!'
      : 'You earned $points loyalty points!';

  // ---------- Loyalty ----------
  static String get selectBranchBeforeRedeeming => _ar
      ? 'ط·آ§ط·آ®ط·ع¾ط·آ± ط·آ§ط¸â€‍ط¸ظ¾ط·آ±ط·آ¹ ط¸â€ڑط·آ¨ط¸â€‍ ط·آ§ط·آ³ط·ع¾ط·آ¨ط·آ¯ط·آ§ط¸â€‍ ط¸â€،ط·آ°ط¸â€، ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط·آ§ط¸ظ¾ط·آ£ط·آ©.'
      : 'Select a branch before redeeming this reward.';
  static String get orderPurchaseLabel =>
      _ar ? 'ط·آ´ط·آ±ط·آ§ط·طŒ ط·آ·ط¸â€‍ط·آ¨' : 'Order purchase';
  static String get rewardRedeemedLabel =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·آ§ط·آ³ط·ع¾ط·آ¨ط·آ¯ط·آ§ط¸â€‍ ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط·آ§ط¸ظ¾ط·آ£ط·آ©' : 'Reward redeemed';
  static String get pointsRefundedLabel =>
      _ar ? 'ط·ع¾ط¸â€¦ ط·آ§ط·آ³ط·ع¾ط·آ±ط·آ¬ط·آ§ط·آ¹ ط·آ§ط¸â€‍ط¸â€ ط¸â€ڑط·آ§ط·آ·' : 'Points refunded';
  static String get pointsExpiredLabel =>
      _ar ? 'ط·آ§ط¸â€ ط·ع¾ط¸â€،ط·ع¾ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·آ§ط¸â€‍ط¸â€ ط¸â€ڑط·آ§ط·آ·' : 'Points expired';
  static String get balanceAdjustmentLabel =>
      _ar ? 'ط·ع¾ط·آ¹ط·آ¯ط¸ظ¹ط¸â€‍ ط¸ظ¾ط¸ظ¹ ط·آ§ط¸â€‍ط·آ±ط·آµط¸ظ¹ط·آ¯' : 'Balance adjustment';
  static String get loyaltyActivityLabel =>
      _ar ? 'ط¸â€ ط·آ´ط·آ§ط·آ· ط·آ¹ط¸â€‍ط¸â€° ط·آ§ط¸â€‍ط¸â€ ط¸â€ڑط·آ§ط·آ·' : 'Loyalty activity';

  // ---------- Shared widgets ----------
  static String get showPassword => _ar ? 'ط·آ¥ط·آ¸ط¸â€،ط·آ§ط·آ± ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±' : 'Show password';
  static String get hidePassword => _ar ? 'ط·آ¥ط·آ®ط¸ظ¾ط·آ§ط·طŒ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ±' : 'Hide password';
  static String get saudiRiyal => _ar ? 'ط·آ±ط¸ظ¹ط·آ§ط¸â€‍ ط·آ³ط·آ¹ط¸ث†ط·آ¯ط¸ظ¹' : 'Saudi Riyal';
  static String get bundleLabel => _ar ? 'ط·آ¨ط·آ§ط¸â€ڑط·آ©' : 'Bundle';
}
