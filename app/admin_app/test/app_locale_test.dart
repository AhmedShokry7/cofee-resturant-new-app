import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:admin_app/core/locale/app_locale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  test('initialize restores a saved language', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'admin_app_language': 'ar'});
    await AppLocale.instance.initialize();
    expect(AppLocale.instance.language, AppLanguage.arabic);
    expect(AppLocale.instance.textDirection, TextDirection.rtl);
  });

  test('setLanguage persists the selection', () async {
    await AppLocale.instance.setLanguage(AppLanguage.arabic);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('admin_app_language'), 'ar');
    expect(AppLocale.instance.isArabic, isTrue);

    await AppLocale.instance.setLanguage(AppLanguage.english);
    expect(preferences.getString('admin_app_language'), 'en');
  });

  test('switching updates locale and text direction', () {
    AppLocale.instance.debugSet(AppLanguage.english);
    expect(AppLocale.instance.locale, const Locale('en'));
    expect(AppLocale.instance.textDirection, TextDirection.ltr);

    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(AppLocale.instance.locale, const Locale('ar'));
    expect(AppLocale.instance.textDirection, TextDirection.rtl);
  });
}
