import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_card.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_image.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

SubscriptionPlan _plan({String? imageUrl, String nameAr = 'الباقة الأساسية'}) =>
    SubscriptionPlan(
      id: 'plan-1',
      code: 'basic',
      nameAr: nameAr,
      nameEn: 'Basic plan',
      price: 150,
      currencyCode: 'SAR',
      cupsPerCycle: 30,
      imageUrl: imageUrl,
    );

/// The announcement the whole card carries, above the tap it answers to.
///
/// The button inside the card announces itself too, so the card's own line is
/// the one whose child is the tap.
final _cardSemantics = find.descendant(
  of: find.byType(SubscriptionPlanCard),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.child is InkWell,
  ),
);

Future<double> _assetRatio(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final ratio = frame.image.width / frame.image.height;
  frame.image.dispose();
  codec.dispose();
  return ratio;
}

/// Builds [child] and lets the real image decoder run.
///
/// Decoding is engine work, so it only completes outside the fake clock;
/// without this the widgets below would be measured while still showing the
/// placeholder box.
Future<void> _pumpWithRealDecoder(WidgetTester tester, Widget child) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(child);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  });
}

void main() {
  // The plan fixtures carry Arabic names, so the cards are read in Arabic.
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  group('SubscriptionPlanCard', () {
    Widget host(
      SubscriptionPlan plan, {
      VoidCallback? onTap,
      VoidCallback? onSubscribe,
      bool busy = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 800,
            child: GridView.builder(
              // The card is laid out against the grid that ships it, so the
              // test reads that delegate instead of restating its numbers.
              gridDelegate: SubscriptionPlansPage.gridDelegate,
              itemCount: 1,
              itemBuilder: (context, _) => SubscriptionPlanCard(
                plan: plan,
                onTap: onTap ?? () {},
                onSubscribe: onSubscribe ?? () {},
                busy: busy,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('fills the cell without overflowing on a small screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(_plan(imageUrl: 'assets/images/product.png')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('الباقة الأساسية'), findsOneWidget);
      expect(find.text('${S.cupsLabel}: 30'), findsOneWidget);
      // The picture takes the free space of the card.
      expect(find.byType(DbImage), findsOneWidget);
    });

    testWidgets('the subscribe button and the card are both tappable', (
      tester,
    ) async {
      var subscribed = 0;
      var opened = 0;
      await tester.pumpWidget(
        host(
          _plan(imageUrl: 'assets/images/product.png'),
          onTap: () => opened++,
          onSubscribe: () => subscribed++,
        ),
      );
      await tester.pump();

      await tester.tap(find.text(S.subscribeNow));
      await tester.pump();
      expect(subscribed, 1);

      await tester.tap(find.text('الباقة الأساسية'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('a card with a write in flight answers nothing', (
      tester,
    ) async {
      var subscribed = 0;
      var opened = 0;
      await tester.pumpWidget(
        host(
          _plan(imageUrl: 'assets/images/product.png'),
          onTap: () => opened++,
          onSubscribe: () => subscribed++,
          busy: true,
        ),
      );
      await tester.pump();

      await tester.tap(find.text(S.subscribeNow));
      await tester.tap(find.text('الباقة الأساسية'));
      await tester.pump();

      expect(subscribed, 0);
      expect(opened, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, S.subscribeNow),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('the card is one control that says what it opens', (
      tester,
    ) async {
      await tester.pumpWidget(host(_plan()));
      await tester.pump();

      final semantics = tester.widget<Semantics>(_cardSemantics);
      expect(semantics.properties.button, isTrue);
      expect(
        semantics.properties.label,
        allOf(contains('الباقة الأساسية'), contains(S.priceLabel)),
        reason:
            'a reader hears the card as one named action, not a pile of text',
      );

      await tester.pumpWidget(host(_plan(), busy: true));
      await tester.pump();

      expect(
        tester.widget<Semantics>(_cardSemantics).properties.button,
        isNot(true),
        reason: 'a disabled control must not be announced as a button',
      );
    });

    testWidgets('the price is read as money, not as a bare number', (
      tester,
    ) async {
      await tester.pumpWidget(host(_plan()));
      await tester.pump();

      expect(find.textContaining(S.priceLabel), findsOneWidget);
      expect(find.textContaining('150'), findsOneWidget);
    });
  });

  group('SubscriptionPlanImage', () {
    testWidgets('shows the whole picture, keeping its own ratio', (
      tester,
    ) async {
      const asset = 'assets/images/product.png';
      final ratio = (await tester.runAsync(() => _assetRatio(asset)))!;

      await _pumpWithRealDecoder(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SubscriptionPlanImage(imageUrl: asset),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(SubscriptionPlanImage));
      expect(size.height, closeTo(300 / ratio, 1));
      // The picture is never cropped.
      final image = tester.widget<DbImage>(find.byType(DbImage));
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('caps the height of a very tall picture', (tester) async {
      await _pumpWithRealDecoder(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SubscriptionPlanImage(
                imageUrl: 'assets/images/product.png',
                maxHeight: 100,
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(SubscriptionPlanImage));
      expect(size.height, 100);
    });
  });
}
