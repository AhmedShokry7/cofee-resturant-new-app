import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_categories_dialog.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_directory.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_directory_page_layout.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class InventoryPageBody extends StatelessWidget {
  const InventoryPageBody({
    super.key,
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.search,
    required this.category,
    required this.statusFilter,
    required this.branchId,
    required this.filters,
    required this.metrics,
    required this.isRefreshingRows,
    required this.canAdjust,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onMovement,
    required this.onRecordMovement,
    required this.onDelete,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onBranchChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onRefresh,
    this.onManageCategories,
    this.onCategorySelection,
    this.selectedCategory,
    this.errorMessage,
  });

  final List<AdminInventoryItem> items;
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final String search;
  final String? category;
  final InventoryStatusFilter statusFilter;
  final String? branchId;
  final AdminInventoryFilters filters;
  final AdminInventoryMetrics metrics;
  final bool isRefreshingRows;
  final bool canAdjust;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<AdminInventoryItem> onEdit;
  final ValueChanged<AdminInventoryItem> onMovement;
  final VoidCallback onRecordMovement;
  final ValueChanged<AdminInventoryItem> onDelete;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<InventoryStatusFilter> onStatusChanged;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onManageCategories;
  final ValueChanged<String?>? onCategorySelection;
  final String? selectedCategory;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, _) {
          // السكرول على الصفحة كاملة: الترويسة والبطاقات والقائمة تتحرك
          // معًا، والقائمة تأخذ ارتفاعًا متجاوبًا مع مساحة الشاشة.

          final directory = InventoryDirectory(
            items: items,
            total: total,
            page: page,
            pages: pages,
            pageSize: pageSize,
            search: search,
            category: category,
            statusFilter: statusFilter,
            branchId: branchId,
            filters: filters,
            isRefreshingRows: isRefreshingRows,
            canAdjust: canAdjust,
            canEdit: canEdit,
            onSearchChanged: onSearchChanged,
            onCategoryChanged: onCategoryChanged,
            onStatusChanged: onStatusChanged,
            onBranchChanged: onBranchChanged,
            onClearFilters: onClearFilters,
            onPageChanged: onPageChanged,
            onAdd: onAdd,
            onEdit: onEdit,
            onMovement: onMovement,
            onDelete: onDelete,
          );
          final sections = <Widget>[
            AdminPageHeader(
              title: S.inventory,
              subtitle: S.inventorySubtitle,
              actions: [
                if (canAdjust)
                  CustomBtn(
                    key: const Key('inventory-record-movement'),
                    text: S.stockMovementAction,
                    onPressed: onRecordMovement,
                    variant: BtnVariant.secondary,
                    leadingIcon: const Icon(AppIcons.exchange01, size: 18),
                    height: 42,
                    borderRadius: AppRadius.pill,
                  ),
                if (canEdit)
                  AdminToolbarButton(
                    key: const Key('inventory-manage-categories'),
                    label: S.inventoryCategories,
                    icon: AppIcons.tag01,
                    onPressed:
                        onManageCategories ??
                        (onCategorySelection == null
                            ? null
                            : () => showInventoryCategoriesDialog(
                                context: context,
                                categories: filters.categories,
                                selectedCategory: selectedCategory,
                                onSelected: onCategorySelection!,
                              )),
                  ),
                if (canEdit)
                  AdminCreateButton(
                    key: const Key('inventory-add-material'),
                    label: S.addRawMaterial,
                    onPressed: onAdd,
                  ),
              ],
              footer: canAdjust
                  ? null
                  : AdminReadOnlyHint(message: S.inventoryReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            InventoryMetricsCards(metrics: metrics),
            const SizedBox(height: AppSizes.px16),
          ];
          return AdminDirectoryPageLayout(
            sections: sections,
            directory: directory,
          );
        },
      ),
    );
  }
}
