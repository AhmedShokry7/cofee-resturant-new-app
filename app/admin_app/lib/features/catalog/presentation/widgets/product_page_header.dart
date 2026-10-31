import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/admin_bulk_selection_bar.dart';
import 'package:admin_app/shared/widgets/admin_excel_page_header.dart';

/// The products heading: the shared Excel header with the products labels.
class ProductPageHeader extends StatelessWidget {
  const ProductPageHeader({
    super.key,
    required this.count,
    this.onAdd,
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

  /// لا تُعرض لمن يقرأ المنتجات فقط: 117 ترفض كتابته بـ `catalog.product.write`.
  final VoidCallback? onAdd;
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
    return AdminExcelPageHeader(
      title: S.products,
      subtitle: S.productsCount(count),
      addActionLabel: S.addProduct,
      onAdd: onAdd,
      onPickFile: onPickFile,
      onDownloadSample: onDownloadSample,
      onExport: onExport,
      importProgress: importProgress,
      exportProgress: exportProgress,
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
}
