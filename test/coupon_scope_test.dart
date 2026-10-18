import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

/// Cover for why a scoped coupon is refused.
///
/// `marketing.validate_coupon` answered 'code does not apply to your items' for
/// both a category-scoped and a product-scoped coupon, so a cart with no
/// espresso and a cart with no cold drinks got the identical sentence — and no
/// client could say more, because nothing ever read `applies_to`,
/// `coupons_categories` or `coupons_products`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('reason codes', () {
    test('every reason validate_coupon can emit is handled', () {
      // The literals marketing.validate_coupon returns in `reason_code`.
      const reasons = [
        'not_found',
        'expired',
        'min_order_not_met',
        'fully_used',
        'user_limit_reached',
        'scope_category_no_match',
        'scope_product_no_match',
      ];
      for (final reason in reasons) {
        final english = S.couponRejectedReason(reason, '');
        expect(english, isNotEmpty, reason: reason);
        // Never the machine token itself.
        expect(english, isNot(reason), reason: reason);
        expect(english, isNot(contains('_')), reason: reason);
      }
    });

    test('a category rejection names the category', () {
      expect(
        S.couponRejectedReason('scope_category_no_match', 'Cold drinks'),
        contains('Cold drinks'),
      );
    });

    test('a product rejection names the product', () {
      expect(
        S.couponRejectedReason('scope_product_no_match', 'Espresso'),
        contains('Espresso'),
      );
    });

    test('category and product rejections are distinguishable', () {
      // The whole point of the reason code: the two cases used to be identical.
      final category = S.couponRejectedReason(
        'scope_category_no_match',
        'Cold drinks',
      );
      final product = S.couponRejectedReason(
        'scope_product_no_match',
        'Espresso',
      );
      expect(category, isNot(product));
    });

    test('an unknown scope still reads as a scope problem, not "invalid code"', () {
      final message = S.couponRejectedReason('scope_product_no_match', '');
      expect(message.toLowerCase(), contains('cart'));
      expect(message, isNot(S.invalidCouponCode));
    });

    test('an empty reason falls back to the legacy message translation', () {
      expect(
        S.couponRejectedReason(
          '',
          '',
          legacyMessage: 'you already used this code',
        ),
        S.couponRejected('you already used this code'),
      );
    });

    test('with no reason and no message it is still safe, never raw', () {
      final message = S.couponRejectedReason('', '');
      expect(message, isNotEmpty);
      expect(message, S.invalidCouponCode);
    });

    test('the scope wording follows the app language', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      final english = S.couponRejectedReason(
        'scope_product_no_match',
        'Espresso',
      );
      AppLocale.instance.debugSet(AppLanguage.arabic);
      final arabic = S.couponRejectedReason(
        'scope_product_no_match',
        'إسبريسو',
      );

      expect(arabic, isNot(english));
      expect(RegExp('[\u0600-\u06FF]').hasMatch(arabic), isTrue);
      expect(arabic, contains('إسبريسو'));
    });
  });

  group('CouponModel scope', () {
    CouponModel scoped({
      String appliesTo = 'product',
      List<String> ar = const [],
      List<String> en = const [],
    }) => CouponModel(
      id: 'c1',
      code: 'ESP',
      appliesTo: appliesTo,
      scopeNamesAr: ar,
      scopeNamesEn: en,
    );

    test('an unscoped coupon says so and has no label', () {
      final coupon = CouponModel(id: 'c1', code: 'ALL');
      expect(coupon.isScoped, isFalse);
      expect(coupon.scopeLabel, isEmpty);
      expect(coupon.scopeNames, isEmpty);
    });

    test('names come from the current language', () {
      final coupon = scoped(ar: ['إسبريسو'], en: ['Espresso']);
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(coupon.scopeLabel, 'Espresso');
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(coupon.scopeLabel, 'إسبريسو');
    });

    test('several names are joined for readability', () {
      final coupon = scoped(
        appliesTo: 'category',
        en: ['Cold drinks', 'Desserts'],
      );
      expect(coupon.scopeLabel, 'Cold drinks, Desserts');
    });

    test('a missing translation falls back instead of rendering an empty chip', () {
      final coupon = scoped(ar: ['مشروبات باردة'], en: const []);
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(coupon.scopeLabel, 'مشروبات باردة');
    });

    test('blank names are not treated as content', () {
      final coupon = scoped(en: ['Espresso', '  ']);
      expect(coupon.scopeNames, hasLength(2));
      expect(coupon.scopeLabel, contains('Espresso'));
    });

    test('withUsage carries the scope across', () {
      final base = CouponModel(id: 'c1', code: 'ESP', discountValue: 50);
      final merged = base.withUsage(
        scoped(
          appliesTo: 'product',
          ar: ['إسبريسو'],
          en: ['Espresso'],
        ),
      );
      expect(merged.appliesTo, 'product');
      expect(merged.isScoped, isTrue);
      expect(merged.discountValue, 50);
      expect(merged.scopeNamesEn, ['Espresso']);
    });
  });

  group('the card says the discount is partial', () {
    test('a scoped coupon is flagged, an unscoped one is not', () {
      final unscoped = CouponModel(id: 'c1', code: 'ALL');
      expect(unscoped.discountsOnlyScope, isFalse);

      final scopedCoupon = CouponModel(
        id: 'c2',
        code: 'COLD',
        appliesTo: 'category',
        scopeNamesEn: ['Cold drinks'],
      );
      expect(scopedCoupon.discountsOnlyScope, isTrue);
      expect(scopedCoupon.scopeLabel, 'Cold drinks');
    });

    test('the note is real prose in both languages', () {
      // Without this the cart shows a small discount against a large subtotal
      // and the customer has no way to tell that is correct.
      AppLocale.instance.debugSet(AppLanguage.english);
      final english = S.couponScopeDiscountNote;
      AppLocale.instance.debugSet(AppLanguage.arabic);
      final arabic = S.couponScopeDiscountNote;

      expect(arabic, isNot(english));
      expect(RegExp('[\u0600-\u06FF]').hasMatch(arabic), isTrue);
      expect(english.toLowerCase(), contains('eligible'));
    });
  });
}