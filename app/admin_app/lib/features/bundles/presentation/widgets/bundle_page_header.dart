import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_bulk_selection_bar.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class BundlePageHeader extends StatelessWidget {
  const BundlePageHeader({
    super.key,
    required this.count,
    required this.onAdd,
    this.selectedCount = 0,
    this.onSelectAll,
    this.onClearSelection,
    this.onDeleteSelected,
    this.isDeletingSelected = false,
  });

  final int count;
  final VoidCallback onAdd;
  final int selectedCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;
  final bool isDeletingSelected;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: S.bundles,
      subtitle: S.bundlesCount(count),
      actions: [
        CustomBtn(
          text: S.addBundle,
          onPressed: onAdd,
          leadingIcon: const Icon(AppIcons.add01, size: 18),
          height: 42,
          borderRadius: AppRadius.pill,
          backgroundColor: AppColor.primaryColor,
          textColor: AppColor.whiteColor,
        ),
      ],
      footer: selectedCount > 0
          ? AdminBulkSelectionBar(
              selectedCount: selectedCount,
              totalCount: count,
              selectedLabel: S.selectedCountLabel(selectedCount),
              selectAllLabel: S.selectAllBundles(count),
              deleteLabel: S.deleteSelectedBundles,
              onSelectAll: onSelectAll,
              onClearSelection: onClearSelection,
              onDelete: onDeleteSelected,
              isDeletingSelected: isDeletingSelected,
            )
          : null,
    );
  }
}
