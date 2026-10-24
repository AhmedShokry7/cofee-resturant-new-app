import 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
export 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';

/// The orders that match the search and the active filters.
///
/// The `admin_orders` RPC takes no filter parameters, so the dashboard
/// filters the page it already loaded instead of asking the database again.
List<AdminOrder> filterOrders(
  List<AdminOrder> orders, {
  String search = '',
  String status = '',
  String fulfillment = '',
  String paymentStatus = '',
  String branchId = '',
}) {
  final q = search.trim().toLowerCase();
  return orders
      .where((order) {
        if (status.isNotEmpty && order.status != status) return false;
        if (fulfillment.isNotEmpty && order.fulfillmentType != fulfillment) {
          return false;
        }
        if (paymentStatus.isNotEmpty && order.paymentStatus != paymentStatus) {
          return false;
        }
        if (branchId.isNotEmpty && order.branchId != branchId) return false;
        if (q.isEmpty) return true;
        return order.orderNumber.toLowerCase().contains(q) ||
            (order.customerName ?? '').toLowerCase().contains(q) ||
            order.items.any(
              (item) => (item.productNameEn ?? item.productNameAr ?? '')
                  .toLowerCase()
                  .contains(q),
            );
      })
      .toList(growable: false);
}

/// The list of the order cards, empty when nothing matches.
class OrderRecords extends StatelessWidget {
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
  final String search;
  final String status;
  final String fulfillment;
  final String paymentStatus;
  final String branchId;
  final void Function(AdminOrder order, String status)? onChangeStatus;
  final ValueChanged<AdminOrder>? onOpen;

  @override
  Widget build(BuildContext context) {
    final orders = filterOrders(
      this.orders,
      search: search,
      status: status,
      fulfillment: fulfillment,
      paymentStatus: paymentStatus,
      branchId: branchId,
    );
    if (orders.isEmpty) {
      return Center(
        child: Text(
          S.noOrdersForFilter,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          onChangeStatus: onChangeStatus == null
              ? null
              : (status) => onChangeStatus!(order, status),
          onTap: onOpen == null ? null : () => onOpen!(order),
        );
      },
    );
  }
}

/// One order, with its number, its customer, its status and its money.
