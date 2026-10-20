import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/location/data/model/location_failure.dart';

/// Every user-visible string in one place.
///
/// Each getter reads the current [AppLocale] at build time, so toggling the
/// language rebuilds the whole tree (see `AnimatedBuilder` in `main.dart`)
/// and every label — including database-driven screens — flips together.
/// Database *content* (names, descriptions) stays in the models; everything
/// around it lives here.
class S {
  S._();

  static bool get _ar => AppLocale.instance.isArabic;

  static String get appName => _ar ? 'نيو كوفي' : 'New Coffee';

  // ---------- Common ----------
  static String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
  static String get locationPermissionTitle =>
      _ar ? 'السماح بالوصول إلى الموقع' : 'Allow location access';
  static String get locationPermissionBody => _ar
      ? 'يمكن أن يحسّن الموقع دقة التوصيل والخدمات المرتبطة بالموقع. يمكنك المتابعة دون منح الإذن.'
      : 'Location can improve delivery and location-related features. You can continue without granting permission.';
  static String get enableLocation => _ar ? 'تفعيل الموقع' : 'Enable location';
  static String get notNow => _ar ? 'ليس الآن' : 'Not now';
  static String get locationPermissionDenied => _ar
      ? 'تم رفض الإذن. يمكنك تفعيله لاحقاً من الإعدادات.'
      : 'Permission denied. You can enable it later in settings.';
  static String get ok => _ar ? 'حسناً' : 'OK';
  static String get submit => _ar ? 'إرسال' : 'Submit';
  static String get save => _ar ? 'حفظ' : 'Save';
  static String get apply => _ar ? 'تطبيق' : 'Apply';
  static String get confirm => _ar ? 'تأكيد' : 'Confirm';
  static String get change => _ar ? 'تغيير' : 'Change';
  static String get back => _ar ? 'رجوع' : 'Back';
  static String get verify => _ar ? 'تحقق' : 'Verify';
  static String get total => _ar ? 'الإجمالي' : 'Total';
  static String get subtotal => _ar ? 'المجموع الفرعي' : 'Subtotal';
  static String get deliveryFee => _ar ? 'رسوم التوصيل' : 'Delivery Fee';
  static String get discount => _ar ? 'الخصم' : 'Discount';
  static String get couponDiscount => _ar ? 'خصم الكوبون' : 'Coupon discount';
  static String get required => _ar ? 'مطلوب' : 'Required';

  // ---------- Navigation ----------
  static String get navHome => _ar ? 'الرئيسية' : 'Home';
  static String get navCategories => _ar ? 'التصنيفات' : 'Categories';
  static String get navCart => _ar ? 'السلة' : 'Cart';
  static String get navFavorites => _ar ? 'المفضلة' : 'Favorites';
  static String get navSettings => _ar ? 'الإعدادات' : 'Settings';

  // ---------- Home ----------
  static String get homeQuestion =>
      _ar ? 'ماذا تريد اليوم؟' : 'What would you like today?';
  static String get categories => _ar ? 'التصنيفات' : 'Categories';
  static String get category => _ar ? 'التصنيف' : 'Category';
  static String get seeAll => _ar ? 'عرض الكل' : 'See all';
  static String get viewMore => _ar ? 'عرض المزيد' : 'View more';
  static String get popular => _ar ? 'الأكثر طلبًا' : 'Popular';
  static String get youMayLike => _ar ? 'قد يعجبك' : 'You may like';
  static String get recommendations => _ar ? 'ترشيحات لك' : 'Recommendations';
  static String get hotDayPicks =>
      _ar ? 'اختيارات منعشة ليوم حار' : 'Cool picks for a warm day';
  static String get coldDayPicks =>
      _ar ? 'اختيارات دافئة ليوم بارد' : 'Warm picks for a chilly day';
  static String get bundles => _ar ? 'الباقات' : 'Bundles';
  static String get goodMorning => _ar ? 'صباح الخير' : 'Good Morning';
  static String get goodAfternoon => _ar ? 'مساء الخير' : 'Good Afternoon';
  static String get goodEvening => _ar ? 'مساء الخير' : 'Good Evening';
  static String get homeLoadError =>
      _ar ? 'تعذر تحميل الصفحة الرئيسية' : 'Could not load the home page';
  static String get noProductsFound =>
      _ar ? 'لا توجد منتجات' : 'No products found';
  static String get tryAgainLater => _ar ? 'حاول لاحقًا' : 'Try again later';

  // ---------- Search & filters ----------
  static String get search => _ar ? 'بحث' : 'Search';
  static String get searchHint =>
      _ar ? 'ابحث عن القهوة...' : 'Search coffee...';
  static String get searchPromptTitle =>
      _ar ? 'ابحث عن ما تريد' : 'Search for what you crave';
  static String get searchPromptHint => _ar
      ? 'اكتب اسم مشروب أو حلو… مثال: لاتيه، كابتشينو'
      : 'Type a drink or dessert… e.g. latte, cappuccino';
  static String get searchFailed => _ar ? 'تعذر البحث' : 'Search failed';
  static String get noResults => _ar ? 'لا توجد نتائج' : 'No results found';
  static String get tryDifferentKeyword =>
      _ar ? 'جرّب كلمة أو فلاتر مختلفة' : 'Try a different keyword or filters';
  static String get filters => _ar ? 'الفلاتر' : 'Filters';
  static String get sortBy => _ar ? 'ترتيب حسب' : 'Sort by';
  static String get priceRange => _ar ? 'نطاق السعر' : 'Price range';
  static String get all => _ar ? 'الكل' : 'All';
  static String get reset => _ar ? 'إعادة تعيين' : 'Reset';

  // ---------- Categories tab ----------
  static String get noCategories =>
      _ar ? 'لا توجد تصنيفات بعد' : 'No categories yet';
  static String get categoriesSoon => _ar
      ? 'ستظهر التصنيفات هنا عند إضافتها'
      : 'Categories will appear here once they are added';
  static String get noProductsYet =>
      _ar ? 'لا توجد منتجات بعد' : 'No products yet';
  static String productsIn(String label) => _ar
      ? 'ستظهر المنتجات في $label هنا'
      : 'Products in $label will appear here';
  static String get couldNotLoadCategories =>
      _ar ? 'تعذر تحميل التصنيفات' : 'Could not load categories';

  // ---------- Product details ----------
  static String get productDetails => _ar ? 'تفاصيل المنتج' : 'Product Details';
  static String get totalPrice => _ar ? 'السعر الإجمالي' : 'Total Price';
  static String get addToCart => _ar ? 'أضف إلى السلة' : 'Add to Cart';
  static String get unavailable => _ar ? 'غير متوفر' : 'Unavailable';
  static String get quantity => _ar ? 'الكمية' : 'Quantity';
  static String get goesWellWith => _ar ? 'يتماشى معه' : 'Goes well with';
  static String get addedToCart =>
      _ar ? 'تمت الإضافة إلى السلة' : 'Added to cart';
  static String get adding => _ar ? 'جارٍ الإضافة...' : 'Adding...';
  static String get added => _ar ? 'تمت الإضافة' : 'Added';
  static String get failedToAddToCart =>
      _ar ? 'تعذر الإضافة إلى السلة' : 'Could not add to cart';
  static String addedProductToCart(String name) =>
      _ar ? 'تمت إضافة $name إلى السلة' : '$name added to cart';
  static String get unavailableNow => _ar
      ? 'هذا الخيار غير متوفر حاليًا'
      : 'This combination is not available right now';
  static String chooseOption(String name) =>
      _ar ? 'يجب اختيار $name' : 'Please choose $name';
  static String maxOption(int max, String name) => _ar
      ? 'يمكنك اختيار $max فقط من $name'
      : 'You can pick at most $max for $name';

  // ---------- Cart ----------
  static String get cart => _ar ? 'السلة' : 'Cart';
  static String get cartEmpty => _ar ? 'سلتك فارغة' : 'Your cart is empty';
  static String get cartEmptyHint => _ar
      ? 'أضف قهوتك المفضلة من القائمة'
      : 'Add your favorite coffee from the menu';
  static String get subTotal => _ar ? 'المجموع الفرعي' : 'Sub-Total';
  static String get totalCost => _ar ? 'التكلفة الإجمالية' : 'Total Cost';
  static String get promoCode => _ar ? 'كود الخصم' : 'Promo Code';
static String get clearPromoCode =>
      _ar ? 'مسح كود الخصم' : 'Clear promo code';
  static String get proceedToCheckout =>
      _ar ? 'إتمام الطلب' : 'Proceed to Checkout';
  static String removedFromCart(String name) =>
      _ar ? 'تمت إزالة $name' : 'Removed $name';
  static String get undo => _ar ? 'تراجع' : 'Undo';

  // ---------- Checkout ----------
  static String get checkout => _ar ? 'الدفع' : 'Checkout';
  static String get pickupBranch => _ar ? 'فرع الاستلام' : 'Pickup Branch';
  static String get shippingAddress =>
      _ar ? 'عنوان التوصيل' : 'Shipping Address';
  static String get orderList => _ar ? 'قائمة الطلب' : 'Order List';
  static String get continueToPayment =>
      _ar ? 'المتابعة للدفع' : 'Continue to Payment';
  static String get confirmPayment => _ar ? 'تأكيد الدفع' : 'Confirm Payment';
  static String get orderFailed =>
      _ar ? 'تعذّر إتمام الطلب. حاول مرة أخرى.' : 'Could not place the order. Please try again.';
  static String get addAddressName =>
      _ar ? 'من فضلك أدخل اسم العنوان' : 'Please enter an address name';
  static String get addAddressLocation =>
      _ar ? 'من فضلك أدخل موقعك' : 'Please enter your location';
  static String get enterLocation => _ar ? 'أدخل موقعك' : 'Enter your location';
  static String get eReceipt => _ar ? 'الإيصال' : 'E-Receipt';
  static String get noReceipt => _ar ? 'لا يوجد إيصال بعد' : 'No receipt yet';
  static String get receiptHint => _ar
      ? 'سيظهر إيصال طلبك الأخير هنا'
      : 'Your latest order receipt will appear here';
  static String get goToMain => _ar ? 'إلى الرئيسية' : 'Go to main page';
  static String get useCurrentLocation =>
      _ar ? 'استخدام موقعي الحالي' : 'Use my current location';
  static String get locationUnavailable => _ar
      ? 'تعذّر تحديد موقعك. تأكد من تفعيل خدمة الموقع أو حدّد المكان على الخريطة.'
      : "Couldn't get your location. Turn location services on, or pick a spot on the map.";

  /// Why a position could not be used.
  ///
  /// Each case needs a different action from the customer, so they are separate
  /// strings rather than one shared apology. The permanently-denied case in
  /// particular: the system dialog will never appear again, so only Settings
  /// can fix it — which is why the UI offers a button to open them.
  static String locationFailed(LocationFailure failure) => switch (failure) {
    LocationFailure.servicesDisabled => _ar
        ? 'خدمة الموقع مغلقة. شغّلها ثم حاول مرة أخرى.'
        : 'Location is off. Turn it on and try again.',
    LocationFailure.permissionDenied => _ar
        ? 'التطبيق يحتاج صلاحية الموقع لتحديد عنوانك.'
        : 'The app needs location permission to find your address.',
    LocationFailure.permissionPermanentlyDenied => _ar
        ? 'صلاحية الموقع مرفوضة نهائيًا. فعّلها من إعدادات التطبيق.'
        : 'Location permission is permanently denied. Enable it in app settings.',
    LocationFailure.timeout => _ar
        ? 'ما قدرناش نحدد موقعك في الوقت المناسب. جرّب مكانًا مفتوحًا.'
        : "We couldn't fix your position in time. Try somewhere more open.",
    LocationFailure.unavailable => _ar
        ? 'تعذّر تحديد موقعك حاليًا. حدّد المكان على الخريطة يدويًا.'
        : 'Could not get your position. Pick a spot on the map.',
  };

  /// Opens the app's settings page, for the one case that only Settings fixes.
  static String get openSettings => _ar ? 'فتح الإعدادات' : 'Open settings';
  static String get searchLocation =>
      _ar ? 'ابحث عن موقعك' : 'Search your location';
  static String get addressNameHint =>
      _ar ? 'اسم العنوان (مثال: المنزل)' : 'Address name (e.g. Home)';
  static String get totalToPay => _ar ? 'الإجمالي للدفع' : 'Total to pay';
  static String get paymentSuccess =>
      _ar ? 'تم الدفع بنجاح!' : 'Payment Successful!';
  static String get thankYouPurchase =>
      _ar ? 'شكرًا لشرائك.' : 'Thank you for your purchase.';
  static String get viewEReceipt => _ar ? 'عرض الإيصال' : 'View E-Receipt';
  static String get fulfillmentMethod =>
      _ar ? 'طريقة الاستلام' : 'Fulfillment Method';
  static String get pickupMethod => _ar ? 'استلام من الفرع' : 'Pickup';
  static String get deliveryMethod => _ar ? 'توصيل' : 'Delivery';
  static String get deliveryZone => _ar ? 'منطقة التوصيل' : 'Delivery Zone';
  static String get selectDeliveryZone =>
      _ar ? 'اختر منطقة التوصيل' : 'Select a delivery zone';
  static String get deliveryUnavailable => _ar
      ? 'التوصيل غير متاح لهذا الفرع، اختر الاستلام أو غيّر الفرع.'
      : 'Delivery is unavailable for this branch. Choose pickup or another branch.';
  static String get deliveryAddressRequired => _ar
      ? 'أضف عنوان توصيل لإتمام الطلب.'
      : 'Add a delivery address to place the order.';
  static String get deliveryZoneRequired =>
      _ar ? 'اختر منطقة التوصيل.' : 'Select a delivery zone.';
  static String get deliveryMinimumNotMet => _ar
      ? 'قيمة السلة أقل من الحد الأدنى للتوصيل في هذه المنطقة.'
      : 'Your cart is below the delivery minimum for this zone.';
  static String get deliveryUnavailableError => _ar
      ? 'تعذر تحميل مناطق التوصيل. حاول مجددًا أو اختر الاستلام.'
      : "Couldn't load delivery zones. Try again or choose pickup.";
  static String get deliveryChoosePickup =>
      _ar ? 'اختر الاستلام لإتمام الطلب.' : 'Choose pickup to continue.';

  // ---------- Delivery areas ----------
  static String get deliveryOutOfZone => _ar
      ? 'منطقة التوصيل دي مش بنغطيها. اختر استلام من الفرع، أو غيّر عنوان التوصيل.'
      : "We don't deliver to this address. Choose pickup from the branch, or change your delivery address.";
  static String get deliveryOutOfZoneShort => _ar
      ? 'التوصيل غير متاح لهذا العنوان'
      : 'Delivery is not available for this address';
  static String get deliveryZoneFromAddress => _ar
      ? 'المنطقة حسب عنوانك'
      : 'Area from your address';
  static String get deliveryChooseZoneManually => _ar
      ? 'اختر منطقة التوصيل يدويًا'
      : 'Choose the delivery area manually';
  static String get deliveryZoneAutoUnavailable => _ar
      ? 'ما قدرناش نحدد منطقة موقعك. اخترها يدويًا.'
      : "We couldn't match your location to an area. Pick one manually.";
  static String get deliveryFreeOver => _ar
      ? 'التوصيل مجاني للطلبات فوق'
      : 'Free delivery over';
  static String get deliveryPerKm => _ar ? 'حسب المسافة' : 'By distance';
  static String get deliveryFlatFee => _ar ? 'رسوم ثابتة' : 'Flat fee';
  static String get deliveryAlwaysFree => _ar ? 'التوصيل مجاني' : 'Free delivery';
  static String deliveryDistanceAway(double km) => _ar
      ? 'يبعد $km كم عن الفرع'
      : '$km km from the branch';
  static String get couponAppliesTo => _ar ? 'ينطبق على' : 'Applies to';
  static String get couponAppliesToAll => _ar
      ? 'ينطبق على كل المنتجات'
      : 'Applies to everything in your cart';
  /// A scoped coupon discounts only the eligible items, so the figure is a
  /// percentage of those items and not of the whole basket.
  static String get couponScopeDiscountNote => _ar
      ? 'الخصم على المنتجات المؤهلة فقط، مش على كل السلة'
      : 'The discount applies to the eligible items only, not to your whole cart';
  static String get couponEligibleInCart => _ar
      ? 'المنتجات المؤهلة في سلتك'
      : 'Eligible items in your cart';
  static String get couponDiscountBreakdown => _ar
      ? 'تفصيل الخصم'
      : 'Discount breakdown';
  static String get subTotalDiscounted => _ar ? 'إجمالي الخصم' : 'Total discount';
  static String get lineDiscount => _ar ? 'خصم هذا السطر' : 'Line discount';
  static String get originalPrice => _ar ? 'السعر الأصلي' : 'Original price';
  static String get discountedPrice => _ar ? 'السعر بعد الخصم' : 'Price after discount';
  static String get couponBreakdown => _ar ? 'تفصيل خصم الكوبون' : 'Coupon discount breakdown';
  static String get setDefaultCard => _ar ? 'تعيين كافتراضية' : 'Set as default';
  static String get defaultCardBadge => _ar ? 'افتراضية' : 'Default';
  static String get payWithSavedCard => _ar
      ? 'الدفع ببطاقة محفوظة'
      : 'Pay with a saved card';
  static String get chooseSavedCard => _ar ? 'اختر البطاقة' : 'Choose a card';
  static String get noCardsSaved => _ar
      ? 'لا توجد بطاقات محفوظة'
      : 'No saved cards yet';
  static String get cardExpires => _ar ? 'تنتهي في' : 'Expires';
  static String get couponLineNotIncluded => _ar
      ? 'مش من المنتجات المؤهلة'
      : 'Not an eligible item';
  static String get couponScopeCategories => _ar ? 'الأقسام' : 'categories';
  static String get couponScopeProducts => _ar ? 'المنتجات' : 'products';

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
        'not_found' => _ar ? 'كود الخصم غير صحيح' : 'That coupon code is not valid',
        'expired' => _ar ? 'انتهت صلاحية هذا الكود' : 'This coupon has expired',
        'min_order_not_met' => _ar
            ? 'الطلب لم يصل للحد الأدنى المطلوب للكود'
            : "Your order is below this coupon's minimum",
        'fully_used' => _ar
            ? 'تم استنفاد هذا الكود'
            : 'This coupon has been fully claimed',
        'user_limit_reached' => _ar
            ? 'استخدمت هذا الكود بالحد المسموح لك'
            : 'You have already used this coupon the allowed number of times',
        'scope_category_no_match' => scopeLabel.isEmpty
            ? _ar
                  ? 'الكود مخصص لأقسام محددة مش في سلتك'
                  : 'This coupon is limited to certain categories, none of which are in your cart'
            : _ar
            ? 'الكود مخصص لـ$scopeLabel، وده مش موجود في سلتك'
            : "This coupon is limited to $scopeLabel, which is not in your cart",
        'scope_product_no_match' => scopeLabel.isEmpty
            ? _ar
                  ? 'الكود مخصص لمنتجات محددة مش في سلتك'
                  : 'This coupon is limited to certain products, none of which are in your cart'
            : _ar
            ? 'الكود مخصص لـ$scopeLabel، وده مش موجود في سلتك'
            : "This coupon is limited to $scopeLabel, which is not in your cart",
        // Legacy bridges and older deployments answer with a message rather than
        // a reason code; fall back to translating that.
        _ => couponRejected(
          legacyMessage.trim().isNotEmpty ? legacyMessage : reasonCode,
        ),
      };

  // ---------- Orders ----------
  static String get myOrders => _ar ? 'طلباتي' : 'My Orders';
  static String get orderDetails => _ar ? 'تفاصيل الطلب' : 'Order Details';
  static String get orderStatus => _ar ? 'حالة الطلب' : 'Order Status';
  static String get noOrders => _ar ? 'لا توجد طلبات هنا' : 'No orders here';
  static String get signInToSeeOrders =>
      _ar ? 'سجل الدخول لرؤية طلباتك' : 'Sign in to see your orders';
  static String get orderHistoryAccount =>
      _ar ? 'سجل الطلبات يخص حسابك' : 'Order history belongs to your account';
  static String get couldNotLoadOrders =>
      _ar ? 'تعذر تحميل الطلبات' : 'Could not load orders';
  static String get tryAgain => _ar ? 'حاول مجددًا' : 'Try again';
  static String get ordersEmptyHint => _ar
      ? 'ستظهر طلباتك بهذه الحالة هنا'
      : 'Your orders in this status will appear here';
  static String get cancelOrder => _ar ? 'إلغاء الطلب' : 'Cancel Order';
  static String get orderCancelled =>
      _ar ? 'تم إلغاء الطلب' : 'Order cancelled';
  static String cancelFailed(String error) =>
      _ar ? 'تعذر الإلغاء: $error' : 'Could not cancel: $error';
  static String get trackingId => _ar ? 'رقم التتبع' : 'Tracking ID';
  static String orderNumber(String number) =>
      _ar ? 'طلب رقم $number' : 'Order #$number';
  static String get placed => _ar ? 'تم الطلب' : 'Placed';
  static String get itemsCount => _ar ? 'عدد الأصناف' : 'Items count';
  static String get trackOrder => _ar ? 'تتبع الطلب' : 'Track Order';
  static String get leaveReview => _ar ? 'قيّم الطلب' : 'Leave Review';
  static String get addBundleToCart =>
      _ar ? 'أضف الباقة إلى السلة' : 'Add Bundle to Cart';
  static String redeemedReward(String name) =>
      _ar ? 'تم استبدال $name' : 'Redeemed $name';
  static String get howIsOrder => _ar ? 'كيف كان طلبك؟' : 'How is your order?';
  static String get overallRating =>
      _ar ? 'تقييمك العام' : 'Your overall rating';
  static String get addReview =>
      _ar ? 'أضف تقييمًا مفصلًا' : 'Add detailed review';
  static String get reviewHint =>
      _ar ? 'اكتب رأيك هنا...' : 'Write your review here...';
  static String get selectRating =>
      _ar ? 'من فضلك اختر تقييمًا' : 'Please select a rating';
  static String get reviewSubmitted =>
      _ar ? 'تم إرسال التقييم بنجاح' : 'Review submitted successfully';
  static String get history => _ar ? 'السجل' : 'History';

  // ---------- Favorites ----------
  static String get favorites => _ar ? 'المفضلة' : 'Favorites';
  static String get noFavorites =>
      _ar ? 'لا توجد مفضلة بعد' : 'No favorites yet';
  static String get favoritesHint => _ar
      ? 'اضغط القلب على أي قهوة لحفظها هنا'
      : 'Tap the heart on any coffee to save it here';

  // ---------- Bundles ----------
  static String get noBundles => _ar ? 'لا توجد باقات بعد' : 'No bundles yet';
  static String get bundlesHint => _ar
      ? 'ستظهر الباقات هنا عند إضافتها'
      : 'Bundles will appear here once they are added';
  static String get bundlePrice => _ar ? 'سعر الباقة' : 'Bundle price';
  static String get originalTotal => _ar ? 'الإجمالي الأصلي' : 'Original total';
  static String get youSave => _ar ? 'أنت توفر' : 'You save';
  static String get whatsInside => _ar ? 'محتويات الباقة' : "What's inside";
  static String addedBundleToCart(String title) =>
      _ar ? 'تمت إضافة $title إلى السلة' : '$title added to cart';
  static String bundleNote(String title) =>
      _ar ? 'باقة: $title' : 'Bundle: $title';

  // ---------- Loyalty ----------
  static String get loyaltyPoints => _ar ? 'نقاط الولاء' : 'Loyalty Points';
  static String points(int value) => _ar ? '$value نقطة' : '$value points';
  static String get pointsWord => _ar ? 'نقطة' : 'points';
  static String get redeem => _ar ? 'استبدال' : 'Redeem';
  static String get locked => _ar ? 'مغلق' : 'Locked';
  static String get keepCollectingToUnlock =>
      _ar ? 'واصل الجمع لفتح المكافآت' : 'Keep collecting to unlock rewards';
  static String get yourPointsUnlock =>
      _ar ? 'نقاطك تفتح' : 'Your points unlock';
  static String get keepCollecting => _ar ? 'واصل الجمع' : 'Keep collecting';
  static String get yourBalance => _ar ? 'رصيدك' : 'Your Balance';
  static String get guestWalletDevice =>
      _ar ? 'محفظة الضيف على هذا الجهاز' : 'Guest wallet on this device';
  static String lifetimePoints(String tier, int points) =>
      _ar ? '$tier · $points نقطة تراكمية' : '$tier · $points lifetime points';
  static String get bestOffers =>
      _ar ? 'أفضل العروض لك' : 'Best offers for you';
  static String get loyaltyRewardNote => _ar ? 'مكافأة ولاء' : 'Loyalty reward';
  static String get notEnoughPoints =>
      _ar ? 'لا توجد نقاط كافية بعد' : 'Not enough points yet';
  static String earnRate(String formatted, String currencyCode) => _ar
      ? 'اكسب $formatted نقطة لكل 1 $currencyCode في كل طلب'
      : 'Earn $formatted points per 1 $currencyCode on every order';
  static String get earnRateUnavailable =>
      _ar ? 'معدل الكسب غير متوفر' : 'Earn rate unavailable';

  static String get authEmailNotConfirmed =>
      _ar ? 'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول.' : 'Please confirm your email address before signing in.';
  static String get authTooManyRequests =>
      _ar ? 'محاولات كثيرة جداً. يرجى الانتظار قليلاً والمحاولة مرة أخرى.' : 'Too many attempts. Please wait a moment and try again.';

  // ---------- Coupons ----------
  static String get coupon => _ar ? 'الكوبون' : 'Coupon';
  static String get copyCode => _ar ? 'نسخ الكود' : 'Copy Code';
  static String get noCoupons =>
      _ar ? 'لا توجد كوبونات حاليًا' : 'No coupons right now';
  static String couponsLoadError(String error) =>
      _ar ? 'تعذر تحميل الكوبونات: $error' : 'Could not load coupons: $error';
  static String get couponCheckFailed => _ar
      ? 'تعذر التحقق من الكوبون للمرة الحالية. حدّث السلة وحاول مجددًا.'
      : "Couldn't verify the coupon for the current cart. Refresh and try again.";
  static String codeCopied(String code) =>
      _ar ? 'تم نسخ الكود $code' : 'Code $code copied';

  // ---------- Payment & cards ----------
  static String get payment => _ar ? 'الدفع' : 'Payment';
  static String get paymentMethod => _ar ? 'طريقة الدفع' : 'Payment Method';
  static String get addCard => _ar ? 'إضافة بطاقة' : 'Add Card';
  static String get cardHolder => _ar ? 'اسم الحامل' : 'CARD HOLDER';
  static String get expires => _ar ? 'تنتهي في' : 'EXPIRES';
  static String get cardAdded =>
      _ar ? 'تمت إضافة البطاقة بنجاح' : 'Card added successfully';
  static String get creditDebitCard =>
      _ar ? 'بطاقة ائتمانية / مدى' : 'Credit & Debit Card';
  static String get morePaymentOptions =>
      _ar ? 'خيارات دفع أخرى' : 'More Payment Options';
  static String get noSavedCards =>
      _ar ? 'لا توجد بطاقات محفوظة بعد' : 'No saved cards yet';
  static String get yourName => _ar ? 'اسمك' : 'YOUR NAME';
  static String get saveCard => _ar ? 'حفظ البطاقة' : 'Save Card';
  static String get cardHolderRequired =>
      _ar ? 'اسم حامل البطاقة مطلوب' : 'Card holder name is required';
  static String get validCardNumber =>
      _ar ? 'أدخل رقم بطاقة صحيحًا' : 'Enter a valid card number';
  static String get invalidDate => _ar ? 'تاريخ غير صالح' : 'Invalid date';
  static String get cardBrandFallback => _ar ? 'بطاقة' : 'CARD';
  /// The name printed on the card. "Card holder" reads as the role; "Card holder
  /// name" reads as a form field asking for something else.
static String get cardHolderName =>
      _ar ? 'حامل البطاقة' : 'Card Holder';
  static String get cardNumber => _ar ? 'رقم البطاقة' : 'Card Number';
  static String get expiryFormatHint =>
      _ar ? 'شهر/سنة' : 'MM/YY';
  static String cvvHint(int digits) =>
      _ar ? 'الرمز ($digits أرقام)' : 'CVV ($digits digits)';
  static String invalidCvvLength(int digits) => _ar
      ? 'الرمز المكوّن من $digits أرقام مطلوب'
      : 'CVV must be $digits digits';
  static String get invalidCvv => _ar ? 'أدخل رمز البطاقة بشكل صحيح' : 'Enter a valid CVV';
  static String get cardExpired =>
      _ar ? 'البطاقة منتهية الصلاحية' : 'This card has expired';
  static String get savingCard =>
      _ar ? 'جارٍ حفظ البطاقة...' : 'Saving card...';
  static String get saveCardFailed => _ar
      ? 'تعذّر حفظ البطاقة. حاول مرة أخرى.'
      : 'Could not save the card. Please try again.';
  static String get cardDeclined => _ar
      ? 'لم يتم قبول البطاقة. تحقق من البيانات أو جرّب بطاقة أخرى.'
      : "Your card wasn't accepted. Check the details or try another card.";
  static String get cardSaveNotAllowed => _ar
      ? 'سجّل الدخول لحفظ البطاقات.'
      : 'Sign in to save cards.';
  /// The card provider is not reachable at all — a build/deploy problem.
  ///
  /// Deliberately not "try again later": retrying cannot fix a function that
  /// was never deployed, and that wording is what hid this in the first place.
  static String get cardSavingNotConfigured => _ar
      ? 'حفظ البطاقات غير متاح حالياً. برجاء المحاولة لاحقاً أو التواصل معنا.'
      : 'Saving cards is unavailable right now. Please try again later or contact us.';
  static String get addNewCard =>
      _ar ? '+ إضافة بطاقة جديدة' : '+ Add new card';
  static String get paymentProcessing => _ar
      ? 'جارٍ تنفيذ الدفع. سنوافيك بالتحديث.'
      : 'Payment is being processed. We will update you soon.';
  static String get paymentFailed => _ar
      ? 'تعذّر إتمام الدفع. حاول مرة أخرى.'
      : 'Payment could not be completed. Please try again.';
  static String get invalidCardDetails =>
      _ar ? 'أدخل بيانات بطاقة صحيحة' : 'Please enter valid card details';
  static String get tokenizationFailed => _ar
      ? 'تعذّر حفظ بيانات البطاقة. حاول مرة أخرى.'
      : 'Could not save the card details. Please try again.';
  static String get paymentNotCompleted =>
      _ar ? 'لم يتم إتمام الدفع.' : 'Payment was not completed.';
  static String get paymentVerificationFailed => _ar
      ? 'فشل التحقق من الدفع.' : 'Payment verification failed.';
  static String get paymentRetryLater => _ar
      ? 'تعذّر إتمام الدفع. حاول مرة أخرى.'
      : 'Payment failed. Please try again.';

  // ---------- Auth ----------
  static String get signIn => _ar ? 'تسجيل الدخول' : 'Sign In';
  static String get signUp => _ar ? 'إنشاء حساب' : 'Sign Up';
  static String get orSignUpWith => _ar ? 'أو سجل عبر' : 'Or sign up with';
  static String get orSignInWith => _ar ? 'أو ادخل عبر' : 'Or sign in with';
  static String get dontHaveAccount =>
      _ar ? 'ليس لديك حساب؟ ' : "Don't have an account? ";
  static String get didntReceiveCode =>
      _ar ? 'لم يصلك الكود؟ ' : "Didn't receive the code? ";
  static String get resend => _ar ? 'إعادة إرسال' : 'Resend';
  static String get codeSent =>
      _ar ? 'تم إرسال كود جديد' : 'A new code has been sent';
  static String get resetPassword =>
      _ar ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  static String get sendCode => _ar ? 'إرسال الكود' : 'Send Code';
  static String get sendResetLink =>
      _ar ? 'إرسال رابط التعيين' : 'Send Reset Link';
  static String get letsGetStarted => _ar ? 'لنبدأ' : "Let's Get Started";
  static String get yourCoffee => _ar ? 'قهوتك' : 'Your Coffee';
  static String get yourMoment =>
      _ar ? 'لحظتك، على طريقتك' : 'Your Moment, Your Way';
  static String get welcomeDescription => _ar
      ? 'اكتشف قهوتك المفضلة واجعل كل لحظة أجمل، كوبًا بعد كوب.'
      : 'Discover your favorite coffee and make every moment a little more special, one cup at a time.';
  static String get continueWithPhone =>
      _ar ? 'المتابعة برقم الهاتف' : 'Continue with phone number';
  static String get continueWithGoogle =>
      _ar ? 'المتابعة بحساب جوجل' : 'Continue with Google';
  static String get forgotPasswordQ =>
      _ar ? 'نسيت كلمة المرور؟' : 'Forget your password?';
  static String get emailRequired =>
      _ar ? 'البريد الإلكتروني مطلوب' : 'Email is required';
  static String get nameRequired => _ar ? 'الاسم مطلوب' : 'Name is required';
  static String get passwordRequired =>
      _ar ? 'كلمة المرور مطلوبة' : 'Password is required';
  static String get passwordsNoMatch =>
      _ar ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
  static String get createAccountSubtitle =>
      _ar ? 'أنشئ حسابك للبدء' : 'Create your account to get started';
  static String get emailHint => _ar ? 'البريد الإلكتروني' : 'Email';
  static String get nameHint => _ar ? 'الاسم' : 'Name';
  static String get passwordHint => _ar ? 'كلمة المرور' : 'Password';
  static String get confirmPasswordHint =>
      _ar ? 'تأكيد كلمة المرور' : 'Confirm Password';
  static String get newPasswordHint => _ar ? 'كلمة مرور جديدة' : 'New Password';
  static String get phoneHint => _ar ? 'رقم الهاتف' : 'Phone number';
  static String get alreadyHaveAccount =>
      _ar ? 'لديك حساب بالفعل؟ ' : 'Already have an account? ';
  static String get enterNewPassword => _ar
      ? 'أدخل كلمة المرور الجديدة بالأسفل'
      : 'Enter your new password below';
  static String get forgetPassword =>
      _ar ? 'نسيت كلمة المرور' : 'Forget Password';
  static String get signInWithPhone =>
      _ar ? 'تسجيل الدخول بالهاتف' : 'Sign In with Phone';
  static String get rememberPasswordQ =>
      _ar ? 'تذكرت كلمة المرور؟ ' : 'Remember your password? ';
  static String get verificationCode =>
      _ar ? 'كود التحقق' : 'Verification Code';
  static String get enterSixDigitCode => _ar
      ? 'من فضلك أدخل الكود المكون من 6 أرقام'
      : 'Please enter the 6-digit code';
  static String get validPhoneNumber =>
      _ar ? 'أدخل رقم هاتف صحيحًا' : 'Enter a valid phone number';
  static String get phoneRequired =>
      _ar ? 'رقم الهاتف مطلوب' : 'Phone number is required';

  // ---------- Profile ----------
  static String get yourProfile => _ar ? 'حسابك' : 'Your Profile';
  static String get help => _ar ? 'المساعدة' : 'Help';
  static String get privacyPolicy => _ar ? 'سياسة الخصوصية' : 'Privacy Policy';
static String get defaultAddress => _ar ? 'افتراضي' : 'Default';
  static String get setDefaultAddress => _ar ? 'تعيين كافتراضي' : 'Set as default';
  static String get editAddress => _ar ? 'تعديل العنوان' : 'Edit address';
  static String get logOut => _ar ? 'تسجيل الخروج' : 'Log Out';
  static String get confirmLogout => _ar ? 'نعم، تسجيل الخروج' : 'Yes, Logout';
  static String get logoutConfirm => _ar
      ? 'هل أنت متأكد من تسجيل الخروج؟'
      : 'Are you sure you want to log out ?';
  /// Shown when the client sign-out itself fails. The customer stays signed in
  /// and the sign-out can be retried.
  static String get logoutFailed =>
      _ar ? 'تعذّر تسجيل الخروج. حاول مرة أخرى.' : 'Could not sign you out. Please try again.';
  static String get faqTitle =>
      _ar ? 'الأسئلة الشائعة' : 'Frequently asked questions';
  static String get profilePicture =>
      _ar ? 'الصورة الشخصية' : 'Profile Picture';
  static String get fullNameHint => _ar ? 'الاسم الكامل' : 'Full Name';
  static String get firstNameHint => _ar ? 'الاسم الأول' : 'First Name';
  static String get lastNameHint => _ar ? 'الاسم الأخير' : 'Last Name';
  static String get profileUpdateFailed => _ar ? 'فشل تحديث الملف الشخصي' : 'Profile update failed';
  static String get phoneNumberHint => _ar ? 'رقم الهاتف' : 'Phone Number';
  static String get profileUpdated =>
      _ar ? 'تم تحديث الحساب بنجاح' : 'Profile updated successfully';
  static String get chooseFromGallery =>
      _ar ? 'اختر من المعرض' : 'Choose from gallery';
  static String get takePhoto => _ar ? 'التقط صورة' : 'Take a photo';
  static String get imagePickerFailed =>
      _ar ? 'تعذر فتح اختيار الصور' : "Couldn't open the image picker";
  static String get photoUploadFailed =>
      _ar ? 'تعذر حفظ الصورة. حاول مرة أخرى.' : "Couldn't save the photo. Please try again.";
  static String get photoFormatUnsupported => _ar
      ? 'صيغة الصورة غير مدعومة. اختر صورة بصيغة مدعومة.'
      : 'That image format is not supported. Choose a JPG, PNG or WebP image.';
  static String get photoSaveFailed => _ar
      ? 'تم رفع الصورة لكن تعذر ربطها بالحساب.'
      : 'The photo was uploaded but could not be linked to your account.';
  static String get photoLoadFailed =>
      _ar ? 'تعذر تحميل الصورة' : "Couldn't load the photo";
  static String get language => _ar ? 'اللغة' : 'Language';
  static String languageValue(bool arabic) =>
      arabic ? 'اللغة: العربية' : 'Language: English';
  static String get arabicLanguage => _ar ? 'العربية' : 'Arabic';
  static String get englishLanguage => _ar ? 'الإنجليزية' : 'English';
  static String get myAddresses => _ar ? 'عناويني' : 'My Addresses';
  static String get noAddresses =>
      _ar ? 'لا توجد عناوين محفوظة بعد' : 'No saved addresses yet';
  static String get addressesHint => _ar
      ? 'أضف عناوينك لإتمام طلبات التوصيل إليها بشكل أسرع'
      : 'Add your addresses to check out delivery faster';
  static String get delete => _ar ? 'حذف' : 'Delete';
  static String get deleteAddress => _ar ? 'حذف العنوان' : 'Delete address';
  static String get deleteAddressConfirm => _ar
      ? 'هل تريد حذف هذا العنوان؟'
      : 'Do you want to delete this address?';
  static String get addressSaveFailed =>
      _ar ? 'تعذر حفظ العنوان. حاول مرة أخرى.' : 'Could not save the address. Please try again.';
  static String get addressDeleteFailed =>
      _ar ? 'تعذر حذف العنوان. حاول مرة أخرى.' : 'Could not delete the address. Please try again.';

  // ---------- Help / FAQ / policy ----------
  static String faqsLoadError(String error) =>
      _ar ? 'تعذر تحميل الأسئلة: $error' : 'Could not load FAQs: $error';
  static String get noFaqs => _ar ? 'لا توجد أسئلة متاحة' : 'No FAQs available';
  static String policyLoadError(String error) =>
      _ar ? 'تعذر تحميل السياسة: $error' : 'Could not load policy: $error';
  static String get policyUnavailable =>
      _ar ? 'سياسة الخصوصية غير متوفرة.' : 'Privacy policy unavailable.';

  // ---------- Notifications ----------
  static String get notifications => _ar ? 'الإشعارات' : 'Notifications';
  static String get signInForNotifications =>
      _ar ? 'سجل الدخول لرؤية الإشعارات' : 'Sign in to see notifications';
  static String get orderUpdatesAccount => _ar
      ? 'تحديثات الطلبات تصل إلى حسابك'
      : 'Order updates arrive in your account';
  static String get couldNotLoadNotifications =>
      _ar ? 'تعذر تحميل الإشعارات' : 'Could not load notifications';
  static String get noNotifications =>
      _ar ? 'لا توجد إشعارات بعد' : 'No notifications yet';
  static String get notificationsHint =>
      _ar ? 'ستظهر تحديثات الطلبات هنا' : 'Order updates will appear here';
  static String get skip => _ar ? 'تخطي' : 'Skip';

  // ---------- Banners ----------
  static String enjoyReward(String name) =>
      _ar ? 'استمتع بـ $name!' : 'Enjoy your $name!';

  // ---------- Assistant ----------
  static String get askAnything => _ar ? 'اسألني أي شيء؟' : 'Ask me anything?';
  static String get assistantTitle => _ar ? 'مساعد القهوة' : 'Coffee Assistant';
  static String get open => _ar ? 'فتح' : 'Open';

  // ---------- Branch ----------
  static String get chooseBranch => _ar ? 'اختر الفرع' : 'Choose branch';

  // ---------- Onboarding ----------
  static String get noSlides =>
      _ar ? 'لا توجد شرائح تعريفية' : 'No onboarding slides';

  // ---------- Auth screens ----------
  static String get welcomeBackSubtitle => _ar
      ? 'أهلًا بعودتك، كنا ننتظرك'
      : "Hi welcome back, you've been missed";
  static String get createAccountTitle => _ar ? 'حساب جديد' : 'Create Account';
  static String get forgotPasswordSubtitle => _ar
      ? 'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين'
      : "Enter your email and we'll send you a link to reset your password";
  static String get phoneAuthSubtitle => _ar
      ? 'أدخل رقم هاتفك وسنرسل لك كود تحقق'
      : "Enter your phone number and we'll send you a verification code";
  static String otpSentTo(String phone) => _ar
      ? 'أرسلنا كودًا مكونًا من 6 أرقام إلى $phone'
      : 'We sent a 6-digit code to $phone';

  // Auth failures. The provider's own English never reaches the customer.
  static String get authInvalidCredentials => _ar
      ? 'بيانات الدخول غير صحيحة، برجاء التحقق من الإيميل وكلمة المرور'
      : 'Wrong email or password. Please check and try again.';
  static String get authUserNotFound => _ar
      ? 'هذا الإيميل غير مسجل، برجاء إنشاء حساب أولًا'
      : 'This email is not registered. Please sign up first.';
  static String get authUserDisabled => _ar
      ? 'هذا الحساب معطّل، برجاء التواصل مع الدعم'
      : 'This account is disabled. Please contact support.';
  static String get authEmailInUse => _ar
      ? 'هذا الإيميل مسجل بالفعل، برجاء تسجيل الدخول أو استخدام إيميل آخر'
      : 'This email is already registered. Sign in or use another email.';
  static String get authWeakPassword => _ar
      ? 'كلمة المرور ضعيفة، برجاء استخدام كلمة مرور أطول وأكثر أمانًا'
      : 'Password is too weak. Please use a longer, stronger password.';
  static String get authInvalidEmail =>
      _ar ? 'إيميل غير صحيح، برجاء إدخال إيميل صحيح' : 'Enter a valid email address.';
  static String get authFailed =>
      _ar ? 'حدث خطأ أثناء الدخول. حاول مرة أخرى.' : 'Something went wrong signing in. Please try again.';
  static String get authUnexpected =>
      _ar ? 'حدث خطأ غير متوقع، برجاء المحاولة مرة أخرى.' : 'Something unexpected happened. Please try again.';

  /// Shown when the backend could not be reached at all. Distinct from
  /// [authFailed], which means the request itself was rejected.
  static String get authServiceUnavailable => _ar
      ? 'الخدمة غير متاحة حالياً. برجاء المحاولة لاحقاً.'
      : 'The service is unavailable right now. Please try again later.';
  static String get signUpEmailVerification => _ar
      ? 'تم إنشاء الحساب. يرجى التحقق من بريدك الإلكتروني لتأكيد حسابك.'
      : 'Account created. Please check your email to verify your account.';
  static String get passwordResetEmailSent => _ar
      ? 'إذا كان هذا البريد مسجلاً، فقد أرسلنا رابط إعادة تعيين كلمة المرور.'
      : 'If that email is registered, we sent a password reset link.';
  static String get passwordResetSuccess =>
      _ar ? 'تم تحديث كلمة المرور.' : 'Your password has been updated.';

  // ---------- Coupons ----------
  static String get couponApplied =>
      _ar ? 'تم تطبيق كود الخصم' : 'Coupon applied';
  static String get invalidCouponCode =>
      _ar ? 'كود الخصم غير صالح' : 'Invalid coupon code';

  /// Why the server refused a coupon.
  ///
  /// `validate_coupon` answers with fixed English codes. Showing those raw put
  /// English sentences — and no explanation — in an Arabic checkout, which read
  /// as the coupon silently vanishing.
  static String couponRejected(String code) => switch (code.trim()) {
    'code not valid' => _ar ? 'كود الخصم غير صحيح' : 'That coupon code is not valid',
    'code expired' => _ar
        ? 'انتهت صلاحية هذا الكود'
        : 'This coupon has expired',
    'minimum order not reached' => _ar
        ? 'الطلب لم يصل للحد الأدنى المطلوب للكود'
        : 'Your order is below this coupon\'s minimum',
    'code fully used' => _ar
        ? 'تم استنفاد هذا الكود'
        : 'This coupon has been fully claimed',
    'you already used this code' => _ar
        ? 'استخدمت هذا الكود بالحد المسموح لك'
        : 'You have already used this coupon the allowed number of times',
    'code does not apply to your items' => _ar
        ? 'هذا الكود لا ينطبق على المنتجات في سلتك'
        : 'This coupon does not apply to the items in your cart',
    _ => _ar ? 'كود الخصم غير صالح' : 'Invalid coupon code',
  };

  static String couponUsesLeft(int count) => _ar
      ? 'متبقي $count استخدام'
      : count == 1
      ? '1 use left'
      : '$count uses left';
  static String get couponNoUsesLeft => _ar
      ? 'استخدمت هذا الكود بالحد المسموح'
      : 'You have used up this coupon';
  static String get couponAppliedBadge =>
      _ar ? 'مطبّق على طلبك' : 'Applied to your order';

  // ---------- Menu / product ----------
  static String get readMore => _ar ? 'اقرأ المزيد' : 'Read more';
  static String get readLess => _ar ? 'اقرأ أقل' : 'Read less';
  static String get productUnavailable =>
      _ar ? 'المنتج غير متاح' : 'Product unavailable';
  static String get productNoLongerAvailable => _ar
      ? 'هذا المنتج لم يعد متاحًا'
      : 'This product is no longer available';

  // ---------- Orders ----------
  static String quantityLabel(int quantity) =>
      _ar ? 'الكمية: $quantity' : 'Qty: $quantity';
  static String get liveStatusFailed =>
      _ar ? 'تعذّر جلب حالة الطلب مباشرة' : 'Could not load live status';
  static String get removedProduct =>
      _ar ? 'منتج محذوف' : 'Removed product';
  static String get addNewShippingAddress =>
      _ar ? '+ إضافة عنوان توصيل جديد' : '+ Add new shipping address';

  // ---------- Checkout ----------
  static String get selectBranchBeforePaying => _ar
      ? 'اختر الفرع قبل الدفع.'
      : 'Select a branch before paying.';
  static String loyaltyPointsEarned(int points) => _ar
      ? 'لقد كسبت $points نقطة ولاء!'
      : 'You earned $points loyalty points!';

  // ---------- Loyalty ----------
  static String get selectBranchBeforeRedeeming => _ar
      ? 'اختر الفرع قبل استبدال هذه المكافأة.'
      : 'Select a branch before redeeming this reward.';
  static String get orderPurchaseLabel =>
      _ar ? 'شراء طلب' : 'Order purchase';
  static String get rewardRedeemedLabel =>
      _ar ? 'تم استبدال المكافأة' : 'Reward redeemed';
  static String get pointsRefundedLabel =>
      _ar ? 'تم استرجاع النقاط' : 'Points refunded';
  static String get pointsExpiredLabel =>
      _ar ? 'انتهت صلاحية النقاط' : 'Points expired';
  static String get balanceAdjustmentLabel =>
      _ar ? 'تعديل في الرصيد' : 'Balance adjustment';
  static String get loyaltyActivityLabel =>
      _ar ? 'نشاط على النقاط' : 'Loyalty activity';

  // ---------- Shared widgets ----------
  static String get showPassword => _ar ? 'إظهار كلمة المرور' : 'Show password';
  static String get hidePassword => _ar ? 'إخفاء كلمة المرور' : 'Hide password';
  static String get saudiRiyal => _ar ? 'ريال سعودي' : 'Saudi Riyal';
  static String get bundleLabel => _ar ? 'باقة' : 'Bundle';
}
