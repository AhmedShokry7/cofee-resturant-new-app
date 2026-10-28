import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/admin_bulk_selection_bar.dart';
import 'package:admin_app/shared/widgets/admin_excel_page_header.dart';

/// The categories heading: the shared Excel header with the categories labels.
class CategoryPageHeader extends StatelessWidget {
  const CategoryPageHeader({
    super.key,
    required this.count,
    required this.onAdd,
    this.onPickFile,
    this.onDownloadSample,
    this.onExport,
    this.importProgress,
    this.exportProgress,
    this.selectedCount = 0,
    this.onSelectAll,
    this.onClearSelection,
    this.onDeleteSelected,
    this.isDeletingSelected = false,
  });

  final int count;
  final VoidCallback onAdd;
  final VoidCallback? onPickFile;
  final VoidCallback? onDownloadSample;
  final VoidCallback? onExport;
  final double? importProgress;
  final double? exportProgress;
  final int selectedCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;
  final bool isDeletingSelected;

  @override
  Widget build(BuildContext context) {
    return AdminExcelPageHeader(
      title: S.categories,
      subtitle: S.categoriesCount(count),
      addActionLabel: S.addCategory,
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
              selectedLabel: S.selectedCountLabel(selectedCount),
              selectAllLabel: S.selectAllCategories(count),
              deleteLabel: S.deleteSelectedCategories,
              onSelectAll: onSelectAll,
              onClearSelection: onClearSelection,
              onDelete: onDeleteSelected,
              isDeletingSelected: isDeletingSelected,
            )
          : null,
    );
  }
}
