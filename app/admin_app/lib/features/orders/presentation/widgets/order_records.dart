import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filtering.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

export 'order_cards.dart';
export 'order_filtering.dart';

class OrderRecords extends StatefulWidget {
  const OrderRecords({
    super.key,
    required this.orders,
    this.search = '',
    this.status = '',
    this.fulfillment = '',
    this.paymentStatus = '',
    this.branchId = '',
    this.onChangeStatus,
    this.onOpen,
  });
  final List<AdminOrder> orders;
  final String search, status, fulfillment, paymentStatus, branchId;
  final void Function(AdminOrder order, String status)? onChangeStatus;
  final ValueChanged<AdminOrder>? onOpen;

  @override
  State<OrderRecords> createState() => _OrderRecordsState();
}

class _OrderRecordsState extends State<OrderRecords> {
  static const _pageSize = 5;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final filtered = filterOrders(
      widget.orders,
      search: widget.search,
      status: widget.status,
      fulfillment: widget.fulfillment,
      paymentStatus: widget.paymentStatus,
      branchId: widget.branchId,
    );
    if (filtered.isEmpty) return Center(child: Text(S.noOrdersForFilter));
    final pages = (filtered.length / _pageSize).ceil();
    final page = _page.clamp(0, pages - 1);
    final start = page * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      children: [
        Expanded(
          child: wide
              ? OrderTable(orders: visible, onOpen: widget.onOpen)
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (context, index) {
                    final order = visible[index];
                    return OrderCard(
                      order: order,
                      onChangeStatus: widget.onChangeStatus == null
                          ? null
                          : (status) => widget.onChangeStatus!(order, status),
                      onTap: widget.onOpen == null
                          ? null
                          : () => widget.onOpen!(order),
                    );
                  },
                ),
        ),
        AdminPagination(
          page: page,
          pages: pages,
          count: filtered.length,
          labelBuilder: (first, last, count) =>
              OrderSummaryMetricFormat.digits(
                S.ordersRowsLabel(first, last, count),
              ),
          onChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}
