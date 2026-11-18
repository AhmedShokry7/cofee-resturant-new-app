import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';

EditableComponent _component(String id, String type, int index) =>
    EditableComponent(
      componentId: id,
      componentType: type,
      pageId: 'home',
      index: index,
      classification: ComponentClassification.editable,
      properties: const {},
      defaultValues: const {},
      validationRules: const {},
      allowedOperations: const ['reorder', 'delete', 'duplicate', 'hide'],
      version: 1,
    );

void main() {
  test('flat drag positions translate to sibling indices for nested nodes', () {
    final components = [
      _component('root-a', 'column', 0),
      _component('child-a', 'text', 0).copyWith(parentId: 'root-a'),
      _component('child-b', 'text', 1).copyWith(parentId: 'root-a'),
      _component('root-b', 'column', 1),
      _component('child-c', 'text', 0).copyWith(parentId: 'root-b'),
    ];

    expect(
      siblingIndexForFlatReorder(
        components: components,
        oldIndex: 4,
        newIndex: 1,
      ),
      0,
      reason: 'السحب إلى أعلى مجموعة root-b يبقى في فهرس أخوتها صفرًا',
    );
    expect(
      siblingIndexForFlatReorder(
        components: components,
        oldIndex: 1,
        newIndex: 3,
      ),
      1,
      reason: 'النقل إلى نهاية أبناء root-a يحتسب الأخ السابق فقط',
    );
    expect(
      siblingIndexForFlatReorder(
        components: components,
        oldIndex: 0,
        newIndex: 4,
      ),
      1,
      reason: 'تحريك الجذر بعد الجذر الآخر لا يحتسب الأبناء كإخوة',
    );
  });

  testWidgets(
    'search-filtered layers cannot be reordered from filtered indices',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              height: 400,
              child: ComponentTreePanel(
                pageId: 'home',
                components: [
                  _component('c1', 'section.text', 0),
                  _component('c2', 'section.heading', 1),
                ],
                selectedComponentId: null,
                onSelect: (_) {},
                onReorder: (_, _) {},
                onDelete: (_) {},
                onDuplicate: (_) {},
                onToggleVisibility: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'section.text');
      await tester.pumpAndSettle();

      expect(find.text('section.text'), findsAtLeastNWidgets(1));
      expect(find.text('section.heading'), findsNothing);
      expect(find.byType(ReorderableDragStartListener), findsNothing);
    },
  );

  testWidgets(
    'the layers panel exposes delete under secondary actions, not on the row',
    (tester) async {
      // الحذف إجراء ثانوي في قائمة مستقلة لتقليل الحذف العرضي.
      var deletedId = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Material(
              child: SizedBox(
                width: 260,
                height: 400,
                child: ComponentTreePanel(
                  pageId: 'home',
                  components: [
                    _component('c1', 'section.text', 0),
                    _component('c2', 'section.heading', 1),
                  ],
                  selectedComponentId: null,
                  onSelect: (_) {},
                  onReorder: (_, __) {},
                  onDelete: (id) => deletedId = id,
                  onDuplicate: (_) {},
                  onToggleVisibility: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The panel rendered both components (row labels fall back to the raw
      // type when the registry has not been warmed up in the test).
      expect(find.text('section.text'), findsAtLeastNWidgets(1));
      expect(find.text('section.heading'), findsAtLeastNWidgets(1));

      final moreActions = find.byTooltip(S.visualEditorMoreActions);
      expect(moreActions, findsNWidgets(2));
      expect(find.byTooltip(S.visualEditorDelete), findsNothing);

      await tester.tap(moreActions.last);
      await tester.pumpAndSettle();
      expect(find.text(S.visualEditorDelete), findsOneWidget);
      await tester.tap(find.text(S.visualEditorDelete));
      await tester.pumpAndSettle();
      expect(deletedId, 'c2');
    },
  );
}
