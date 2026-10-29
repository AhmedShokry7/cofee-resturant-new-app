import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_cards.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_directory.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_page_body.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_table.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

AdminCustomer _customer(
  int index, {
  bool vip = false,
  bool blacklisted = false,
  int orders = 0,
}) => AdminCustomer(
  id: 'c$index',
  fullName: 'Customer $index',
  email: 'customer$index@example.com',
  ordersCount: orders,
  totalSpent: orders * 10,
  isVip: vip,
  isBlacklisted: blacklisted,
  createdAt: DateTime(2026, 1, index),
  lastOrderAt: orders > 0 ? DateTime(2026, 9, 1) : null,
);

List<AdminCustomer> _customers() => [
  _customer(1, vip: true, orders: 2),
  _customer(2),
  _customer(3),
  _customer(4),
  _customer(5),
  _customer(6),
];

Widget _wrap(Widget child, {double width = 1100, double height = 700}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

void _setViewport(
  WidgetTester tester, {
  double width = 1400,
  double height = 1000,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _directory(
  List<AdminCustomer> customers, {
  String search = '',
  ValueChanged<String>? onSearchChanged,
  ValueChanged<AdminCustomer>? onOpen,
  ValueChanged<List<AdminCustomer>>? onExport,
  ValueListenable<bool>? exporting,
}) => CustomerDirectory(
  customers: customers,
  search: search,
  onSearchChanged: onSearchChanged ?? (_) {},
  onOpen: onOpen ?? (_) {},
  onExport: onExport ?? (_) {},
  exporting: exporting,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the directory paginates the real customer rows', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(_wrap(_directory(_customers())));
    await tester.pump();

    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Customer 5'), findsOneWidget);
    expect(find.text('Customer 6'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AdminPagination),
        matching: find.text('2'),
      ),
    );
    await tester.pump();

    expect(find.text('Customer 6'), findsOneWidget);
    expect(find.text('Customer 1'), findsNothing);
  });

  testWidgets('the filters narrow the directory', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(_wrap(_directory(_customers())));
    await tester.pump();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIP customers'));
    await tester.pumpAndSettle();

    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Customer 2'), findsNothing);
    expect(find.text('VIP customers'), findsOneWidget);
  });

  testWidgets('the search field filters and resets the page', (tester) async {
    _setViewport(tester);
    var search = '';
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _wrap(
          _directory(
            _customers(),
            search: search,
            onSearchChanged: (value) => setState(() => search = value),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Customer 3');
    await tester.pump();

    expect(find.text('Customer 1'), findsNothing);
    expect(find.text('Customer 6'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CustomerTable),
        matching: find.text('Customer 3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('exporting uses the selected rows, or all filtered rows', (
    tester,
  ) async {
    _setViewport(tester);
    List<AdminCustomer>? exported;
    await tester.pumpWidget(
      _wrap(_directory(_customers(), onExport: (rows) => exported = rows)),
    );
    await tester.pump();

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(exported?.map((customer) => customer.id), ['c1']);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(exported, hasLength(6));
  });

  testWidgets('opening a customer uses the real row', (tester) async {
    _setViewport(tester);
    AdminCustomer? opened;
    await tester.pumpWidget(
      _wrap(_directory(_customers(), onOpen: (customer) => opened = customer)),
    );
    await tester.pump();

    await tester.tap(find.text('Customer 2'));
    await tester.pump();

    expect(opened?.id, 'c2');
  });

  testWidgets('narrow screens use the customer cards fallback', (tester) async {
    _setViewport(tester);
    AdminCustomer? opened;
    await tester.pumpWidget(
      _wrap(
        _directory(_customers(), onOpen: (customer) => opened = customer),
        width: 600,
      ),
    );
    await tester.pump();

    expect(find.byType(CustomerCards), findsOneWidget);

    await tester.tap(find.text('Customer 1'));
    await tester.pump();

    expect(opened?.id, 'c1');
  });

  testWidgets('the pagination speaks Arabic numerals', (tester) async {
    _setViewport(tester);
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(_wrap(_directory(_customers())));
    await tester.pump();

    expect(find.text('عرض ١–٥ من ٦ عميلًا'), findsOneWidget);
  });

  testWidgets('the metric cards show the aggregates from the backend', (
    tester,
  ) async {
    _setViewport(tester, width: 1200, height: 900);
    final exporting = ValueNotifier<bool>(false);
    addTearDown(exporting.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerPageBody(
            customers: _customers(),
            metrics: const AdminCustomerMetrics(
              totalCustomers: 42,
              newCustomers: 7,
              currentBuyers: 2,
              currentSpent: 300,
              currentRepeatBuyers: 1,
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

    expect(find.text('150.00'), findsOneWidget);
    expect(find.byType(CurrencyIcon), findsWidgets);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
  });
}
