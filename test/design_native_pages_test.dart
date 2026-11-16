import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_document.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_hero_image.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_body.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_title.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'support/fake_design_repository.dart';

/// شاشات التطبيق المدمجة تقرأ طبقتها من المستند المنشور: نصّ وصورة منشوران
/// يعلوان على أصل الشاشة، وإخفاء منشور يُسقط المكوّن، وغياب العقدة يترك
/// الشاشة كما رسمها المصدر.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required PublishedDesign? design,
  }) async {
    final cubit = DesignCubit(repository: FakeDesignRepository(design));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<DesignCubit>.value(
        value: cubit,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await cubit.load();
    await tester.pump();
  }

  group('the welcome screen', () {
    testWidgets('a published hero image replaces the bundled photo', (
      tester,
    ) async {
      await pump(
        tester,
        const WelcomeHeroImage(),
        design: const PublishedDesign(
          schemaVersion: 2,
          extraSections: {
            'welcome': [
              PublishedSection(
                id: 'w_hero',
                type: 'welcome.hero',
                properties: {
                  'imageUrl': 'https://cdn.example.com/hero.jpg',
                  'fit': 'contain',
                  'alignment': 'center',
                },
              ),
            ],
          },
        ),
      );

      final image = tester.widget<DbImage>(find.byType(DbImage));
      expect(image.image, 'https://cdn.example.com/hero.jpg');
      expect(image.fit, BoxFit.contain);
      expect(image.alignment, Alignment.center);
    });

    testWidgets('no hero node keeps the bundled photo', (tester) async {
      await pump(tester, const WelcomeHeroImage(), design: PublishedDesign.none);

      expect(find.byType(DbImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a hidden hero node takes the photo off the screen', (
      tester,
    ) async {
      await pump(
        tester,
        const WelcomeHeroImage(),
        design: const PublishedDesign(
          schemaVersion: 2,
          extraSections: {
            'welcome': [
              PublishedSection(
                id: 'w_hero',
                type: 'welcome.hero',
                visible: false,
              ),
            ],
          },
        ),
      );

      expect(find.byType(DbImage), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('a published title parts replace the copy, sized', (
      tester,
    ) async {
      await pump(
        tester,
        const WelcomeViewTextTitle(),
        design: const PublishedDesign(
          schemaVersion: 2,
          extraSections: {
            'welcome': [
              PublishedSection(
                id: 'w_title',
                type: 'welcome.title',
                properties: {'highlight': 'قهوتك', 'rest': 'على كيفك', 'size': '30'},
              ),
            ],
          },
        ),
      );

      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(WelcomeViewTextTitle),
          matching: find.byType(Text),
        ),
      );
      final spans = (title.textSpan as TextSpan).children!;
      final highlight = spans.first as TextSpan;
      expect(highlight.text, 'قهوتك');
      expect(highlight.style!.fontSize, 30);
      final rest = spans.last as TextSpan;
      expect(rest.text, 'على كيفك');
    });

    testWidgets('a hidden title is off the screen', (tester) async {
      await pump(
        tester,
        const WelcomeViewTextTitle(),
        design: const PublishedDesign(
          schemaVersion: 2,
          extraSections: {
            'welcome': [
              PublishedSection(id: 'w_title', type: 'welcome.title', visible: false),
            ],
          },
        ),
      );

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a published body replaces the description', (tester) async {
      await pump(
        tester,
        const WelcomeViewTextBody(),
        design: const PublishedDesign(
          schemaVersion: 2,
          extraSections: {
            'welcome': [
              PublishedSection(
                id: 'w_body',
                type: 'welcome.body',
                properties: {'text': 'جاهز تبدأ؟', 'size': '18'},
              ),
            ],
          },
        ),
      );

      final body = tester.widget<Text>(find.text('جاهز تبدأ؟'));
      expect(body.style!.fontSize, 18);
    });

    testWidgets('a bilingual body shows each language its own text', (
      tester,
    ) async {
      const design = PublishedDesign(
        schemaVersion: 2,
        extraSections: {
          'welcome': [
            PublishedSection(
              id: 'w_body',
              type: 'welcome.body',
              properties: {'text_ar': 'بالعربي', 'text_en': 'In English'},
            ),
          ],
        },
      );
      AppLocale.instance.debugSet(AppLanguage.arabic);
      await pump(tester, const WelcomeViewTextBody(), design: design);
      expect(find.text('بالعربي'), findsOneWidget);
      expect(find.text('In English'), findsNothing);

      AppLocale.instance.debugSet(AppLanguage.english);
      await tester.pumpWidget(
        BlocProvider<DesignCubit>.value(
          value: DesignCubit(repository: FakeDesignRepository(design)),
          child: const MaterialApp(
            home: Scaffold(body: WelcomeViewTextBody()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('In English'), findsOneWidget);
      expect(find.text('بالعربي'), findsNothing);
      AppLocale.instance.debugSet(AppLanguage.arabic);
    });
  });

  group('the onboarding slides', () {
    test('each onboarding.slide node is one slide, in published order', () {
      final slides = onboardingSlidesFrom(const [
        PublishedSection(
          id: 's1',
          type: 'onboarding.slide',
          properties: {'imageUrl': 'https://cdn.example.com/1.jpg'},
        ),
        PublishedSection(
          id: 's2',
          type: 'onboarding.slide',
          properties: {'title': 'العنوان الثاني'},
        ),
      ]);

      expect(slides, hasLength(2));
      expect(slides[0].image, 'https://cdn.example.com/1.jpg');
      expect(slides[1].title, 'العنوان الثاني');
      // نصّ ناقص يسقط على شريحة المصدر بالمكان نفسه، فلا شريحة فارغة.
      expect(slides[0].title, isNotEmpty);
      expect(slides[1].image, isNotEmpty);
    });

    test('the slide speaks both languages: the UI language wins, the other falls back', () async {
      SharedPreferences.setMockInitialValues({});
      await AppLocale.instance.setLanguage(AppLanguage.english);
      addTearDown(() => AppLocale.instance.setLanguage(AppLanguage.arabic));

      final slides = onboardingSlidesFrom(const [
        PublishedSection(
          id: 's1',
          type: 'onboarding.slide',
          properties: {
            'title_ar': 'كل ما تحب',
            'title_en': 'Everything You Love',
            'body_ar': 'وصف عربي منشور',
            'body_en': 'Published English body',
          },
        ),
        PublishedSection(
          id: 's2',
          type: 'onboarding.slide',
          properties: {'title_en': 'English only'},
        ),
      ]);

      // عربي/إنجليزي منشوران يعلوان على أصل الشريحة في اللغة المعروضة،
      // والإنجليزي المنشور وحده يُقرأ في الواجهة الإنجليزية لا يُسقط.
      expect(slides, hasLength(2));
      expect(slides[0].title, 'Everything You Love');
      expect(slides[0].body, 'Published English body');
      expect(slides[1].title, 'English only');
    });

    test('a hidden slide node drops out of the order', () {
      final slides = onboardingSlidesFrom(const [
        PublishedSection(
          id: 's1',
          type: 'onboarding.slide',
          visible: false,
          properties: {'title': 'مخفية'},
        ),
        PublishedSection(id: 's2', type: 'onboarding.slide'),
      ]);

      expect(slides, hasLength(1));
      expect(slides.first.title, isNot('مخفية'));
    });

    test('no slide nodes means the source slides', () {
      final slides = onboardingSlidesFrom(const []);

      expect(slides, hasLength(3));
      expect(slides[0].image, isNotEmpty);
    });

    test('transition settings come from the node, gaps fall back', () {
      final configured = onboardingTransitionFrom(const [
        PublishedSection(
          id: 't',
          type: 'onboarding.transition',
          properties: {'durationMs': '400', 'seconds': '4'},
        ),
      ]);
      expect(configured.slideDuration, const Duration(milliseconds: 400));
      expect(configured.autoAdvance, const Duration(seconds: 4));

      final absent = onboardingTransitionFrom(const []);
      expect(absent.slideDuration, isNull);
      expect(absent.autoAdvance, isNull);

      // صفر يعني لا تقديم تلقائي، ومدة أقصر من أن تُرى تعني أصل الحركة.
      final zeroed = onboardingTransitionFrom(const [
        PublishedSection(
          id: 't',
          type: 'onboarding.transition',
          properties: {'durationMs': '10', 'seconds': '0'},
        ),
      ]);
      expect(zeroed.slideDuration, isNull);
      expect(zeroed.autoAdvance, isNull);
    });
  });

  group('native node lookup', () {
    test('the first node of the type wins and hidden is an explicit no', () {
      const sections = [
        PublishedSection(id: 'a', type: 'welcome.hero', visible: false),
        PublishedSection(id: 'b', type: 'welcome.hero'),
      ];
      final node = nativeSection(sections, 'welcome.hero');
      expect(node?.id, 'a');
      expect(nativeHidden(node), isTrue);
      expect(nativeHidden(null), isFalse);
    });
  });

  group('bilingual property lookup', () {
    test('the current language wins, the other falls back, legacy last', () {
      const section = PublishedSection(
        id: 's',
        type: 'welcome.body',
        properties: {'text_en': 'English only', 'text': 'legacy'},
      );
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(section.localizedText('text'), 'English only');
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(section.localizedText('text'), 'English only');
      const legacy = PublishedSection(
        id: 's',
        type: 'welcome.body',
        properties: {'text': 'legacy'},
      );
      expect(legacy.localizedText('text'), 'legacy');
      AppLocale.instance.debugSet(AppLanguage.arabic);
    });
  });
}
