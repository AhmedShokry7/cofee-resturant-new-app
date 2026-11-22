import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/features/design/data/design_preview_store.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';
import 'package:new_coffee/features/splash/presentation/views/widgets/splash_brand_mark.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

import 'support/fake_design_repository.dart';

class _DeferredDesignRepository implements DesignRepository {
  final Completer<PublishedDesign?> completer = Completer<PublishedDesign?>();

  @override
  Future<PublishedDesign?> published({bool forceRefresh = false}) =>
      completer.future;

  @override
  Future<PublishedDesign?> lastKnown() async => null;
}

/// Like the real repository, this honours the admin preview store before the
/// fallback document. A plain [FakeDesignRepository] cannot model editor pushes.
class _PreviewAwareDesignRepository implements DesignRepository {
  final FakeDesignRepository _fallback = FakeDesignRepository(null);

  @override
  Future<PublishedDesign?> published({bool forceRefresh = false}) async {
    final override = DesignPreviewStore.instance.document;
    if (override != null) {
      final previewed = PublishedDesign.fromJson(override);
      if (previewed != null) return previewed;
    }
    return _fallback.published(forceRefresh: forceRefresh);
  }

  @override
  Future<PublishedDesign?> lastKnown() => _fallback.lastKnown();
}

/// Mirrors app.dart: the entry route is the splash, and the destination pages
/// render inside the same MaterialApp.
///
/// تطبيق العميل يزوّد كل مساراته بـ DesignCubit من جذره، وهنا يُقلّد ذلك
/// بمستودع زائف يجيب بلا مستند — فترسم الشاشات أصولها.
Widget _app(
  String targetRoute, {
  PublishedDesign? design,
  DesignCubit? cubit,
  Key? treeKey,
}) {
  final app = MaterialApp(
    onGenerateRoute: AppRouteGenerator.onGenerateRoute,
    routes: {
      SplashView.routeName: (context) => SplashView(targetRoute: targetRoute),
      ...AppRoutes.routes,
    },
    initialRoute: SplashView.routeName,
  );
  Widget provided;
  if (cubit != null) {
    provided = BlocProvider.value(value: cubit, child: app);
  } else {
    provided = BlocProvider<DesignCubit>(
      create: (context) =>
          DesignCubit(repository: FakeDesignRepository(design)),
      child: app,
    );
  }
  // مفتاح الشجرة يجبر إعادة الإنشاء بين سيناريوهين في نفس الاختبار؛
  // pumpWidget يعيد استعمال شجرة العناصر فيتوقف cubit الأول حيًّا.
  return treeKey == null
      ? provided
      : KeyedSubtree(key: treeKey, child: provided);
}

/// Renders the splash on a surface of the given logical size.
Future<void> _pumpSplash(
  WidgetTester tester,
  Size logicalSize, {
  double pixelRatio = 1.0,
  String targetRoute = WelcomePage.routeName,
  PublishedDesign? design,
  DesignCubit? cubit,
  Key? treeKey,
}) async {
  tester.view.physicalSize = logicalSize * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _app(targetRoute, design: design, cubit: cubit, treeKey: treeKey),
  );
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

  testWidgets(
    'بدون صورة افتتاحية تنطلق الشاشة إلى لوجو الهوية، ومع صورة تبقى كل صورة منفصلة',
    (tester) async {
      // لا صورة افتتاحية — لكن الهوية تحمل لوجوًا: الاحتياط يقرأه لا الأصل.
      const logoOnly = PublishedDesign(
        schemaVersion: 2,
        theme: PublishedTheme(
          colors: {},
          textFactor: 1,
          logoUrl: 'https://cdn.example.com/identity-logo.png',
        ),
        extraSections: {
          'splash': [
            PublishedSection(
              id: 'splash_settings',
              type: 'splash.settings',
              properties: {'imageVisible': true},
            ),
          ],
        },
      );
      await _pumpSplash(
        tester,
        const Size(360, 690),
        design: logoOnly,
        treeKey: const ValueKey('identity-logo-scenario'),
      );
      await tester.pump();
      expect(
        tester.widget<DbImage>(find.byType(DbImage)).image,
        'https://cdn.example.com/identity-logo.png',
        reason: 'غياب صورة الافتتاحية يرجع للوجو لا للأصل المضمّن',
      );

      // صورة افتتاحية موجودة: تقول كلمتها وتتجاهل لوجو الهوية تمامًا.
      const splashImage = PublishedDesign(
        schemaVersion: 2,
        theme: PublishedTheme(
          colors: {},
          textFactor: 1,
          logoUrl: 'https://cdn.example.com/identity-logo.png',
        ),
        extraSections: {
          'splash': [
            PublishedSection(
              id: 'splash_settings',
              type: 'splash.settings',
              properties: {
                'imageUrl': 'https://cdn.example.com/splash-hero.png',
              },
            ),
          ],
        },
      );
      await _pumpSplash(
        tester,
        const Size(360, 690),
        design: splashImage,
        treeKey: const ValueKey('splash-hero-scenario'),
      );
      await tester.pump();
      expect(
        tester.widget<DbImage>(find.byType(DbImage)).image,
        'https://cdn.example.com/splash-hero.png',
        reason: 'صورة الافتتاحية تسبق اللوجو ولا تُستبدل به',
      );
    },
  );

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

    // Matched by ancestry: the framework puts its own Transform widgets in the
    // tree, so an unscoped finder is ambiguous. The entrance wrapper is the
    // nearest Transform above the logo itself (framework transforms sit
    // between them, so child matching no longer works).
    double scale() => tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byType(Image),
            matching: find.byType(Transform),
          ),
        )
        .first
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

  testWidgets('published splash image, optional text and background are used', (
    tester,
  ) async {
    const design = PublishedDesign(
      schemaVersion: 2,
      extraSections: {
        'splash': [
          PublishedSection(
            id: 'splash_settings',
            type: 'splash.settings',
            properties: {
              'imageUrl': 'https://cdn.example.com/splash.png',
              'imageFit': 'cover',
              'imageWidth': 210,
              'imageAlignment': 'topCenter',
              'text_ar': 'أهلاً بك',
              'textColor': '#123456',
              'textSize': 20,
              'textAlignment': 'end',
              'backgroundColor': '#ABCDEF',
              'durationMs': 2500,
              'animation': 'fade',
              'animationDurationMs': 500,
            },
          ),
        ],
      },
    );
    await _pumpSplash(tester, const Size(360, 690), design: design);
    await tester.pump();

    final image = tester.widget<DbImage>(find.byType(DbImage));
    expect(image.image, 'https://cdn.example.com/splash.png');
    expect(image.width, 210);
    expect(image.fit, BoxFit.cover);
    expect(find.text('أهلاً بك'), findsOneWidget);
    final text = tester.widget<Text>(find.text('أهلاً بك'));
    expect(text.textAlign, TextAlign.end);
    expect(text.style?.fontSize, 20);
    expect(text.style?.color, const Color(0xFF123456));
    final background = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(background.backgroundColor, const Color(0xFFABCDEF));
  });

  testWidgets(
    'a pushed editor document repaints the splash without publishing',
    (tester) async {
      addTearDown(() => DesignPreviewStore.instance.setDocument(null));
      final cubit = DesignCubit(repository: _PreviewAwareDesignRepository());
      addTearDown(cubit.close);
      await _pumpSplash(tester, const Size(360, 690), cubit: cubit);
      await tester.pump();

      Future<void> pushDocument(String url, String color) async {
        DesignPreviewStore.instance.setDocument({
          'schema_version': 2,
          'pages': [
            {
              'page': 'splash',
              'root': {
                'id': 'root_splash',
                'type': DesignWidgetTypes.pageHome,
                'children': [
                  {
                    'id': 'splash_settings',
                    'type': DesignWidgetTypes.splashSettings,
                    'visible': true,
                    'properties': {
                      'imageUrl': url,
                      'backgroundColor': color,
                      'durationMs': 5000,
                    },
                  },
                ],
              },
            },
          ],
        });
        await cubit.load(forceRefresh: true);
        await tester.pump();
      }

      await pushDocument('https://cdn.example.com/first.png', '#112233');
      expect(
        tester.widget<DbImage>(find.byType(DbImage)).image,
        'https://cdn.example.com/first.png',
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(0xFF112233),
      );

      await pushDocument('https://cdn.example.com/second.png', '#445566');
      expect(
        tester.widget<DbImage>(find.byType(DbImage)).image,
        'https://cdn.example.com/second.png',
        reason: 'تغيير صورة الافتتاحية في المعاينة يجب أن يستبدل الصورة',
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(0xFF445566),
        reason: 'تغيير لون الافتتاحية في المعاينة يجب أن يُعاد رسمه',
      );
    },
  );

  testWidgets('a published hidden splash image keeps its text visible', (
    tester,
  ) async {
    const design = PublishedDesign(
      schemaVersion: 2,
      extraSections: {
        'splash': [
          PublishedSection(
            id: 'splash_settings',
            type: 'splash.settings',
            properties: {
              'imageVisible': false,
              'text_ar': 'النص يبقى ظاهرًا',
              'durationMs': 2500,
            },
          ),
        ],
      },
    );
    await _pumpSplash(tester, const Size(360, 690), design: design);
    await tester.pump();

    expect(find.byType(DbImage), findsNothing);
    expect(find.text('النص يبقى ظاهرًا'), findsOneWidget);
  });

  testWidgets(
    'published duration controls the handover without changing route',
    (tester) async {
      const design = PublishedDesign(
        schemaVersion: 2,
        extraSections: {
          'splash': [
            PublishedSection(
              id: 'splash_settings',
              type: 'splash.settings',
              properties: {'durationMs': 250},
            ),
          ],
        },
      );
      tester.view.physicalSize = const Size(360, 690);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(WelcomePage.routeName, design: design));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 249));
      expect(find.byType(SplashView), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);
    },
  );

  testWidgets('initial handover waits for a late published splash duration', (
    tester,
  ) async {
    final repository = _DeferredDesignRepository();
    final cubit = DesignCubit(repository: repository);
    await _pumpSplash(tester, const Size(360, 690), cubit: cubit);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashView), findsOneWidget);

    repository.completer.complete(
      const PublishedDesign(
        schemaVersion: 2,
        extraSections: {
          'splash': [
            PublishedSection(
              id: 'splash_settings',
              type: 'splash.settings',
              properties: {'durationMs': 2500},
            ),
          ],
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2499));
    expect(find.byType(SplashView), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);

    await cubit.close();
  });

  testWidgets('a hidden splash content leaves a blank configured surface', (
    tester,
  ) async {
    const design = PublishedDesign(
      schemaVersion: 2,
      extraSections: {
        'splash': [
          PublishedSection(
            id: 'splash_settings',
            type: 'splash.settings',
            visible: false,
            properties: {'backgroundColor': '#F0F0F0', 'durationMs': 1000},
          ),
        ],
      },
    );
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(WelcomePage.routeName, design: design));
    await tester.pump();

    expect(find.byType(SplashBrandMark), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFFF0F0F0));
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
