import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_material_save_outcome.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_movement_outcome.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_mutation_outcome.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('labels', () {
    test('unit labels localise every supported unit', () {
      expect(inventoryUnits.map(inventoryUnitLabel), <String>[
        'kg',
        'g',
        'L',
        'mL',
        'pc',
        'pack',
        'box',
        'bag',
        'bottle',
        'can',
      ]);
      expect(inventoryUnitLabel('ton'), 'ton');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(inventoryUnitLabel('kg'), 'كجم');
      expect(inventoryUnitLabel('g'), 'جم');
      expect(inventoryUnitLabel('l'), 'لتر');
      expect(inventoryUnitLabel('ml'), 'مل');
      expect(inventoryUnitLabel('piece'), 'قطعة');
      expect(inventoryUnitLabel('bottle'), 'زجاجة');
    });

    test('status labels cover ok, low and out', () {
      expect(inventoryStatusLabel('ok'), S.inStock);
      expect(inventoryStatusLabel('low'), S.lowStock);
      expect(inventoryStatusLabel('out'), S.inventoryStatusOut);
      expect(inventoryStatusLabel('anything'), S.inStock);
    });

    test('type and period filters have readable labels', () {
      expect(
        inventoryTypeFilterLabel(StockMovementTypeFilter.all),
        S.stockMovementAllTypes,
      );
      expect(
        inventoryTypeFilterLabel(StockMovementTypeFilter.receipt),
        S.movementReceipt,
      );
      expect(
        inventoryTypeFilterLabel(StockMovementTypeFilter.issue),
        S.movementIssue,
      );
      expect(
        inventoryTypeFilterLabel(StockMovementTypeFilter.waste),
        S.movementWaste,
      );
      expect(
        inventoryTypeFilterLabel(StockMovementTypeFilter.count),
        S.movementCount,
      );

      expect(inventoryPeriodLabel(StockMovementPeriod.all), S.stockPeriodAll);
      expect(inventoryPeriodLabel(StockMovementPeriod.today), S.today);
      expect(inventoryPeriodLabel(StockMovementPeriod.week), S.stockPeriodWeek);
      expect(
        inventoryPeriodLabel(StockMovementPeriod.month),
        S.stockPeriodMonth,
      );

      expect(
        inventoryStatusFilterLabel(InventoryStatusFilter.all),
        S.inventoryFilterAllStatuses,
      );
      expect(inventoryStatusFilterLabel(InventoryStatusFilter.low), S.lowStock);
      expect(
        inventoryStatusFilterLabel(InventoryStatusFilter.out),
        S.inventoryStatusOut,
      );
    });

    test('movement types map to labels, colors and icons', () {
      expect(
        stockMovementTypeLabel(InventoryMovementType.receipt),
        S.movementReceipt,
      );
      expect(stockMovementTypeLabel(null), '—');
      expect(stockMovementTypeLabelFor('waste'), S.movementWaste);
      expect(stockMovementTypeLabelFor(null), '—');
      expect(
        stockMovementTypeColor(InventoryMovementType.receipt),
        AppColor.trendPositive,
      );
      expect(
        stockMovementTypeColor(InventoryMovementType.issue),
        AppColor.adminInfo,
      );
      expect(
        stockMovementTypeColor(InventoryMovementType.waste),
        AppColor.trendNegative,
      );
      expect(
        stockMovementTypeColor(InventoryMovementType.count),
        AppColor.adminWarning,
      );
      expect(stockMovementTypeColor(null), AppColor.adminMuted);
      expect(stockMovementTypeIcon(InventoryMovementType.receipt), isNotNull);
      expect(stockMovementTypeIcon(InventoryMovementType.count), isNotNull);
    });
  });

  group('quantities', () {
    test('whole quantities are grouped and fraction zeros are trimmed', () {
      expect(inventoryQuantityValue(1250), '1,250');
      expect(inventoryQuantityValue(1250.5), '1,250.5');
      expect(inventoryQuantityValue(0.25), '0.25');
      expect(inventoryQuantityValue(12.000), '12');
    });

    test('quantities carry the localised unit', () {
      expect(inventoryQuantity(1250, 'kg'), '1,250 kg');
      expect(inventoryQuantity(2.5, 'piece'), '2.5 pc');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(inventoryQuantity(1250, 'kg'), '١٬٢٥٠ كجم');
      expect(inventoryQuantity(2.5, 'piece'), '٢٫٥ قطعة');
    });

    test('deltas show their direction', () {
      expect(inventoryDelta(2.5, 'kg'), '+2.5 kg');
      expect(inventoryDelta(-2.5, 'kg'), '−2.5 kg');
      expect(inventoryDelta(0, 'kg'), '0 kg');
    });

    test('money is localised with the currency', () {
      expect(inventoryMoney(1234.5), contains('1,234.50'));
    });

    test('missing dates render a dash', () {
      expect(inventoryDateLabel(null), '—');
      expect(inventoryDateTimeLabel(null), '—');
    });
  });

  group('names', () {
    test('the movement material and branch follow the active language', () {
      const movement = AdminStockMovement(
        id: 1,
        materialNameAr: 'حبوب أرابيكا',
        materialNameEn: 'Arabica beans',
        branchNameAr: 'المعادي',
        branchNameEn: 'Maadi',
      );
      expect(inventoryMovementMaterialName(movement), 'Arabica beans');
      expect(inventoryMovementBranchName(movement), 'Maadi');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(inventoryMovementMaterialName(movement), 'حبوب أرابيكا');
      expect(inventoryMovementBranchName(movement), 'المعادي');
    });

    test('the actor falls back from name to email to system', () {
      const named = AdminStockMovement(
        id: 1,
        actorName: ' Mona Ali ',
        actorEmail: 'mona@example.com',
      );
      const emailOnly = AdminStockMovement(
        id: 2,
        actorEmail: 'staff@example.com',
      );
      const anonymous = AdminStockMovement(id: 3, actorName: '  ');
      expect(inventoryMovementActorName(named), 'Mona Ali');
      expect(inventoryMovementActorName(emailOnly), 'staff@example.com');
      expect(inventoryMovementActorName(anonymous), S.stockMovementSystemActor);
    });

    test('an empty category reads as uncategorised', () {
      expect(inventoryCategoryLabel('  '), S.inventoryNoCategory);
      expect(inventoryCategoryLabel(' ألبان '), 'ألبان');
    });
  });

  group('errors', () {
    test('material saves map to readable messages', () {
      expect(
        materialSaveErrorMessage(InventoryMaterialSaveOutcome.duplicateSku),
        S.materialSaveDuplicateSku,
      );
      expect(
        materialSaveErrorMessage(InventoryMaterialSaveOutcome.unitLocked),
        S.materialSaveUnitLocked,
      );
      expect(
        materialSaveErrorMessage(InventoryMaterialSaveOutcome.saved),
        isEmpty,
      );
    });

    test('deletes map to readable messages', () {
      expect(
        materialMutationErrorMessage(InventoryMutationOutcome.hasMovements),
        S.materialDeleteBlockedMovements,
      );
      expect(
        materialMutationErrorMessage(InventoryMutationOutcome.hasStock),
        S.materialDeleteBlockedStock,
      );
      expect(
        materialMutationErrorMessage(InventoryMutationOutcome.permissionDenied),
        S.materialSavePermissionDenied,
      );
    });

    test('movement outcomes map to readable messages', () {
      expect(
        movementErrorMessage(InventoryMovementOutcome.insufficientStock),
        S.movementInsufficientStock,
      );
      expect(
        movementErrorMessage(InventoryMovementOutcome.noChange),
        S.movementNoChange,
      );
      expect(
        movementErrorMessage(InventoryMovementOutcome.permissionDenied),
        S.movementPermissionDenied,
      );
      expect(movementErrorMessage(InventoryMovementOutcome.success), isEmpty);
    });
  });
}
