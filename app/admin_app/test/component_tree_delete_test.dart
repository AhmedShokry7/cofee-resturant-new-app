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
    'the layers panel delete button is tappable, not covered by the drag handle',
    (tester) async {
      // كان فلتر يرسم مقبض سحب افتراضيًا فوق آخر الصف فيغطي زر الحذف؛
      // هذا الاختبار يثبت أن زر الحذف يستجيب للضغط.
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
      expect(find.text('section.text'), findsOneWidget);
      expect(find.text('section.heading'), findsOneWidget);

      // Find the delete tooltips/buttons: each row shows three actions; the
      // delete button is the one bound to onDelete. Tapping the row's delete
      // must call back even though the row sits inside a reorderable list.
      final deleteButtons = find.byTooltip(S.visualEditorDelete);
      expect(deleteButtons, findsNWidgets(2));

      await tester.tap(deleteButtons.last);
      await tester.pump();
      expect(deletedId, 'c2');
    },
  );
}
