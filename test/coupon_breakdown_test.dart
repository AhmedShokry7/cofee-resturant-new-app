import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/coupon_breakdown.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

/// Cover for the per-line coupon breakdown.
///
/// 071 made a scoped coupon discount only the eligible lines. That is correct
/// but reads as a bug: 20% off cold drinks against a basket that is mostly
/// something else produces a small figure with nothing to explain it. The
/// breakdown is the explanation, so its arithmetic is the thing under test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  CouponLineDiscount line({
    required String name,
    required double total,
    required double discount,
    bool eligible = true,
  }) => CouponLineDiscount(
    productId: name,
    nameEn: name,
    lineTotal: total,
    discount: discount,
    isEligible: eligible,
  );

  group('CouponLineDiscount', () {
    test('the payable total is the line minus its share', () {
      expect(line(name: 'Latte', total: 12, discount: 2.4).payableTotal, 9.6);
    });

    test('an untouched line still costs its full amount', () {
      expect(line(name: 'Cookie', total: 5, discount: 0).payableTotal, 5);
    });

    test('a zero discount on an eligible line differs from an excluded one', () {
      // A share too small to be a cent is still "covered"; an out-of-scope line
      // is not, and the two are told apart in the UI.
      expect(line(name: 'X', total: 1, discount: 0).isEligible, isTrue);
      expect(
        line(name: 'X', total: 1, discount: 0, eligible: false).isEligible,
        isFalse,
      );
    });

    test('reads a server row', () {
      final parsed = CouponLineDiscount.fromDatabase({
        'product_id': 'p1',
        'product_name_en': 'Latte',
        'line_total': 12,
        'discount': 2.4,
        'eligible': true,
      });
      expect(parsed.productId, 'p1');
      expect(parsed.name, 'Latte');
      expect(parsed.lineTotal, 12);
      expect(parsed.discount, 2.4);
    });
  });

  group('ValidatedCoupon', () {
    ValidatedCoupon coupon(List<CouponLineDiscount> lines) => ValidatedCoupon(
      coupon: const CouponModel(id: 'c', code: 'COLD'),
      discount: lines.fold<double>(0, (s, l) => s + l.discount),
      subtotal: lines.fold<double>(0, (s, l) => s + l.lineTotal),
      lines: lines,
    );

    test('no breakdown means nothing to explain, not a failure', () {
      final c = coupon([]);
      expect(c.lines, isEmpty);
      expect(c.discountedLines, isEmpty);
      expect(c.isPartial, isFalse);
    });

    test('partial when some lines were excluded', () {
      final c = coupon([
        line(name: 'Latte', total: 12, discount: 2.4),
        line(name: 'Cookie', total: 5, discount: 0, eligible: false),
      ]);
      expect(c.discountedLines, hasLength(1));
      expect(c.isPartial, isTrue);
    });

    test('not partial when every line is covered', () {
      final c = coupon([
        line(name: 'Latte', total: 12, discount: 2.4),
        line(name: 'Mocha', total: 13, discount: 2.6),
      ]);
      expect(c.discountedLines, hasLength(2));
      expect(c.isPartial, isFalse);
    });

    test('the total always equals the sum of the shares', () {
      // The property the whole feature rests on: the server allocates with
      // cumulative rounding precisely so this holds to the cent.
      final c = coupon([
        line(name: 'A', total: 10.33, discount: 1.03),
        line(name: 'B', total: 7.77, discount: 0.78),
        line(name: 'C', total: 5.01, discount: 0.5),
      ]);
      final sum = c.lines.fold<double>(0, (s, l) => s + l.discount);
      expect((sum - c.discount).abs() < 0.005, isTrue);
    });

    test('copyWithLines keeps the approved amount untouched', () {
      const approved = ValidatedCoupon(
        coupon: CouponModel(id: 'c', code: 'X'),
        discount: 6.25,
        subtotal: 50,
      );
      final withLines = approved.copyWithLines([
        line(name: 'A', total: 20, discount: 6.25),
      ]);
      expect(withLines.discount, 6.25);
      expect(withLines.subtotal, 50);
      expect(withLines.lines, hasLength(1));
    });
  });

  group('widget', () {
    Future<void> pumpBreakdown(
      WidgetTester tester,
      ValidatedCoupon coupon,
    ) async {
      tester.view.physicalSize = const Size(360, 900) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CouponBreakdown(coupon: coupon)),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders nothing when the server gave no breakdown', (
      tester,
    ) async {
      await pumpBreakdown(
        tester,
        const ValidatedCoupon(
          coupon: CouponModel(id: 'c', code: 'X'),
          discount: 5,
          subtotal: 50,
        ),
      );
      expect(find.byType(CouponBreakdown), findsOneWidget);
      expect(find.text(S.subTotalDiscounted), findsNothing);
    });

    testWidgets('a partial discount says how many lines were covered', (
      tester,
    ) async {
      await pumpBreakdown(
        tester,
        ValidatedCoupon(
          coupon: const CouponModel(id: 'c', code: 'X'),
          discount: 2.4,
          subtotal: 17,
          lines: [
            line(name: 'Latte', total: 12, discount: 2.4),
            line(name: 'Cookie', total: 5, discount: 0, eligible: false),
          ],
        ),
      );

      // The counts live inside the localized sentence: appending "(1/2)" to an
      // Arabic label moved the pair to the other end of the line on screen.
      final caption = S.couponEligibleInCartCount(1, 2);
      expect(find.text(caption), findsOneWidget);
      // Collapsed by default: a normal coupon costs no extra taps.
      expect(find.text('Latte'), findsNothing);

      await tester.tap(find.text(caption));
      await tester.pump();

      expect(find.text('Latte'), findsOneWidget);
      expect(find.text('Cookie'), findsOneWidget);
      // The excluded line says why it got nothing, so the grey row is not a bug.
      expect(find.text(S.couponLineNotIncluded), findsOneWidget);
      expect(find.text(S.subTotalDiscounted), findsOneWidget);
    });

    testWidgets('a fully covered discount uses the plain label', (
      tester,
    ) async {
      await pumpBreakdown(
        tester,
        ValidatedCoupon(
          coupon: const CouponModel(id: 'c', code: 'X'),
          discount: 5,
          subtotal: 10,
          lines: [
            line(name: 'A', total: 5, discount: 2.5),
            line(name: 'B', total: 5, discount: 2.5),
          ],
        ),
      );
      expect(find.text(S.couponDiscountBreakdown), findsOneWidget);
    });
  });
}
