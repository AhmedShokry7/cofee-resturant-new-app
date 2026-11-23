import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/reports/domain/repositories/reports_repository.dart';
import 'package:admin_app/features/reports/presentation/manager/reports_cubit.dart';
import 'package:admin_app/features/reports/presentation/pages/reports_page.dart';
import 'package:admin_app/features/reports/presentation/widgets/reports_metric_cards.dart';
import 'package:admin_app/features/reports/presentation/widgets/reports_orders_table.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart.dart';

class _ReportsRepository implements ReportsRepository {
  _ReportsRepository(this.orders);
  final List<AdminOrder> orders;
  int loads = 0;

  @override
  Future<List<AdminOrder>> loadOrders() async {
    loads++;
    return orders;
  }
}

AdminOrder _order({
  required String id,
  required String status,
  required String productName,
  required double total,
}) {
  final now = DateTime.now();
  return AdminOrder(
    id: id,
    orderNumber: 'ORD-$id',
    userId: 'customer-$id',
    customerName: 'Customer $id',
    branchId: 'branch-1',
    branchNameAr: 'فرع الرياض',
    branchNameEn: 'Riyadh',
    fulfillmentType: 'pickup',
    status: status,
    paymentStatus: status == 'cancelled' ? 'refunded' : 'paid',
    subtotal: total,
    discountTotal: 0,
    deliveryFee: 0,
    taxTotal: 0,
    grandTotal: total,
    placedAt: DateTime(now.year, now.month, now.day, 12),
    items: [
      AdminOrderItem(
        productNameAr: 'قهوة',
        productNameEn: productName,
        quantity: 2,
        unitPrice: total / 2,
        lineTotal: total,
      ),
    ],
  );
}

void _setViewport(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpReports(
  WidgetTester tester, {
  required AppLanguage language,
  required double width,
  required AdminSearchController search,
  required ReportsCubit cubit,
}) async {
  AppLocale.instance.debugSet(language);
  _setViewport(tester, width);
  await cubit.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: language.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: ReportsPage(searchController: search, cubit: cubit),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('renders the full report with localized desktop breakdowns', (
    tester,
  ) async {
    final repository = _ReportsRepository([
      _order(id: '1', status: 'completed', productName: 'Latte', total: 30),
      _order(id: '2', status: 'cancelled', productName: 'Mocha', total: 12),
    ]);
    final cubit = ReportsCubit(repository: repository);
    final search = AdminSearchController();
    addTearDown(cubit.close);
    addTearDown(search.dispose);

    await _pumpReports(
      tester,
      language: AppLanguage.english,
      width: 1400,
      search: search,
      cubit: cubit,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.reports), findsOneWidget);
    expect(find.text(S.reportsSalesTrend), findsOneWidget);
    expect(find.text(S.reportsStatuses), findsOneWidget);
    expect(find.text(S.reportsPayments), findsWidgets);
    expect(find.text(S.reportsChannels), findsOneWidget);
    expect(find.text(S.reportsBranches), findsOneWidget);
    expect(find.byType(ReportsMetricCards), findsOneWidget);
    expect(find.byType(ReportsOrdersTable), findsOneWidget);
    expect(find.byType(AdminTrendChart), findsOneWidget);
    expect(find.text('ORD-1'), findsOneWidget);
    expect(find.text('ORD-2'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    // Cancelled tickets stay visible in orders but never inflate sold-product sales.
    expect(find.text('Mocha'), findsNothing);
    expect(find.text('30.00'), findsAtLeastNWidgets(1));
  });

  testWidgets('shell search filters report data without reloading', (
    tester,
  ) async {
    final repository = _ReportsRepository([
      _order(id: '1', status: 'completed', productName: 'Latte', total: 30),
      _order(id: '2', status: 'completed', productName: 'Mocha', total: 12),
    ]);
    final cubit = ReportsCubit(repository: repository);
    final search = AdminSearchController();
    addTearDown(cubit.close);
    addTearDown(search.dispose);

    await _pumpReports(
      tester,
      language: AppLanguage.english,
      width: 1200,
      search: search,
      cubit: cubit,
    );
    expect(repository.loads, 1);

    search.update('latte');
    await tester.pumpAndSettle();

    expect(find.text('ORD-1'), findsOneWidget);
    expect(find.text('ORD-2'), findsNothing);
    expect(cubit.analytics.sales, 30);
    expect(repository.loads, 1);
  });

  testWidgets('Arabic report fits a narrow viewport and filters to zero', (
    tester,
  ) async {
    final repository = _ReportsRepository([
      _order(id: '1', status: 'completed', productName: 'Latte', total: 30),
    ]);
    final cubit = ReportsCubit(repository: repository);
    final search = AdminSearchController();
    addTearDown(cubit.close);
    addTearDown(search.dispose);

    await _pumpReports(
      tester,
      language: AppLanguage.arabic,
      width: 390,
      search: search,
      cubit: cubit,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('التقارير'), findsOneWidget);
    expect(find.text('اتجاه المبيعات'), findsOneWidget);
    expect(find.text('تفاصيل الطلبات'), findsOneWidget);
    expect(find.text('ORD-1'), findsOneWidget);

    search.update('not-found');
    await tester.pumpAndSettle();
    expect(cubit.analytics.orders, isEmpty);
    expect(find.text(S.reportsNoOrders), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh is explicit and refetches the orders repository', (
    tester,
  ) async {
    final repository = _ReportsRepository([
      _order(id: '1', status: 'completed', productName: 'Latte', total: 30),
    ]);
    final cubit = ReportsCubit(repository: repository);
    final search = AdminSearchController();
    addTearDown(cubit.close);
    addTearDown(search.dispose);

    await _pumpReports(
      tester,
      language: AppLanguage.english,
      width: 1200,
      search: search,
      cubit: cubit,
    );
    await tester.tap(find.byKey(const Key('reports-refresh')));
    await tester.pumpAndSettle();

    expect(repository.loads, 2);
    expect(tester.takeException(), isNull);
  });
}
