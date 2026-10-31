import 'dart:math';

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/dining_format.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/tables/domain/entities/dining_table_draft.dart';
import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_cubit.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_messages.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// Opens the table/room editor. Returns true when the table was saved.
Future<bool?> showDiningTableDialog(
  BuildContext context, {
  required DiningTablesCubit cubit,
  DiningTable? table,
  String? branchId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DiningTableDialog(cubit: cubit, table: table, branchId: branchId),
  );
}

class _DiningTableDialog extends StatefulWidget {
  const _DiningTableDialog({required this.cubit, this.table, this.branchId});

  final DiningTablesCubit cubit;
  final DiningTable? table;
  final String? branchId;

  @override
  State<_DiningTableDialog> createState() => _DiningTableDialogState();
}

class _DiningTableDialogState extends State<_DiningTableDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _capacity;
  late final TextEditingController _sort;
  late final TextEditingController _note;
  late DiningArea _area;
  late bool _active;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.table != null;

  @override
  void initState() {
    super.initState();
    final table = widget.table;
    _name = TextEditingController(text: table?.name ?? '');
    _capacity = TextEditingController(text: '${table?.capacity ?? 2}');
    _sort = TextEditingController(text: '${table?.sortOrder ?? 0}');
    _note = TextEditingController(text: table?.note ?? '');
    _area = table?.area ?? DiningArea.hall;
    _active = table?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _sort.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final branchId =
        widget.table?.branchId ??
        widget.branchId ??
        widget.cubit.state.branchId;
    if (branchId == null || branchId.isEmpty) {
      setState(() => _error = S.tablesNoBranch);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await widget.cubit.saveTable(
      DiningTableDraft(
        id: widget.table?.id,
        branchId: branchId,
        name: _name.text.trim(),
        area: _area.value,
        capacity: parseLocalizedInt(_capacity.text) ?? 2,
        note: _note.text.trim(),
        sortOrder: parseLocalizedInt(_sort.text) ?? 0,
        isActive: _active,
      ),
    );
    if (!mounted) return;
    if (outcome == DiningTableSaveOutcome.saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = diningTableSaveErrorMessage(outcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(520.0, size.width - 32);
    final height = min(600.0, size.height * .9);

    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxl,
        ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDialogHeader(
                title: _editing ? S.editTable : S.addTable,
                subtitle: S.tableEditorSubtitle,
                onClose: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 20,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? S.tableNameRequired
                              : null,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.tableName,
                            hint: S.tableNameHint,
                            required: true,
                          ),
                        ),
                        const SizedBox(height: AppSizes.px12),
                        Text(
                          S.tableArea,
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size10_5,
                            fontWeight: AppFontWeights.semiBold,
                          ),
                        ),
                        const SizedBox(height: AppSizes.px8),
                        _AreaPicker(
                          value: _area,
                          enabled: !_saving,
                          onChanged: (value) => setState(() => _area = value),
                        ),
                        const SizedBox(height: AppSizes.px14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _capacity,
                                enabled: !_saving,
                                maxLength: 2,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  final count = parseLocalizedInt(value ?? '');
                                  return count == null ||
                                          count < 1 ||
                                          count > 40
                                      ? S.tableCapacityRange
                                      : null;
                                },
                                style: TextStyle(
                                  color: adminBodyColor(theme),
                                  fontSize: AppFontSizes.size11_5,
                                ),
                                decoration: adminDialogFieldDecoration(
                                  context,
                                  label: S.tableCapacityField,
                                  hint: '2',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSizes.px10),
                            Expanded(
                              child: TextFormField(
                                controller: _sort,
                                enabled: !_saving,
                                maxLength: 3,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                // بلا هذا الفحص كان النص غير الرقمي يمرّ ترتيبًا صفرًا:
                                // الترتيب الذي كتبه المدير يختفي ولا أحد يُنبَّه.
                                validator: (value) {
                                  final text = (value ?? '').trim();
                                  if (text.isEmpty) return null;
                                  return parseLocalizedInt(text) == null
                                      ? S.invalidNumber
                                      : null;
                                },
                                style: TextStyle(
                                  color: adminBodyColor(theme),
                                  fontSize: AppFontSizes.size11_5,
                                ),
                                decoration: adminDialogFieldDecoration(
                                  context,
                                  label: S.tableSortOrder,
                                  hint: '0',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.px2),
                        TextFormField(
                          controller: _note,
                          enabled: !_saving,
                          maxLength: 240,
                          maxLines: 2,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.tableNote,
                            hint: S.tableNoteHint,
                          ),
                        ),
                        const SizedBox(height: AppSizes.px8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: adminTintedSurfaceColor(theme),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: adminControlBorderColor(theme),
                            ),
                          ),
                          child: Row(
                            children: [
                              AppIcon(
                                AppIcons.checkmarkCircle02,
                                size: 16,
                                color: _active
                                    ? AppColor.trendPositive
                                    : adminMutedColor(theme),
                              ),
                              const SizedBox(width: AppSizes.px8),
                              Expanded(
                                child: Text(
                                  S.tableActiveLabel,
                                  style: TextStyle(
                                    color: adminBodyColor(theme),
                                    fontSize: AppFontSizes.size10_5,
                                    height: AppTextHeights.line1_5,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _active,
                                onChanged: _saving
                                    ? null
                                    : (value) =>
                                          setState(() => _active = value),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSizes.px12),
                          AdminErrorBanner(message: _error!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              AdminDialogFooter(
                saving: _saving,
                onCancel: () => Navigator.of(context).maybePop(),
                onSave: _save,
                saveKey: const Key('dining-table-save'),
                saveLabel: S.save,
                savingLabel: S.saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaPicker extends StatelessWidget {
  const _AreaPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final DiningArea value;
  final bool enabled;
  final ValueChanged<DiningArea> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final area in DiningArea.values)
          _AreaOption(
            area: area,
            selected: area == value,
            onTap: enabled ? () => onChanged(area) : null,
          ),
      ],
    );
  }
}

class _AreaOption extends StatelessWidget {
  const _AreaOption({
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final DiningArea area;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? adminFlagForeground(theme, AppColor.adminAccent)
        : adminBodyColor(theme);
    return Material(
      color: selected
          ? adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            )
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColor.adminAccent.withValues(alpha: .4)
                  : adminControlBorderColor(theme),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                diningAreaIcon(area),
                size: 15,
                color: selected
                    ? adminFlagForeground(theme, AppColor.adminAccent)
                    : adminMutedColor(theme),
              ),
              const SizedBox(width: AppSizes.px6),
              Text(
                diningAreaLabel(area),
                style: TextStyle(
                  color: foreground,
                  fontSize: AppFontSizes.size10,
                  fontWeight: selected
                      ? AppFontWeights.bold
                      : AppFontWeights.medium,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
