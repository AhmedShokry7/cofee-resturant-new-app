import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_section_heading.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/theme_studio_panel.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// ما تسجّله اللوحة من نقرات، لا ما تظن أنها أرسلته.
class _Recorder {
  final List<(DesignColorRole, String)> colors = <(DesignColorRole, String)>[];
  final List<DesignColorRole> cleared = <DesignColorRole>[];
  final List<String> scales = <String>[];
  final List<String> rejections = <String>[];
  int restores = 0;

  String? setColor(DesignColorRole role, String hex) {
    colors.add((role, hex));
    return null;
  }

  void clearColor(DesignColorRole role) => cleared.add(role);

  String? setScale(String key) {
    scales.add(key);
    return null;
  }

  void restoreAll() => restores++;

  void reject(String message) => rejections.add(message);
}

DesignDocument _doc(DesignTheme theme) =>
    WidgetRegistry.defaultDocument().withTheme(theme);

/// لون عنوان المقطع كما رسمته الشاشة: النص نفسه، لا رقم موضعه في الشجرة.
Color? _titleColor(WidgetTester tester, String title) =>
    tester.widget<Text>(find.text(title)).style?.color;

Future<void> _pumpHeading(WidgetTester tester, DesignDocument? document) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SimulatorPaletteScope.forDocument(
          document: document,
          child: const SimulatorSectionHeading(
            title: 'الأكثر طلبًا',
            subtitle: 'ما يختاره الزبائن اليوم',
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required DesignTheme theme,
  required _Recorder recorder,
  bool enabled = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: ThemeStudioPanel(
                theme: theme,
                enabled: enabled,
                onSetColor: recorder.setColor,
                onClearColor: recorder.clearColor,
                onTextScale: recorder.setScale,
                onRestoreAll: recorder.restoreAll,
                onRejection: recorder.reject,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// حقل دور بلغة اللوحة: العنوان نفسه الذي يقرأه الموظف فوق الحقل.
Finder _roleField(String label) => find.descendant(
  of: find.widgetWithText(CustomTextFormField, label),
  matching: find.byType(TextFormField),
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('طبقة الشكل تُرى في الهاتف', () {
    testWidgets('لا كتابة: العنوان على لونه الذي كان عليه', (tester) async {
      late ThemeData host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = Theme.of(context);
              return SimulatorPaletteScope.forDocument(
                document: null,
                child: const SimulatorSectionHeading(title: 'الأكثر طلبًا'),
              );
            },
          ),
        ),
      );
      expect(_titleColor(tester, 'الأكثر طلبًا'), adminHeadingColor(host));
    });

    testWidgets('كتابة النص الأساسي تغيّر الهاتف وحده', (tester) async {
      await _pumpHeading(
        tester,
        _doc(
          const DesignTheme(
            colors: <DesignColorRole, String>{
              DesignColorRole.textPrimary: '#112233',
            },
          ),
        ),
      );
      expect(_titleColor(tester, 'الأكثر طلبًا'), const Color(0xFF112233));
    });

    testWidgets('الدور الغائب يبقى على لونه بجانب الدور المكتوب', (
      tester,
    ) async {
      late ThemeData host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = Theme.of(context);
              return SimulatorPaletteScope.forDocument(
                document: _doc(
                  const DesignTheme(
                    colors: <DesignColorRole, String>{
                      DesignColorRole.textPrimary: '#112233',
                    },
                  ),
                ),
                child: const SimulatorSectionHeading(
                  title: 'الأكثر طلبًا',
                  subtitle: 'ما يختاره الزبائن اليوم',
                ),
              );
            },
          ),
        ),
      );
      expect(_titleColor(tester, 'الأكثر طلبًا'), const Color(0xFF112233));
      // السطر الثانوي لم تُكتب له طبقة: يبقى على لون اللوحة، لا على الأسود الذي
      // اختاره الموظف للعنوان.
      expect(
        _titleColor(tester, 'ما يختاره الزبائن اليوم'),
        adminMutedColor(host),
      );
    });

    testWidgets('مقياس الخط يُضرب في مقياس الجهاز لا يحلّ محلّه', (
      tester,
    ) async {
      late TextScaler scaler;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: SimulatorPaletteScope.forDocument(
              document: _doc(const DesignTheme(textScale: 'large')),
              // القراءة من داخل الطبقة: خارجها يُقرأ مقياس الجهاز وحده وتنجح
              // الشهادة على شيء لم يُختبر.
              child: Builder(
                builder: (context) {
                  scaler = MediaQuery.textScalerOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      // 1.2 الذي اختاره صاحب الجهاز يبقى، والزيادة من المستند تُضرب فيه.
      expect(scaler.scale(10), closeTo(10 * 1.2 * 1.15, 0.001));
    });

    testWidgets('مقياس افتراضي لا يمسّ مقياس الجهاز', (tester) async {
      late TextScaler scaler;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: SimulatorPaletteScope.forDocument(
              document: null,
              child: Builder(
                builder: (context) {
                  scaler = MediaQuery.textScalerOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(scaler.scale(10), 12);
    });

    testWidgets('كل دور في اللوحة له لون يُقرأ من الطبقة', (tester) async {
      for (final role in SimulatorPalette.paintRoles) {
        final palette = SimulatorPalette(
          DesignTheme(colors: <DesignColorRole, String>{role: '#40E0D0'}),
        );
        expect(
          palette.color(role),
          const Color(0xFF40E0D0),
          reason: '${role.key} معروض في اللوحة ولا تُقرأ منه الطبقة',
        );
      }
    });
  });

  group('استوديو الشكل يكتب ما يراه الموظف', () {
    testWidgets('الكتابة الكاملة وحدها تصل إلى المستند', (tester) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: DesignTheme.none,
        recorder: recorder,
      );

      await tester.enterText(_roleField('Primary'), '11');
      await tester.pump();
      expect(recorder.colors, isEmpty);

      await tester.enterText(_roleField('Primary'), '112233');
      await tester.pump();
      expect(recorder.colors, <(DesignColorRole, String)>[
        (DesignColorRole.primary, '#112233'),
      ]);
    });

    testWidgets('الكتابة الخاطئة تبقى في الحقل بخطأ يسمّيه', (tester) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: DesignTheme.none,
        recorder: recorder,
      );

      await tester.enterText(_roleField('Primary'), '#12345#');
      await tester.pumpAndSettle();
      expect(recorder.colors, isEmpty);
      expect(find.text('Colour must be #RRGGBB'), findsOneWidget);
    });

    testWidgets('رجوع الدور يحذف كتابته وحدها', (tester) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: const DesignTheme(
          colors: <DesignColorRole, String>{
            DesignColorRole.primary: '#112233',
            DesignColorRole.border: '#223344',
          },
        ),
        recorder: recorder,
      );

      await tester.tap(find.byTooltip('Restore Primary to the system colour'));
      await tester.pump();
      expect(recorder.cleared, <DesignColorRole>[DesignColorRole.primary]);
    });

    testWidgets('الدور بلا كتابة لا يحمل زرّ رجوع', (tester) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: const DesignTheme(
          colors: <DesignColorRole, String>{
            DesignColorRole.border: '#223344',
          },
        ),
        recorder: recorder,
      );
      // الحدود مكتوبة فالزرّ موجود، والأساسي لا يُعرض زرٌّ لرجوعه لأنه راجع أصلًا.
      expect(
        find.byTooltip('Restore Border to the system colour'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Restore Primary to the system colour'),
        findsNothing,
      );
    });

    testWidgets('مقياس الخط يُختار باسمه', (tester) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: DesignTheme.none,
        recorder: recorder,
      );

      expect(find.text('Default'), findsOneWidget);
      await tester.ensureVisible(find.text('Large'));
      await tester.tap(find.text('Large'));
      await tester.pump();
      expect(recorder.scales, <String>['large']);
    });

    testWidgets('الرجوع للتصميم الأصلي يظهر حين يخالف شيء الأصل', (
      tester,
    ) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: DesignTheme.none,
        recorder: recorder,
      );
      expect(find.text('Restore the original design'), findsNothing);

      await _pumpPanel(
        tester,
        theme: const DesignTheme(
          colors: <DesignColorRole, String>{
            DesignColorRole.surface: '#334455',
          },
        ),
        recorder: recorder,
      );
      await tester.ensureVisible(find.text('Restore the original design'));
      await tester.tap(find.text('Restore the original design'));
      await tester.pumpAndSettle();
      expect(recorder.restores, 1);
    });

    testWidgets('المشاهدة تُقرأ ولا تُكتب', (tester) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: DesignTheme.none,
        recorder: recorder,
        enabled: false,
      );

      // كل حقل تحت يدين لا تكتبان: اللمسة لا تصل للحقل أصلًا.
      for (final role in SimulatorPalette.paintRoles) {
        expect(
          tester
              .widget<IgnorePointer>(
                find.byKey(ValueKey('theme-field-${role.key}')),
              )
              .ignoring,
          isTrue,
          reason: '${role.key} يُكتب في المشاهدة',
        );
      }
      await tester.ensureVisible(find.text('Large'));
      await tester.tap(find.text('Large'));
      await tester.pump();
      expect(recorder.scales, isEmpty);
      expect(find.text('Restore the original design'), findsNothing);
    });

    testWidgets('الأدوار المعروضة هي ما يرسمه الهاتف، لا كل العقد', (
      tester,
    ) async {
      final recorder = _Recorder();
      await _pumpPanel(
        tester,
        theme: DesignTheme.none,
        recorder: recorder,
      );
      for (final role in SimulatorPalette.paintRoles) {
        expect(
          find.text(role.label(AppLanguage.english)),
          findsOneWidget,
          reason: '${role.key} يغلّفه الهاتف فلا يُترك بلا حقل',
        );
      }
      // الأدوار التي لا يقرأها موضع بعد تبقى خارج اللوحة: لا زرّ يلون لا شيء.
      for (final role in DesignColorRole.values) {
        if (SimulatorPalette.paintRoles.contains(role)) continue;
        expect(
          find.text(role.label(AppLanguage.english)),
          findsNothing,
          reason: '${role.key} بلا راسم في المعاينة، فلا يُعرض كإتاحة',
        );
      }
    });
  });
}
