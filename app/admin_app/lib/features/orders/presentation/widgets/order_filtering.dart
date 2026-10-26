import 'package:admin_app/features/orders/domain/entities/admin_order.dart';

List<AdminOrder> filterOrders(
  List<AdminOrder> orders, {
  String search = '',
  String status = '',
  String fulfillment = '',
  String paymentStatus = '',
  String branchId = '',
}) {
  final query = search.trim().toLowerCase();
  return orders
      .where((order) {
        if (!_matchesStatus(order, status)) {
          return false;
        }
        if (fulfillment.isNotEmpty && order.fulfillmentType != fulfillment) {
          return false;
        }
        if (paymentStatus.isNotEmpty && order.paymentStatus != paymentStatus) {
          return false;
        }
        if (branchId.isNotEmpty && order.branchId != branchId) {
          return false;
        }
        if (query.isEmpty) return true;
        final text = <String>[
          order.orderNumber,
          order.customerName ?? '',
          order.customerEmail ?? '',
          order.customerPhone ?? '',
          order.branchNameAr ?? '',
          order.branchNameEn ?? '',
          for (final item in order.items) ...[
            item.productNameEn ?? '',
            item.productNameAr ?? '',
          ],
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}

bool _matchesStatus(AdminOrder order, String filter) => switch (filter) {
  '' => true,
  'processing' => const {
    'pending',
    'confirmed',
    'preparing',
    'ready',
  }.contains(order.status),
  'shipped' => order.status == 'out_for_delivery',
  _ => order.status == filter,
};
