import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/features/payments/data/models/tax_configuration.dart';

void main() {
  group('TaxConfiguration.fromJson', () {
    test('maps the VAT configuration RPC contract', () {
      final value = TaxConfiguration.fromJson({
        'registration_status': 'registered',
        'tax_rate': 15,
        'tax_included': true,
        'delivery_fee_taxable': false,
        'version': 3,
        'effective_at': '2026-01-01T00:00:00Z',
      });

      expect(value.registrationStatus, 'registered');
      expect(value.taxRate, 15);
      expect(value.taxIncluded, isTrue);
      expect(value.deliveryFeeTaxable, isFalse);
      expect(value.version, 3);
      expect(value.effectiveAt, DateTime.utc(2026));
    });

    test('provides safe defaults when optional fields are absent', () {
      final value = TaxConfiguration.fromJson(const {});

      expect(value.registrationStatus, 'unconfigured');
      expect(value.taxRate, 0);
      expect(value.taxIncluded, isFalse);
      expect(value.deliveryFeeTaxable, isFalse);
      expect(value.version, isNull);
      expect(value.effectiveAt, isNull);
    });
  });
}
