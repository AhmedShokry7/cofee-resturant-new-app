import 'package:new_coffee/shared/utils/card_brand.dart';

class SavedCardModel {
  const SavedCardModel({
    required this.id,
    required this.brand,
    required this.last4,
    required this.holder,
    required this.expiry,
    this.tapCustomerId,
    this.tapCardId,
    this.paymentAgreementId,
    this.expiryMonth,
    this.expiryYear,
    this.isActive = true,
  });

  final String id;
  final CardBrand brand;
  final String last4;
  final String holder;
  final String expiry;
  final String? tapCustomerId;
  final String? tapCardId;
  final String? paymentAgreementId;
  final String? expiryMonth;
  final String? expiryYear;
  final bool isActive;

  factory SavedCardModel.fromDatabase(Map<String, dynamic> json) {
    final brandName = json['brand']?.toString() ?? '';
    final brand = CardBrand.values.firstWhere(
      (value) => value.name.toLowerCase() == brandName.toLowerCase(),
      orElse: () => CardBrand.unknown,
    );
    final month = json['expiry_month']?.toString();
    final year = json['expiry_year']?.toString();
    final expiry = (month != null && year != null && month.isNotEmpty && year.isNotEmpty)
        ? '$month/$year'
        : (json['expiry']?.toString() ?? '');
    final last4 = json['last4']?.toString() ?? '';
    return SavedCardModel(
      id: json['id']?.toString() ?? '',
      brand: brand,
      last4: last4,
      holder: json['holder_name']?.toString() ?? '',
      expiry: expiry,
      tapCustomerId: json['tap_customer_id']?.toString(),
      tapCardId: json['tap_card_id']?.toString(),
      paymentAgreementId: json['payment_agreement_id']?.toString(),
      expiryMonth: month,
      expiryYear: year,
      isActive: json['is_active'] != false,
    );
  }
}
