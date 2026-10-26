import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';
import 'package:admin_app/shared/widgets/admin_bulk_selection_bar.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class ProductPageHeader extends StatelessWidget {
  const ProductPageHeader({
    super.key,
    required this.count,
    required this.onAdd,
    this.selectedCount = 0,
    this.onSelectAll,
    this.onClearSelection,
    this.onDeleteSelected,
    this.isSelectingAll = false,
    this.isDeletingSelected = false,
    this.onPickFile,
    this.onDownloadSample,
    this.onExport,
    this.importProgress,
    this.exportProgress,
  });

  final int count;
  final VoidCallback onAdd;
  final int selectedCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;
  final bool isSelectingAll;
  final bool isDeletingSelected;
  final VoidCallback? onPickFile;
  final VoidCallback? onDownloadSample;
  final VoidCallback? onExport;
  final double? importProgress;
  final double? exportProgress;

  @override
  Widget build(BuildContext context) {
    final progress = importProgress ?? exportProgress;
    final busy = progress != null;

    return AdminPageHeader(
      title: S.products,
      subtitle: S.productsCount(count),
      progress: progress,
      progressLabel: importProgress != null ? S.importing : S.exporting,
      actions: [
        if (onPickFile != null || onDownloadSample != null)
          _circleIcon(
            context,
            icon: AppIcons.upload02,
            tooltip: S.importExcel,
            onTap: busy ? null : () => _showImportDialog(context),
          ),
        if (onExport != null)
          _circleIcon(
            context,
            icon: AppIcons.download02,
            tooltip: S.exportExcel,
            onTap: busy ? null : onExport,
          ),
        CustomBtn(
          text: S.addProduct,
          onPressed: busy ? null : onAdd,
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
              selectedLabel: S.selectedProductsCount(selectedCount),
              selectAllLabel: S.selectAllProducts(count),
              deleteLabel: S.deleteSelectedProducts,
              onSelectAll: onSelectAll,
              onClearSelection: onClearSelection,
              onDelete: onDeleteSelected,
              isSelectingAll: isSelectingAll,
              isDeletingSelected: isDeletingSelected,
            )
          : null,
    );
  }

  Widget _circleIcon(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final isDisabled = onTap == null;
    final background = isDisabled
        ? (dark ? AppColor.darkCard : AppColor.borderColor)
        : (dark ? AppColor.darkSurfaceContainer : AppColor.lightGreyColor);
    final foreground = isDisabled
        ? (dark ? AppColor.darkTextSecondary : AppColor.greyColor)
        : (dark ? AppColor.secondaryColor : AppColor.primaryColor);

    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => ImportExcelDialog(
        onPickFile: () {
          Navigator.of(context).pop();
          onPickFile?.call();
        },
        onDownloadSample: () {
          Navigator.of(context).pop();
          onDownloadSample?.call();
        },
      ),
    );
  }
}
