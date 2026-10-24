import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_header.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_records.dart';

class ProductPageBody extends StatelessWidget {
  const ProductPageBody({
    super.key,
    required this.products,
    required this.onAdd,
    this.total,
    this.categories = const <AdminCategory>[],
    this.onPickFile,
    this.onDownloadSample,
    this.onExport,
    this.onToggleFeatured,
    this.onDelete,
    this.onSave,
    this.onOpenImages,
    this.onSelect,
    this.selectedIds = const <String>{},
    this.onSelectAll,
    this.onClearSelection,
    this.onDeleteSelected,
    this.isSelectingAll = false,
    this.isDeletingSelected = false,
    this.onCreateCategory,
    this.savingProductId,
    this.importProgress,
    this.exportProgress,
    this.footer,
  });

  final List<AdminProduct> products;
  final VoidCallback onAdd;
  final int? total;
  final List<AdminCategory> categories;
  final VoidCallback? onPickFile;
  final VoidCallback? onDownloadSample;
  final VoidCallback? onExport;
  final ValueChanged<AdminProduct>? onToggleFeatured;
  final ValueChanged<AdminProduct>? onDelete;
  final ValueChanged<AdminProduct>? onSave;
  final ValueChanged<AdminProduct>? onOpenImages;
  final ValueChanged<AdminProduct>? onSelect;
  final Set<String> selectedIds;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;
  final bool isSelectingAll;
  final bool isDeletingSelected;
  final Future<AdminCategory?> Function(
    String nameAr,
    String nameEn, [
    String? descriptionAr,
    String? descriptionEn,
  ])?
  onCreateCategory;
  final String? savingProductId;
  final double? importProgress;
  final double? exportProgress;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductPageHeader(
            count: total ?? products.length,
            selectedCount: selectedIds.length,
            isSelectingAll: isSelectingAll,
            isDeletingSelected: isDeletingSelected,
            onSelectAll: onSelectAll,
            onClearSelection: onClearSelection,
            onDeleteSelected: onDeleteSelected,
            onAdd: onAdd,
            onPickFile: onPickFile,
            onDownloadSample: onDownloadSample,
            onExport: onExport,
            importProgress: importProgress,
            exportProgress: exportProgress,
          ),
          const SizedBox(height: AppDimensions.lg),
          ProductRecords(
            products: products,
            categories: categories,
            savingProductId: savingProductId,
            onCreateCategory: onCreateCategory,
            onToggleFeatured: onToggleFeatured,
            onDelete: onDelete,
            onSave: onSave,
            onOpenImages: onOpenImages,
            onSelect: onSelect,
            selectedIds: selectedIds,
            footer: footer,
          ),
        ],
      ),
    );
  }
}
