import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/reports/domain/entities/reports_analytics.dart';

AdminOrder _order({
  required String id,
  required DateTime date,
  String status = 'completed',
  String paymentStatus = 'paid',
  String channel = 'pickup',
  String branch = 'branch-1',
  String customer = 'customer-1',
  double total = 20,
  double discount = 2,
  List<AdminOrderItem> items = const [],
}) => AdminOrder(
  id: id,
  orderNumber: id,
  userId: customer,
  customerName: customer,
  branchId: branch,
  branchNameAr: branch == 'branch-1' ? 'فرع الرياض' : 'فرع جدة',
  branchNameEn: branch == 'branch-1' ? 'Riyadh' : 'Jeddah',
  fulfillmentType: channel,
  status: status,
  paymentStatus: paymentStatus,
  subtotal: total,
  discountTotal: discount,
  deliveryFee: 3,
  taxTotal: 1,
  grandTotal: total,
  placedAt: date,
  items: items,
);

void main() {
  group('ReportsAnalytics', () {
    final from = DateTime(2026, 4, 1);
    final to = DateTime(2026, 4, 30);
    final orders = <AdminOrder>[
      _order(
        id: 'one',
        date: DateTime(2026, 4, 3, 10),
        total: 40,
        items: const [
          AdminOrderItem(
            productNameAr: 'لاتيه',
            productNameEn: 'Latte',
            quantity: 2,
            unitPrice: 20,
            lineTotal: 40,
          ),
        ],
      ),
      _order(
        id: 'two',
        date: DateTime(2026, 4, 4, 12),
        customer: 'customer-2',
        status: 'cancelled',
        paymentStatus: 'refunded',
        channel: 'delivery',
        branch: 'branch-2',
        total: 30,
        items: const [
          AdminOrderItem(
            productNameAr: 'كيك',
            productNameEn: 'Cake',
            quantity: 1,
            unitPrice: 30,
            lineTotal: 30,
          ),
        ],
      ),
      _order(id: 'three', date: DateTime(2026, 3, 31, 23), total: 100),
    ];

    test('keeps cancelled orders in counts but excludes them from sales', () {
      final report = ReportsAnalytics.build(source: orders, from: from, to: to);

      expect(report.orders.map((order) => order.id), ['two', 'one']);
      expect(report.sales, 40);
      expect(report.paidSales, 40);
      expect(report.averageOrderValue, 40);
      expect(report.cancelledOrders, 1);
      expect(report.completedOrders, 1);
      expect(report.itemsSold, 2);
      expect(report.discountTotal, 2);
      expect(report.uniqueCustomers, 2);
      expect(report.salesPoints.length, 30);
      expect(report.salesPoints.first.date, DateTime(2026, 4, 1));
      expect(report.salesPoints[2].revenue, 40);
      expect(report.salesPoints[2].orders, 1);
      expect(report.products.single.nameEn, 'Latte');
      expect(report.products.single.quantity, 2);
      expect(report.branches.length, 2);
      expect(report.channels.map((row) => row.key), ['pickup', 'delivery']);
    });

    test('applies status, payment, channel, branch and text filters', () {
      final report = ReportsAnalytics.build(
        source: orders,
        from: from,
        to: to,
        status: 'completed',
        payment: 'paid',
        channel: 'pickup',
        branch: 'branch-1',
        query: 'latte',
      );

      expect(report.orders.map((order) => order.id), ['one']);
      expect(report.sales, 40);
      expect(report.cancelledOrders, 0);
    });

    test(
      'search ignores case and matching period excludes orders outside it',
      () {
        final report = ReportsAnalytics.build(
          source: orders,
          from: DateTime(2026, 4, 4),
          to: DateTime(2026, 4, 30),
          query: 'CUSTOMER-2',
        );

        expect(report.orders.map((order) => order.id), ['two']);
        expect(report.sales, 0);
        expect(report.paidSales, 0);
      },
    );

    test('aggregates daily revenue and monthly revenue windows', () {
      final source = [
        _order(id: 'jan-1', date: DateTime(2026, 1, 2), total: 10),
        _order(id: 'feb-1', date: DateTime(2026, 2, 2), total: 15),
      ];
      final report = ReportsAnalytics.build(
        source: source,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 5, 31),
      );

      expect(report.salesPoints.length, 5);
      expect(report.salesPoints[0].revenue, 10);
      expect(report.salesPoints[1].revenue, 15);
      expect(report.salesPoints[2].revenue, 0);
    });

    test('filters work even with an empty source and zero-safe values', () {
      final report = ReportsAnalytics.build(
        source: const [],
        from: from,
        to: to,
      );

      expect(report.sales, 0);
      expect(report.averageOrderValue, 0);
      expect(report.salesPoints, hasLength(30));
      expect(report.statuses, isEmpty);
      expect(report.products, isEmpty);
    });
  });
}
