import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';

/// Persists which onboarding/auth step the user reached, so the app can
/// resume on the right screen after a restart. Single place for the
/// `routes` key — widgets never touch SharedPreferences for this.
class SessionRepository {
  const SessionRepository();

  Future<String?> currentRoute() =>
      SharedPref.getValue(key: AppConstant.routesKey);

  Future<void> markOnboardingSeen() => SharedPref.setValue(
    key: AppConstant.routesKey,
    value: AppConstant.onBoardingRoute,
  );

  Future<void> markAuthenticated() => SharedPref.setValue(
    key: AppConstant.routesKey,
    value: AppConstant.homeRoute,
  );

  /// Skipped onboarding: user has seen it but is not signed in yet.
  Future<void> markOnboardingSkipped() => SharedPref.setValue(
    key: AppConstant.routesKey,
    value: AppConstant.authRoute,
  );

  Future<void> clear() => SharedPref.setValue(
    key: AppConstant.routesKey,
    value: AppConstant.authRoute,
  );
}
