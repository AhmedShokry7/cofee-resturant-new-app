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
  testWidgets('the layers panel delete button is tappable, not covered by the drag handle', (
    tester,
  ) async {
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
  });
}
