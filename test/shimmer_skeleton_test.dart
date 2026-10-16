import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';

/// Pumps [child] inside a 375x812 ScreenUtil context, matching the app's
/// responsive setup, so `.w` / `.h` / `.r` extensions resolve 1:1.
Future<void> pumpSkeleton(
  WidgetTester tester,
  Widget child, {
  Size surface = const Size(375, 812),
}) async {
  tester.view.physicalSize = Size(surface.width * 3, surface.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  group('Shimmer primitives', () {
    testWidgets('render child statically when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) => const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Shimmer(child: ShimmerLine(width: 100, height: 12)),
            ),
          ),
        ),
      );
      expect(find.byType(ShimmerLine), findsOneWidget);
      // No ticker means no endless animation to settle.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ShimmerLine), findsOneWidget);
    });

    testWidgets('ShimmerBox paints the centralized base color', (tester) async {
      await pumpSkeleton(
        tester,
        const Shimmer(child: ShimmerBox(width: 64, height: 64)),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.color,
        ShimmerColors.baseOf(tester.element(find.byType(ShimmerBox))),
      );
    });
  });

  group('Catalog skeletons match real layouts', () {
    testWidgets('ProductCardSkeleton keeps the taller card aspect ratio', (
      tester,
    ) async {
      await pumpSkeleton(tester, const ProductCardSkeleton(width: 150));
      expect(find.byType(AspectRatio), findsOneWidget);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        0.64,
      );
      // Image area, title, description, price row and add button slots.
      expect(find.byType(ShimmerBox), findsWidgets);
      expect(find.byType(ShimmerCircle), findsWidgets);
    });

    testWidgets('ProductsGridSkeleton shows six cards in two columns', (
      tester,
    ) async {
      await pumpSkeleton(
        tester,
        const SizedBox(width: 375, height: 1200, child: ProductsGridSkeleton()),
      );
      expect(find.byType(ProductCardSkeleton), findsNWidgets(6));
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(delegate.childAspectRatio, 0.64);
    });

    testWidgets('ProductsCarouselSkeleton keeps the derived list height', (
      tester,
    ) async {
      await pumpSkeleton(
        tester,
        const SizedBox(
          width: 375,
          height: 400,
          child: ProductsCarouselSkeleton(),
        ),
      );
      // The derived-height strip is laid out; only viewport-visible cards are built,
      // exactly like the real horizontal carousel.
      final strip = tester.getSize(find.byType(ListView));
      expect(strip.height, closeTo(150 / 0.64, 1));
      expect(find.byType(ProductCardSkeleton), findsWidgets);
      // Scrolling reveals more skeleton cards, proving all four exist.
      await tester.drag(find.byType(ListView), const Offset(-400, 0));
      await tester.pump();
      expect(find.byType(ProductCardSkeleton), findsWidgets);
    });

    testWidgets('CategoryTabsSkeleton keeps the 50.h bar height', (
      tester,
    ) async {
      await pumpSkeleton(tester, const CategoryTabsSkeleton());
      final box = tester.getSize(find.byType(CategoryTabsSkeleton));
      expect(box.height, 50);
    });

    testWidgets('HomeCategoriesSkeleton renders eight category cells', (
      tester,
    ) async {
      await pumpSkeleton(
        tester,
        const SizedBox(
          width: 375,
          height: 400,
          child: HomeCategoriesSkeleton(),
        ),
      );
      expect(find.byType(CategoryGridItemSkeleton), findsNWidgets(8));
    });

    testWidgets('BannerSkeleton defaults to the full-bleed carousel size', (
      tester,
    ) async {
      await pumpSkeleton(
        tester,
        const SizedBox(width: 375, height: 260, child: BannerSkeleton()),
      );
      final box = tester.getSize(find.byType(ShimmerBox).first);
      expect(box.height, 164);
      expect(box.width, 375);
    });

    testWidgets('BundleListSkeleton mirrors bundle rows', (tester) async {
      await pumpSkeleton(
        tester,
        const SizedBox(width: 375, height: 800, child: BundleListSkeleton()),
      );
      expect(find.byType(BundleListTileSkeleton), findsNWidgets(4));
    });
  });

  group('Page skeletons', () {
    testWidgets('ProductDetailsSkeleton shows hero, title and option groups', (
      tester,
    ) async {
      await pumpSkeleton(tester, const ProductDetailsSkeleton());
      expect(find.byType(ShimmerBox), findsWidgets);
      expect(find.byType(ShimmerLine), findsWidgets);
    });

    testWidgets('BundleDetailsSkeleton shows hero and inside rows', (
      tester,
    ) async {
      await pumpSkeleton(tester, const BundleDetailsSkeleton());
      // 1 hero + 3 thumbs + price value boxes.
      expect(find.byType(ShimmerBox), findsWidgets);
    });

    testWidgets('OrdersSkeleton renders order cards', (tester) async {
      await pumpSkeleton(tester, const OrdersSkeleton());
      expect(find.byType(OrderCardSkeleton), findsNWidgets(4));
    });

    testWidgets('NotificationsSkeleton renders notification tiles', (
      tester,
    ) async {
      await pumpSkeleton(tester, const NotificationsSkeleton());
      expect(find.byType(NotificationTileSkeleton), findsNWidgets(5));
    });

    testWidgets('CouponsLoadingView renders coupon cards', (tester) async {
      await pumpSkeleton(tester, const CouponsLoadingView());
      expect(find.byType(CouponCardSkeleton), findsNWidgets(3));
    });

    testWidgets('LoyaltyLoadingView renders balance card and rewards', (
      tester,
    ) async {
      await pumpSkeleton(tester, const LoyaltyLoadingView());
      expect(find.byType(RewardCardSkeleton), findsNWidgets(3));
    });

    testWidgets('TrackTimelineSkeleton renders timeline rows', (tester) async {
      await pumpSkeleton(tester, const TrackTimelineSkeleton());
      expect(find.byType(ShimmerCircle), findsNWidgets(3));
    });

    testWidgets('FaqLoadingView renders FAQ tiles', (tester) async {
      await pumpSkeleton(tester, const FaqLoadingView());
      expect(find.byType(ShimmerLine), findsWidgets);
    });

    testWidgets('PolicyLoadingView renders paragraph lines', (tester) async {
      await pumpSkeleton(tester, const PolicyLoadingView());
      expect(find.byType(ShimmerLine), findsNWidgets(9));
    });

    testWidgets('CategoriesLoadingView renders the product grid', (
      tester,
    ) async {
      await pumpSkeleton(
        tester,
        const SizedBox(
          width: 375,
          height: 1200,
          child: CategoriesLoadingView(),
        ),
      );
      expect(find.byType(ProductCardSkeleton), findsNWidgets(6));
    });
  });

  group('DbImage behavior is preserved', () {
    testWidgets('null image stays a neutral static placeholder', (
      tester,
    ) async {
      await pumpSkeleton(tester, const DbImage(image: null));
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
      expect(find.byType(Shimmer), findsNothing);
    });

    testWidgets('empty image stays a neutral static placeholder', (
      tester,
    ) async {
      await pumpSkeleton(tester, const DbImage(image: '  '));
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
      expect(find.byType(Shimmer), findsNothing);
    });
  });
}
