import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/features/customers/data/models/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_page_body.dart';

AdminCustomer _customer(int index) => AdminCustomer(
  id: 'c$index',
  fullName: 'Customer $index',
  email: 'customer$index@example.com',
  createdAt: DateTime(2026, 1, index),
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('a narrow page fits without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exporting = ValueNotifier<bool>(false);
    addTearDown(exporting.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerPageBody(
            customers: <AdminCustomer>[
              for (var index = 1; index <= 6; index++) _customer(index),
            ],
            metrics: const AdminCustomerMetrics(
              totalCustomers: 6,
              newCustomers: 6,
            ),
            search: '',
            onSearchChanged: (_) {},
            onOpen: (_) {},
            onExport: (_) {},
            exporting: exporting,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(S.customersRowsLabel(1, 5, 6)), findsWidgets);
  });

  testWidgets('a very narrow page with an active filter fits', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exporting = ValueNotifier<bool>(false);
    addTearDown(exporting.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerPageBody(
            customers: <AdminCustomer>[
              for (var index = 1; index <= 6; index++) _customer(index),
            ],
            metrics: const AdminCustomerMetrics(
              totalCustomers: 6,
              newCustomers: 6,
            ),
            search: '',
            onSearchChanged: (_) {},
            onOpen: (_) {},
            onExport: (_) {},
            exporting: exporting,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip(S.customersFilter));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.customersFilterVip));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
