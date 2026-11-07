import 'package:new_coffee/core/locale/app_locale.dart';

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

  static String get appName => _ar ? 'غيم وسحب' : 'Ghaim & Sohob';

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
  static String get vat => _ar ? 'ضريبة القيمة المضافة' : 'VAT';
  static String get vatIncluded => _ar
      ? 'أسعار المنتجات تشمل ضريبة القيمة المضافة'
      : 'Product prices include VAT';
  static String get discount => _ar ? 'الخصم' : 'Discount';
  static String get couponDiscount => _ar ? 'خصم الكوبون' : 'Coupon discount';

  /// The discount a promotion on the product itself applied.
  static String get productDiscount => _ar ? 'خصم المنتج' : 'Product discount';
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

  /// Same label as the bottom-nav tab; defined once there.
  static String get categories => navCategories;
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

  /// What the home page says when some of its sections did not load. The
  /// section names stay in the cubit for the logs; the customer is told the
  /// outcome and how to act on it.
  static String get homeDegradedNotice => _ar
      ? 'بعض الأقسام لم تصل هذا المرة. اسحب لتحميلها مجددًا.'
      : 'Some sections did not load this time. Pull down to try again.';
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
  static String get sortRelevance => _ar ? 'الأكثر صلة' : 'Relevance';
  static String get sortPriceLow => _ar ? 'السعر: من الأقل' : 'Price: Low';
  static String get sortPriceHigh => _ar ? 'السعر: من الأعلى' : 'Price: High';
  static String get sortName => _ar ? 'الاسم' : 'Name';
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

  /// A banner or a notification can name a category the catalogue no longer has -
  /// deleted or unpublished between the two reads. "No categories yet" would
  /// claim the shop has none, and the products themselves are not what is
  /// missing here.
  static String get categoryUnavailable => _ar
      ? 'هذا التصنيف غير متاح حالياً'
      : 'This category is not available right now';

  // ---------- Product details ----------
  static String get productDetails => _ar ? 'تفاصيل المنتج' : 'Product Details';
  static String get totalPrice => _ar ? 'السعر الإجمالي' : 'Total Price';
  static String get addToCart => _ar ? 'أضف إلى السلة' : 'Add to Cart';
  static String get unavailable => _ar ? 'غير متوفر' : 'Unavailable';
  static String get quantity => _ar ? 'الكمية' : 'Quantity';
  static String caloriesValue(int value) =>
      _ar ? '$value سعرة حرارية' : '$value kcal';
  static String get caloriesUnavailable =>
      _ar ? 'السعرات الحرارية غير مسجلة' : 'Calories not provided';
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
  static String get cart => navCart;
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
  static String get cartSyncFailed => _ar
      ? 'تعذّر حفظ السلة على الخادم. سنعيد المحاولة تلقائيًا.'
      : 'The cart could not be saved on the server. We will retry automatically.';
  static String get couldNotLoadCart =>
      _ar ? 'تعذّر تحميل السلة' : 'The cart could not be loaded';

  /// The cart's line cap belongs to the cart's state layer; the sentence carries
  /// the number it was given so the two can never disagree.
  static String cartLineLimitReached(int limit) => _ar
      ? 'لا يمكن للسلة حمل أكثر من $limit صنفًا'
      : 'The cart cannot hold more than $limit lines';
  static String get favoritesSyncFailed => _ar
      ? 'تعذّر حفظ المفضلة على الخادم. سنعيد المحاولة تلقائيًا.'
      : 'The favorites could not be saved on the server. '
            'We will retry automatically.';

  // ---------- Checkout ----------
  static String get checkout => _ar ? 'الدفع' : 'Checkout';
  static String get pickupBranch => _ar ? 'فرع الاستلام' : 'Pickup Branch';
  static String get shippingAddress =>
      _ar ? 'عنوان التوصيل' : 'Shipping Address';
  static String get orderList => _ar ? 'قائمة الطلب' : 'Order List';
  static String get continueToPayment =>
      _ar ? 'المتابعة للدفع' : 'Continue to Payment';
  static String get confirmPayment => _ar ? 'تأكيد الدفع' : 'Confirm Payment';
  static String get orderFailed => _ar
      ? 'تعذّر إتمام الطلب. حاول مرة أخرى.'
      : 'Could not place the order. Please try again.';
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
  /// strings rather than one shared apology. Which case is showing is decided
  /// by the location feature (`LocationFailure.userMessage`), because core must
  /// not know that type; the wording always stays here.
  static String get locationServicesDisabled => _ar
      ? 'خدمة الموقع مغلقة. شغّلها ثم حاول مرة أخرى.'
      : 'Location is off. Turn it on and try again.';

  static String get locationPermissionNeeded => _ar
      ? 'التطبيق يحتاج صلاحية الموقع لتحديد عنوانك.'
      : 'The app needs location permission to find your address.';

  static String get locationPermissionPermanentlyDenied => _ar
      ? 'صلاحية الموقع مرفوضة نهائيًا. فعّلها من إعدادات التطبيق.'
      : 'Location permission is permanently denied. Enable it in app settings.';

  static String get locationTimeout => _ar
      ? 'ما قدرناش نحدد موقعك في الوقت المناسب. جرّب مكانًا مفتوحًا.'
      : "We couldn't fix your position in time. Try somewhere more open.";

  static String get locationNoFix => _ar
      ? 'تعذّر تحديد موقعك حاليًا. حدّد المكان على الخريطة يدويًا.'
      : 'Could not get your position. Pick a spot on the map.';

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
  static String get deliveryNeedsBranch => _ar
      ? 'اختر الفرع أولاً لمعرفة هل التوصيل متاح.'
      : 'Choose a branch first to see whether delivery is available.';
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
  static String get deliveryZoneFromAddress =>
      _ar ? 'المنطقة حسب عنوانك' : 'Area from your address';
  static String get deliveryChooseZoneManually =>
      _ar ? 'اختر منطقة التوصيل يدويًا' : 'Choose the delivery area manually';
  static String get deliveryZoneAutoUnavailable => _ar
      ? 'ما قدرناش نحدد منطقة موقعك. اخترها يدويًا.'
      : "We couldn't match your location to an area. Pick one manually.";
  static String get deliveryFreeOver =>
      _ar ? 'التوصيل مجاني للطلبات فوق' : 'Free delivery over';
  static String get deliveryPerKm => _ar ? 'حسب المسافة' : 'By distance';
  static String get deliveryFlatFee => _ar ? 'رسوم ثابتة' : 'Flat fee';
  static String get deliveryAlwaysFree =>
      _ar ? 'التوصيل مجاني' : 'Free delivery';
  static String deliveryDistanceAway(double km) =>
      _ar ? 'يبعد $km كم عن الفرع' : '$km km from the branch';
  static String get couponAppliesTo => _ar ? 'ينطبق على' : 'Applies to';
  static String get couponAppliesToAll =>
      _ar ? 'ينطبق على كل المنتجات' : 'Applies to everything in your cart';

  /// A scoped coupon discounts only the eligible items, so the figure is a
  /// percentage of those items and not of the whole basket.
  static String get couponScopeDiscountNote => _ar
      ? 'الخصم على المنتجات المؤهلة فقط، مش على كل السلة'
      : 'The discount applies to the eligible items only, not to your whole cart';

  /// The eligible-item caption with its counts written into the sentence.
  ///
  /// A widget that appended "(2/5)" after the Arabic label got the pair pushed
  /// to the other end of the line by the right-to-left run, so the numbers
  /// belong to the wording, not to the layout.
  static String couponEligibleInCartCount(int eligible, int total) => _ar
      ? '$eligible من $total منتجًا مؤهلًا في سلتك'
      : '$eligible of $total items in your cart are eligible';
  static String get couponDiscountBreakdown =>
      _ar ? 'تفصيل الخصم' : 'Discount breakdown';
  static String get subTotalDiscounted =>
      _ar ? 'إجمالي الخصم' : 'Total discount';
  static String get lineDiscount => _ar ? 'خصم هذا السطر' : 'Line discount';
  static String get originalPrice => _ar ? 'السعر الأصلي' : 'Original price';
  static String get discountedPrice =>
      _ar ? 'السعر بعد الخصم' : 'Price after discount';
  static String get couponBreakdown =>
      _ar ? 'تفصيل خصم الكوبون' : 'Coupon discount breakdown';

  /// The rule of a percentage coupon, e.g. `خصم 20% حتى 15.00` /
  /// `20% off up to 15.00`. [cappedAt] is the money already formatted.
  static String couponPercentOff(String percent, String? cappedAt) =>
      cappedAt == null
      ? (_ar ? 'خصم $percent%' : '$percent% off')
      : (_ar ? 'خصم $percent% حتى $cappedAt' : '$percent% off up to $cappedAt');

  /// The rule of a fixed-amount coupon, e.g. `خصم 10.00` / `10.00 off`.
  static String couponAmountOff(String amount) =>
      _ar ? 'خصم $amount' : '$amount off';
  static String get setDefaultCard =>
      _ar ? 'تعيين كافتراضية' : 'Set as default';
  static String get defaultCardBadge => _ar ? 'افتراضية' : 'Default';
  static String get payWithSavedCard =>
      _ar ? 'الدفع ببطاقة محفوظة' : 'Pay with a saved card';
  static String get chooseSavedCard => _ar ? 'اختر البطاقة' : 'Choose a card';
  static String get cardExpires => _ar ? 'تنتهي في' : 'Expires';
  static String get couponLineNotIncluded =>
      _ar ? 'مش من المنتجات المؤهلة' : 'Not an eligible item';
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
    'min_order_not_met' =>
      _ar
          ? 'الطلب لم يصل للحد الأدنى المطلوب للكود'
          : "Your order is below this coupon's minimum",
    'fully_used' =>
      _ar ? 'تم استنفاد هذا الكود' : 'This coupon has been fully claimed',
    'user_limit_reached' =>
      _ar
          ? 'استخدمت هذا الكود بالحد المسموح لك'
          : 'You have already used this coupon the allowed number of times',
    'scope_category_no_match' =>
      scopeLabel.isEmpty
          ? _ar
                ? 'الكود مخصص لأقسام محددة مش في سلتك'
                : 'This coupon is limited to certain categories, none of which are in your cart'
          : _ar
          ? 'الكود مخصص لـ$scopeLabel، وده مش موجود في سلتك'
          : "This coupon is limited to $scopeLabel, which is not in your cart",
    'scope_product_no_match' =>
      scopeLabel.isEmpty
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
  static String get couldNotCancelOrder => _ar
      ? 'تعذر إلغاء الطلب. حاول مجددًا.'
      : 'Could not cancel the order. Try again.';
  static String get trackingId => _ar ? 'رقم التتبع' : 'Tracking ID';
  static String orderNumber(String number) =>
      _ar ? 'طلب رقم $number' : 'Order #$number';
  static String get placed => _ar ? 'تم الطلب' : 'Placed';
  static String get itemsCount => _ar ? 'عدد الأصناف' : 'Items count';
  static String get trackOrder => _ar ? 'تتبع الطلب' : 'Track Order';

  /// The three buckets the order list groups by.
  static String get orderStatusActive => _ar ? 'قيد التنفيذ' : 'Active';
  static String get orderStatusCompleted => _ar ? 'مكتمل' : 'Completed';
  static String get orderStatusCancelled => _ar ? 'ملغي' : 'Cancelled';

  /// The tracking timeline, one label per server status.
  static String get trackingOrderPlaced =>
      _ar ? 'تم استلام الطلب' : 'Order placed';
  static String get trackingOrderConfirmed =>
      _ar ? 'تم تأكيد الطلب' : 'Order confirmed';
  static String get trackingPreparing => _ar ? 'قيد التحضير' : 'Preparing';
  static String get trackingReadyForDelivery =>
      _ar ? 'جاهز للتوصيل' : 'Ready for delivery';
  static String get trackingReadyForPickup =>
      _ar ? 'جاهز للاستلام' : 'Ready for pickup';
  static String get trackingOutForDelivery =>
      _ar ? 'خرج للتوصيل' : 'Out for delivery';
  static String get trackingCompleted => _ar ? 'مكتمل' : 'Completed';
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
  static String get reviewSubmitFailed => _ar
      ? 'لم يُرسل التقييم. تحقّق من اتصالك ثم حاول مجددًا'
      : 'The review was not sent. Check your connection and try again';
  static String rateStars(int stars) =>
      _ar ? 'تقييم $stars من 5' : 'Rate $stars of 5';
  static String get history => _ar ? 'السجل' : 'History';

  // ---------- Favorites ----------
  static String get favorites => navFavorites;
  static String get noFavorites =>
      _ar ? 'لا توجد مفضلة بعد' : 'No favorites yet';
  static String get favoritesHint => _ar
      ? 'اضغط القلب على أي قهوة لحفظها هنا'
      : 'Tap the heart on any coffee to save it here';
  static String get couldNotLoadFavorites =>
      _ar ? 'تعذّر تحميل المفضلة' : 'The favorites could not be loaded';

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
  static String get couldNotLoadLoyalty => _ar
      ? 'تعذّر تحميل نقاط الولاء'
      : 'The loyalty wallet could not be loaded';
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

  static String get authEmailNotConfirmed => _ar
      ? 'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول.'
      : 'Please confirm your email address before signing in.';
  static String get authTooManyRequests => _ar
      ? 'محاولات كثيرة جداً. يرجى الانتظار قليلاً والمحاولة مرة أخرى.'
      : 'Too many attempts. Please wait a moment and try again.';

  // ---------- Coupons ----------
  static String get coupon => _ar ? 'الكوبون' : 'Coupon';
  static String get copyCode => _ar ? 'نسخ الكود' : 'Copy Code';
  static String get noCoupons =>
      _ar ? 'لا توجد كوبونات حاليًا' : 'No coupons right now';

  /// What an empty offer list means, so it does not read as a failure.
  static String get noCouponsHint => _ar
      ? 'تظهر العروض الجديدة هنا عند توفرها.'
      : 'New offers appear here as soon as one is published.';
  static String get couldNotLoadCoupons =>
      _ar ? 'تعذر تحميل الكوبونات.' : 'Could not load the coupons.';
  static String get couponCheckFailed => _ar
      ? 'لم يتم التحقق من الكوبون للطلب الحالي. حدّث وحاول مرة أخرى.'
      : "Couldn't verify the coupon for the current cart. Refresh and try again.";
  static String get couponNotAppliedAtCheckout => _ar
      ? 'لم يُطبّق خصم الكوبون عند إتمام الطلب، وتم احتساب المبلغ بدون الخصم.'
      : 'The coupon discount could not be applied at checkout, so the order was placed without it.';
  static String codeCopied(String code) =>
      _ar ? 'تم نسخ الكود $code' : 'Code $code copied';

  /// The device refused the clipboard. The code stays readable, but the copy
  /// did not happen and the customer has to know before they leave the page.
  static String get couldNotCopyCode => _ar
      ? 'تعذر نسخ الكود على هذا الجهاز.'
      : 'The code could not be copied on this device.';

  /// The offers were re-read and failed: what is on screen may be old.
  static String get couponsOutdated => _ar
      ? 'تعذر تحديث العروض. قد تكون العروض المعروضة قديمة.'
      : 'The offers could not be refreshed. These offers may be out of date.';

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
  static String get couldNotLoadSavedCards => _ar
      ? 'تعذّر تحميل بطاقاتك المحفوظة'
      : 'Your saved cards could not be loaded';
  static String get couldNotLoadAccountDetails => _ar
      ? 'تعذّر تحميل بيانات حسابك'
      : 'Your account details could not be loaded';

  /// The first read of the checkout (its payment methods and zones) broke.
  static String get couldNotLoadCheckout => _ar
      ? 'تعذّر تحميل معلومات الدفع'
      : 'The payment information could not be loaded';

  /// A product page that never got its product.
  static String get couldNotLoadProduct =>
      _ar ? 'تعذّر تحميل هذا المنتج' : 'This product could not be loaded';
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
  static String get cardHolderName => _ar ? 'حامل البطاقة' : 'Card Holder';
  static String get cardNumber => _ar ? 'رقم البطاقة' : 'Card Number';
  static String get expiryFormatHint => _ar ? 'شهر/سنة' : 'MM/YY';
  static String cvvHint(int digits) =>
      _ar ? 'الرمز ($digits أرقام)' : 'CVV ($digits digits)';
  static String invalidCvvLength(int digits) => _ar
      ? 'الرمز المكوّن من $digits أرقام مطلوب'
      : 'CVV must be $digits digits';
  static String get invalidCvv =>
      _ar ? 'أدخل رمز البطاقة بشكل صحيح' : 'Enter a valid CVV';
  static String get cardExpired =>
      _ar ? 'البطاقة منتهية الصلاحية' : 'This card has expired';
  static String get savingCard =>
      _ar ? 'جارٍ حفظ البطاقة...' : 'Saving card...';
  static String get saveCardFailed => _ar
      ? 'تعذّر حفظ البطاقة. حاول مرة أخرى.'
      : 'Could not save the card. Please try again.';
  static String get cardDeleteFailed => _ar
      ? 'تعذّر حذف البطاقة. ما زالت محفوظة.'
      : 'The card could not be removed. It is still saved.';

  /// The card the list still shows is not on the account any more.
  ///
  /// Distinct from [cardDeleteFailed]: nothing failed — the customer (or a
  /// second device) already removed it, and the row on screen is stale.
  static String get cardAlreadyRemoved => _ar
      ? 'هذه البطاقة لم تعد محفوظة لديك.'
      : 'This card is no longer saved to your account.';

  static String get deleteCard => _ar ? 'حذف البطاقة' : 'Delete card';

  /// Says what the customer is about to lose, not just "are you sure".
  static String get deleteCardConfirm => _ar
      ? 'سيتم حذف هذه البطاقة المحفوظة ولن تستطيع الدفع بها بعد ذلك.'
      : 'This saved card will be removed and cannot be used to pay again.';
  static String get cardDeclined => _ar
      ? 'لم يتم قبول البطاقة. تحقق من البيانات أو جرّب بطاقة أخرى.'
      : "Your card wasn't accepted. Check the details or try another card.";
  static String get cardSaveNotAllowed =>
      _ar ? 'سجّل الدخول لحفظ البطاقات.' : 'Sign in to save cards.';

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
  static String get paymentVerificationFailed =>
      _ar ? 'فشل التحقق من الدفع.' : 'Payment verification failed.';
  static String get paymentRetryLater => _ar
      ? 'تعذّر إتمام الدفع. حاول مرة أخرى.'
      : 'Payment failed. Please try again.';

  // ---------- Auth ----------
  static String get signIn => _ar ? 'تسجيل الدخول' : 'Sign In';
  static String get signUp => _ar ? 'إنشاء حساب' : 'Sign Up';
  static String get signInRequired =>
      _ar ? 'يلزم تسجيل الدخول' : 'Sign in required';
  static String get signInOrCreateAccount => _ar
      ? 'يرجى تسجيل الدخول أو إنشاء حساب للمتابعة.'
      : 'Please sign in or create an account to continue.';
  static String get createAccount => _ar ? 'إنشاء حساب' : 'Create Account';
  static String get bundleLoadFailed => _ar
      ? 'تعذر تحميل تفاصيل الباقة. حاول مرة أخرى لاحقًا.'
      : 'Could not load bundle details. Please try again later.';
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
  static String get continueWithFacebook =>
      _ar ? 'المتابعة بحساب فيسبوك' : 'Continue with Facebook';
  static String get continueWithApple =>
      _ar ? 'المتابعة بحساب أبل' : 'Continue with Apple';

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

  /// The sign-in identity is not a profile field: the server moves it only
  /// after the new address confirms.
  static String get emailNotEditableHere => _ar
      ? 'بريدك هو هويّة تسجيل الدخول، ولا يتغيّر من هذه الصفحة'
      : 'Your email is your sign-in identity and cannot be changed here';
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
  static String get signInWithEmailCode =>
      _ar ? 'تسجيل الدخول بكود على البريد' : 'Sign in with an e-mail code';
  static String get emailAuthSubtitle => _ar
      ? 'أدخل بريدك الإلكتروني وسنرسل إليه كود تحقق مكونًا من 6 أرقام.'
      : 'Enter your e-mail address and we will send a 6-digit verification code to it.';
  static String get continueWithEmailCode => _ar
      ? 'المتابعة بكود على البريد الإلكتروني'
      : 'Continue with an e-mail code';
  static String emailOtpSentTo(String email) => _ar
      ? 'أرسلنا كود التحقق إلى $email'
      : 'We sent the verification code to $email';
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
  static String get setDefaultAddress =>
      _ar ? 'تعيين كافتراضي' : 'Set as default';
  static String get editAddress => _ar ? 'تعديل العنوان' : 'Edit address';
  static String get logOut => _ar ? 'تسجيل الخروج' : 'Log Out';
  static String get confirmLogout => _ar ? 'نعم، تسجيل الخروج' : 'Yes, Logout';
  static String get logoutConfirm => _ar
      ? 'هل أنت متأكد من تسجيل الخروج؟'
      : 'Are you sure you want to log out ?';

  /// Shown when the client sign-out itself fails. The customer stays signed in
  /// and the sign-out can be retried.
  static String get logoutFailed => _ar
      ? 'تعذّر تسجيل الخروج. حاول مرة أخرى.'
      : 'Could not sign you out. Please try again.';
  static String get faqTitle =>
      _ar ? 'الأسئلة الشائعة' : 'Frequently asked questions';
  static String get profilePicture =>
      _ar ? 'الصورة الشخصية' : 'Profile Picture';
  static String get fullNameHint => _ar ? 'الاسم الكامل' : 'Full Name';
  static String get firstNameHint => _ar ? 'الاسم الأول' : 'First Name';
  static String get lastNameHint => _ar ? 'الاسم الأخير' : 'Last Name';
  static String get profileUpdateFailed =>
      _ar ? 'فشل تحديث الملف الشخصي' : 'Profile update failed';
  static String get phoneNumberHint => _ar ? 'رقم الهاتف' : 'Phone Number';
  static String get profileUpdated =>
      _ar ? 'تم تحديث الحساب بنجاح' : 'Profile updated successfully';
  static String get changePassword =>
      _ar ? 'تغيير كلمة المرور' : 'Change password';
  static String get currentPasswordHint =>
      _ar ? 'كلمة المرور الحالية' : 'Current password';
  static String get passwordMinLength =>
      _ar ? '٦ أحرف على الأقل' : 'At least 6 characters';
  static String get passwordChanged =>
      _ar ? 'تم تغيير كلمة المرور' : 'Password changed';
  static String get passwordChangeFailed => _ar
      ? 'تعذر تغيير كلمة المرور، تحقق من كلمة المرور الحالية'
      : 'Could not change the password. Check the current one.';
  static String get consumeSubscription =>
      _ar ? 'استهلاك اشتراك' : 'Consume a subscription';
  static String get qrTokenLabel => _ar ? 'رمز QR' : 'QR token';
  static String get productIdLabel => _ar ? 'معرّف المنتج' : 'Product id';
  static String get deduct => _ar ? 'خصم' : 'Deduct';
  static String get invalidQuantity =>
      _ar ? 'أدخل عدد أكواب صحيحًا' : 'Enter a whole number of cups';
  static String cupsRemaining(int remaining) =>
      _ar ? 'الأكواب المتبقية: $remaining' : 'Cups remaining: $remaining';
  static String get chooseFromGallery =>
      _ar ? 'اختر من المعرض' : 'Choose from gallery';
  static String get takePhoto => _ar ? 'التقط صورة' : 'Take a photo';
  static String get imagePickerFailed =>
      _ar ? 'تعذر فتح اختيار الصور' : "Couldn't open the image picker";
  static String get photoUploadFailed => _ar
      ? 'تعذر حفظ الصورة. حاول مرة أخرى.'
      : "Couldn't save the photo. Please try again.";
  static String get photoFormatUnsupported => _ar
      ? 'صيغة الصورة غير مدعومة. اختر صورة بصيغة مدعومة.'
      : 'That image format is not supported. Choose a JPG, PNG or WebP image.';
  static String get photoSaveFailed => _ar
      ? 'تم رفع الصورة لكن تعذر ربطها بالحساب.'
      : 'The photo was uploaded but could not be linked to your account.';
  static String get photoLoadFailed =>
      _ar ? 'تعذر تحميل الصورة' : "Couldn't load the photo";
  static String get photoSignInRequired => _ar
      ? 'سجّل الدخول أولاً لحفظ صورة الملف الشخصي.'
      : 'Sign in first to save a profile photo.';
  static String get language => _ar ? 'اللغة' : 'Language';

  /// The selected language as the tile's own value line. The tile's label
  /// already says "Language", so the value repeats nothing: it is the name of
  /// the language the screen is drawn in.
  static String languageValue(bool arabic) =>
      arabic ? arabicLanguage : englishLanguage;
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
  static String get deleteAddressConfirm =>
      _ar ? 'هل تريد حذف هذا العنوان؟' : 'Do you want to delete this address?';
  static String get addressSaveFailed => _ar
      ? 'تعذر حفظ العنوان. حاول مرة أخرى.'
      : 'Could not save the address. Please try again.';
  static String get addressDeleteFailed => _ar
      ? 'تعذر حذف العنوان. حاول مرة أخرى.'
      : 'Could not delete the address. Please try again.';
  static String get couldNotLoadAddresses =>
      _ar ? 'تعذّر تحميل العناوين' : 'The saved addresses could not be loaded';

  // ---------- Help / FAQ / policy ----------
  static String get couldNotLoadFaqs =>
      _ar ? 'تعذر تحميل الأسئلة.' : 'Could not load the questions.';
  static String get noFaqs => _ar ? 'لا توجد أسئلة متاحة' : 'No FAQs available';
  static String get couldNotLoadPolicy =>
      _ar ? 'تعذر تحميل السياسة.' : 'Could not load the policy.';
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
  static String get turnOnNotifications =>
      _ar ? 'تفعيل الإشعارات' : 'Turn on notifications';
  static String get turnOffNotifications =>
      _ar ? 'إيقاف الإشعارات' : 'Turn off notifications';
  static String get notificationsTurnedOn =>
      _ar ? 'تم تفعيل الإشعارات' : 'Notifications are on';
  static String get notificationsTurnedOff =>
      _ar ? 'تم إيقاف الإشعارات' : 'Notifications are off';
  static String get notificationPermissionDenied => _ar
      ? 'لم يُسمح بالإشعارات. فعّلها من إعدادات الهاتف.'
      : 'Notifications are not allowed. Turn them on in the phone settings.';
  static String get notificationPreferences =>
      _ar ? 'إعدادات الإشعارات' : 'Notification settings';
  static String get notificationPreferencesHint => _ar
      ? 'هذه المفاتيح تحدد ما يصلك فورًا على الهاتف أو في بريدك. قائمة الإشعارات داخل التطبيق تصل كاملة مهما كان اختيارك.'
      : 'These switches decide what reaches your phone or your mailbox at once. The in-app list arrives complete whatever you choose.';
  static String get preferenceEmail =>
      _ar ? 'رسائل البريد الإلكتروني' : 'E-mail messages';
  static String get preferenceEmailHint => _ar
      ? 'تصل إلى البريد المسجّل في حسابك، منفصلة تمامًا عن إشعارات الهاتف'
      : 'They arrive at the address on your account, apart from phone notifications';
  static String get preferenceOrderStatus =>
      _ar ? 'تحديثات الطلبات' : 'Order updates';
  static String get preferenceOrderStatusHint => _ar
      ? 'تغيّر حالة طلب عند الطهي أو التوصيل'
      : 'When an order starts cooking or is out for delivery';
  static String get preferencePromo =>
      _ar ? 'العروض والخصومات' : 'Offers and discounts';
  static String get preferencePromoHint =>
      _ar ? 'حملات المتجر والكوبونات' : 'Store campaigns and coupons';
  static String get preferenceLoyalty => _ar ? 'نقاط الولاء' : 'Loyalty points';
  static String get preferenceLoyaltyHint =>
      _ar ? 'إيداع النقاط والمكافآت' : 'Points earned and rewards';
  static String get preferenceSystem => _ar ? 'رسائل المتجر' : 'Store messages';
  static String get preferenceSystemHint =>
      _ar ? 'إشعارات عامة من المتجر' : 'General messages from the store';
  static String get preferenceNotSaved => _ar
      ? 'لم يُحفظ التغيير. تحقّق من الاتصال وحاول مجددًا.'
      : 'The change was not saved. Check the connection and try again.';

  /// The bell in the app bar offers this when a row still waits.
  static String get notificationMarkAllRead =>
      _ar ? 'تعليم الكل كمقروء' : 'Mark all as read';

  /// Rows the server holds beyond the ones on screen.
  static String get notificationShowMore => _ar ? 'عرض المزيد' : 'Show more';

  static String get notificationDayToday => _ar ? 'اليوم' : 'Today';
  static String get notificationDayYesterday => _ar ? 'أمس' : 'Yesterday';

  /// The list is silent about the phone channel while the customer has never
  /// chosen: the banner asks, it does not accuse.
  static String get notificationPushPausedTitle => _ar
      ? 'الإشعارات متوقفة على هذا الهاتف'
      : 'Notifications are off on this phone';
  static String get notificationPushPausedHint => _ar
      ? 'فعّلها لتصلك تحديثات الطلب والعروض فورًا.'
      : 'Turn them on so order updates and offers reach you right away.';

  /// An order named by a notification that this account never placed.
  static String get orderNotInAccount =>
      _ar ? 'هذا الطلب ليس في حسابك' : 'This order is not in your account';
  static String get orderNotInAccountHint => _ar
      ? 'رقم الطلب لا يوجد بين طلبات هذا الحساب. تحقّق من الحساب أو راجع قائمة طلباتك.'
      : 'That order is not among this account\'s orders. Check the account or open your order list.';

  static String get skip => _ar ? 'تخطي' : 'Skip';

  // ---------- Banners ----------
  static String enjoyReward(String name) =>
      _ar ? 'استمتع بـ $name!' : 'Enjoy your $name!';

  // ---------- Assistant ----------
  static String get askAnything => _ar ? 'اسألني أي شيء؟' : 'Ask me anything?';
  static String get assistantTitle => _ar ? 'مساعد القهوة' : 'Coffee Assistant';
  static String get open => _ar ? 'فتح' : 'Open';

  /// Under an answer that was read from the shop's own documents. Each source
  /// is its own line, so the heading is read once per link by a screen reader.
  static String get assistantSourcesHeading =>
      _ar ? 'المصادر' : 'Sources';

  // ---------- Assistant memory ----------
  static String get assistantMemoryTitle =>
      _ar ? 'ذاكرة المساعد' : 'Assistant memory';
  static String get assistantMemorySubtitle => _ar
      ? 'يتذكّر المساعد ما أخبرته به عن نفسك، داخل حسابك وحدك.'
      : 'The assistant keeps what you tell it about yourself, in your account only.';
  static String get assistantMemoryEnable =>
      _ar ? 'السماح بتذكّر محادثاتي' : 'Let the assistant remember me';
  static String get assistantMemoryEmpty => _ar
      ? 'لا شيء محفوظة بعد.' : 'Nothing has been remembered yet.';

  /// A device that is not signed in has no island to open, which is a different
  /// fact from an empty one.
  static String get assistantMemorySignedOut => _ar
      ? 'الذاكرة مرتبطة بحسابك. سجّل الدخول لتراها.'
      : 'Memory belongs to your account. Sign in to see it.';
  static String get assistantMemoryPrivate =>
      _ar ? 'معلومة خاصة (مشفّرة)' : 'Private detail (encrypted)';

  /// How the assistant reads a memory it kept: a stated fact is not a
  /// preference, and neither of them is a guess it made.
  static String assistantMemoryKind(String kind) => switch (kind) {
    'fact' => _ar ? 'حقيقة' : 'Fact',
    'preference' => _ar ? 'تفضيل' : 'Preference',
    'opinion' => _ar ? 'رأي' : 'Opinion',
    _ => _ar ? 'تخمين' : 'Guess',
  };

  static String get assistantMemoryDelete =>
      _ar ? 'حذف' : 'Delete';
  static String get assistantMemoryDeleteAll =>
      _ar ? 'حذف كل ذاكرتي' : 'Delete all my memory';
  static String get assistantMemoryDeletedAll => _ar
      ? 'تم حذف كل ما كان المساعد يعرفه عنك.'
      : 'Everything the assistant knew about you has been deleted.';
  static String get assistantMemoryOffWarning => _ar
      ? 'إيقاف الذاكرة يحذف كل ما حفظه المساعد عنك. لا يمكن التراجع.'
      : 'Turning memory off deletes everything the assistant kept about you. This cannot be undone.';

  /// Letting the assistant read outside the shop. Separate from memory: a
  /// customer may want the bot to remember them and still not want it browsing.
  static String get assistantWebSearchEnable =>
      _ar ? 'السماح بالبحث في الإنترنت' : 'Let the assistant search the web';
  static String get assistantWebSearchNote => _ar
      ? 'يقرأ المساعد صفحات الإنترنت عند الحاجة ويذكر روابطها مع الرد. ما يقرأه لا يُستخدم لتدريبه.'
      : 'The assistant reads web pages when it needs to and lists them with the answer. What it reads is never used to train it.';

  // ---------- Assistant conversations ----------
  /// The drawer of chats the customer already had. Each row is the question
  /// they opened it with, in their own words.
  static String get assistantNewChat => _ar ? 'محادثة جديدة' : 'New chat';
  static String get assistantChatsHeading =>
      _ar ? 'محادثاتك السابقة' : 'Your previous chats';
  static String get assistantChatsTooltip =>
      _ar ? 'المحادثات' : 'Conversations';
  static String get assistantChatDelete =>
      _ar ? 'حذف المحادثة' : 'Delete this conversation';
  static String get assistantChatDeleted =>
      _ar ? 'تم حذف المحادثة.' : 'Conversation deleted.';
  static String get assistantEmptyHistory => _ar
      ? 'لسه في محادثة واحدة مفتوحة. اللي قبلها هيظهروا هنا.'
      : 'Nothing here yet. Chats you have already had will be listed here.';

  // ---------- Branch ----------
  static String get chooseBranch => _ar ? 'اختر الفرع' : 'Choose branch';

  // ---------- Onboarding ----------
  static String get noSlides =>
      _ar ? 'لا توجد شرائح تعريفية' : 'No onboarding slides';

  /// The three intro slides the first launch shows.
  static String get onBoardingCatalogTitle =>
      _ar ? 'كل ما تحب في مكان واحد' : 'Everything You Love, in One Place';
  static String get onBoardingCatalogBody => _ar
      ? 'اكتشف القهوة والمشروبات ومنتجاتك المفضلة بسهولة.'
      : 'Explore coffee, drinks, and your favorite products with ease.';
  static String get onBoardingPaymentTitle =>
      _ar ? 'ادفع بالطريقة التي تناسبك' : 'Pay Your Way';
  static String get onBoardingPaymentBody => _ar
      ? 'استمتع بتجربة دفع سهلة وآمنة لإكمال طلبك بكل راحة.'
      : 'Enjoy a smooth and secure payment experience every time you order.';
  static String get onBoardingAssistantTitle =>
      _ar ? 'مساعدك الذكي معك دائمًا' : 'Meet Your AI Assistant';
  static String get onBoardingAssistantBody => _ar
      ? 'احصل على اقتراحات ذكية واكتشف ما يناسب ذوقك بسهولة.'
      : 'Get smart recommendations and discover what matches your taste.';

  // ---------- Auth screens ----------
  static String get welcomeBackSubtitle =>
      _ar ? 'أهلًا بعودتك، كنا ننتظرك' : "Hi welcome back, you've been missed";
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
  static String get authStaffAccount => _ar
      ? 'هذا الحساب خاص بالموظفين. برجاء تسجيل الدخول من تطبيق الإدارة.'
      : 'This is a staff account. Please sign in from the admin app.';
  static String get authUserDisabled => _ar
      ? 'هذا الحساب معطّل، برجاء التواصل مع الدعم'
      : 'This account is disabled. Please contact support.';
  static String get authEmailInUse => _ar
      ? 'هذا الإيميل مسجل بالفعل، برجاء تسجيل الدخول أو استخدام إيميل آخر'
      : 'This email is already registered. Sign in or use another email.';
  static String get authWeakPassword => _ar
      ? 'كلمة المرور ضعيفة، برجاء استخدام كلمة مرور أطول وأكثر أمانًا'
      : 'Password is too weak. Please use a longer, stronger password.';
  static String get authInvalidEmail => _ar
      ? 'إيميل غير صحيح، برجاء إدخال إيميل صحيح'
      : 'Enter a valid email address.';
  static String get authFailed => _ar
      ? 'حدث خطأ أثناء الدخول. حاول مرة أخرى.'
      : 'Something went wrong signing in. Please try again.';
  static String get authUnexpected => _ar
      ? 'حدث خطأ غير متوقع، برجاء المحاولة مرة أخرى.'
      : 'Something unexpected happened. Please try again.';

  /// Shown when Google Sign-In was refused because the OAuth client that
  /// matches this build's signing certificate is missing or misconfigured.
  static String get authGoogleUnavailable => _ar
      ? 'تعذّر تسجيل الدخول بحساب جوجل. برجاء المحاولة مرة أخرى.'
      : 'Google sign-in could not be completed. Please try again.';

  /// Shown when the service itself has no such sign-in method switched on, so
  /// the customer knows to use the door that is open rather than retrying.
  static String get authProviderNotEnabled => _ar
      ? 'هذه الطريقة لتسجيل الدخول غير مفعّلة حالياً. استخدم البريد الإلكتروني وكلمة المرور.'
      : 'This sign-in method is not available yet. Use your email and password instead.';

  /// Shown when Google on the device refused the account — a certificate or
  /// client Google does not accept, or the account is signed out of the
  /// Google app. Distinct from [authGoogleUnavailable] because the customer
  /// cannot fix it by tapping again.
  static String get authGoogleRefused => _ar
      ? 'رفض جوجل هذا الحساب على الجهاز، ولم يتم التحقق منه. '
            'تأكد من أنك مسجّل الدخول في تطبيق جوجل، أو ادخل بالبريد الإلكتروني وكلمة المرور.'
      : 'Google could not verify this account on your device. '
            'Check that you are signed in to the Google app, or sign in with your email and password.';

  /// Shown when the phone holds no Google account at all, so the button can
  /// never work there — retrying is not the answer, adding an account is.
  static String get authGoogleNoAccount => _ar
      ? 'لا يوجد حساب جوجل مسجّل الدخول على هذا الجهاز. أضِف حسابًا من إعدادات جوجل، أو ادخل بالبريد الإلكتروني وكلمة المرور.'
      : 'There is no Google account signed in on this device. Add one in your Google settings, or sign in with your email and password.';

  /// Shown when the six-digit code no longer works: it went stale, or another
  /// code replaced it. Typing the same digits again cannot help, so the answer
  /// points at the button that can.
  static String get authOtpInvalid => _ar
      ? 'انتهت صلاحية هذا الكود أو كان غير صحيح. اطلب كودًا جديدًا.'
      : 'This code has expired or is not correct. Request a new one.';

  /// Shown when the message itself could not leave the backend — the provider
  /// refused, or its key is missing. The customer did nothing wrong and the
  /// number is not blocked, so the other door is named.
  static String get authSmsSendFailed => _ar
      ? 'تعذّر إرسال رسالة التحقق. حاول مرة أخرى بعد قليل '
            'أو سجّل الدخول بالبريد الإلكتروني وكلمة المرور.'
      : 'The verification message could not be sent. Try again in a moment, '
            'or sign in with your email and password.';

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

  /// Shown when the reset screen is asked for a new password before the emailed
  /// link has ever been opened. The link, not this screen, authorises the
  /// change, so the customer needs to know which of the two they are missing.
  static String get authRecoveryLinkRequired => _ar
      ? 'افتح رابط إعادة التعيين الذي وصلك في بريدك أولاً، ثم أدخل كلمة المرور '
            'الجديدة. لا يمكن لهذه الشاشة تغيير كلمة المرور بدون الرابط.'
      : 'Open the reset link from your email first, then set the new password. '
            'This screen cannot change a password without that link.';

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
    'code not valid' =>
      _ar ? 'كود الخصم غير صحيح' : 'That coupon code is not valid',
    'code expired' =>
      _ar ? 'انتهت صلاحية هذا الكود' : 'This coupon has expired',
    'minimum order not reached' =>
      _ar
          ? 'الطلب لم يصل للحد الأدنى المطلوب للكود'
          : 'Your order is below this coupon\'s minimum',
    'code fully used' =>
      _ar ? 'تم استنفاد هذا الكود' : 'This coupon has been fully claimed',
    'you already used this code' =>
      _ar
          ? 'استخدمت هذا الكود بالحد المسموح لك'
          : 'You have already used this coupon the allowed number of times',
    'code does not apply to your items' =>
      _ar
          ? 'هذا الكود لا ينطبق على المنتجات في سلتك'
          : 'This coupon does not apply to the items in your cart',
    _ => _ar ? 'كود الخصم غير صالح' : 'Invalid coupon code',
  };

  static String couponUsesLeft(int count) => _ar
      ? 'متبقي $count استخدام'
      : count == 1
      ? '1 use left'
      : '$count uses left';
  static String get couponNoUsesLeft =>
      _ar ? 'استخدمت هذا الكود بالحد المسموح' : 'You have used up this coupon';
  static String get couponAppliedBadge =>
      _ar ? 'مطبّق على طلبك' : 'Applied to your order';

  // ---------- Menu / product ----------
  static String get readMore => _ar ? 'اقرأ المزيد' : 'Read more';
  static String get readLess => _ar ? 'اقرأ أقل' : 'Read less';
  static String get productUnavailable =>
      _ar ? 'المنتج غير متاح' : 'Product unavailable';
  static String get productNoLongerAvailable =>
      _ar ? 'هذا المنتج لم يعد متاحًا' : 'This product is no longer available';

  // ---------- Orders ----------
  static String quantityLabel(int quantity) =>
      _ar ? 'الكمية: $quantity' : 'Qty: $quantity';
  static String get liveStatusFailed =>
      _ar ? 'تعذّر جلب حالة الطلب مباشرة' : 'Could not load live status';
  static String get removedProduct => _ar ? 'منتج محذوف' : 'Removed product';
  static String get addNewShippingAddress =>
      _ar ? '+ إضافة عنوان توصيل جديد' : '+ Add new shipping address';

  // ---------- Checkout ----------
  static String get selectBranchBeforePaying =>
      _ar ? 'اختر الفرع قبل الدفع.' : 'Select a branch before paying.';
  static String loyaltyPointsEarned(int points) => _ar
      ? 'لقد كسبت $points نقطة ولاء!'
      : 'You earned $points loyalty points!';

  // ---------- Loyalty ----------
  static String get selectBranchBeforeRedeeming => _ar
      ? 'اختر الفرع قبل استبدال هذه المكافأة.'
      : 'Select a branch before redeeming this reward.';
  static String get rewardRequiresAccount => _ar
      ? 'سجّل الدخول لاستبدال مكافآت الباقات والاشتراكات.'
      : 'Sign in to redeem bundle and subscription rewards.';
  static String rewardSubscriptionActivated(String name) =>
      _ar ? 'تم تفعيل اشتراك $name!' : 'Your $name subscription is active!';
  static String rewardOrderCreated(String name) => _ar
      ? 'تم إنشاء طلب مجاني لـ $name. تجده في طلباتك للاستلام من الفرع.'
      : 'A free order for $name was created. Find it in your orders for pickup at the branch.';
  static String get orderPurchaseLabel => _ar ? 'شراء طلب' : 'Order purchase';
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

  /// The wallet was re-read and failed: the points on screen may be old.
  static String get couldNotRefreshWallet => _ar
      ? 'تعذر تحديث رصيدك. قد تكون النقاط المعروضة قديمة.'
      : 'Your wallet could not be refreshed. These points may be out of date.';

  /// A reward the server refused. Saying "not enough points" here would blame
  /// the customer for a failure that was on the network.
  static String get couldNotRedeemReward => _ar
      ? 'تعذر استبدال المكافأة. لم تُخصم نقاطك.'
      : 'The reward could not be redeemed. Your points were not spent.';

  /// The account tier, in the language the customer reads the app in.
  ///
  /// `user_points.tier` holds the column's own word; showing it raw printed
  /// `bronze` in an Arabic screen.
  static String tierLabel(String tier) => switch (tier) {
    'bronze' => _ar ? 'برونز' : 'Bronze',
    'silver' => _ar ? 'فضي' : 'Silver',
    'gold' => _ar ? 'ذهبي' : 'Gold',
    'platinum' => _ar ? 'بلاتيني' : 'Platinum',
    _ => tier,
  };

  // ---------- Subscriptions ----------
  static String get subscriptionPlans =>
      _ar ? 'باقات اشتراك القهوة' : 'Coffee subscription plans';
  static String get mySubscription => _ar ? 'اشتراكي' : 'My subscription';
  static String get noPlansAvailable =>
      _ar ? 'لا توجد باقات متاحة حالياً' : 'No plans available';
  static String get noSubscriptionYet =>
      _ar ? 'لا يوجد اشتراك حالياً' : 'No subscription yet';
  static String get browsePlans => _ar ? 'تصفح الباقات' : 'Browse plans';
  static String get planDetails => _ar ? 'تفاصيل الباقة' : 'Plan details';
  static String get planLabel => _ar ? 'الباقة' : 'Plan';
  static String get subscribeNow => _ar ? 'اشترك الآن' : 'Subscribe now';
  static String get renew => _ar ? 'تجديد' : 'Renew';
  static String get subscriptionStatus => _ar ? 'الحالة' : 'Status';
  static String get subscriptionPendingPayment =>
      _ar ? 'بانتظار تأكيد الدفع' : 'Pending payment';
  static String get subscriptionActive => _ar ? 'فعال' : 'Active';
  static String get subscriptionExpired => _ar ? 'منتهي' : 'Expired';
  static String get subscriptionCancelled => _ar ? 'ملغي' : 'Cancelled';
  static String get subscriptionStart => _ar ? 'البداية' : 'Start';
  static String get subscriptionEnd => _ar ? 'الانتهاء' : 'End';
  static String get availableCups => _ar ? 'الأكواب المتاحة' : 'Available cups';
  static String get cupsUsed => _ar ? 'المستخدم' : 'Used';
  static String get cupsCarriedOver => _ar ? 'المرحل' : 'Carried over';
  static String get extraCredit => _ar ? 'الرصيد الإضافي' : 'Extra credit';
  static String get creditExpires => _ar ? 'انتهاء الرصيد' : 'Credit expires';
  static String get autoRenew => _ar ? 'تجديد تلقائي' : 'Auto renew';
  static String get checkPaymentStatus =>
      _ar ? 'التحقق من حالة الدفع' : 'Check payment status';
  static String get showQrCode => _ar ? 'عرض رمز QR' : 'Show QR code';
  static String get qrSingleUseHint => _ar
      ? 'رمز QR (صالح 5 دقائق، لمرة واحدة):'
      : 'QR code (valid 5 minutes, single use):';
  static String get usageHistory => _ar ? 'سجل الاستخدام' : 'Usage history';
  static String get noUsageYet => _ar ? 'لا توجد عمليات' : 'No usage yet';
  static String get cupUnit => _ar ? 'كوب' : 'cup';
  static String get cupsLabel => _ar ? 'الأكواب' : 'Cups';
  static String get priceLabel => _ar ? 'السعر' : 'Price';
  static String get durationLabel => _ar ? 'المدة' : 'Duration';
  static String get cupsPerCycle =>
      _ar ? 'الأكواب في كل دورة' : 'Cups per cycle';
  static String get rolloverCap => _ar ? 'حد ترحيل الأكواب' : 'Rollover cap';
  static String get renewalLabel => _ar ? 'التجديد' : 'Renewal';
  static String get renewalAutomatic => _ar ? 'تلقائي' : 'Automatic';
  static String get renewalManual => _ar ? 'يدوي' : 'Manual';
  static String get branchLabel => _ar ? 'الفرع' : 'Branch';
  static String get allBranches => _ar ? 'جميع الفروع' : 'All branches';
  static String get selectedBranches =>
      _ar ? 'فروع محددة' : 'Selected branches';
  static String get productsLabel => _ar ? 'المنتجات' : 'Products';
  static String get allProducts => _ar ? 'جميع المنتجات' : 'All products';
  static String get selectedProducts =>
      _ar ? 'منتجات محددة' : 'Selected products';
  static String get includedProducts =>
      _ar ? 'المنتجات المشمولة' : 'Included products';

  static String get couldNotLoadSubscription =>
      _ar ? 'تعذر تحميل الاشتراك.' : 'Could not load the subscription.';
  static String get couldNotLoadPlans =>
      _ar ? 'تعذر تحميل الباقات.' : 'Could not load the plans.';
  static String get couldNotLoadUsage =>
      _ar ? 'تعذر تحميل سجل الاستخدام.' : 'Could not load the usage history.';
  static String get couldNotLoadPlanProducts => _ar
      ? 'تعذر تحميل منتجات الباقة.'
      : 'Could not load the products of this plan.';

  static String get couldNotStartSubscription => _ar
      ? 'تعذر بدء الاشتراك. حاول مرة أخرى.'
      : 'Could not start the subscription. Try again.';
  static String get couldNotRenewSubscription => _ar
      ? 'تعذر تجديد الاشتراك. حاول مرة أخرى.'
      : 'Could not renew the subscription. Try again.';
  static String get couldNotCancelSubscription => _ar
      ? 'تعذر إلغاء الاشتراك. حاول مرة أخرى.'
      : 'Could not cancel the subscription. Try again.';

  static String get couldNotDeductCups => _ar
      ? 'تعذر خصم الكوب. حاول مرة أخرى.'
      : 'Could not deduct the cup. Try again.';

  /// The subscription page could be re-read, so what is on screen may be old.
  ///
  /// The rows stay visible under this line: they are the customer's own facts,
  /// and a failed refresh is not a reason to throw away a cup balance.
  static String get subscriptionOutdated => _ar
      ? 'تعذر تحديث الاشتراك. قد تكون البيانات المعروضة قديمة.'
      : 'The subscription could not be refreshed. These details may be out of date.';

  static String get couldNotShowQr => _ar
      ? 'تعذر إنشاء رمز QR. حاول مرة أخرى.'
      : 'Could not create the QR code. Try again.';

  static String get couldNotSaveAutoRenew => _ar
      ? 'تعذر حفظ خيار التجديد التلقائي.'
      : 'Could not save the auto-renew choice.';

  /// A renewal was created but no payment was opened for it.
  ///
  /// The app only knows the price from the plan list, so a renewal whose plan
  /// is not in that list cannot be charged honestly and has to say so.
  static String get couldNotPriceRenewal => _ar
      ? 'تعذر معرفة سعر التجديد. حاول مرة أخرى.'
      : 'The renewal price could not be read. Try again.';

  /// How a cup left the subscription.
  ///
  /// The history table stores `'qr'` and `'cashier'`; the customer reads the
  /// counter, not the column value.
  static String get usageByQr => _ar ? 'برمز QR' : 'With a QR code';
  static String get usageByCashier => _ar ? 'من الموظف' : 'At the counter';
  static String get usageUnknownMethod => _ar ? 'عملية' : 'Redemption';

  static String cupsCount(int count) =>
      _ar ? '$count كوب' : '$count ${count == 1 ? 'cup' : 'cups'}';

  static String daysCount(int days) => _ar ? '$days يوم' : '$days days';

  // ---------- Shared widgets ----------
  static String get showPassword => _ar ? 'إظهار كلمة المرور' : 'Show password';
  static String get hidePassword => _ar ? 'إخفاء كلمة المرور' : 'Hide password';
  static String get saudiRiyal => _ar ? 'ريال سعودي' : 'Saudi Riyal';
  static String get bundleLabel => _ar ? 'باقة' : 'Bundle';
  static String get subscriptionLabel => _ar ? 'اشتراك' : 'Subscription';

  /// A build with no backend configured still has to explain itself in the
  /// language the customer is reading the app in.
  static String get configMissing => _ar
      ? 'إعدادات الخدمة غير مكتملة. راجع ضبط التطبيق.'
      : 'Service configuration is missing. Check the app configuration.';
}
