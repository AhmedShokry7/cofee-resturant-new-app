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

  Future<void> markOnboardingSeen() => SharedPref.setValue(
    key: AppConstant.routesKey,
    value: AppConstant.onBoardingRoute,
  );

  Future<void> markAuthenticated() async {
    await SharedPref.setValue(
      key: AppConstant.routesKey,
      value: AppConstant.homeRoute,
    );
    await _markOnboardingDone();
  }

  /// Skipped onboarding: user has seen it but is not signed in yet.
  Future<void> markOnboardingSkipped() async {
    await SharedPref.setValue(
      key: AppConstant.routesKey,
      value: AppConstant.authRoute,
    );
    await _markOnboardingDone();
  }

  /// The onboarding marker is written with confirmation, because the whole
  /// point of the flag is to survive a restart: an unconfirmed write would
  /// send the customer back to the onboarding on the next launch.
  Future<bool> markOnboardingSkippedConfirmed() async {
    final written = await SharedPref.setValueConfirmed(
      key: AppConstant.routesKey,
      value: AppConstant.authRoute,
    );
    if (!written) return false;
    await _markOnboardingDone();
    return true;
  }

  Future<void> clear() async {
    await SharedPref.setValue(
      key: AppConstant.routesKey,
      value: AppConstant.authRoute,
    );
  }

  Future<void> _markOnboardingDone() => SharedPref.setValue(
    key: AppConstant.onBoardingDoneKey,
    value: 'true',
  );
}
