import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movements_directory.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movements_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class StockMovementsPageBody extends StatelessWidget {
  const StockMovementsPageBody({
    super.key,
    required this.movements,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.search,
    required this.type,
    required this.period,
    required this.branchId,
    required this.filters,
    required this.metrics,
    required this.isRefreshingRows,
    required this.canAdjust,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onPeriodChanged,
    required this.onBranchChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onOpen,
    required this.onRecordMovement,
    required this.onRefresh,
    this.errorMessage,
  });

  final List<AdminStockMovement> movements;
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final String search;
  final StockMovementTypeFilter type;
  final StockMovementPeriod period;
  final String? branchId;
  final AdminInventoryFilters filters;
  final AdminStockMovementMetrics metrics;
  final bool isRefreshingRows;
  final bool canAdjust;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<StockMovementTypeFilter> onTypeChanged;
  final ValueChanged<StockMovementPeriod> onPeriodChanged;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AdminStockMovement> onOpen;
  final VoidCallback onRecordMovement;
  final VoidCallback onRefresh;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 650;
          final directory = StockMovementsDirectory(
            movements: movements,
            total: total,
            page: page,
            pages: pages,
            pageSize: pageSize,
            search: search,
            type: type,
            period: period,
            branchId: branchId,
            filters: filters,
            isRefreshingRows: isRefreshingRows,
            canAdjust: canAdjust,
            onSearchChanged: onSearchChanged,
            onTypeChanged: onTypeChanged,
            onPeriodChanged: onPeriodChanged,
            onBranchChanged: onBranchChanged,
            onClearFilters: onClearFilters,
            onPageChanged: onPageChanged,
            onOpen: onOpen,
            onRecordMovement: onRecordMovement,
          );
          final sections = <Widget>[
            AdminPageHeader(
              title: S.stockMovements,
              subtitle: S.stockMovementsSubtitle,
              actions: [
                if (canAdjust)
                  CustomBtn(
                    key: const Key('stock-movements-record-movement'),
                    text: S.stockMovementAction,
                    onPressed: onRecordMovement,
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
                  : AdminReadOnlyHint(message: S.stockMovementsReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: 7),
            StockMovementsMetricsCards(metrics: metrics),
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
