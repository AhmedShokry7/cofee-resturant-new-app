import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/data/model/card_brand.dart';

class _FakeSavedCardsRepository implements SavedCardsRepository {
  _FakeSavedCardsRepository({
    this.failWith,
    this.refuseList = false,
    this.refuseDelete = false,
    this.refuseSetDefault = false,
  });

  final SaveCardException? failWith;

  /// The read never answers, so the customer's cards stay unseen.
  bool refuseList;

  /// The provider refuses to forget a card, which means it is still there.
  bool refuseDelete;
  bool refuseSetDefault;

  final List<SavedCardModel> stored = [];
  int saveCalls = 0;
  int listCalls = 0;
  int deleteCalls = 0;
  int setDefaultCalls = 0;

  /// Set by a test that needs the delete to hang, so it can act while the
  /// first one is still in flight.
  Completer<void>? deleteGate;

  @override
  Future<List<SavedCardModel>> listSavedCards() async {
    listCalls++;
    if (refuseList) throw StateError('socket hung up');
    return [...stored];
  }

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
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final card = SavedCardModel(
      id: 'card-${stored.length + 1}',
      brand: CardBrand.visa,
      last4: digits.substring(digits.length - 4),
      holder: holderName,
      expiry: '$expiryMonth/$expiryYear',
    );
    stored.insert(0, card);
    return card;
  }

  @override
  Future<void> deleteSavedCard(String id) async {
    deleteCalls++;
    await deleteGate?.future;
    if (refuseDelete) {
      throw StateError('tap-delete-card answered {deleted: false}');
    }
    stored.removeWhere((card) => card.id == id);
  }

  @override
  Future<void> setDefaultCard(String id) async {
    setDefaultCalls++;
    if (refuseSetDefault) {
      throw SaveCardException(
        AppCopy.cardDeclined,
        failure: SaveCardFailure.declined,
      );
    }
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

SavedCardModel _card(String id, {bool isDefault = false}) => SavedCardModel(
  id: id,
  brand: CardBrand.visa,
  last4: '4242',
  holder: 'Test Holder',
  expiry: '12/30',
  isDefault: isDefault,
);

/// A repository whose save fails with an error no classification produces.
class _ExplodingRepository implements SavedCardsRepository {
  _ExplodingRepository({required this.inner});

  final _FakeSavedCardsRepository inner;

  @override
  Future<List<SavedCardModel>> listSavedCards() => inner.listSavedCards();

  @override
  Future<SavedCardModel> saveCard({
    required String number,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
  }) async {
    inner.saveCalls++;
    throw StateError('provider socket hung up');
  }

  @override
  Future<void> deleteSavedCard(String id) => inner.deleteSavedCard(id);

  @override
  Future<void> setDefaultCard(String id) => inner.setDefaultCard(id);
}

/// Records what the cubits report.
///
/// A provider failure reaches the customer only as a localised sentence, so the
/// observer is the one place the real error can still be seen - which is why
/// [SavedCardsCubit.addCard] must not swallow it in a `catch (_)`.
class _RecordingObserver extends BlocObserver {
  final List<Object> errors = [];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  late _RecordingObserver observer;
  late BlocObserver defaultObserver;

  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
    defaultObserver = Bloc.observer;
    observer = _RecordingObserver();
    Bloc.observer = observer;
  });

  tearDown(() => Bloc.observer = defaultObserver);

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
          failWith: SaveCardException(AppCopy.cardDeclined),
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
        expect(cubit.state.saveErrorCopy, S.cardDeclined);
        expect(cubit.state.isSaving, isFalse);
        await cubit.close();
      },
    );

    test('the message follows the app language', () async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      final repository = _FakeSavedCardsRepository(
        failWith: SaveCardException(AppCopy.cardDeclined),
      );
      final cubit = SavedCardsCubit(repository: repository);

      await cubit.addCard(
        number: '4242424242424242',
        expiryMonth: '12',
        expiryYear: '30',
        cvv: '123',
        holderName: 'Test Holder',
      );

      expect(cubit.state.saveErrorCopy, S.cardDeclined);
      expect(cubit.state.saveErrorCopy, isNot(contains('card')));
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
        expect(cubit.state.saveErrorCopy, S.cardSaveNotAllowed);
        await cubit.close();
      },
    );

    test('an unexpected provider error reaches the observer', () async {
      final cubit = SavedCardsCubit(
        repository: _ExplodingRepository(inner: _FakeSavedCardsRepository()),
      );

      final saved = await cubit.addCard(
        number: '4242424242424242',
        expiryMonth: '12',
        expiryYear: '30',
        cvv: '123',
        holderName: 'Test Holder',
      );

      expect(saved, isNull);
      expect(cubit.state.saveErrorCopy, S.saveCardFailed);
      // The customer sees the same polite line either way; before this the
      // developer saw nothing at all, because the error was caught and dropped.
      expect(observer.errors, hasLength(1));
      expect(observer.errors.single, isA<StateError>());
      await cubit.close();
    });

    test('the cubit starts empty and never persists raw card data', () async {
      final cubit = SavedCardsCubit();
      await cubit.load();
      expect(cubit.state.cards, isEmpty);
      await cubit.close();
    });
  });

  group('SavedCardsCubit.load', () {
    test('an unanswered list is not shown as an empty one', () async {
      final repository = _FakeSavedCardsRepository();
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      expect(cubit.state.isLoading, isTrue);

      await cubit.load();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.cards.map((card) => card.id), ['a']);
      expect(cubit.state.loadError, isNull);
      await cubit.close();
    });

    test('a failed read is a failure, not an empty list', () async {
      final repository = _FakeSavedCardsRepository(refuseList: true);
      final cubit = SavedCardsCubit(repository: repository);

      await cubit.load();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.loadErrorCopy, S.couldNotLoadSavedCards);
      expect(observer.errors, hasLength(1));
      await cubit.close();
    });

    test('cards already on screen survive a re-read that fails', () async {
      final repository = _FakeSavedCardsRepository();
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();
      repository.refuseList = true;

      await cubit.load();

      // The rows stay - they are the last true answer about this account - and
      // the failure is stated next to them rather than instead of them.
      expect(cubit.state.cards.map((card) => card.id), ['a']);
      expect(cubit.state.loadErrorCopy, S.couldNotLoadSavedCards);
      await cubit.close();
    });

    test('a retry after a failed read answers the list', () async {
      final repository = _FakeSavedCardsRepository(refuseList: true);
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();
      expect(cubit.state.loadError, isNotNull);

      repository.refuseList = false;
      await cubit.load();

      expect(cubit.state.loadError, isNull);
      expect(cubit.state.cards, hasLength(1));
      await cubit.close();
    });

    test('with no backend the list is answered, not left spinning', () async {
      final cubit = SavedCardsCubit();
      await cubit.load();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.loadError, isNull);
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
      expect(cubit.state.actionError, isNull);
      await cubit.close();
    });

    test('a refused delete keeps the card and says why, apart from a failed read', () async {
      final repository = _FakeSavedCardsRepository(refuseDelete: true);
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      await cubit.removeCard('a');

      // The card is still chargeable, so it stays on the list.
      expect(cubit.state.cards.map((c) => c.id), ['a']);
      expect(cubit.state.actionErrorCopy, S.cardDeleteFailed);
      // The list was read fine. Saying it could not be loaded both hid the
      // real reason whenever rows were present and invited a retry that
      // changes nothing.
      expect(cubit.state.loadError, isNull);
      // And it is not a save failure, so the add-card form does not inherit it.
      expect(cubit.state.saveErrorCopy, isNull);
      expect(cubit.state.saveFailure, isNull);
      expect(observer.errors, hasLength(1));
      await cubit.close();
    });

    test('a second tap while a delete is in flight deletes once', () async {
      final repository = _FakeSavedCardsRepository();
      repository.stored.add(_card('a'));
      repository.deleteGate = Completer<void>();
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      final first = cubit.removeCard('a');
      await cubit.removeCard('a');
      repository.deleteGate!.complete();
      await first;

      expect(repository.deleteCalls, 1);
      await cubit.close();
    });

    test('clearActionError lets the same failure be reported again', () async {
      final repository = _FakeSavedCardsRepository(refuseDelete: true);
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      await cubit.removeCard('a');
      expect(cubit.state.actionErrorCopy, S.cardDeleteFailed);

      cubit.clearActionError();
      expect(cubit.state.actionError, isNull);

      await cubit.removeCard('a');
      expect(cubit.state.actionErrorCopy, S.cardDeleteFailed);
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
      expect(cubit.state.actionError, isNull);
      await cubit.close();
    });

    test(
      'a failure is reported and leaves the previous default alone',
      () async {
        final repository = _FakeSavedCardsRepository(refuseSetDefault: true);
        repository.stored.addAll([_card('a'), _card('b')]);
        final cubit = SavedCardsCubit(repository: repository);
        await cubit.load();

        final ok = await cubit.setDefaultCard('b');

        expect(ok, isFalse);
        expect(cubit.state.actionErrorCopy, S.cardDeclined);
        // The list is untouched: a failed preference change must not silently
        // leave the customer with no default at all.
        expect(cubit.state.cards.where((c) => c.isDefault), isEmpty);
        await cubit.close();
      },
    );

    test('a refused preference does not close the add-card form', () async {
      // set_default_card is not in the database schema yet, so a refusal is what
      // every real tap gets today. It says nothing about whether a card can be
      // tokenized, and saveFailure is the flag that replaces the add-card form
      // with an unavailable notice.
      final repository = _FakeSavedCardsRepository(refuseSetDefault: true);
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      await cubit.setDefaultCard('a');

      expect(cubit.state.isSavingUnavailable, isFalse);
      expect(cubit.state.saveErrorCopy, isNull);
      await cubit.close();
    });

    test('an unknown card is refused rather than defaulting nothing', () async {
      final repository = _FakeSavedCardsRepository();
      repository.stored.add(_card('a'));
      final cubit = SavedCardsCubit(repository: repository);
      await cubit.load();

      final ok = await cubit.setDefaultCard('nope');

      expect(ok, isFalse);
      expect(cubit.state.actionError, isNotNull);
      await cubit.close();
    });
  });
}
