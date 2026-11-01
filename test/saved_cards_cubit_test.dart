import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/data/model/card_brand.dart';

class _FakeSavedCardsRepository implements SavedCardsRepository {
  _FakeSavedCardsRepository({this.failWith});

  final SaveCardException? failWith;
  final List<SavedCardModel> stored = [];
  int saveCalls = 0;

  @override
  Future<List<SavedCardModel>> listSavedCards() async => [...stored];

  @override
  Future<SavedCardModel> saveCard({
    required String number,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
  }) async {
    saveCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    final card = SavedCardModel(
      id: 'card-${stored.length + 1}',
      brand: CardBrand.visa,
      last4: number
          .replaceAll(RegExp(r'\D'), '')
          .substring(number.replaceAll(RegExp(r'\D'), '').length - 4),
      holder: holderName,
      expiry: '$expiryMonth/$expiryYear',
    );
    stored.insert(0, card);
    return card;
  }

  @override
  Future<void> deleteSavedCard(String id) async =>
      stored.removeWhere((card) => card.id == id);

  @override
  Future<void> setDefaultCard(String id) async {
    final failure = failWith;
    if (failure != null) throw failure;
    final target = stored.firstWhere((card) => card.id == id);
    for (var i = 0; i < stored.length; i++) {
      if (stored[i].id == id) {
        stored[i] = target.copyWith(isDefault: true);
      } else {
        stored[i] = stored[i].copyWith(isDefault: false);
      }
    }
  }
}

SavedCardModel _card(String id) => SavedCardModel(
  id: id,
  brand: CardBrand.visa,
  last4: '4242',
  holder: 'Test Holder',
  expiry: '12/30',
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('SavedCardsCubit.addCard', () {
    test('stores the card and reports it', () async {
      final repository = _FakeSavedCardsRepository();
      final cubit = SavedCardsCubit(repository: repository);

      final saved = await cubit.addCard(
        number: '4242424242424242',
        expiryMonth: '12',
        expiryYear: '30',
        cvv: '123',
        holderName: 'Test Holder',
      );

      expect(saved, isNotNull);
      expect(saved!.last4, '4242');
      expect(repository.saveCalls, 1);
      expect(cubit.state.isSaving, isFalse);
      // The list shows the new card without waiting for a manual reload.
      expect(cubit.state.cards.single.id, saved.id);
      await cubit.close();
    });

    test(
      'a failure is reported in the app language and stores nothing',
      () async {
        final repository = _FakeSavedCardsRepository(
          failWith: SaveCardException(S.cardDeclined),
        );
        final cubit = SavedCardsCubit(repository: repository);

        final saved = await cubit.addCard(
          number: '4242424242424242',
          expiryMonth: '12',
          expiryYear: '30',
          cvv: '123',
          holderName: 'Test Holder',
        );

        expect(saved, isNull);
        expect(cubit.state.cards, isEmpty);
        expect(cubit.state.saveError, S.cardDeclined);
        expect(cubit.state.isSaving, isFalse);
        await cubit.close();
      },
    );

    test('the message follows the app language', () async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      final repository = _FakeSavedCardsRepository(
        failWith: SaveCardException(S.cardDeclined),
      );
      final cubit = SavedCardsCubit(repository: repository);

      await cubit.addCard(
        number: '4242424242424242',
        expiryMonth: '12',
        expiryYear: '30',
        cvv: '123',
        holderName: 'Test Holder',
      );

      expect(cubit.state.saveError, S.cardDeclined);
      expect(cubit.state.saveError, isNot(contains('card')));
      await cubit.close();
    });

    test('a second tap while saving does not tokenize twice', () async {
      final repository = _FakeSavedCardsRepository();
      final cubit = SavedCardsCubit(repository: repository);

      final first = cubit.addCard(
        number: '4242424242424242',
        expiryMonth: '12',
        expiryYear: '30',
        cvv: '123',
        holderName: 'Test Holder',
      );
      final second = cubit.addCard(
        number: '4242424242424242',
        expiryMonth: '12',
        expiryYear: '30',
        cvv: '123',
        holderName: 'Test Holder',
      );

      expect(await first, isNotNull);
      expect(await second, isNull);
      expect(repository.saveCalls, 1);
      await cubit.close();
    });

    test(
      'without a backend it reports rather than pretending to save',
      () async {
        final cubit = SavedCardsCubit();

        final saved = await cubit.addCard(
          number: '4242424242424242',
          expiryMonth: '12',
          expiryYear: '30',
          cvv: '123',
          holderName: 'Test Holder',
        );

        expect(saved, isNull);
        expect(cubit.state.saveError, S.cardSaveNotAllowed);
        await cubit.close();
      },
    );

    test('the cubit starts empty and never persists raw card data', () async {
      final cubit = SavedCardsCubit();
      await cubit.load();
      expect(cubit.state.cards, isEmpty);
      await cubit.close();
    });
  });

  group('SavedCardsCubit.removeCard', () {
    test('deletes and reloads', () async {
      final repository = _FakeSavedCardsRepository();
      repository.stored.addAll([_card('a'), _card('b')]);
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      await cubit.removeCard('a');

      expect(cubit.state.cards.map((c) => c.id), ['b']);
      await cubit.close();
    });
  });

  group('SavedCardsCubit.setDefaultCard', () {
    test('makes the chosen card the only default', () async {
      final repository = _FakeSavedCardsRepository();
      repository.stored.addAll([_card('a'), _card('b'), _card('c')]);
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      final ok = await cubit.setDefaultCard('b');

      expect(ok, isTrue);
      expect(cubit.state.cards.where((c) => c.isDefault).map((c) => c.id), [
        'b',
      ]);
      expect(cubit.state.saveError, isNull);
      await cubit.close();
    });

    test(
      'a failure is reported and leaves the previous default alone',
      () async {
        final repository = _FakeSavedCardsRepository(
          failWith: SaveCardException(S.cardDeclined),
        );
        repository.stored.addAll([_card('a'), _card('b')]);
        final cubit = SavedCardsCubit(repository: repository);
        await cubit.load();

        final ok = await cubit.setDefaultCard('b');

        expect(ok, isFalse);
        expect(cubit.state.saveError, S.cardDeclined);
        // The list is untouched: a failed preference change must not silently
        // leave the customer with no default at all.
        expect(cubit.state.cards.where((c) => c.isDefault), isEmpty);
        await cubit.close();
      },
    );

    test('an unknown card is refused rather than defaulting nothing', () async {
      final repository = _FakeSavedCardsRepository();
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      final ok = await cubit.setDefaultCard('nope');

      expect(ok, isFalse);
      expect(cubit.state.saveError, isNotNull);
      await cubit.close();
    });
  });
}
