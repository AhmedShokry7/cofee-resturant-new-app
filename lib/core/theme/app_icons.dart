import 'package:hugeicons/hugeicons.dart';

/// The app's icon index: every glyph is named here once, and `hugeicons` is
/// imported nowhere else.
///
/// All entries are the `strokeRounded` set, so one drawing weight runs through
/// the whole app. A page asks for `AppIcons.coffee` - never for
/// `HugeIcons.strokeRounded...` - and adds a glyph here when it needs one that
/// is not listed yet.
///
/// The package ships stroke glyphs only, so a state that Material used to show
/// as a filled shape (an active star, a saved favourite) is carried by colour
/// instead of by a second outline.
abstract final class AppIcons {
  // Navigation
  static const home = HugeIcons.strokeRoundedHome01;
  static const back = HugeIcons.strokeRoundedArrowLeft01;
  static const forward = HugeIcons.strokeRoundedArrowRight01;
  static const arrowUp = HugeIcons.strokeRoundedArrowUp01;
  static const arrowDown = HugeIcons.strokeRoundedArrowDown01;
  static const menu = HugeIcons.strokeRoundedMenu01;
  static const grid = HugeIcons.strokeRoundedGridView;
  static const filter = HugeIcons.strokeRoundedFilterHorizontal;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const reload = HugeIcons.strokeRoundedReload;
  static const externalLink = HugeIcons.strokeRoundedLink01;

  // Commerce
  static const cart = HugeIcons.strokeRoundedShoppingCart01;
  static const bag = HugeIcons.strokeRoundedShoppingBag01;
  static const package = HugeIcons.strokeRoundedPackage;
  static const coupon = HugeIcons.strokeRoundedCoupon01;
  static const discount = HugeIcons.strokeRoundedDiscount01;
  static const discountTag = HugeIcons.strokeRoundedDiscountTag01;
  static const percent = HugeIcons.strokeRoundedPercent;
  static const receipt = HugeIcons.strokeRoundedReceiptDollar;
  static const sent = HugeIcons.strokeRoundedSent;

  // Products
  static const coffee = HugeIcons.strokeRoundedCoffee02;
  static const coffeeHot = HugeIcons.strokeRoundedCoffee01;
  static const coffeeIced = HugeIcons.strokeRoundedBubbleTea01;
  static const tea = HugeIcons.strokeRoundedTea;
  static const softDrink = HugeIcons.strokeRoundedSodaCan;
  static const milkshake = HugeIcons.strokeRoundedMilkBottle;
  static const dessert = HugeIcons.strokeRoundedIceCream01;
  static const snack = HugeIcons.strokeRoundedCookie;
  static const bakery = HugeIcons.strokeRoundedCroissant;
  static const donut = HugeIcons.strokeRoundedCupcake01;
  static const bundle = HugeIcons.strokeRoundedPackage02;
  static const gift = HugeIcons.strokeRoundedGift;
  static const sparkles = HugeIcons.strokeRoundedSparkles;
  /// The assistant's own memory of one customer - what it was told, and what
  /// it may take back.
  static const memory = HugeIcons.strokeRoundedBrain;

  // Delivery and place
  static const deliveryTruck = HugeIcons.strokeRoundedTruckDelivery;
  static const location = HugeIcons.strokeRoundedLocation01;
  static const store = HugeIcons.strokeRoundedStore01;
  static const branch = HugeIcons.strokeRoundedRestaurant01;

  // Account
  static const user = HugeIcons.strokeRoundedUser;
  static const profile = HugeIcons.strokeRoundedUserCircle;
  static const mail = HugeIcons.strokeRoundedMail01;
  static const password = HugeIcons.strokeRoundedCirclePassword;
  static const settings = HugeIcons.strokeRoundedSettings01;
  static const logout = HugeIcons.strokeRoundedLogout01;
  static const darkMode = HugeIcons.strokeRoundedMoon02;
  static const language = HugeIcons.strokeRoundedLanguageCircle;
  static const notification = HugeIcons.strokeRoundedNotification01;
  static const notificationOff = HugeIcons.strokeRoundedNotificationBlock01;
  static const favourite = HugeIcons.strokeRoundedFavourite;
  static const star = HugeIcons.strokeRoundedStar;
  static const starOff = HugeIcons.strokeRoundedStarOff;
  static const thumbsUp = HugeIcons.strokeRoundedThumbsUp;
  static const thumbsDown = HugeIcons.strokeRoundedThumbsDown;

  // Money and cards
  static const creditCard = HugeIcons.strokeRoundedCreditCard;
  static const cardNotAccepted = HugeIcons.strokeRoundedCreditCardNotAccept;
  static const wallet = HugeIcons.strokeRoundedWallet01;

  // Brands - the same mark serves a social sign-in button and a pay row
  static const apple = HugeIcons.strokeRoundedApple;
  static const google = HugeIcons.strokeRoundedGoogle;
  static const facebook = HugeIcons.strokeRoundedFacebook01;

  // Editing
  static const add = HugeIcons.strokeRoundedAdd01;
  static const remove = HugeIcons.strokeRoundedRemove01;
  static const minus = HugeIcons.strokeRoundedMinusSign;
  static const edit = HugeIcons.strokeRoundedPencilEdit02;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const camera = HugeIcons.strokeRoundedCamera01;
  static const image = HugeIcons.strokeRoundedImage01;
  static const imageMissing = HugeIcons.strokeRoundedImageNotFound01;
  static const radioButton = HugeIcons.strokeRoundedRadioButton;

  // Status
  static const checkmark = HugeIcons.strokeRoundedTick02;
  static const checkmarkCircle = HugeIcons.strokeRoundedCheckmarkCircle01;
  static const alert = HugeIcons.strokeRoundedAlert02;
  static const alertCircle = HugeIcons.strokeRoundedAlertCircle;
  static const information = HugeIcons.strokeRoundedInformationCircle;
  static const help = HugeIcons.strokeRoundedHelpCircle;
  static const shield = HugeIcons.strokeRoundedShieldKey;
  static const offline = HugeIcons.strokeRoundedNoInternet;
  static const hot = HugeIcons.strokeRoundedFire;
  static const calendar = HugeIcons.strokeRoundedCalendar03;
  static const smartphone = HugeIcons.strokeRoundedSmartPhone01;

  // Reveal
  static const view = HugeIcons.strokeRoundedView;
  static const viewOff = HugeIcons.strokeRoundedViewOff;
}
