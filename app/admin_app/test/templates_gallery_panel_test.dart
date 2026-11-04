import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_template.dart';
import 'package:admin_app/features/customer_preview/domain/registry/template_registry.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/templates_gallery_panel.dart';

/// ما تسجّله اللوحة من نقرات، لا ما تظن أنها أرسلته.
class _Recorder {
  final List<AppTemplate> builtIn = <AppTemplate>[];
  final List<String> saved = <String>[];
  final List<String> deleted = <String>[];
  final List<String> names = <String>[];

  /// ما ترجعه اللوحة للمحرّر عند الحفظ: false تعني أن القاعدة ردّت بالرفض.
  bool accepts = true;

  Future<bool> save(String name) async {
    names.add(name);
    return accepts;
  }
}

Finder _field() => find.descendant(
  of: find.byKey(const ValueKey('template-name-field')),
  matching: find.byType(TextFormField),
);

Future<void> _pump(
  WidgetTester tester, {
  List<DesignTemplate> saved = const <DesignTemplate>[],
  bool enabled = true,
  required _Recorder recorder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: TemplatesGalleryPanel(
                saved: saved,
                enabled: enabled,
                onApplyBuiltIn: recorder.builtIn.add,
                onApplySaved: recorder.saved.add,
                onSave: recorder.save,
                onDelete: recorder.deleted.add,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('ما يعرضه المعرض', () {
    testWidgets('المضمّنات بأسمائها وملاحظاتها، ولا صفوف وهمية', (
      tester,
    ) async {
      await _pump(tester, recorder: _Recorder());

      for (final template in TemplateRegistry.builtIns) {
        expect(
          find.text(template.name(AppLanguage.english)),
          findsOneWidget,
        );
        expect(
          find.text(template.note(AppLanguage.english)),
          findsOneWidget,
          reason: '${template.slug} بلا سطر يقول للموظف ماذا يتغيّر.',
        );
      }
      // لا شيء محفوظ بعد: اللوحة تقول ذلك ولا تملأ نفسها بقالب مخترع.
      expect(find.textContaining('No saved template yet'), findsOneWidget);
    });

    testWidgets('القالب المحفوظ باسمه وتاريخه، والصف بلا تاريخ يظهر بلا تاريخ',
        (tester) async {
      await _pump(
        tester,
        recorder: _Recorder(),
        saved: <DesignTemplate>[
          DesignTemplate(
            id: 't1',
            name: 'My arrangement',
            schemaVersion: 2,
            updatedAt: DateTime.utc(2026, 11, 4, 12),
          ),
          DesignTemplate(
            id: 't2',
            name: 'Undated',
            schemaVersion: 2,
            updatedAt: DateTime.utc(1970),
          ),
        ],
      );

      expect(find.text('My arrangement'), findsOneWidget);
      expect(find.text('2026-11-04'), findsOneWidget);
      // تاريخ مختلَق يخدع الموظف في مقارنة قوالبه.
      expect(find.textContaining('1970'), findsNothing);
    });
  });

  group('النقر في اللوحة', () {
    testWidgets('التطبيق يرسل القالب نفسه لا اسمه، والحذف يرسل المعرّف', (
      tester,
    ) async {
      final recorder = _Recorder();
      await _pump(
        tester,
        recorder: recorder,
        saved: <DesignTemplate>[
          DesignTemplate(
            id: 't1',
            name: 'My arrangement',
            schemaVersion: 2,
            updatedAt: DateTime.utc(2026, 11, 4, 12),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('template-apply-Quick Order')));
      await tester.tap(find.byKey(const Key('template-apply-My arrangement')));
      await tester.tap(find.byKey(const Key('template-delete-My arrangement')));
      await tester.pumpAndSettle();

      expect(recorder.builtIn.map((t) => t.slug), <String>['quick-order']);
      expect(recorder.saved, <String>['t1']);
      expect(recorder.deleted, <String>['t1']);
    });

    testWidgets('المشاهدة تقرأ ولا تُطبّق: لا زرّ يعمل', (tester) async {
      final recorder = _Recorder();
      await _pump(tester, enabled: false, recorder: recorder);

      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('template-apply-Today’s layout')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('template-save-button')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('template-apply-Quick Order')));
      await tester.pumpAndSettle();
      expect(recorder.builtIn, isEmpty);
    });
  });

  group('الحفظ باسم', () {
    testWidgets('اسم فارغ يُقال في الحقل ولا يصل إلى المحرّر', (tester) async {
      final recorder = _Recorder();
      await _pump(tester, recorder: recorder);

      await tester.tap(find.byKey(const ValueKey('template-save-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Give the template a name before saving.'),
        findsOneWidget,
      );
      expect(recorder.names, isEmpty);
    });

    testWidgets('ما قبلته القاعدة يمسح الحقل، وما رفضته يبقيه بلا رسالة مخترعة',
        (tester) async {
      final recorder = _Recorder();
      await _pump(tester, recorder: recorder);

      await tester.enterText(_field(), 'Summer menu');
      await tester.tap(find.byKey(const ValueKey('template-save-button')));
      await tester.pumpAndSettle();

      expect(recorder.names, <String>['Summer menu']);
      expect(tester.widget<TextFormField>(_field()).controller?.text, isEmpty);

      // الرفض سببه في لوحة الحالة التي يملكها المحرّر، فلا رسالة ثانية هنا.
      recorder.accepts = false;
      await tester.enterText(_field(), 'Broken');
      await tester.tap(find.byKey(const ValueKey('template-save-button')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(_field()).controller?.text,
        'Broken',
      );
      expect(find.textContaining('did not come back'), findsNothing);
    });
  });
}
