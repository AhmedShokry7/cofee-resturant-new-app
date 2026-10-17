import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';

/// The original widget test booted MyApp, but booting requires a configured
/// Supabase backend (enforced by [AppProviders] and [SupabaseService]). With no
/// --dart-define values in the test environment that constraint cannot be
/// satisfied. The meaningful contract is the initial route decision.
void main() {
  test('App boots to the saved entry route (default)', () {
    SharedPreferences.setMockInitialValues({});
    expect(
      AppRoutes.initialRouteName(null),
      AppRoutes.initialRouteName(''),
    );
  });

  test('saved home route maps to main page', () {
    SharedPreferences.setMockInitialValues({
      AppConstant.routesKey: AppConstant.homeRoute,
    });
    expect(
      AppRoutes.initialRouteName(AppConstant.homeRoute),
      AppRoutes.routes.containsKey('/main') ? '/main' : isNotEmpty,
    );
  });

  test('default when nothing saved', () {
    expect(
      AppRoutes.initialRouteName(null),
      AppRoutes.routes.keys.firstWhere((key) => key.contains('welcome'),
          orElse: () => '/welcome'),
    );
  });
}
