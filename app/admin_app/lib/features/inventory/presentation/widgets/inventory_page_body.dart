import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_directory.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
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
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 650;
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
                    leadingIcon: const Icon(
                      HugeIcons.strokeRoundedExchange01,
                      size: 18,
                    ),
                    height: 42,
                    borderRadius: AppDimensions.radiusPill,
                  ),
                if (canEdit)
                  CustomBtn(
                    key: const Key('inventory-add-material'),
                    text: S.addRawMaterial,
                    onPressed: onAdd,
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
              footer: canAdjust
                  ? null
                  : AdminReadOnlyHint(message: S.inventoryReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: 7),
            InventoryMetricsCards(metrics: metrics),
            const SizedBox(height: 16),
          ];
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(height: 700, child: directory),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              Expanded(child: directory),
            ],
          );
        },
      ),
    );
  }
}
