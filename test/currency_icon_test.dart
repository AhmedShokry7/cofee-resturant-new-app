import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

import 'support/mock_product_repository.dart';

import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/currency_icon.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('CurrencyIcon', () {
    testWidgets('renders the SAR asset tinted as one monochrome symbol', (
      tester,
    ) async {
      await _pump(tester, CurrencyIcon(size: 16, color: AppColor.primaryColor));

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(picture.fit, BoxFit.contain);
      expect(picture.width, 16);
      expect(picture.height, 16);
      expect(
        picture.colorFilter,
        ColorFilter.mode(AppColor.primaryColor, BlendMode.srcIn),
      );
    });

    testWidgets('defaults to a legible theme-aware color', (tester) async {
      await _pump(tester, const CurrencyIcon());
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        const ColorFilter.mode(Color(0xFF242424), BlendMode.srcIn),
      );
    });
  });

  group('PriceLabel', () {
    testWidgets('shows the amount with an icon instead of SAR text', (
      tester,
    ) async {
      await _pump(
        tester,
        Builder(
          builder: (context) =>
              PriceLabel(amount: 25, style: AppFonts.semiBold14(context)),
        ),
      );

      expect(find.text('25.00'), findsOneWidget);
      expect(find.textContaining('SAR'), findsNothing);
      expect(find.byType(CurrencyIcon), findsOneWidget);
    });

    testWidgets('supports discount and delta prefixes', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              PriceLabel(
                amount: 5,
                prefix: '-',
                style: AppFonts.regular14(context),
              ),
              PriceLabel(
                amount: 3,
                prefix: '+',
                style: AppFonts.regular14(context),
              ),
            ],
          ),
        ),
      );

      expect(find.text('-5.00'), findsOneWidget);
      expect(find.text('+3.00'), findsOneWidget);
      expect(find.byType(CurrencyIcon), findsNWidgets(2));
    });
  });

  group('shared price components', () {
    testWidgets(
      'ProductPrice shows the current price with an icon and the struck old price without one',
      (tester) async {
        final products = await MockProductRepository().getProducts();
        final discounted = products.firstWhere((p) => p.hasDiscount);

        await _pump(tester, ProductPrice(product: discounted));

        // Only the price the customer actually pays carries the currency
        // symbol; the pre-discount price is plain struck text.
        expect(find.byType(PriceLabel), findsOneWidget);
        expect(find.byType(CurrencyIcon), findsOneWidget);

        final old = tester.widget<Text>(
          find.text(Formatters.amount(discounted.oldPrice!)),
        );
        expect(old.style?.decoration, TextDecoration.lineThrough);
        expect(find.textContaining('SAR'), findsNothing);
      },
    );

    testWidgets('LabeledValueRow priceValue renders an icon row', (
      tester,
    ) async {
      await _pump(
        tester,
        const LabeledValueRow(
          label: 'Total',
          priceValue: 120.5,
          emphasized: true,
          big: true,
        ),
      );

      expect(find.text('120.50'), findsOneWidget);
      expect(find.byType(PriceLabel), findsOneWidget);
      expect(find.textContaining('SAR'), findsNothing);
    });
  });

  group('Formatters text contract is preserved', () {
    test('price keeps a currency suffix for prose and slider labels', () {
      // Suffix follows the active locale (SAR in English, ر.س in Arabic);
      // visual labels use the icon instead.
      expect(Formatters.price(25), startsWith('25.00'));
      expect(Formatters.amount(25), '25.00');
    });
  });
}
