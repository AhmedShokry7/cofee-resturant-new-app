import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/payment/data/model/card_brand.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/payment/presentation/views/widgets/saved_card_tile.dart';

/// A card store the screen can be pointed at, with the failures a real provider
/// produces: a read that never answers, a delete that is refused.
class _FakeSavedCardsRepository implements SavedCardsRepository {
  _FakeSavedCardsRepository({
    this.refuseList = false,
    this.refuseDelete = false,
    this.refuseSetDefault = false,
  });

  bool refuseList;
  bool refuseDelete;
  bool refuseSetDefault;

  /// When set, a read stops here until the test releases it. A fake that answers
  /// in the same microtask makes "the list has not been answered yet"
  /// unobservable, and that is the state the screen has to get right.
  Completer<void>? listGate;

  final List<SavedCardModel> stored = [];
  int listCalls = 0;
  int deleteCalls = 0;
  int setDefaultCalls = 0;

  @override
  Future<List<SavedCardModel>> listSavedCards() async {
    listCalls++;
    if (refuseList) throw StateError('socket hung up');
    await listGate?.future;
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
    throw UnimplementedError('the add-card form has its own cover');
  }

  @override
  Future<void> deleteSavedCard(String id) async {
    deleteCalls++;
    if (refuseDelete) {
      throw SaveCardException(
        AppCopy.cardDeleteFailed,
        failure: SaveCardFailure.temporary,
      );
    }
    stored.removeWhere((card) => card.id == id);
  }

  @override
  Future<void> setDefaultCard(String id) async {
    setDefaultCalls++;
    if (refuseSetDefault) {
      throw SaveCardException(
        AppCopy.saveCardFailed,
        failure: SaveCardFailure.temporary,
      );
    }
    for (var i = 0; i < stored.length; i++) {
      stored[i] = stored[i].copyWith(isDefault: stored[i].id == id);
    }
  }
}

SavedCardModel _card(
  String id, {
  bool isDefault = false,
  CardBrand brand = CardBrand.visa,
}) => SavedCardModel(
  id: id,
  brand: brand,
  last4: id,
  holder: 'Test Holder',
  expiry: '12/30',
  isDefault: isDefault,
);

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeSavedCardsRepository repository,
) {
  return tester.pumpWidget(
    // Mirrors AppProviders: the cubit is app level and sits above the
    // Navigator, so the add-card route this page pushes reads the same one.
    // The locale and direction come from AppLocale, the way app.dart wires
    // them, so an Arabic run of this screen really is a right-to-left one.
    BlocProvider(
      create: (_) => SavedCardsCubit(repository: repository),
      child: MaterialApp(
        locale: AppLocale.instance.locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: AppLocale.instance.textDirection,
          child: child ?? const SizedBox.shrink(),
        ),
        routes: {AddCardPage.routeName: (context) => const AddCardPage()},
        home: const SavedCardsPage(),
      ),
    ),
  );
}

/// Lets the snackbar expire so no timer outlives the test.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
    SupabaseService.debugSetSignedIn(true);
  });

  tearDown(SupabaseService.debugReset);

  testWidgets('opening the screen reads the cards again', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    repository.stored.add(_card('4242'));

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // The app reads once at start; the screen re-reads on entry, so a card
    // added or deleted elsewhere cannot stay on screen indefinitely.
    expect(repository.listCalls, greaterThan(0));
    expect(find.text('**** **** **** 4242'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an unanswered list is not labelled as an empty one', (
    tester,
  ) async {
    await _setSurface(tester);
    final gate = Completer<void>();
    final repository = _FakeSavedCardsRepository()..listGate = gate;
    repository.stored.add(_card('4242'));

    await _pumpPage(tester, repository);
    // One frame, before the read answers.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(S.noSavedCards), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('**** **** **** 4242'), findsOneWidget);
  });

  testWidgets('an empty book says so', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.noSavedCards), findsOneWidget);
    expect(find.text(S.couldNotLoadSavedCards), findsNothing);
  });

  testWidgets('a failed read offers a retry that answers the list', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository(refuseList: true);
    repository.stored.add(_card('4242'));

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // "No saved cards" would invite the customer to add the card the server
    // already holds.
    expect(find.text(S.couldNotLoadSavedCards), findsOneWidget);
    expect(find.text(S.noSavedCards), findsNothing);

    repository.refuseList = false;
    await tester.tap(find.text(S.retry));
    await tester.pumpAndSettle();

    expect(find.text('**** **** **** 4242'), findsOneWidget);
    expect(find.text(S.couldNotLoadSavedCards), findsNothing);
  });

  testWidgets('a card that is not the default offers both actions', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    repository.stored.addAll([_card('1111'), _card('2222', isDefault: true)]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // The row for the default card used to trade its star away for the trash,
    // and the other way round: a customer could not delete the default card,
    // and could not make a second one default without deleting the first.
    expect(find.byIcon(AppIcons.delete), findsNWidgets(2));
    expect(find.byIcon(AppIcons.star), findsOneWidget);
    expect(find.text(S.defaultCardBadge), findsOneWidget);
  });

  testWidgets('the star makes that card the default', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    repository.stored.addAll([_card('1111'), _card('2222', isDefault: true)]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.star));
    await tester.pumpAndSettle();

    expect(repository.setDefaultCalls, 1);
    expect(find.text('**** **** **** 2222'), findsOneWidget);
    // Only one default, and it is the one just chosen.
    expect(find.text(S.defaultCardBadge), findsOneWidget);
    expect(find.byIcon(AppIcons.star), findsOneWidget);
    expect(
      tester
          .widgetList<SavedCardTile>(find.byType(SavedCardTile))
          .where((tile) => tile.card.isDefault)
          .map((tile) => tile.card.id),
      ['1111'],
    );
  });

  testWidgets('deleting asks first, and a cancel deletes nothing', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    repository.stored.add(_card('4242'));

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();

    expect(find.text(S.deleteCardConfirm), findsOneWidget);
    expect(repository.deleteCalls, 0);

    await tester.tap(find.text(S.cancel));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(find.text('**** **** **** 4242'), findsOneWidget);
  });

  testWidgets('a confirmed delete takes the card off the list', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    repository.stored.addAll([_card('4242'), _card('1111')]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.delete).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text('**** **** **** 4242'), findsNothing);
    expect(find.text('**** **** **** 1111'), findsOneWidget);
  });

  testWidgets('a refused delete says why and keeps the card', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository(refuseDelete: true);
    repository.stored.add(_card('4242'));

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();

    // The card is still on the account, so the row stays and the reason shows.
    expect(find.text('**** **** **** 4242'), findsOneWidget);
    expect(find.text(S.cardDeleteFailed), findsOneWidget);
    await _expireSnackBar(tester);
  });

  testWidgets('a default that cannot be saved keeps the old one', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository(refuseSetDefault: true);
    repository.stored.addAll([_card('1111'), _card('2222', isDefault: true)]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.star));
    await tester.pumpAndSettle();

    expect(find.text(S.saveCardFailed), findsOneWidget);
    expect(
      tester
          .widgetList<SavedCardTile>(find.byType(SavedCardTile))
          .where((tile) => tile.card.isDefault)
          .map((tile) => tile.card.id),
      ['2222'],
    );
    await _expireSnackBar(tester);
  });

  testWidgets('the add-card button opens the form', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.addNewCard));
    await tester.pumpAndSettle();

    expect(find.byType(AddCardPage), findsOneWidget);
    expect(find.text(S.cardNumber), findsOneWidget);
  });

  testWidgets('a guest is asked to sign in and no card read is issued', (
    tester,
  ) async {
    await _setSurface(tester);
    SupabaseService.debugSetSignedIn(false);
    final repository = _FakeSavedCardsRepository();
    repository.stored.add(_card('4242'));

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.signInRequired), findsOneWidget);
    expect(find.text(S.paymentMethod), findsNothing);
    // The cards belong to one customer, so nothing may be read for a session
    // that has none.
    expect(repository.listCalls, 0);
  });

  testWidgets('the default row is drawn with the heavier hairline', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    repository.stored.addAll([_card('1111'), _card('2222', isDefault: true)]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    final widths = <String, double>{};
    for (final tile in tester.widgetList<SavedCardTile>(
      find.byType(SavedCardTile),
    )) {
      // The tile's own box is the first Container under it, and it is the one
      // wearing the border.
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byWidget(tile),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      widths[tile.card.id] = decoration.border!.top.width;
    }
    // The two weights come from the field-border tokens, the same pair the rest
    // of the app uses for "this one is the chosen one".
    expect(widths['2222'], AppDimensions.fieldBorderWidthActive);
    expect(widths['1111'], AppDimensions.fieldBorderWidth);
  });

  testWidgets('the widest brand still leaves both actions on the row', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    repository.stored.addAll([
      _card('1111', brand: CardBrand.discover),
      _card('2222', brand: CardBrand.mastercard, isDefault: true),
    ]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // Reaching this frame without an overflow is the assertion: the name gives
    // way to the two actions instead of pushing one of them off the tile.
    expect(find.byIcon(AppIcons.delete), findsNWidgets(2));
    expect(find.text('DISCOVER'), findsOneWidget);
    expect(find.text('MASTERCARD'), findsOneWidget);
  });

  testWidgets('the row reads the same right-to-left', (tester) async {
    await _setSurface(tester);
    AppLocale.instance.debugSet(AppLanguage.arabic);
    final repository = _FakeSavedCardsRepository();
    repository.stored.addAll([_card('1111'), _card('2222', isDefault: true)]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // The proof the frame above is actually mirrored, so this test cannot pass
    // by quietly rendering English left-to-right again.
    expect(
      Directionality.of(tester.element(find.byType(SavedCardTile).first)),
      TextDirection.rtl,
    );
    expect(find.text('**** **** **** 1111'), findsOneWidget);
    expect(find.text(S.defaultCardBadge), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsNWidgets(2));
    // The default card answers to both actions in Arabic too.
    expect(find.byIcon(AppIcons.star), findsOneWidget);
  });
}
