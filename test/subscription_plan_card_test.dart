import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
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

Future<double> _assetRatio(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final ratio = frame.image.width / frame.image.height;
  frame.image.dispose();
  codec.dispose();
  return ratio;
}

void main() {
  group('SubscriptionPlanCard', () {
    Widget host(SubscriptionPlan plan, {VoidCallback? onTap, VoidCallback? onSubscribe}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 800,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              itemCount: 1,
              itemBuilder: (context, _) => SubscriptionPlanCard(
                plan: plan,
                onTap: onTap ?? () {},
                onSubscribe: onSubscribe ?? () {},
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
      expect(find.text('الأكواب: 30'), findsOneWidget);
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

      await tester.tap(find.text('اشترك الآن'));
      await tester.pump();
      expect(subscribed, 1);

      await tester.tap(find.text('الباقة الأساسية'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('SubscriptionPlanImage', () {
    testWidgets('shows the whole picture, keeping its own ratio', (tester) async {
      const asset = 'assets/images/product.png';
      // Decoding is real engine work, so it has to run outside the fake clock.
      final ratio = (await tester.runAsync(() => _assetRatio(asset)))!;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SubscriptionPlanImage(imageUrl: asset),
            ),
          ),
        ),
      );
      // The shimmer keeps animating, so settle is not an option here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final size = tester.getSize(find.byType(SubscriptionPlanImage));
      expect(size.height, closeTo(300 / ratio, 1));
      // The picture is never cropped.
      final image = tester.widget<DbImage>(find.byType(DbImage));
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('caps the height of a very tall picture', (tester) async {
      await tester.pumpWidget(
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final size = tester.getSize(find.byType(SubscriptionPlanImage));
      expect(size.height, 100);
    });
  });
}
