import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_directory.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_values.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_page_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

class OrderPageBody extends StatefulWidget {
  const OrderPageBody({
    super.key,
    required this.orders,
    this.branches = const [],
    required this.search,
    required this.onSearchChanged,
    required this.onChangeStatus,
    required this.onOpen,
    required this.onRefresh,
    this.onExport,
    this.exporting,
    this.errorMessage,
  });

  final List<AdminOrder> orders;
  final List<AdminBranch> branches;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final void Function(AdminOrder order, String status) onChangeStatus;
  final ValueChanged<AdminOrder> onOpen;
  final VoidCallback onRefresh;
  final ValueChanged<List<AdminOrder>>? onExport;
  final ValueListenable<bool>? exporting;
  final String? errorMessage;

  @override
  State<OrderPageBody> createState() => _OrderPageBodyState();
}

class _OrderPageBodyState extends State<OrderPageBody> {
  OrderFilterValues _filters = const OrderFilterValues();

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrderPageHeader(),
          if (widget.errorMessage != null)
            AdminInlineError(
              message: widget.errorMessage!,
              onRetry: widget.onRefresh,
              retryLabel: S.ordersRetry,
            ),
          const SizedBox(height: AppSizes.px8),
          OrderSummaryCards(orders: widget.orders, branchId: _filters.branchId),
          const SizedBox(height: AppSizes.px16),
          Expanded(
            child: OrderDirectory(
              orders: widget.orders,
              branches: widget.branches,
              search: widget.search,
              onSearchChanged: widget.onSearchChanged,
              filters: _filters,
              onFiltersChanged: (value) => setState(() => _filters = value),
              onChangeStatus: widget.onChangeStatus,
              onOpen: widget.onOpen,
              onExport: widget.onExport,
              exporting: widget.exporting,
            ),
          ),
        ],
      ),
    );
  }
}
