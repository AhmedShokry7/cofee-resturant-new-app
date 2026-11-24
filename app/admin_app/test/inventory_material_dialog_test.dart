import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_material_save_outcome.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_material_dialog.dart';

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('new material category is selected from inventory categories', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdminInventoryDraft? savedDraft;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: InventoryMaterialDialog(
            categories: const <AdminInventoryCategoryOption>[
              AdminInventoryCategoryOption(value: 'Beans', count: 4),
            ],
            onSave: (draft) async {
              savedDraft = draft;
              return InventoryMaterialSaveOutcome.saved;
            },
          ),
        ),
      ),
    );

    final categoryPicker = find.byKey(const Key('inventory-material-category'));
    expect(categoryPicker, findsOneWidget);
    await tester.tap(categoryPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beans').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Espresso beans');
    await tester.tap(find.byKey(const Key('inventory-material-save')));
    await tester.pumpAndSettle();

    expect(savedDraft?.category, 'Beans');
    expect(tester.takeException(), isNull);
  });

  testWidgets('new material cannot be saved without an inventory category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var saveCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: InventoryMaterialDialog(
            categories: const <AdminInventoryCategoryOption>[],
            onSave: (draft) async {
              saveCalled = true;
              return InventoryMaterialSaveOutcome.saved;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), 'Espresso beans');
    await tester.tap(find.byKey(const Key('inventory-material-save')));
    await tester.pumpAndSettle();

    expect(saveCalled, isFalse);
    expect(find.text(S.materialNeedsCategory), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
