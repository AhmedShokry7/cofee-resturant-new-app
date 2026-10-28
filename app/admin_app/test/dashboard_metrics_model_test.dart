import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/dashboard/data/models/admin_dashboard_metrics_model.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_channel_slice.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_sales_point.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_setup_step.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_insights.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('metrics payload', () {
    test('the jsonb shape of the function parses to every panel', () {
      final metrics = AdminDashboardMetricsModel.fromJson(
        const <String, dynamic>{
          'today_orders': 8,
          'today_revenue': 211.71,
          'yesterday_orders': 5,
          'yesterday_revenue': 140,
          'average_order_value': 26.46,
          'active_orders': 4,
          'total_orders': 8,
          'week_orders': 21,
          'week_revenue': 640,
          'prev_week_revenue': 500,
          'month_orders': 40,
          'month_revenue': 1800,
          'prev_month_orders': 35,
          'prev_month_revenue': 1500,
          'monthly_revenue_target': 1200,
          'total_customers': 96,
          'customers_before_month': 88,
          'new_customers': 6,
          'previous_new_customers': 4,
          'setup_steps': <Map<String, dynamic>>[
            {'key': 'first_product', 'done': true},
            {'key': 'revenue_target', 'done': false},
          ],
          'sales_series': <Map<String, dynamic>>[
            {'date': '2026-10-01', 'revenue': 120, 'orders': 2},
          ],
          'channels': <Map<String, dynamic>>[
            {'channel': 'pickup', 'orders': 3, 'revenue': 150},
          ],
          'top_products': <Map<String, dynamic>>[
            {
              'product_name_ar': 'لاتيه',
              'product_name_en': 'Latte',
              'quantity': 4,
              'revenue': 40,
              'image_url': 'https://cdn.test/latte.png',
            },
          ],
          'recent_orders': <Map<String, dynamic>>[
            {
              'id': 'r1',
              'order_number': 'ORD-71',
              'status': 'completed',
              'fulfillment_type': 'delivery',
              'grand_total': 55,
              'items_count': 2,
              'placed_at': '2026-10-02T18:00:00',
              'customer_name': 'Sara',
            },
          ],
        },
      );

      expect(metrics.todayOrders, 8);
      expect(metrics.averageOrderValue, 26.46);
      expect(metrics.prevMonthRevenue, 1500);
      expect(metrics.monthlyRevenueTarget, 1200);
      expect(metrics.totalCustomers, 96);
      expect(metrics.newCustomers, 6);
      expect(metrics.setupSteps.first.key, 'first_product');
      expect(metrics.setupSteps.last.done, isFalse);
      expect(metrics.salesSeries.single.date, DateTime(2026, 10, 1));
      expect(metrics.channels.single.orders, 3);
      expect(metrics.topProducts.single.quantity, 4);
      expect(metrics.topProducts.single.imageUrl, 'https://cdn.test/latte.png');
      expect(metrics.recentOrders.single.customerName, 'Sara');
      expect(metrics.hasAnyOrder, isTrue);
    });

    test('a withheld field stays silence instead of becoming a zero', () {
      // مدير فرع واحد لا تصله الهدف ولا العملاء: صفر هنا يعني «لا عملاء»،
      // والغياب يعني «لم يُسمح لك بالقراءة» — واللوحة تصمت في الحالة الثانية.
      final metrics = AdminDashboardMetricsModel.fromJson(
        const <String, dynamic>{'total_orders': 3},
      );

      expect(metrics.monthlyRevenueTarget, isNull);
      expect(metrics.totalCustomers, isNull);
      expect(metrics.customersBeforeMonth, isNull);
      expect(metrics.newCustomers, isNull);
      expect(metrics.previousNewCustomers, isNull);
    });

    test('a payload with nothing in it reads as no orders', () {
      final metrics = AdminDashboardMetricsModel.fromJson(
        const <String, dynamic>{},
      );

      expect(metrics.hasAnyOrder, isFalse);
      expect(metrics.setupSteps, isEmpty);
      expect(metrics.topProducts, isEmpty);
      expect(metrics.recentOrders, isEmpty);
    });

    test(
      'a row without a readable date is dropped, not stamped with a fake one',
      () {
        final metrics = AdminDashboardMetricsModel.fromJson(
          const <String, dynamic>{
            'total_orders': 4,
            'sales_series': <Map<String, dynamic>>[
              {'date': 'not-a-day', 'revenue': 90, 'orders': 1},
              {'date': '2026-10-02', 'revenue': 40, 'orders': 1},
            ],
            'recent_orders': <Map<String, dynamic>>[
              {'id': 'r9', 'order_number': 'ORD-9'},
            ],
          },
        );

        expect(metrics.salesSeries, hasLength(1));
        expect(metrics.salesSeries.single.revenue, 40);
        expect(metrics.recentOrders, isEmpty);
      },
    );

    test('an order line without a customer name keeps the name absent', () {
      final metrics = AdminDashboardMetricsModel.fromJson(
        const <String, dynamic>{
          'recent_orders': <Map<String, dynamic>>[
            {
              'id': 'r2',
              'order_number': 'ORD-72',
              'placed_at': '2026-10-01T09:00:00',
              'customer_name': null,
            },
          ],
        },
      );

      expect(metrics.recentOrders.single.customerName, isNull);
    });
  });

  group('derived figures', () {
    test('a window sums the days it was shown, never beyond them', () {
      final metrics = AdminDashboardMetrics(
        salesSeries: <AdminDashboardSalesPoint>[
          AdminDashboardSalesPoint(
            date: DateTime(2026, 10, 1),
            revenue: 100,
            orders: 2,
          ),
          AdminDashboardSalesPoint(
            date: DateTime(2026, 10, 2),
            revenue: 50,
            orders: 1,
          ),
        ],
      );

      expect(metrics.salesWindow(30), hasLength(2));
      expect(metrics.salesWindow(1).single.date, DateTime(2026, 10, 2));
      expect(metrics.revenueWindow(1), 50);
      expect(metrics.ordersWindow(1), 1);
    });

    test('growth and progress are ratios of two returned numbers', () {
      const metrics = AdminDashboardMetrics(
        weekRevenue: 640,
        prevWeekRevenue: 500,
        monthRevenue: 900,
        monthlyRevenueTarget: 1200,
      );

      expect(metrics.targetProgress, closeTo(.75, .0001));

      // بلا هدف مكتوب لا نسبة: قسمة على صفر تُختلق رقمًا لا تملكه القاعدة.
      expect(
        const AdminDashboardMetrics(monthRevenue: 100).targetProgress,
        isNull,
      );
    });

    test('a share has no denominator until the base sends rows', () {
      const metrics = AdminDashboardMetrics(
        weekRevenue: 200,
        channels: <AdminDashboardChannelSlice>[
          AdminDashboardChannelSlice(channel: 'pickup', orders: 3, revenue: 90),
          AdminDashboardChannelSlice(
            channel: 'dine_in',
            orders: 1,
            revenue: 30,
          ),
        ],
      );

      expect(metrics.channelRevenueTotal, 120);
      expect(metrics.shareOf(3, 4), .75);
      expect(metrics.shareOf(3, 0), 0);
      expect(const AdminDashboardMetrics().channelRevenueTotal, 0);
      expect(
        metrics.topProductShare(
          const AdminDashboardTopProduct(
            nameAr: '',
            nameEn: 'Latte',
            quantity: 1,
            revenue: 50,
          ),
        ),
        .25,
      );
    });

    test('the card counts the steps it can name, and only those', () {
      const metrics = AdminDashboardMetrics(
        setupSteps: <DashboardSetupStep>[
          DashboardSetupStep(key: 'first_product', done: true),
          DashboardSetupStep(key: 'shipping_zone', done: false),
          DashboardSetupStep(key: 'revenue_target', done: false),
          DashboardSetupStep(key: 'first_order', done: false),
        ],
      );

      // خطوة لا اسم للوحة بها تُحذف من السطر ومن المقام معًا: «١/٤» فوق ثلاثة
      // أسطر كذب، وسطرٌ برمز خام أمام الأدمن يُقرأ خللًا في المتجر.
      expect(dashboardVisibleSetupSteps(metrics), hasLength(3));
      expect(dashboardSetupLabel('shipping_zone'), isNull);
      expect(dashboardSetupLabel('first_product'), isNotNull);
      expect(
        dashboardVisibleSetupSteps(const AdminDashboardMetrics()),
        isEmpty,
      );
    });

    test('a product named in one language falls back to the other', () {
      const latinOnly = AdminDashboardTopProduct(
        nameAr: '',
        nameEn: 'Flat White',
        quantity: 1,
        revenue: 18,
      );

      expect(dashboardProductName(latinOnly), 'Flat White');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(dashboardProductName(latinOnly), 'Flat White');
    });
  });
}
