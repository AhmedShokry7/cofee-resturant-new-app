/// Keys for the small settings the app persists on the device itself, plus the
/// defaults it assumes when the backend has nothing to say.
class AppConstant {
  static const String routesKey = "routes";
  static const String onBoardingRoute = "2";
  static const String authRoute = "3";
  static const String homeRoute = "4";

  /// Separate flag for "the onboarding was finished", independent of [routesKey].
  ///
  /// [routesKey] also encodes the sign-in state, so it can be rewritten by a
  /// logout. Keeping the onboarding marker on its own means a returning
  /// customer is never pushed back to the welcome screen because of it.
  static const String onBoardingDoneKey = "onboarding_done";

  /// The currency shown before the brand row has been read.
  ///
  /// Every price on this app is riyal-denominated until `brand.currency_code`
  /// answers, so an unanswered read must not print an empty code.
  static const String defaultCurrencyCode = 'SAR';
}
