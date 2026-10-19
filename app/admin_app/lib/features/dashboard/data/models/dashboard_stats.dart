class RecentOrder {
  const RecentOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.grandTotal,
    required this.fulfillmentType,
    this.placedAt,
  });

  final String id;
  final String orderNumber;
  final String status;
  final double grandTotal;
  final String fulfillmentType;
  final DateTime? placedAt;

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    return RecentOrder(
      id: '${json['id'] ?? ''}',
      orderNumber: '${json['order_number'] ?? ''}',
      status: '${json['status'] ?? ''}',
      grandTotal: _toDouble(json['grand_total']),
      fulfillmentType: '${json['fulfillment_type'] ?? ''}',
      placedAt: DateTime.tryParse('${json['placed_at'] ?? ''}'),
    );
  }
}

class DashboardStats {
  const DashboardStats({
    this.todayOrders,
    this.todayRevenue,
    this.activeOrders,
    this.totalOrders,
    this.activeProducts,
    this.customers,
    this.activeBranches,
    this.recentOrders = const <RecentOrder>[],
  });

  final int? todayOrders;
  final double? todayRevenue;
  final int? activeOrders;
  final int? totalOrders;
  final int? activeProducts;
  final int? customers;
  final int? activeBranches;
  final List<RecentOrder> recentOrders;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
