import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_cubit.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_excel_controller.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_actions.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_excel_actions.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_page_header.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_records.dart';

/// The header and the grid of the categories, the whole content of the page.
///
/// The body wires the dialogs, the Excel jobs and the records to the cubit
/// of the categories, so the page itself only owns the lifecycle.
class CategoryPageBody extends StatelessWidget {
  const CategoryPageBody({
    super.key,
    required this.cubit,
    required this.excel,
    required this.categories,
    required this.search,
    required this.importProgress,
    required this.exportProgress,
  });

  final AdminCategoryCubit cubit;
  final CategoryExcelController excel;
  final List<AdminCategory> categories;
  final String search;
  final double? importProgress;
  final double? exportProgress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CategoryPageHeader(
            count: filterCategories(categories, search).length,
            onAdd: () => showCategoryDataDialog(context: context, cubit: cubit),
            onPickFile: () => runCategoryImport(context, excel),
            onDownloadSample: () => runCategorySampleDownload(context, excel),
            onExport: () => runCategoryExport(context, excel, categories),
            importProgress: importProgress,
            exportProgress: exportProgress,
          ),
          const SizedBox(height: AppDimensions.lg),
          Expanded(
            child: CategoryRecords(
              categories: categories,
              search: search,
              onEdit: (category) => showCategoryDataDialog(
                context: context,
                cubit: cubit,
                initialCategory: category,
              ),
              onDelete: (category) =>
                  confirmDeleteCategory(context, cubit, category),
              onToggleActive: (category) =>
                  toggleCategoryActive(context, cubit, category),
              onChangeImage: (category) => showCategoryImageDialog(
                context: context,
                cubit: cubit,
                category: category,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
