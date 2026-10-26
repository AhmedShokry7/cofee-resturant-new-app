import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// The row under a page header that drives a bulk action on picked records.
class AdminBulkSelectionBar extends StatelessWidget {
  const AdminBulkSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.selectedLabel,
    required this.selectAllLabel,
    required this.deleteLabel,
    this.onSelectAll,
    this.onClearSelection,
    this.onDelete,
    this.isSelectingAll = false,
    this.isDeletingSelected = false,
  });

  final int selectedCount;

  /// How many records the current filter matches.
  final int totalCount;

  final String selectedLabel;
  final String selectAllLabel;
  final String deleteLabel;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDelete;
  final bool isSelectingAll;
  final bool isDeletingSelected;

  bool get _busy => isSelectingAll || isDeletingSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColor.darkTextSecondary
        : AppColor.greyColor;
    final allSelected = selectedCount >= totalCount;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          selectedLabel,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        TextButton.icon(
          onPressed: _busy
              ? null
              : allSelected
              ? onClearSelection
              : onSelectAll,
          icon: isSelectingAll
              ? const SizedBox(
                  width: AppSizes.px16,
                  height: AppSizes.px16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  allSelected ? AppIcons.cancel01 : AppIcons.tick01,
                  size: 18,
                ),
          label: Text(allSelected ? S.clearSelection : selectAllLabel),
        ),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : onDelete,
          icon: isDeletingSelected
              ? const SizedBox(
                  width: AppSizes.px16,
                  height: AppSizes.px16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.delete01, size: 18),
          label: Text(deleteLabel),
          style: FilledButton.styleFrom(foregroundColor: AppColor.errorColor),
        ),
      ],
    );
  }
}
