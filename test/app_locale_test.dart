import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  test('selecting a language updates the locale immediately', () async {
    expect(AppLocale.instance.language, AppLanguage.arabic);
    expect(AppLocale.instance.locale, const Locale('ar'));
    expect(AppLocale.instance.textDirection, TextDirection.rtl);

    await AppLocale.instance.setLanguage(AppLanguage.english);

    expect(AppLocale.instance.language, AppLanguage.english);
    expect(AppLocale.instance.locale, const Locale('en'));
    expect(AppLocale.instance.textDirection, TextDirection.ltr);
  });

  test('the selection is persisted and survives a restart', () async {
    await AppLocale.instance.setLanguage(AppLanguage.english);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_language'), 'en');

    // A fresh initialize() reads the saved value back, which is what the next
    // app start does in main().
    await AppLocale.instance.initialize();
    expect(AppLocale.instance.language, AppLanguage.english);
  });

  test('a saved language wins over the device language', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'ar'});
    await AppLocale.instance.initialize();
    expect(AppLocale.instance.language, AppLanguage.arabic);
  });

  test('toggle switches between the two supported languages', () async {
    expect(AppLocale.instance.language, AppLanguage.arabic);
    await AppLocale.instance.toggle();
    expect(AppLocale.instance.language, AppLanguage.english);
    await AppLocale.instance.toggle();
    expect(AppLocale.instance.language, AppLanguage.arabic);
  });

  test('fromCode treats anything outside en as arabic', () {
    expect(AppLanguage.fromCode('en'), AppLanguage.english);
    expect(AppLanguage.fromCode('en-US'), AppLanguage.english);
    expect(AppLanguage.fromCode('ar'), AppLanguage.arabic);
    expect(AppLanguage.fromCode(null), AppLanguage.arabic);
  });
}
