import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/theme_mode_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeModeCubit.applyRoles(isDark: false);
  });

  test(
    'a preview mode switch repaints the app without saving a preference',
    () async {
      final cubit = ThemeModeCubit();
      addTearDown(cubit.close);
      addTearDown(() => ThemeModeCubit.applyRoles(isDark: false));

      cubit.setPreviewMode(ThemeMode.dark);

      expect(cubit.state, ThemeMode.dark);
      expect(AppColor.isDarkMode, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('theme_mode'), isNull);
    },
  );

  test(
    'an explicit initial mode starts the preview there without a read',
    () async {
      final cubit = ThemeModeCubit(initialMode: ThemeMode.dark);
      addTearDown(cubit.close);
      addTearDown(() => ThemeModeCubit.applyRoles(isDark: false));

      expect(cubit.state, ThemeMode.dark);
      expect(AppColor.isDarkMode, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('theme_mode'), isNull);
    },
  );

  test('the ordinary toggle still persists the customer choice', () async {
    final cubit = ThemeModeCubit();
    addTearDown(cubit.close);
    addTearDown(() => ThemeModeCubit.applyRoles(isDark: false));

    await cubit.set(ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme_mode'), 'dark');
  });
}
