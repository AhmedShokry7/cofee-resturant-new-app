import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_movement_outcome.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

typedef MaterialSearchCallback =
    Future<List<AdminInventoryMaterialOption>> Function({
      String? search,
      String? branchId,
    });

typedef RecordMovementCallback = Future<InventoryMovementOutcome> Function(
  AdminStockMovementDraft draft,
);

Future<bool?> showInventoryMovementDialog({
  required BuildContext context,
  required AdminInventoryFilters filters,
  required MaterialSearchCallback searchMaterials,
  required RecordMovementCallback onRecord,
  String? branchId,
  AdminInventoryItem? initialItem,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => InventoryMovementDialog(
      branches: filters.branches,
      initialBranchId: branchId,
      initialItem: initialItem,
      searchMaterials: searchMaterials,
      onRecord: onRecord,
    ),
  );
}

/// Records a receipt, issue, waste or count for one material at one branch.
class InventoryMovementDialog extends StatefulWidget {
  const InventoryMovementDialog({
    super.key,
    required this.branches,
    required this.searchMaterials,
    required this.onRecord,
    this.initialBranchId,
    this.initialItem,
  });

  final List<AdminInventoryBranchOption> branches;
  final String? initialBranchId;
  final AdminInventoryItem? initialItem;
  final MaterialSearchCallback searchMaterials;
  final RecordMovementCallback onRecord;

  @override
  State<InventoryMovementDialog> createState() =>
      _InventoryMovementDialogState();
}

class _InventoryMovementDialogState extends State<InventoryMovementDialog> {
  final _materialSearchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  Timer? _searchDebounce;
  int _searchRequest = 0;
  String? _branchId;
  InventoryMovementType _type = InventoryMovementType.receipt;
  AdminInventoryMaterialOption? _selectedMaterial;
  List<AdminInventoryMaterialOption> _options =
      const <AdminInventoryMaterialOption>[];
  bool _loadingOptions = false;
  bool _optionsFailed = false;
  String? _error;
  bool _saving = false;
  String? _pendingInitialId;

  bool get _needsBranch => widget.branches.length > 1 && _branchId == null;

  @override
  void initState() {
    super.initState();
    final initialBranch = widget.initialBranchId;
    if (initialBranch != null &&
        widget.branches.any((branch) => branch.id == initialBranch)) {
      _branchId = initialBranch;
    } else if (widget.branches.length == 1) {
      _branchId = widget.branches.first.id;
    }
    _pendingInitialId = widget.initialItem?.id;
    if (_branchId != null) {
      final item = widget.initialItem;
      _loadOptions(search: item == null ? null : _initialSearch(item));
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _materialSearchController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _initialSearch(AdminInventoryItem item) {
    final sku = item.sku?.trim() ?? '';
    return sku.isNotEmpty ? sku : item.nameAr;
  }

  Future<void> _loadOptions({String? search}) async {
    final branchId = _branchId;
    if (branchId == null) return;
    final request = ++_searchRequest;
    setState(() {
      _loadingOptions = true;
      _optionsFailed = false;
    });
    try {
      final options = await widget.searchMaterials(
        search: search,
        branchId: branchId,
      );
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _options = options;
        _loadingOptions = false;
      });
      final pendingId = _pendingInitialId;
      if (pendingId != null && _selectedMaterial == null) {
        for (final option in options) {
          if (option.id == pendingId) {
            _selectMaterial(option);
            break;
          }
        }
        _pendingInitialId = null;
      }
    } catch (_) {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _options = const <AdminInventoryMaterialOption>[];
        _loadingOptions = false;
        _optionsFailed = true;
      });
    }
  }

  void _onMaterialSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadOptions(search: value.trim()),
    );
  }

  void _setBranch(String? value) {
    if (value == _branchId) return;
    _searchDebounce?.cancel();
    setState(() {
      _branchId = value;
      _selectedMaterial = null;
      _options = const <AdminInventoryMaterialOption>[];
      _materialSearchController.clear();
      _quantityController.clear();
      _unitCostController.clear();
      _pendingInitialId = null;
      _error = null;
    });
    if (value != null) _loadOptions();
  }

  void _setType(InventoryMovementType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _error = null;
    });
    if (type == InventoryMovementType.count && _selectedMaterial != null) {
      _quantityController.text = _numberForInput(
        _selectedMaterial!.quantityOnHand,
      );
    }
    if (type == InventoryMovementType.receipt &&
        _selectedMaterial != null &&
        _unitCostController.text.trim().isEmpty &&
        _selectedMaterial!.unitCost > 0) {
      _unitCostController.text = _numberForInput(_selectedMaterial!.unitCost);
    }
  }

  void _selectMaterial(AdminInventoryMaterialOption option) {
    setState(() {
      _selectedMaterial = option;
      _error = null;
      if (_type == InventoryMovementType.count) {
        _quantityController.text = _numberForInput(option.quantityOnHand);
      }
      if (_type == InventoryMovementType.receipt && option.unitCost > 0) {
        _unitCostController.text = _numberForInput(option.unitCost);
      }
    });
  }

  void _clearMaterial() {
    _searchDebounce?.cancel();
    setState(() {
      _selectedMaterial = null;
      _options = const <AdminInventoryMaterialOption>[];
      _materialSearchController.clear();
      _quantityController.clear();
      _unitCostController.clear();
      _error = null;
    });
    _loadOptions();
  }

  String _numberForInput(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  double? _parseNumber(String text) {
    final value = normalizeDigits(text.trim()).replaceAll(',', '.');
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  double? get _quantity => _parseNumber(_quantityController.text);

  double? get _balancePreview {
    final material = _selectedMaterial;
    final quantity = _quantity;
    if (material == null || quantity == null) return null;
    final balance = switch (_type) {
      InventoryMovementType.receipt => material.quantityOnHand + quantity,
      InventoryMovementType.issue ||
      InventoryMovementType.waste => material.quantityOnHand - quantity,
      InventoryMovementType.count => quantity,
    };
    return balance < 0 ? null : balance;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final branchId = _branchId;
    if (branchId == null) {
      setState(() => _error = S.movementNeedsBranch);
      return;
    }
    final material = _selectedMaterial;
    if (material == null) {
      setState(() => _error = S.movementNeedsMaterial);
      return;
    }
    final quantity = _quantity;
    if (quantity == null || quantity < 0) {
      setState(() => _error = S.movementNeedsQuantity);
      return;
    }
    if (_type != InventoryMovementType.count && quantity <= 0) {
      setState(() => _error = S.movementNeedsQuantity);
      return;
    }
    double? unitCost;
    if (_type == InventoryMovementType.receipt) {
      final text = _unitCostController.text.trim();
      if (text.isNotEmpty) {
        unitCost = _parseNumber(text);
        if (unitCost == null || unitCost < 0) {
          setState(() => _error = S.movementInvalidCost);
          return;
        }
      }
    }

    final reference = _referenceController.text.trim();
    final note = _noteController.text.trim();
    final draft = AdminStockMovementDraft(
      materialId: material.id,
      branchId: branchId,
      type: _type,
      quantity: quantity,
      unitCost: unitCost,
      reference: reference.isEmpty ? null : reference,
      note: note.isEmpty ? null : note,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await widget.onRecord(draft);
    if (!mounted) return;
    if (outcome == InventoryMovementOutcome.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = movementErrorMessage(outcome);
    });
  }

  void _close() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal:
            MediaQuery.sizeOf(context).width < AppBreakpoints.dialogPadding
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: S.stockMovementTitle,
              subtitle: S.stockMovementSubtitle,
              onClose: _close,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      AdminErrorBanner(message: _error!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      S.movementTypeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColor.greyColor,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in InventoryMovementType.values)
                          ChoiceChip(
                            label: Text(stockMovementTypeLabel(type)),
                            selected: _type == type,
                            showCheckmark: false,
                            avatar: AppIcon(
                              stockMovementTypeIcon(type),
                              size: 15,
                              color: stockMovementTypeColor(type),
                            ),
                            onSelected: (_) => _setType(type),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (widget.branches.isEmpty)
                      Text(
                        S.movementNoBranches,
                        style: const TextStyle(
                          color: AppColor.errorColor,
                          fontSize: AppFontSizes.size10_5,
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _branchId,
                        decoration: InputDecoration(
                          labelText: S.movementBranch,
                        ),
                        items: [
                          for (final branch in widget.branches)
                            DropdownMenuItem(
                              value: branch.id,
                              child: Text(inventoryBranchName(branch)),
                            ),
                        ],
                        onChanged: _saving ? null : _setBranch,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    _buildMaterialPicker(context),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final quantity = _MovementField(
                          controller: _quantityController,
                          label: _type == InventoryMovementType.count
                              ? S.movementCountedQuantity
                              : S.movementQuantity,
                          hint: S.movementQuantityHint,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_quantityFormatter],
                          suffixText: _selectedMaterial == null
                              ? null
                              : inventoryUnitLabel(_selectedMaterial!.unit),
                          onChanged: (_) => setState(() {}),
                        );
                        if (_type != InventoryMovementType.receipt) {
                          return quantity;
                        }
                        return constraints.maxWidth < 480
                            ? Column(
                                children: [
                                  quantity,
                                  const SizedBox(height: AppSpacing.md),
                                  _MovementField(
                                    controller: _unitCostController,
                                    label: S.movementUnitCost,
                                    hint: S.materialUnitCostHint,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [_quantityFormatter],
                                    suffixText: S.currency,
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: quantity),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: _MovementField(
                                      controller: _unitCostController,
                                      label: S.movementUnitCost,
                                      hint: S.materialUnitCostHint,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [_quantityFormatter],
                                      suffixText: S.currency,
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                    if (_selectedMaterial != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _BalancePreview(
                        current: inventoryQuantity(
                          _selectedMaterial!.quantityOnHand,
                          _selectedMaterial!.unit,
                        ),
                        after: _balancePreview == null
                            ? null
                            : inventoryQuantity(
                                _balancePreview!,
                                _selectedMaterial!.unit,
                              ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _MovementField(
                      controller: _referenceController,
                      label: S.reference,
                      hint: S.movementReferenceHint,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MovementField(
                      controller: _noteController,
                      label: S.materialNotes,
                      hint: S.movementNoteHint,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              onCancel: _close,
              onSave: _submit,
              saveKey: const Key('inventory-movement-save'),
              saveLabel: S.movementSave,
              savingLabel: S.movementSaving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialPicker(BuildContext context) {
    final theme = Theme.of(context);
    if (_needsBranch) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: adminTintedSurfaceColor(theme),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            AppIcon(
              AppIcons.warehouse,
              size: 16,
              color: adminMutedColor(theme),
            ),
            const SizedBox(width: AppSizes.px8),
            Text(
              S.movementSelectBranch,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size10_5,
              ),
            ),
          ],
        ),
      );
    }

    final selected = _selectedMaterial;
    if (selected != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: adminTintedSurfaceColor(theme),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: adminCardBorderColor(theme)),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.package, size: 18, color: AppColor.adminAccent),
            const SizedBox(width: AppSizes.px8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.nameFor(AppLocale.instance.language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11_5,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  Text(
                    [
                      if ((selected.sku ?? '').trim().isNotEmpty)
                        selected.sku!.trim(),
                      '${S.movementCurrentStock}: '
                          '${inventoryQuantity(selected.quantityOnHand, selected.unit)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: S.clearSearch,
              onPressed: _saving ? null : _clearMaterial,
              style: IconButton.styleFrom(
                fixedSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: AppIcon(
                AppIcons.cancel01,
                size: 16,
                color: adminMutedColor(theme),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _materialSearchController,
          onChanged: _onMaterialSearch,
          decoration: InputDecoration(
            labelText: S.movementMaterial,
            hintText: S.movementMaterialSearch,
            prefixIcon: AppIcon(
              AppIcons.search01,
              size: 17,
              color: adminMutedColor(theme),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.px8),
        Container(
          height: 152,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _loadingOptions
              ? const Center(
                  child: SizedBox(
                    width: AppSizes.px20,
                    height: AppSizes.px20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _optionsFailed
              ? Center(
                  child: Text(
                    S.movementFailed,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size10,
                    ),
                  ),
                )
              : _options.isEmpty
              ? Center(
                  child: Text(
                    S.movementNoMaterials,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size10,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _options.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: adminRowBorderColor(theme)),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return InkWell(
                      onTap: () => _selectMaterial(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.nameFor(AppLocale.instance.language),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: adminBodyColor(theme),
                                      fontSize: AppFontSizes.size10_5,
                                      fontWeight: AppFontWeights.semiBold,
                                      height: AppTextHeights.line1_5,
                                    ),
                                  ),
                                  Text(
                                    [
                                      if ((option.sku ?? '').trim().isNotEmpty)
                                        option.sku!.trim(),
                                      inventoryQuantity(
                                        option.quantityOnHand,
                                        option.unit,
                                      ),
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: adminSubtleColor(theme),
                                      fontSize: AppFontSizes.size8_5,
                                      height: AppTextHeights.line1_5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppIcon(
                              AppIcons.arrowRight01,
                              size: 15,
                              color: adminMutedColor(theme),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

final _quantityFormatter = FilteringTextInputFormatter.allow(
  RegExp('[0-9٠-٩.,٫]'),
);

class _BalancePreview extends StatelessWidget {
  const _BalancePreview({required this.current, this.after});

  final String current;
  final String? after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        Text(
          '${S.movementCurrentStock}: $current',
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9_5,
            height: AppTextHeights.line1_5,
          ),
        ),
        if (after != null)
          Text(
            '${S.stockMovementBalanceAfter}: $after',
            style: TextStyle(
              color: AppColor.adminAccent,
              fontSize: AppFontSizes.size9_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
      ],
    );
  }
}

class _MovementField extends StatelessWidget {
  const _MovementField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.suffixText,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLines: maxLines,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      alignLabelWithHint: maxLines > 1,
    ),
  );
}
