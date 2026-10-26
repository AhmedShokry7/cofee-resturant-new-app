import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_material_save_outcome.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_inventory_cubit.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';

Future<bool?> showInventoryMaterialCreateDialog({
  required BuildContext context,
  required AdminInventoryCubit cubit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => InventoryMaterialDialog(onSave: cubit.saveMaterial),
  );
}

Future<bool?> showInventoryMaterialEditDialog({
  required BuildContext context,
  required AdminInventoryCubit cubit,
  required AdminInventoryItem item,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        InventoryMaterialDialog(initialItem: item, onSave: cubit.saveMaterial),
  );
}

/// Creates or edits a raw material: identity, unit, cost and reorder level.
class InventoryMaterialDialog extends StatefulWidget {
  const InventoryMaterialDialog({
    super.key,
    required this.onSave,
    this.initialItem,
  });

  final Future<InventoryMaterialSaveOutcome> Function(AdminInventoryDraft draft)
  onSave;
  final AdminInventoryItem? initialItem;

  @override
  State<InventoryMaterialDialog> createState() =>
      _InventoryMaterialDialogState();
}

class _InventoryMaterialDialogState extends State<InventoryMaterialDialog> {
  late final TextEditingController _skuController;
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _categoryController;
  late final TextEditingController _unitCostController;
  late final TextEditingController _reorderController;
  late final TextEditingController _notesController;
  late String _unit;
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.initialItem != null;

  bool get _unitLocked =>
      _isEditing && widget.initialItem!.lastMovementAt != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _skuController = TextEditingController(text: item?.sku ?? '');
    _nameArController = TextEditingController(text: item?.nameAr ?? '');
    _nameEnController = TextEditingController(text: item?.nameEn ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _unitCostController = TextEditingController(
      text: item == null ? '' : _numberForInput(item.unitCost),
    );
    _reorderController = TextEditingController(
      text: item == null ? '' : _numberForInput(item.reorderLevel),
    );
    _notesController = TextEditingController(text: item?.notes ?? '');
    _unit = item?.unit ?? 'piece';
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _categoryController.dispose();
    _unitCostController.dispose();
    _reorderController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _numberForInput(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  double? _parseNumber(String text) {
    final value = normalizeDigits(text.trim()).replaceAll(',', '.');
    if (value.isEmpty) return 0;
    return double.tryParse(value);
  }

  Future<void> _submit() async {
    if (_saving) return;

    final nameAr = _nameArController.text.trim();
    if (nameAr.isEmpty) {
      setState(() => _error = S.materialNeedsName);
      return;
    }
    final sku = _skuController.text.trim().toUpperCase();
    if (sku.isNotEmpty &&
        !RegExp(r'^[A-Z0-9][A-Z0-9._-]{0,39}$').hasMatch(sku)) {
      setState(() => _error = S.materialSaveInvalidSku);
      return;
    }
    final category = _categoryController.text.trim();
    if (category.length > 80) {
      setState(() => _error = S.materialSaveInvalidCategory);
      return;
    }
    final unitCost = _parseNumber(_unitCostController.text);
    if (unitCost == null || unitCost < 0) {
      setState(() => _error = S.materialSaveInvalidCost);
      return;
    }
    final reorder = _parseNumber(_reorderController.text);
    if (reorder == null || reorder < 0) {
      setState(() => _error = S.materialSaveInvalidReorder);
      return;
    }
    final notes = _notesController.text.trim();
    if (notes.length > 500) {
      setState(() => _error = S.materialSaveInvalidNotes);
      return;
    }
    final nameEn = _nameEnController.text.trim();

    final draft = AdminInventoryDraft(
      id: widget.initialItem?.id,
      sku: sku.isEmpty ? null : sku,
      nameAr: nameAr,
      nameEn: nameEn.isEmpty ? null : nameEn,
      category: category,
      unit: _unit,
      unitCost: unitCost,
      reorderLevel: reorder,
      notes: notes.isEmpty ? null : notes,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await widget.onSave(draft);
    if (!mounted) return;
    if (outcome == InventoryMaterialSaveOutcome.saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = materialSaveErrorMessage(outcome);
    });
  }

  void _close() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.initialItem;
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
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: item == null ? S.addRawMaterial : S.editRawMaterial,
              subtitle: item == null
                  ? S.inventorySubtitle
                  : (item.sku?.trim().isNotEmpty ?? false)
                  ? item.sku!.trim()
                  : inventoryMaterialName(item),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final sku = _MaterialField(
                          controller: _skuController,
                          label: S.materialSku,
                          hint: S.materialSkuHint,
                          textCapitalization: TextCapitalization.characters,
                        );
                        final category = _MaterialField(
                          controller: _categoryController,
                          label: S.category,
                          hint: S.materialCategoryHint,
                        );
                        return constraints.maxWidth < 480
                            ? Column(
                                children: [
                                  sku,
                                  const SizedBox(height: AppSpacing.md),
                                  category,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: sku),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: category),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MaterialField(
                      controller: _nameArController,
                      label: '${S.nameAr} *',
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MaterialField(
                      controller: _nameEnController,
                      label: S.nameEn,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      S.materialIdentity,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColor.greyColor,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: InputDecoration(
                        labelText: S.materialUnitOfMeasure,
                      ),
                      items: [
                        for (final unit in inventoryUnits)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(inventoryUnitLabel(unit)),
                          ),
                      ],
                      onChanged: _unitLocked
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _unit = value);
                            },
                    ),
                    if (_unitLocked) ...[
                      const SizedBox(height: AppSizes.px6),
                      Row(
                        children: [
                          const AppIcon(
                            AppIcons.password,
                            size: 13,
                            color: AppColor.adminMuted,
                          ),
                          const SizedBox(width: AppSizes.px6),
                          Expanded(
                            child: Text(
                              S.materialUnitLocked,
                              style: const TextStyle(
                                color: AppColor.adminMuted,
                                fontSize: AppFontSizes.size9_5,
                                height: AppTextHeights.line1_5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cost = _MaterialField(
                          controller: _unitCostController,
                          label: S.materialUnitCost,
                          hint: S.materialUnitCostHint,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_decimalFormatter],
                          suffixText: S.currency,
                        );
                        final reorder = _MaterialField(
                          controller: _reorderController,
                          label: S.materialReorderLevel,
                          hint: S.materialReorderHint,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_decimalFormatter],
                          suffixText: inventoryUnitLabel(_unit),
                        );
                        return constraints.maxWidth < 480
                            ? Column(
                                children: [
                                  cost,
                                  const SizedBox(height: AppSpacing.md),
                                  reorder,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: cost),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: reorder),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MaterialField(
                      controller: _notesController,
                      label: S.materialNotes,
                      hint: S.materialNotesHint,
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
              saveKey: const Key('inventory-material-save'),
              saveLabel: S.save,
              savingLabel: S.saving,
            ),
          ],
        ),
      ),
    );
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp('[0-9٠-٩.,٫]'),
);

class _MaterialField extends StatelessWidget {
  const _MaterialField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.textDirection,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.suffixText,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextDirection? textDirection;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final String? suffixText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    textDirection: textDirection,
    textCapitalization: textCapitalization,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      alignLabelWithHint: maxLines > 1,
    ),
  );
}
