import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';
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
    final theme = Theme.of(context);
    final progress = importProgress ?? exportProgress;
    final isImporting = importProgress != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColor.lightGreyColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColor.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  isImporting ? S.importing : S.exporting,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.products,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    S.productsCount(count),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColor.greyColor,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPickFile != null || onDownloadSample != null)
                  _circleIcon(
                    icon: HugeIcons.strokeRoundedUpload02,
                    tooltip: S.importExcel,
                    onTap: progress != null
                        ? null
                        : () => _showImportDialog(context),
                  ),
                if (onExport != null) ...[
                  const SizedBox(width: AppDimensions.sm),
                  _circleIcon(
                    icon: HugeIcons.strokeRoundedDownload02,
                    tooltip: S.exportExcel,
                    onTap: progress != null ? null : onExport,
                  ),
                ],
                const SizedBox(width: AppDimensions.sm),
                CustomBtn(
                  text: S.addProduct,
                  onPressed: progress != null ? null : onAdd,
                  leadingIcon: const Icon(
                    HugeIcons.strokeRoundedAdd01,
                    size: 18,
                  ),
                  height: 42,
                  borderRadius: AppDimensions.radiusPill,
                  backgroundColor: AppColor.primaryColor,
                  textColor: AppColor.whiteColor,
                ),
              ],
            ),
          ],
        ),
        if (count > 0 || selectedCount > 0) ...[
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (selectedCount > 0)
                Text(
                  S.selectedProductsCount(selectedCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
              if (selectedCount > 0)
                TextButton.icon(
                  onPressed: isSelectingAll || isDeletingSelected
                      ? null
                      : selectedCount >= count
                      ? onClearSelection
                      : onSelectAll,
                  icon: isSelectingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          selectedCount >= count
                              ? HugeIcons.strokeRoundedCancel01
                              : HugeIcons.strokeRoundedTick01,
                          size: 18,
                        ),
                  label: Text(
                    selectedCount >= count
                        ? S.clearSelection
                        : S.selectAllProducts(count),
                  ),
                ),
              if (selectedCount > 0)
                FilledButton.tonalIcon(
                  onPressed: isSelectingAll || isDeletingSelected
                      ? null
                      : onDeleteSelected,
                  icon: isDeletingSelected
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(HugeIcons.strokeRoundedDelete01, size: 18),
                  label: Text(S.deleteSelectedProducts),
                  style: FilledButton.styleFrom(
                    foregroundColor: AppColor.errorColor,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _circleIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return Material(
      color: isDisabled ? AppColor.borderColor : AppColor.lightGreyColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: isDisabled ? AppColor.greyColor : AppColor.primaryColor,
            ),
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
