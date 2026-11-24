import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;

  setUp(() {
    client = SupabaseClient('http://localhost:54321', 'test-key');
  });

  tearDown(() => client.dispose());

  test(
    'invoice lookup uses the customer RPC and returns its snapshot',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final repository = SupabaseOrdersRepository(
        client: client,
        userIdProvider: () => 'customer-1',
        rpc: (name, params) async {
          calls.add((name, params));
          return {
            'invoice_id': 'invoice-1',
            'invoice_number': 'INV-1',
            'invoice_type': 'simplified',
            'status': 'issued',
            'issued_at': '2026-11-24T10:00:00Z',
            'currency_code': 'SAR',
            'snapshot': {
              'taxable_total': '100.00',
              'vat_total': 15,
              'tax_rate': 15,
              'tax_included': true,
            },
            'document_url':
                'https://storage.example/signed/invoice.pdf?token=short',
          };
        },
      );

      final invoice = await repository.invoiceForOrder(
        '11111111-1111-4111-8111-111111111111',
      );

      expect(calls, hasLength(1));
      expect(calls.single.$1, 'my_order_invoice');
      expect(calls.single.$2, {
        'p_order_id': '11111111-1111-4111-8111-111111111111',
      });
      expect(invoice?.invoiceNumber, 'INV-1');
      expect(invoice?.taxableAmount, 100);
      expect(invoice?.vatAmount, 15);
      expect(invoice?.taxRate, 15);
      expect(invoice?.taxIncluded, isTrue);
      expect(invoice?.secureDocumentUri?.scheme, 'https');
    },
  );

  test(
    'missing invoices are null and malformed order ids never call RPC',
    () async {
      var called = false;
      final repository = SupabaseOrdersRepository(
        client: client,
        userIdProvider: () => 'customer-1',
        rpc: (name, params) async {
          called = true;
          return null;
        },
      );

      expect(await repository.invoiceForOrder('not-a-uuid'), isNull);
      expect(called, isFalse);
    },
  );

  test(
    'invoice is not issued without an issued status, number and timestamp',
    () {
      final invoice = OrderInvoice.fromJson({
        'invoice_id': 'invoice-1',
        'invoice_number': 'INV-1',
        'invoice_type': 'simplified',
        'status': 'pending',
        'currency_code': 'SAR',
        'snapshot': const <String, dynamic>{},
        'document_url':
            'https://storage.example/signed/invoice.pdf?token=short',
      });

      expect(invoice.isIssued, isFalse);
      expect(invoice.secureDocumentUri, isNull);
    },
  );

  test('invoice document access rejects insecure or malformed URLs', () {
    final invoice = OrderInvoice.fromJson({
      'invoice_id': 'invoice-1',
      'invoice_number': 'INV-1',
      'invoice_type': 'simplified',
      'status': 'issued',
      'issued_at': '2026-11-24T10:00:00Z',
      'currency_code': 'SAR',
      'snapshot': const <String, dynamic>{},
      'document_url': 'http://storage.example/public/invoice.pdf',
    });

    expect(invoice.isIssued, isTrue);
    expect(invoice.secureDocumentUri, isNull);
  });
}
