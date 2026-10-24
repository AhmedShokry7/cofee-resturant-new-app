import 'package:admin_app/features/orders/presentation/widgets/order_summary_cards.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filters.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_records.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';

/// The title, filters, summary cards, and orders list.
///
/// Filter choices are view state of this screen only.
/// They do not reach the repository.
class OrderPageBody extends StatefulWidget {
  const OrderPageBody({
    super.key,
    required this.orders,
    this.branches = const [],
    required this.search,
    required this.onChangeStatus,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<AdminOrder> orders;
  final List<AdminBranch> branches;
  final String search;
  final void Function(AdminOrder order, String status) onChangeStatus;
  final ValueChanged<AdminOrder> onOpen;
  final VoidCallback onRefresh;

  @override
  State<OrderPageBody> createState() => _OrderPageBodyState();
}

class _OrderPageBodyState extends State<OrderPageBody> {
  OrderFilterValues _filters = const OrderFilterValues();

  @override
  Widget build(BuildContext context) {
    final visible = filterOrders(
      widget.orders,
      search: widget.search,
      status: _filters.status,
      fulfillment: _filters.fulfillment,
      paymentStatus: _filters.paymentStatus,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminPageTitle(S.orders),
              ),
              Text(
                S.ordersCount(visible.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColor.greyColor,
                    ),
              ),
              IconButton(
                tooltip: S.retry,
                onPressed: widget.onRefresh,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  size: 20, color: AppColor.greyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          OrderSummaryCards(
            orders: widget.orders,
          ),
          const SizedBox(height: AppDimensions.sm),
          OrderFilters(
            value: _filters,
            branches: widget.branches,
            onChanged: (value) {
              setState(() => _filters = value);
            },
          ),
          Expanded(
            child:             OrderRecords(
              orders: widget.orders,
              search: widget.search,
              status: _filters.status,
              fulfillment: _filters.fulfillment,
              paymentStatus: _filters.paymentStatus,
              branchId: _filters.branchId,
              onChangeStatus: widget.onChangeStatus,
              onOpen: widget.onOpen,
            ),
          ),
        ],
      ),
    );
  }
}
