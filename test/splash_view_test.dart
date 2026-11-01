import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';

/// Mirrors main.dart: the entry route is the splash and ScreenUtil wraps the
/// app, which the destination page needs.
Widget _app(String targetRoute) => ScreenUtilInit(
  designSize: const Size(360, 690),
  builder: (context, child) => MaterialApp(
    onGenerateRoute: AppRouteGenerator.onGenerateRoute,
    routes: {
      SplashView.routeName: (context) => SplashView(targetRoute: targetRoute),
      ...AppRoutes.routes,
    },
    initialRoute: SplashView.routeName,
  ),
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

void main() {
  testWidgets('splash paints the brand mark on a white screen', (tester) async {
    await _pumpSplash(tester, const Size(360, 690));

    expect(find.byType(SplashView), findsOneWidget);

    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as AssetImage).assetName, AppImages.logo);

    final background = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SplashView),
        matching: find.byType(Scaffold),
      ),
    );
    expect(background.backgroundColor, const Color(0xFFFFFFFF));
  });

  testWidgets('the mark starts transparent and reaches full opacity', (
    tester,
  ) async {
    await _pumpSplash(tester, const Size(360, 690));

    double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;

    expect(opacity(), 0);

    await tester.pump(SplashView.entranceDuration);
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

    expect(scale(), closeTo(0.92, 0.001));

    await tester.pump(SplashView.entranceDuration);
    await tester.pump();

    expect(scale(), closeTo(1.0, 0.001));
  });

  testWidgets('the logo scales with the screen instead of a fixed circle', (
    tester,
  ) async {
    await _pumpSplash(tester, const Size(360, 800), pixelRatio: 3);

    final logo = tester.widget<Image>(find.byType(Image));
    const screenWidth = 360.0;

    expect(logo.width, closeTo(screenWidth * 0.66, 0.5));
    expect(logo.width, greaterThan(160));
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

    // Tear the splash down before its timer is due.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('replaced'))),
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

      final logo = tester.widget<Image>(find.byType(Image));
      // The asset is 1024x827, so the height follows from the width requested.
      final logoHeight = logo.width! * 827 / 1024;

      expect(
        logo.width!,
        lessThanOrEqualTo(size.shortestSide),
        reason: '$size',
      );
      expect(logoHeight, lessThanOrEqualTo(size.shortestSide), reason: '$size');
      expect(tester.takeException(), isNull, reason: 'render error at $size');
    }
  });
}
