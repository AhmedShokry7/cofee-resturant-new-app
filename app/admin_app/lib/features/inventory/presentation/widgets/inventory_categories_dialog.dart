import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_category_mutation_outcome.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';

Future<bool?> showInventoryCategoriesDialog({
  required BuildContext context,
  required List<AdminInventoryCategoryOption> categories,
  required String? selectedCategory,
  required ValueChanged<String?> onSelected,
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
}) => showDialog<bool>(
  context: context,
  builder: (context) => InventoryCategoriesDialog(
    categories: categories,
    selectedCategory: selectedCategory,
    onSelected: onSelected,
    onCreate: onCreate,
    onRename: onRename,
    onDelete: onDelete,
  ),
);

class InventoryCategoriesDialog extends StatefulWidget {
  const InventoryCategoriesDialog({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    this.onCreate,
    this.onRename,
    this.onDelete,
  });

  final List<AdminInventoryCategoryOption> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;
  final Future<InventoryCategoryMutationOutcome> Function(String name)?
  onCreate;
  final Future<InventoryCategoryMutationOutcome> Function({
    required String currentName,
    required String newName,
  })?
  onRename;
  final Future<InventoryCategoryMutationOutcome> Function({
    required String name,
    String? reassignTo,
  })?
  onDelete;

  @override
  State<InventoryCategoriesDialog> createState() =>
      _InventoryCategoriesDialogState();
}

class _InventoryCategoriesDialogState extends State<InventoryCategoriesDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _create() async {
    final name = await _askForName();
    if (name == null || widget.onCreate == null || !mounted) return;
    await _applyMutation(() => widget.onCreate!(name));
  }

  Future<void> _rename(String currentName) async {
    final name = await _askForName(initialName: currentName);
    if (name == null || widget.onRename == null || !mounted) return;
    await _applyMutation(
      () => widget.onRename!(currentName: currentName, newName: name),
    );
  }

  Future<String?> _askForName({String initialName = ''}) => showDialog<String>(
    context: context,
    builder: (context) =>
        _InventoryCategoryNameDialog(initialName: initialName),
  );

  Future<void> _delete(AdminInventoryCategoryOption category) async {
    if (widget.onDelete == null) return;
    String? target;
    if (category.count > 0) {
      final choices = widget.categories
          .where((option) => option.value != category.value)
          .toList(growable: false);
      final selected = await showDialog<String>(
        context: context,
        builder: (context) =>
            _ReassignCategoryDialog(category: category, choices: choices),
      );
      if (selected == null || !mounted) return;
      target = selected == _uncategorisedValue ? null : selected;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.inventoryCategoryDelete),
          content: Text(S.inventoryCategoryDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.cancel),
            ),
            FilledButton(
              key: const Key('inventory-category-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(S.delete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _applyMutation(
      () => widget.onDelete!(name: category.value, reassignTo: target),
    );
  }

  Future<void> _applyMutation(
    Future<InventoryCategoryMutationOutcome> Function() mutate,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await mutate();
    if (!mounted) return;
    if (outcome == InventoryCategoryMutationOutcome.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = _errorText(outcome);
    });
  }

  String _errorText(
    InventoryCategoryMutationOutcome outcome,
  ) => switch (outcome) {
    InventoryCategoryMutationOutcome.success => '',
    InventoryCategoryMutationOutcome.invalidName =>
      S.inventoryCategoryNameInvalid,
    InventoryCategoryMutationOutcome.duplicateName =>
      S.inventoryCategoryDuplicate,
    InventoryCategoryMutationOutcome.notFound => S.inventoryCategorySaveFailed,
    InventoryCategoryMutationOutcome.invalidTarget =>
      S.inventoryCategoryReassignRequired,
    InventoryCategoryMutationOutcome.permissionDenied =>
      S.inventoryCategoryPermissionDenied,
    InventoryCategoryMutationOutcome.failed => S.inventoryCategorySaveFailed,
  };

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: maxHeight < 680 ? maxHeight : 680,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: S.inventoryCategories,
              onClose: () => Navigator.of(context).pop(false),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: AdminErrorBanner(message: _error!),
              ),
            if (widget.onCreate != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    key: const Key('inventory-category-add'),
                    onPressed: _saving ? null : _create,
                    icon: const Icon(AppIcons.add01, size: 18),
                    label: Text(S.inventoryCategoryAdd),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final category in widget.categories)
                    ListTile(
                      key: ValueKey('inventory-category-${category.value}'),
                      title: Text(category.value),
                      subtitle: Text(
                        S.inventoryCategoryCount(
                          localizeDigits(category.count.toString()),
                        ),
                      ),
                      selected: widget.selectedCategory == category.value,
                      onTap: _saving
                          ? null
                          : () {
                              widget.onSelected(category.value);
                              Navigator.of(context).pop(false);
                            },
                      trailing:
                          widget.onRename == null && widget.onDelete == null
                          ? null
                          : Wrap(
                              spacing: AppSpacing.xs,
                              children: [
                                if (widget.onRename != null)
                                  IconButton(
                                    key: ValueKey(
                                      'inventory-category-edit-${category.value}',
                                    ),
                                    tooltip: S.inventoryCategoryEdit,
                                    onPressed: _saving
                                        ? null
                                        : () => _rename(category.value),
                                    icon: const Icon(AppIcons.edit01, size: 18),
                                  ),
                                if (widget.onDelete != null)
                                  IconButton(
                                    key: ValueKey(
                                      'inventory-category-delete-${category.value}',
                                    ),
                                    tooltip: S.inventoryCategoryDelete,
                                    onPressed: _saving
                                        ? null
                                        : () => _delete(category),
                                    icon: const Icon(
                                      AppIcons.delete01,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  if (widget.categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(S.inventoryNoCategory),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.onSelected(null);
                  Navigator.of(context).pop(false);
                },
                icon: const Icon(Icons.clear),
                label: Text(S.inventoryAllCategories),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCategoryNameDialog extends StatefulWidget {
  const _InventoryCategoryNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_InventoryCategoryNameDialog> createState() =>
      _InventoryCategoryNameDialogState();
}

class _InventoryCategoryNameDialogState
    extends State<_InventoryCategoryNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialName.isEmpty
          ? S.inventoryCategoryAdd
          : S.inventoryCategoryEdit,
    ),
    content: TextField(
      key: const Key('inventory-category-name'),
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      decoration: InputDecoration(labelText: S.inventoryCategoryName),
      onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.cancel),
      ),
      FilledButton(
        key: const Key('inventory-category-name-save'),
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: Text(S.save),
      ),
    ],
  );
}

const _uncategorisedValue = '\u0000uncategorised';

class _ReassignCategoryDialog extends StatefulWidget {
  const _ReassignCategoryDialog({
    required this.category,
    required this.choices,
  });

  final AdminInventoryCategoryOption category;
  final List<AdminInventoryCategoryOption> choices;

  @override
  State<_ReassignCategoryDialog> createState() =>
      _ReassignCategoryDialogState();
}

class _ReassignCategoryDialogState extends State<_ReassignCategoryDialog> {
  String? _target;

  @override
  Widget build(BuildContext context) {
    final choices = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: _uncategorisedValue,
        child: Text(S.inventoryCategoryUncategorised),
      ),
      for (final category in widget.choices)
        DropdownMenuItem(value: category.value, child: Text(category.value)),
    ];
    return AlertDialog(
      title: Text(S.inventoryCategoryDelete),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(S.inventoryCategoryDeleteConfirm),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('inventory-category-reassign'),
            initialValue: _target,
            decoration: InputDecoration(
              labelText: S.inventoryCategoryReassignTo,
            ),
            items: choices,
            onChanged: (value) => setState(() => _target = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          key: const Key('inventory-category-delete-confirm'),
          onPressed: _target == null
              ? null
              : () => Navigator.of(context).pop(_target),
          child: Text(S.delete),
        ),
      ],
    );
  }
}
