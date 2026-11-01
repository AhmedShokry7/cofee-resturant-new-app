import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';
import 'package:new_coffee/features/splash/presentation/views/widgets/splash_brand_mark.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';

/// Mirrors app.dart: the entry route is the splash, and the destination pages
/// render inside the same MaterialApp.
Widget _app(String targetRoute) => MaterialApp(
  onGenerateRoute: AppRouteGenerator.onGenerateRoute,
  routes: {
    SplashView.routeName: (context) => SplashView(targetRoute: targetRoute),
    ...AppRoutes.routes,
  },
  initialRoute: SplashView.routeName,
);

/// Renders the splash on a surface of the given logical size.
Future<void> _pumpSplash(
  WidgetTester tester,
  Size logicalSize, {
  double pixelRatio = 1.0,
  String targetRoute = WelcomePage.routeName,
}) async {
  tester.view.physicalSize = logicalSize * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(targetRoute));
}

/// Counts every copy of the destination on the navigator stack, including the
/// ones a pushed route hides offstage. A second navigation would stack a
/// second copy, so this is what proves the handoff happens exactly once.
int _destinations(WidgetTester tester) =>
    find.byType(WelcomePage, skipOffstage: false).evaluate().length;

Image _logo(WidgetTester tester) => tester.widget<Image>(find.byType(Image));

void main() {
  testWidgets('splash paints the brand mark on a white screen', (tester) async {
    await _pumpSplash(tester, const Size(360, 690));

    expect(find.byType(SplashView), findsOneWidget);

    expect((_logo(tester).image as AssetImage).assetName, AppImages.logo);

    final background = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SplashView),
        matching: find.byType(Scaffold),
      ),
    );
    expect(background.backgroundColor, AppColor.whiteColor);
  });

  testWidgets('the mark starts transparent and reaches full opacity', (
    tester,
  ) async {
    await _pumpSplash(tester, const Size(360, 690));

    double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;

    expect(opacity(), 0);

    await tester.pump(MotionTokens.entrance);
    await tester.pump();

    expect(opacity(), 1);
  });

  testWidgets('the mark scales up from its entrance size', (tester) async {
    await _pumpSplash(tester, const Size(360, 690));

    // Matched by shape: the framework puts its own Transform widgets in the
    // tree, so an unscoped finder is ambiguous. The entrance wrapper is the
    // one that directly wraps the logo.
    double scale() => tester
        .widget<Transform>(
          find.byWidgetPredicate(
            (widget) => widget is Transform && widget.child is Image,
          ),
        )
        .transform
        // storage[0] is m11: the horizontal scale. getMaxScaleOnAxis is not
        // usable here because it reports the untouched z axis as 1.0.
        .storage[0];

    expect(scale(), closeTo(SplashBrandMark.startScale, 0.001));

    await tester.pump(MotionTokens.entrance);
    await tester.pump();

    expect(scale(), closeTo(1.0, 0.001));
  });

  testWidgets('the logo scales with the screen instead of a fixed circle', (
    tester,
  ) async {
    await _pumpSplash(tester, const Size(360, 800), pixelRatio: 3);

    const screenWidth = 360.0;

    expect(
      _logo(tester).width,
      closeTo(screenWidth * SplashBrandMark.widthRatio, 0.5),
    );
    expect(_logo(tester).width, greaterThan(SplashBrandMark.minWidth));
  });

  testWidgets('a wide screen does not get an oversized mark', (tester) async {
    await _pumpSplash(tester, const Size(1024, 1366));

    expect(_logo(tester).width, SplashBrandMark.maxWidth);
  });

  testWidgets('splash is still on screen just before it hands over', (
    tester,
  ) async {
    await _pumpSplash(tester, const Size(360, 690));

    await tester.pump(
      SplashView.displayDuration - const Duration(milliseconds: 1),
    );

    expect(find.byType(SplashView), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('splash hands over to the saved entry route', (tester) async {
    await _pumpSplash(tester, const Size(360, 690));

    expect(find.byType(WelcomePage), findsNothing);

    await tester.pump(SplashView.displayDuration);
    await tester.pumpAndSettle();

    expect(find.byType(SplashView), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('the target route is opened exactly once', (tester) async {
    await _pumpSplash(tester, const Size(360, 690));

    await tester.pump(SplashView.displayDuration);
    await tester.pumpAndSettle();

    // Keep the clock moving well past the handoff; a second push would stack
    // another copy rather than being hidden by the replacement animation.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(_destinations(tester), 1);
  });

  testWidgets('a rebuild of the splash does not navigate twice', (
    tester,
  ) async {
    await _pumpSplash(tester, const Size(360, 690));

    // Mirrors a startup rebuild: the entry widget is rebuilt while the timer
    // is still pending.
    await tester.pumpWidget(_app(WelcomePage.routeName));

    await tester.pump(SplashView.displayDuration);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(_destinations(tester), 1);
  });

  testWidgets('disposing the splash prevents the delayed navigation', (
    tester,
  ) async {
    await _pumpSplash(tester, const Size(360, 690));

    expect(find.byType(SplashView), findsOneWidget);

    // Tear the splash down before its timer is due. The distinct key matters:
    // both roots are MaterialApp, so without it the test would update the
    // existing navigator instead of disposing the splash with it.
    await tester.pumpWidget(
      const MaterialApp(
        key: ValueKey('replaced'),
        home: Scaffold(body: Text('replaced')),
      ),
    );
    expect(find.byType(SplashView), findsNothing);

    await tester.pump(SplashView.displayDuration);
    await tester.pumpAndSettle();

    expect(_destinations(tester), 0);
    expect(find.text('replaced'), findsOneWidget);
  });

  testWidgets('the mark stays within the screen on every supported size', (
    tester,
  ) async {
    // Small portrait phone, reference phone, large phone, landscape phone and
    // tablet.
    const sizes = [
      Size(320, 568),
      Size(360, 690),
      Size(412, 915),
      Size(800, 360),
      Size(1024, 1366),
    ];

    for (final size in sizes) {
      await _pumpSplash(tester, size);

      final width = _logo(tester).width!;
      final height =
          width * SplashBrandMark.assetHeight / SplashBrandMark.assetWidth;

      expect(width, lessThanOrEqualTo(size.shortestSide), reason: '$size');
      expect(height, lessThanOrEqualTo(size.shortestSide), reason: '$size');
      expect(tester.takeException(), isNull, reason: 'render error at $size');
    }
  });
}
