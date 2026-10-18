import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/shared/utils/card_brand.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';

void main() {
  test('SavedCardsCubit starts empty and never persists raw card data', () async {
    final cubit = SavedCardsCubit();
    await cubit.load();
    expect(cubit.state.cards, isEmpty);

    // addCard is a no-op for raw data: state remains empty without a backend.
    cubit.addCard(
      const SavedCardModel(
        id: 'local-1',
        brand: CardBrand.unknown,
        last4: '1234',
        holder: 'Test',
        expiry: '12/30',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.cards, isEmpty);
    await cubit.close();
  });
}
