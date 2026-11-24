/// Persisted VAT configuration values returned by the finance RPC.
class TaxConfiguration {
  const TaxConfiguration({
    required this.registrationStatus,
    required this.taxRate,
    required this.taxIncluded,
    required this.deliveryFeeTaxable,
    this.version,
    this.effectiveAt,
  });

  final String registrationStatus;
  final double taxRate;
  final bool taxIncluded;
  final bool deliveryFeeTaxable;
  final int? version;
  final DateTime? effectiveAt;

  factory TaxConfiguration.fromJson(Map<String, dynamic> json) =>
      TaxConfiguration(
        registrationStatus: '${json['registration_status'] ?? 'unconfigured'}',
        taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
        taxIncluded: json['tax_included'] == true,
        deliveryFeeTaxable: json['delivery_fee_taxable'] == true,
        version: (json['version'] as num?)?.toInt(),
        effectiveAt: DateTime.tryParse('${json['effective_at'] ?? ''}'),
      );
}
