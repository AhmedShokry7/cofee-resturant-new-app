import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_page_body.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_state.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_channel_slice.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_sales_point.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_setup_step.dart';
import 'package:admin_app/shared/widgets/admin_panel_row.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

final _metrics = AdminDashboardMetrics(
  todayOrders: 8,
  todayRevenue: 211.71,
  yesterdayOrders: 5,
  yesterdayRevenue: 140,
  averageOrderValue: 26.46,
  yesterdayAverageOrderValue: 28,
  activeOrders: 4,
  totalOrders: 12,
  weekOrders: 21,
  weekRevenue: 640,
  prevWeekOrders: 18,
  prevWeekRevenue: 500,
  monthOrders: 30,
  monthRevenue: 900,
  prevMonthOrders: 20,
  prevMonthRevenue: 500,
  monthlyRevenueTarget: 1200,
  totalCustomers: 45,
  customersBeforeMonth: 39,
  salesSeries: <AdminDashboardSalesPoint>[
    AdminDashboardSalesPoint(
      date: DateTime(2026, 10, 1),
      revenue: 120,
      orders: 2,
    ),
    AdminDashboardSalesPoint(
      date: DateTime(2026, 10, 2),
      revenue: 240,
      orders: 3,
    ),
  ],
  channels: <AdminDashboardChannelSlice>[
    AdminDashboardChannelSlice(channel: 'pickup', orders: 3, revenue: 150),
    AdminDashboardChannelSlice(channel: 'dine_in', orders: 1, revenue: 50),
  ],
  topProducts: <AdminDashboardTopProduct>[
    AdminDashboardTopProduct(
      nameAr: 'Espresso',
      nameEn: 'Espresso',
      quantity: 3,
      revenue: 27,
    ),
    AdminDashboardTopProduct(
      nameAr: 'Iced',
      nameEn: 'Iced',
      quantity: 2,
      revenue: 36,
    ),
  ],
  recentOrders: <AdminDashboardRecentOrder>[
    AdminDashboardRecentOrder(
      id: 'r1',
      orderNumber: 'ORD-71',
      status: 'completed',
      fulfillmentType: 'delivery',
      grandTotal: 55,
      itemsCount: 2,
      placedAt: DateTime(2026, 10, 2, 18),
      customerName: 'Sara',
    ),
    AdminDashboardRecentOrder(
      id: 'r2',
      orderNumber: 'ORD-72',
      status: 'cancelled',
      fulfillmentType: 'pickup',
      grandTotal: 19,
      itemsCount: 1,
      placedAt: DateTime(2026, 10, 1, 9),
    ),
  ],
  setupSteps: <DashboardSetupStep>[
    DashboardSetupStep(key: 'first_product', done: true),
    DashboardSetupStep(key: 'branch_image', done: false),
    DashboardSetupStep(key: 'revenue_target', done: true),
    DashboardSetupStep(key: 'first_order', done: true),
  ],
);

void main() {
  testWidgets('probe board with equal height rows', (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: DashboardPageBody(
            state: AdminDashboardState(
              status: AdminDashboardStatus.ready,
              metrics: _metrics,
            ),
            staffName: 'Ahmed',
            canManageTarget: true,
            canAddProduct: true,
            onRefresh: () {},
            onRangeChanged: (_) {},
            onEditTarget: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminPanelRow), findsNWidgets(3));

    // البطاقات في الصف الواحد متساوية الارتفاع: نفس الحافة السفلى.
    final cards = tester
        .widgetList<AdminSectionCard>(find.byType(AdminSectionCard))
        .toList();
    expect(cards.length, greaterThanOrEqualTo(6));
    final rects = cards
        .map((card) => tester.getRect(find.byWidget(card)))
        .toList();
    final rows = <List<Rect>>[];
    for (final rect in rects) {
      final row = rows
          .where((r) => (r.first.top - rect.top).abs() < 1)
          .firstOrNull;
      if (row == null) {
        rows.add([rect]);
      } else {
        row.add(rect);
      }
    }
    final pairs = rows.where((r) => r.length > 1).toList();
    expect(pairs.length, 3, reason: 'ثلاثة صفوف ببطاقتين كلٌّ منها');
    for (final pair in pairs) {
      for (final rect in pair) {
        expect((rect.height - pair.first.height).abs(), lessThan(0.5));
      }
    }
  });
}
