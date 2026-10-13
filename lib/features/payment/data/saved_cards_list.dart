import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/shared/utils/card_brand.dart';

List<SavedCardModel> getSavedCardsList() {
  return const [
    SavedCardModel(
      id: "1",
      brand: CardBrand.visa,
      last4: "4242",
      holder: "Ahmed Shokry",
      expiry: "02/30",
    ),
    SavedCardModel(
      id: "2",
      brand: CardBrand.mastercard,
      last4: "4444",
      holder: "Ahmed Shokry",
      expiry: "09/28",
    ),
  ];
}
