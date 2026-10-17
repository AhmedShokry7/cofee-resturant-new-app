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

  static String get appName => _ar ? 'نيو كوفي' : 'New Coffee';

  // ---------- Common ----------
  static String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
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

  // ---------- Coupons ----------
  static String get coupon => _ar ? 'الكوبون' : 'Coupon';
  static String get copyCode => _ar ? 'نسخ الكود' : 'Copy Code';
  static String get noCoupons =>
      _ar ? 'لا توجد كوبونات حاليًا' : 'No coupons right now';
  static String couponsLoadError(String error) =>
      _ar ? 'تعذر تحميل الكوبونات: $error' : 'Could not load coupons: $error';
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
      _ar ? 'اسم الحامل مطلوب' : 'Card holder name is required';
  static String get validCardNumber =>
      _ar ? 'أدخل رقم بطاقة صحيحًا' : 'Enter a valid card number';
  static String get invalidDate => _ar ? 'تاريخ غير صالح' : 'Invalid date';
  static String get cardBrandFallback => _ar ? 'بطاقة' : 'CARD';
  static String get cardHolderName =>
      _ar ? 'اسم حامل البطاقة' : 'Card Holder Name';
  static String get cardNumber => _ar ? 'رقم البطاقة' : 'Card Number';

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
  static String get phoneNumberHint => _ar ? 'رقم الهاتف' : 'Phone Number';
  static String get profileUpdated =>
      _ar ? 'تم تحديث الحساب بنجاح' : 'Profile updated successfully';
  static String get chooseFromGallery =>
      _ar ? 'اختر من المعرض' : 'Choose from gallery';
  static String get takePhoto => _ar ? 'التقط صورة' : 'Take a photo';
  static String get imagePickerFailed =>
      _ar ? 'تعذر فتح اختيار الصور' : "Couldn't open the image picker";
  static String get language => _ar ? 'اللغة' : 'Language';
  static String languageValue(bool arabic) =>
      arabic ? 'اللغة: العربية' : 'Language: English';

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
}
