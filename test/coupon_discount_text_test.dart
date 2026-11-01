import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

/// The card text comes from the numeric rule and the app language, never from
/// a string the database stores.
void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  CouponModel rule({
    String type = 'percentage',
    double value = 20,
    double? cap,
  }) {
    return const CouponModel(
      id: 'c1',
      code: 'WELCOME',
    ).copyWith(discountType: type, discountValue: value, maxDiscount: cap);
  }

  test('a percentage rule reads as a percentage', () {
    expect(rule().discount, '20% off');
  });

  test('a capped percentage names the cap', () {
    expect(rule(cap: 25).discount, '20% off up to ${Formatters.price(25)}');
  });

  test('a fixed rule reads as an amount', () {
    expect(
      rule(type: 'fixed', value: 15).discount,
      '${Formatters.price(15)} off',
    );
  });

  test('a whole percent is not shown with decimals', () {
    expect(rule(value: 12.5).discount, '12.5% off');
    expect(rule(value: 15).discount, '15% off');
  });

  test('the Arabic rule is phrased in Arabic', () {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(rule().discount, 'خصم 20%');
    expect(rule(cap: 25).discount, contains('خصم 20%'));
    expect(rule(type: 'fixed', value: 15).discount, startsWith('خصم'));
  });
}
