import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_invoice_card.dart';

class _InvoiceRepository implements OrderInvoiceRepository {
  _InvoiceRepository(this.result);

  final Future<OrderInvoice?> result;
  int calls = 0;

  @override
  Future<OrderInvoice?> invoiceForOrder(String orderId) {
    calls++;
    return result;
  }
}

OrderInvoice _invoice({
  String status = 'issued',
  String invoiceNumber = 'INV-100',
  DateTime? issuedAt,
  String? documentUrl,
  Map<String, dynamic> snapshot = const {},
}) => OrderInvoice(
  invoiceId: 'invoice-1',
  invoiceNumber: invoiceNumber,
  invoiceType: 'simplified',
  status: status,
  issuedAt: issuedAt ?? DateTime.utc(2026, 11, 24),
  currencyCode: 'SAR',
  snapshot: snapshot,
  documentUrl: documentUrl,
);

Widget _app(
  OrderInvoiceRepository repository, {
  Future<bool> Function(Uri)? open,
}) => MaterialApp(
  home: Scaffold(
    body: ListView(
      children: [
        const Text('Order receipt remains visible'),
        OrderInvoiceCard(
          orderId: 'order-1',
          repository: repository,
          openDocument: open,
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('keeps the order receipt while no invoice exists', (
    tester,
  ) async {
    final repository = _InvoiceRepository(Future.value(null));
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Order receipt remains visible'), findsOneWidget);
    expect(find.text(S.invoicePending), findsOneWidget);
    expect(find.text(S.downloadInvoice), findsNothing);
    expect(repository.calls, 1);
  });

  testWidgets('does not label pending or failed invoices as issued', (
    tester,
  ) async {
    for (final status in ['pending', 'failed']) {
      final repository = _InvoiceRepository(
        Future.value(_invoice(status: status, documentUrl: 'https://x.test/a')),
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('INV-100'), findsNothing);
      expect(find.text(S.downloadInvoice), findsNothing);
      expect(
        find.text(status == 'failed' ? S.invoiceUnavailable : S.invoicePending),
        findsOneWidget,
      );
    }
  });

  testWidgets('shows issued invoice tax breakdown and opens only signed URL', (
    tester,
  ) async {
    final repository = _InvoiceRepository(
      Future.value(
        _invoice(
          snapshot: const {'taxable_total': 100, 'vat_total': 15},
          documentUrl: 'https://storage.example/signed/invoice.pdf?token=short',
        ),
      ),
    );
    Uri? opened;
    await tester.pumpWidget(
      _app(
        repository,
        open: (uri) async {
          opened = uri;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INV-100'), findsOneWidget);
    expect(find.text(S.taxableAmount), findsOneWidget);
    expect(find.text(S.vat), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('15.00'), findsOneWidget);
    await tester.tap(find.text(S.downloadInvoice));
    await tester.pumpAndSettle();
    expect(opened?.scheme, 'https');
    expect(opened?.queryParameters['token'], 'short');
  });

  testWidgets(
    'issued invoice without a secure document has no download action',
    (tester) async {
      final repository = _InvoiceRepository(
        Future.value(
          _invoice(documentUrl: 'http://storage.example/public/invoice.pdf'),
        ),
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('INV-100'), findsOneWidget);
      expect(find.text(S.invoiceDocumentUnavailable), findsOneWidget);
      expect(find.text(S.downloadInvoice), findsNothing);
    },
  );
}
