import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_cubit.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_state.dart';
import 'package:admin_app/features/payments/presentation/pages/payment_page.dart';
import 'package:admin_app/features/payments/presentation/widgets/payment_records.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class _FakePaymentCubit extends AdminPaymentCubit {
  _FakePaymentCubit(this.payments);

  final List<AdminPayment> payments;

  @override
  Future<void> load() async {
    emit(
      AdminPaymentState(status: AdminPaymentStatus.ready, payments: payments),
    );
  }
}

const _payments = [
  AdminPayment(
    id: 'payment-1',
    orderNumber: 'ORD-1001',
    customerName: 'Ahmed',
    provider: 'stripe',
    providerReference: 'ref_1',
    amount: 120.5,
    currencyCode: 'EGP',
    status: 'captured',
    cardBrand: 'visa',
    cardLast4: '4242',
    verifiedByServer: true,
  ),
  AdminPayment(
    id: 'payment-2',
    orderNumber: 'ORD-1002',
    customerName: 'Mona',
    provider: 'paymob',
    amount: 80,
    currencyCode: 'EGP',
    status: 'failed',
  ),
];

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required AdminPaymentCubit cubit,
  required AdminSearchController search,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PaymentPage(searchController: search, cubit: cubit),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('payments page shows its header, actions and records', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    final cubit = _FakePaymentCubit(_payments);
    await cubit.load();

    await _pumpPage(tester, cubit: cubit, search: AdminSearchController());

    expect(find.text(S.payments), findsOneWidget);
    expect(find.text(S.paymentsDescription), findsOneWidget);
    expect(find.text(S.paymentsExport), findsOneWidget);
    expect(find.text(S.paymentsPrint), findsOneWidget);
    expect(find.text('ORD-1001'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text(S.paymentStatusPaid), findsOneWidget);
    expect(find.text(S.paymentStatusFailed), findsOneWidget);
    expect(find.text(S.verifiedByServer), findsOneWidget);

    final actions = tester
        .widgetList<AdminToolbarButton>(find.byType(AdminToolbarButton))
        .toList();
    expect(actions, hasLength(2));
    expect(actions.every((action) => action.onPressed != null), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payments page fits a narrow screen and filters by search', (
    tester,
  ) async {
    _setViewport(tester, 360);
    final cubit = _FakePaymentCubit(_payments);
    await cubit.load();
    final search = AdminSearchController();

    await _pumpPage(tester, cubit: cubit, search: search);
    expect(tester.takeException(), isNull);

    search.update('ORD-1002');
    await tester.pumpAndSettle();

    expect(find.text('ORD-1002'), findsOneWidget);
    expect(find.text('ORD-1001'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each payment card prints only its own transaction', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    AdminPayment? printed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentRecords(
            payments: _payments,
            onPrint: (payment) => printed = payment,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(S.paymentPrintOne), findsNWidgets(2));
    await tester.tap(find.byTooltip(S.paymentPrintOne).first);
    await tester.pump();

    expect(printed?.id, 'payment-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty payments page disables export and print', (tester) async {
    _setViewport(tester, 1280);
    final cubit = _FakePaymentCubit(const []);
    await cubit.load();

    await _pumpPage(tester, cubit: cubit, search: AdminSearchController());

    expect(find.text(S.noPaymentsYet), findsOneWidget);
    final actions = tester
        .widgetList<AdminToolbarButton>(find.byType(AdminToolbarButton))
        .toList();
    expect(actions.every((action) => action.onPressed == null), isTrue);
    expect(tester.takeException(), isNull);
  });
}
