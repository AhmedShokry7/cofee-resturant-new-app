import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_category_mutation_outcome.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_categories_dialog.dart';

const _categories = <AdminInventoryCategoryOption>[
  AdminInventoryCategoryOption(value: 'Beans', count: 2),
  AdminInventoryCategoryOption(value: 'Milk', count: 3),
];

Future<void> _pumpCategories(
  WidgetTester tester, {
  List<AdminInventoryCategoryOption> categories = _categories,
  Future<InventoryCategoryMutationOutcome> Function(String name)? onCreate,
  Future<InventoryCategoryMutationOutcome> Function({
    required String currentName,
    required String newName,
  })?
  onRename,
  Future<InventoryCategoryMutationOutcome> Function({
    required String name,
    String? reassignTo,
  })?
  onDelete,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showInventoryCategoriesDialog(
              context: context,
              categories: categories,
              selectedCategory: null,
              onSelected: (_) {},
              onCreate: onCreate,
              onRename: onRename,
              onDelete: onDelete,
            ),
            child: const Text('Open categories'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open categories'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('adds an inventory category', (tester) async {
    String? created;
    await _pumpCategories(
      tester,
      onCreate: (name) async {
        created = name;
        return InventoryCategoryMutationOutcome.success;
      },
    );

    await tester.tap(find.byKey(const Key('inventory-category-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('inventory-category-name')),
      'Packaging',
    );
    await tester.tap(find.byKey(const Key('inventory-category-name-save')));
    await tester.pumpAndSettle();

    expect(created, 'Packaging');
    expect(tester.takeException(), isNull);
  });

  testWidgets('renames a category', (tester) async {
    String? oldName;
    String? renamed;
    await _pumpCategories(
      tester,
      onRename: ({required currentName, required newName}) async {
        oldName = currentName;
        renamed = newName;
        return InventoryCategoryMutationOutcome.success;
      },
    );

    await tester.tap(find.byKey(const Key('inventory-category-edit-Beans')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('inventory-category-name')),
      'Coffee beans',
    );
    await tester.tap(find.byKey(const Key('inventory-category-name-save')));
    await tester.pumpAndSettle();

    expect(oldName, 'Beans');
    expect(renamed, 'Coffee beans');
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes a category after choosing where to move its materials', (
    tester,
  ) async {
    String? deleted;
    String? reassignedTo;
    await _pumpCategories(
      tester,
      onDelete: ({required name, reassignTo}) async {
        deleted = name;
        reassignedTo = reassignTo;
        return InventoryCategoryMutationOutcome.success;
      },
    );

    await tester.tap(find.byKey(const Key('inventory-category-delete-Beans')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-category-reassign')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('inventory-category-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(deleted, 'Beans');
    expect(reassignedTo, 'Milk');
    expect(tester.takeException(), isNull);
  });
}
