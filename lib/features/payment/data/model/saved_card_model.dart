import 'package:new_coffee/features/payment/data/model/card_brand.dart';

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
    this.isDefault = false,
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

  /// The card this customer pays with by default.
  ///
  /// At most one per customer; the server enforces that with a partial unique
  /// index, so the app never has to arbitrate between two defaults.
  final bool isDefault;

  /// True when this card is the customer's preferred one.
  ///
  /// The checkout uses this to decide which card to charge without asking, so it
  /// has to be readable rather than inferred from list position.
  bool get isPreferred => isDefault;

  factory SavedCardModel.fromDatabase(Map<String, dynamic> json) {
    final brandName = json['brand']?.toString() ?? '';
    final brand = CardBrand.values.firstWhere(
      (value) => value.name.toLowerCase() == brandName.toLowerCase(),
      orElse: () => CardBrand.unknown,
    );
    final month = json['expiry_month']?.toString();
    final year = json['expiry_year']?.toString();
    final expiry =
        (month != null && year != null && month.isNotEmpty && year.isNotEmpty)
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
      isDefault: json['is_default'] == true,
    );
  }

  SavedCardModel copyWith({
    String? id,
    String? last4,
    String? holder,
    String? expiry,
    bool? isActive,
    bool? isDefault,
  }) => SavedCardModel(
    id: id ?? this.id,
    brand: brand,
    last4: last4 ?? this.last4,
    holder: holder ?? this.holder,
    expiry: expiry ?? this.expiry,
    tapCustomerId: tapCustomerId,
    tapCardId: tapCardId,
    paymentAgreementId: paymentAgreementId,
    expiryMonth: expiryMonth,
    expiryYear: expiryYear,
    isActive: isActive ?? this.isActive,
    isDefault: isDefault ?? this.isDefault,
  );
}
