import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/data/repositories/admin_inventory_repository.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';

const inventoryUnits = <String>[
  'kg',
  'g',
  'l',
  'ml',
  'piece',
  'pack',
  'box',
  'bag',
  'bottle',
  'can',
];

String inventoryUnitLabel(String unit) => switch (unit) {
  'kg' => S.inventoryUnitKg,
  'g' => S.inventoryUnitGram,
  'l' => S.inventoryUnitLiter,
  'ml' => S.inventoryUnitMilliliter,
  'piece' => S.inventoryUnitPiece,
  'pack' => S.inventoryUnitPack,
  'box' => S.inventoryUnitBox,
  'bag' => S.inventoryUnitBag,
  'bottle' => S.inventoryUnitBottle,
  'can' => S.inventoryUnitCan,
  _ => unit,
};

String inventoryStatusLabel(String status) => switch (status) {
  'out' => S.inventoryStatusOut,
  'low' => S.lowStock,
  _ => S.inStock,
};

Color inventoryStatusColor(String status) => switch (status) {
  'out' => AppColor.trendNegative,
  'low' => AppColor.adminWarning,
  _ => AppColor.trendPositive,
};

IconData inventoryStatusIcon(String status) => switch (status) {
  'out' => HugeIcons.strokeRoundedPackageRemove,
  'low' => HugeIcons.strokeRoundedAlert02,
  _ => HugeIcons.strokeRoundedPackage,
};

String inventoryTypeFilterLabel(StockMovementTypeFilter filter) =>
    switch (filter) {
      StockMovementTypeFilter.all => S.stockMovementAllTypes,
      StockMovementTypeFilter.receipt => S.movementReceipt,
      StockMovementTypeFilter.issue => S.movementIssue,
      StockMovementTypeFilter.waste => S.movementWaste,
      StockMovementTypeFilter.count => S.movementCount,
    };

String inventoryPeriodLabel(StockMovementPeriod period) => switch (period) {
  StockMovementPeriod.all => S.stockPeriodAll,
  StockMovementPeriod.today => S.today,
  StockMovementPeriod.week => S.stockPeriodWeek,
  StockMovementPeriod.month => S.stockPeriodMonth,
};

String inventoryStatusFilterLabel(InventoryStatusFilter filter) =>
    switch (filter) {
      InventoryStatusFilter.all => S.inventoryFilterAllStatuses,
      InventoryStatusFilter.out => S.inventoryStatusOut,
      InventoryStatusFilter.low => S.lowStock,
      InventoryStatusFilter.ok => S.inStock,
    };

String stockMovementTypeLabel(InventoryMovementType? type) => switch (type) {
  InventoryMovementType.receipt => S.movementReceipt,
  InventoryMovementType.issue => S.movementIssue,
  InventoryMovementType.waste => S.movementWaste,
  InventoryMovementType.count => S.movementCount,
  null => '—',
};

String stockMovementTypeLabelFor(String? value) =>
    stockMovementTypeLabel(InventoryMovementType.fromValue(value));

Color stockMovementTypeColor(InventoryMovementType? type) => switch (type) {
  InventoryMovementType.receipt => AppColor.trendPositive,
  InventoryMovementType.issue => AppColor.adminInfo,
  InventoryMovementType.waste => AppColor.trendNegative,
  InventoryMovementType.count => AppColor.adminWarning,
  null => AppColor.adminMuted,
};

IconData stockMovementTypeIcon(InventoryMovementType? type) => switch (type) {
  InventoryMovementType.receipt => HugeIcons.strokeRoundedArrowDown01,
  InventoryMovementType.issue => HugeIcons.strokeRoundedArrowUp01,
  InventoryMovementType.waste => HugeIcons.strokeRoundedDelete02,
  InventoryMovementType.count => HugeIcons.strokeRoundedClipboard,
  null => HugeIcons.strokeRoundedExchange01,
};

/// A grouped quantity without its unit, e.g. `1,250.5`.
String inventoryQuantityValue(num value) {
  final fixed = value.abs().toDouble().toStringAsFixed(3);
  final parts = fixed.split('.');
  final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
  final whole = formatCount(int.parse(parts[0]));
  return fraction.isEmpty ? whole : '$whole.$fraction';
}

String inventoryQuantity(num value, String unit) =>
    '${localizeDigits(inventoryQuantityValue(value))} '
    '${inventoryUnitLabel(unit)}';

String inventoryDelta(num value, String unit) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '−'
      : '';
  return '$sign${localizeDigits(inventoryQuantityValue(value))} '
      '${inventoryUnitLabel(unit)}';
}

String inventoryMoney(num value) => formatMoneyWithCurrency(value);

String inventoryDateLabel(DateTime? value) =>
    value == null ? '—' : localizedDate(value);

String inventoryDateTimeLabel(DateTime? value) =>
    value == null ? '—' : localizedDateTime(value);

String inventoryRelativeLabel(DateTime? value) => localizedRelativeDay(
  value,
  todayLabel: S.today,
  yesterdayLabel: S.yesterday,
);

String inventoryMaterialName(AdminInventoryItem item) =>
    item.nameFor(AppLocale.instance.language);

String inventoryBranchName(AdminInventoryBranchOption branch) =>
    branch.nameFor(AppLocale.instance.language);

String inventoryMovementMaterialName(AdminStockMovement movement) =>
    movement.materialNameFor(AppLocale.instance.language);

String inventoryMovementBranchName(AdminStockMovement movement) =>
    movement.branchNameFor(AppLocale.instance.language);

String inventoryMovementActorName(AdminStockMovement movement) {
  final name = movement.actorName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = movement.actorEmail?.trim();
  if (email != null && email.isNotEmpty) return email;
  return S.stockMovementSystemActor;
}

String inventoryCategoryLabel(String category) =>
    category.trim().isEmpty ? S.inventoryNoCategory : category.trim();

String materialSaveErrorMessage(
  InventoryMaterialSaveOutcome outcome,
) => switch (outcome) {
  InventoryMaterialSaveOutcome.saved => '',
  InventoryMaterialSaveOutcome.duplicateSku => S.materialSaveDuplicateSku,
  InventoryMaterialSaveOutcome.invalidName => S.materialNeedsName,
  InventoryMaterialSaveOutcome.invalidSku => S.materialSaveInvalidSku,
  InventoryMaterialSaveOutcome.invalidCategory => S.materialSaveInvalidCategory,
  InventoryMaterialSaveOutcome.invalidUnit => S.materialSaveInvalidUnit,
  InventoryMaterialSaveOutcome.invalidCost => S.materialSaveInvalidCost,
  InventoryMaterialSaveOutcome.invalidReorder => S.materialSaveInvalidReorder,
  InventoryMaterialSaveOutcome.invalidNotes => S.materialSaveInvalidNotes,
  InventoryMaterialSaveOutcome.unitLocked => S.materialSaveUnitLocked,
  InventoryMaterialSaveOutcome.notFound => S.materialSaveNotFound,
  InventoryMaterialSaveOutcome.permissionDenied =>
    S.materialSavePermissionDenied,
  InventoryMaterialSaveOutcome.failed => S.materialSaveFailed,
};

String materialMutationErrorMessage(InventoryMutationOutcome outcome) =>
    switch (outcome) {
      InventoryMutationOutcome.success => '',
      InventoryMutationOutcome.notFound => S.materialSaveNotFound,
      InventoryMutationOutcome.hasMovements => S.materialDeleteBlockedMovements,
      InventoryMutationOutcome.hasStock => S.materialDeleteBlockedStock,
      InventoryMutationOutcome.inUse => S.materialDeleteInUse,
      InventoryMutationOutcome.permissionDenied =>
        S.materialSavePermissionDenied,
      InventoryMutationOutcome.failed => S.materialMutationFailed,
    };

String movementErrorMessage(InventoryMovementOutcome outcome) =>
    switch (outcome) {
      InventoryMovementOutcome.success => '',
      InventoryMovementOutcome.materialNotFound => S.movementMaterialNotFound,
      InventoryMovementOutcome.invalidBranch => S.movementInvalidBranch,
      InventoryMovementOutcome.invalidType => S.materialSaveInvalidUnit,
      InventoryMovementOutcome.invalidQuantity => S.movementNeedsQuantity,
      InventoryMovementOutcome.invalidCost => S.movementInvalidCost,
      InventoryMovementOutcome.insufficientStock => S.movementInsufficientStock,
      InventoryMovementOutcome.noChange => S.movementNoChange,
      InventoryMovementOutcome.permissionDenied => S.movementPermissionDenied,
      InventoryMovementOutcome.failed => S.movementFailed,
    };
