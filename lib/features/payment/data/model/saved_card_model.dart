import 'package:new_coffee/shared/utils/card_brand.dart';

class SavedCardModel {
  const SavedCardModel({
    required this.id,
    required this.brand,
    required this.last4,
    required this.holder,
    required this.expiry,
  });

  final String id;
  final CardBrand brand;
  final String last4;
  final String holder;
  final String expiry;
}
