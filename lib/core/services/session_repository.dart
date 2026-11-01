import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';

/// Persists which onboarding/auth step the user reached, so the app can
/// resume on the right screen after a restart. Single place for the
/// `routes` key — widgets never touch SharedPreferences for this.
class SessionRepository {
  const SessionRepository();

  Future<String?> currentRoute() =>
      SharedPref.getValue(key: AppConstant.routesKey);

  /// Whether the customer has already been through the onboarding.
  ///
  /// Kept as its own flag instead of being derived from the `routes` value,
  /// so a corrupted or missing route value can never send a returning
  /// customer back to the welcome/onboarding screens.
  Future<bool> hasCompletedOnboarding() async =>
      await SharedPref.getValue(key: AppConstant.onBoardingDoneKey) == 'true';

  /// The customer left the welcome screen and is about to see the onboarding.
  ///
  /// Confirmed, because the whole point of the marker is to survive a restart:
  /// an unconfirmed write would meet them with the welcome screen again.
  Future<bool> markOnboardingSeenConfirmed() =>
      _saveRouteConfirmed(AppConstant.onBoardingRoute);

  /// The customer holds an authenticated session and belongs in the store.
  ///
  /// Both writes are confirmed, because both decide what the *next* launch
  /// looks like: the route key picks the screen, and the onboarding flag picks
  /// whether a returning customer is walked through it again. An unconfirmed
  /// write would meet them with the onboarding after a sign-in.
  Future<bool> markAuthenticatedConfirmed() async {
    if (!await _saveRouteConfirmed(AppConstant.homeRoute)) return false;
    return _markOnboardingDoneConfirmed();
  }

  /// The customer left the onboarding and is about to be asked for credentials.
  Future<bool> markOnboardingSkippedConfirmed() async {
    if (!await _saveRouteConfirmed(AppConstant.authRoute)) return false;
    return _markOnboardingDoneConfirmed();
  }

  /// The customer signed out, so the next start asks for credentials again.
  Future<bool> markSignedOutConfirmed() =>
      _saveRouteConfirmed(AppConstant.authRoute);

  Future<bool> _saveRouteConfirmed(String route) =>
      SharedPref.setValueConfirmed(key: AppConstant.routesKey, value: route);

  Future<bool> _markOnboardingDoneConfirmed() => SharedPref.setValueConfirmed(
    key: AppConstant.onBoardingDoneKey,
    value: 'true',
  );
}
