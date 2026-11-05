import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/payment/data/model/card_brand.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

/// The card form checked against the two things it is for: it asks each brand
/// for what that brand actually prints, and it closes only once the backend
/// really stored the card.
class _FakeSavedCardsRepository implements SavedCardsRepository {
  _FakeSavedCardsRepository({this.saveFailure});

  /// Thrown from [saveCard] instead of storing, carrying the reason and the
  /// failure kind the screen branches on.
  SaveCardException? saveFailure;

  final List<SavedCardModel> stored = [];
  int listCalls = 0;
  int saveCalls = 0;

  /// Exactly what the page handed the backend, digits and all.
  final List<String> savedNumbers = [];
  final List<String> savedCvvs = [];
  final List<String> savedMonths = [];
  final List<String> savedYears = [];

  @override
  Future<List<SavedCardModel>> listSavedCards() async {
    listCalls++;
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
    savedNumbers.add(number);
    savedCvvs.add(cvv);
    savedMonths.add(expiryMonth);
    savedYears.add(expiryYear);
    final failure = saveFailure;
    if (failure != null) throw failure;
    final card = SavedCardModel(
      id: 'card-${stored.length + 1}',
      brand: detectCardBrand(number),
      last4: number.substring(number.length - 4),
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
  Future<void> setDefaultCard(String id) async {}
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1400) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Opens the form the way the customer does - pushed from another route, with
/// the app-level cubit above the navigator - so a pop is a real pop.
Future<void> _pumpForm(
  WidgetTester tester,
  _FakeSavedCardsRepository repository,
) async {
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => SavedCardsCubit(repository: repository),
      child: MaterialApp(
        routes: {AddCardPage.routeName: (context) => const AddCardPage()},
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AddCardPage.routeName),
                child: const Text('open-form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-form'));
  await tester.pumpAndSettle();
}

/// [cvvDigits] is what the field asks for at that moment, which follows the
/// brand already typed into the number field.
Future<void> _type(
  WidgetTester tester, {
  required String name,
  required String number,
  required String expiry,
  required String cvv,
  int cvvDigits = 3,
}) async {
  await tester.enterText(_field(S.cardHolderName), name);
  await tester.enterText(_field(S.cardNumber), number);
  await tester.enterText(_field(S.expiryFormatHint), expiry);
  await tester.enterText(_field(S.cvvHint(cvvDigits)), cvv);
  await tester.pump();
}

/// The save button is the only one on the form; the app bar title and the
/// button share [S.addCard], so the button is found by its type.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byType(CustomBtn));
  await tester.pumpAndSettle();
}

/// Lets the snackbar expire so no timer outlives the test.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
}

/// The four fields of this form are told apart by the hint they were built
/// with, which is also what the customer reads.
Finder _field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

String _expiryValue(WidgetTester tester) =>
    tester.widget<TextField>(_field(S.expiryFormatHint)).controller!.text;

void main() {
  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
    SupabaseService.debugSetSignedIn(true);
  });

  tearDown(SupabaseService.debugReset);

  testWidgets('a complete Visa saves, closes the form and says so', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '4242424242424242',
      expiry: '1230',
      cvv: '123',
    );
    await _tapSave(tester);

    expect(repository.saveCalls, 1);
    expect(repository.savedNumbers.single, '4242424242424242');
    expect(repository.savedMonths.single, '12');
    expect(repository.savedYears.single, '30');
    expect(find.byType(AddCardPage), findsNothing);
    expect(find.text(S.cardAdded), findsOneWidget);
    await _expireSnackBar(tester);
  });

  testWidgets('a fifteen-digit Amex is accepted', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '371449635398431',
      expiry: '1230',
      cvv: '1234',
      cvvDigits: 4,
    );
    await _tapSave(tester);

    // The length rule used to be one number for every brand, so a complete Amex
    // - which prints fifteen digits - could never be saved.
    expect(repository.saveCalls, 1);
    expect(repository.savedNumbers.single, '371449635398431');
    expect(repository.savedCvvs.single, '1234');
  });

  testWidgets('a fifteen-digit Visa is refused and nothing is sent', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '424242424242424',
      expiry: '1230',
      cvv: '123',
    );
    await _tapSave(tester);

    expect(find.text(S.validCardNumber), findsOneWidget);
    expect(repository.saveCalls, 0);
  });

  testWidgets('an Amex asks for four CVV digits and refuses three', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '371449635398431',
      expiry: '1230',
      cvv: '123',
      cvvDigits: 4,
    );
    await _tapSave(tester);

    expect(find.text(S.invalidCvvLength(4)), findsOneWidget);
    expect(repository.saveCalls, 0);
  });

  testWidgets('a month of thirteen is refused', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '4242424242424242',
      expiry: '1330',
      cvv: '123',
    );
    await _tapSave(tester);

    // Thirteen never arrives, and read against this month it looked "still
    // valid" for years.
    expect(find.text(S.invalidDate), findsOneWidget);
    expect(repository.saveCalls, 0);
  });

  testWidgets(
    'a pasted four-digit year is not read as a card that never expires',
    (tester) async {
      await _setSurface(tester);
      final repository = _FakeSavedCardsRepository();
      await _pumpForm(tester, repository);

      await _type(
        tester,
        name: 'Ahmed Shokry',
        number: '4242424242424242',
        expiry: '12/2025',
        cvv: '123',
      );

      // Two year digits at most: the field cannot hold '2025', so the expiry
      // rule is never handed a year whose century it has to guess.
      expect(_expiryValue(tester), '12/20');

      await _tapSave(tester);

      // '12/20' is a card that expired in 2020, not one valid until 4020.
      expect(find.text(S.cardExpired), findsOneWidget);
      expect(repository.saveCalls, 0);
    },
  );

  testWidgets('a refused save keeps the customer on the form', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository(
      saveFailure: SaveCardException(AppCopy.cardDeclined),
    );
    await _pumpForm(tester, repository);

    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '4242424242424242',
      expiry: '1230',
      cvv: '123',
    );
    await _tapSave(tester);

    expect(find.byType(AddCardPage), findsOneWidget);
    expect(find.text(S.cardDeclined), findsOneWidget);
    // The number stays typed: one refusal should not cost a customer the whole
    // card again.
    expect(
      tester.widget<TextField>(_field(S.cardNumber)).controller!.text,
      '4242 4242 4242 4242',
    );
    await _expireSnackBar(tester);
  });

  testWidgets('an empty form saves nothing', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    await _tapSave(tester);

    expect(repository.saveCalls, 0);
    expect(find.text(S.cardHolderRequired), findsOneWidget);
    expect(find.text(S.validCardNumber), findsOneWidget);
    expect(find.text(S.invalidDate), findsOneWidget);
    expect(find.byType(AddCardPage), findsOneWidget);
  });

  testWidgets('a backend that cannot store cards stops asking for the number', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository(
      saveFailure: SaveCardException(
        AppCopy.cardSavingNotConfigured,
        failure: SaveCardFailure.notConfigured,
      ),
    );
    await _pumpForm(tester, repository);

    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '4242424242424242',
      expiry: '1230',
      cvv: '123',
    );
    await _tapSave(tester);

    // An absent edge function is not something typing can fix, so the form that
    // collects a real card number is replaced by the reason and a way out.
    expect(_field(S.cardNumber), findsNothing);
    expect(find.text(S.cardSavingNotConfigured), findsWidgets);
    expect(find.widgetWithText(CustomBtn, S.back), findsOneWidget);

    await tester.tap(find.widgetWithText(CustomBtn, S.back));
    await tester.pumpAndSettle();
    expect(find.byType(AddCardPage), findsNothing);
  });

  testWidgets('a card that expires this month is still good', (tester) async {
    await _setSurface(tester);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final year = (now.year % 100).toString().padLeft(2, '0');
    await _type(
      tester,
      name: 'Ahmed Shokry',
      number: '4242424242424242',
      expiry: '$month$year',
      cvv: '123',
    );
    await _tapSave(tester);

    // The last day of the expiry month is the last day the card works, so the
    // current month must not be refused.
    expect(repository.saveCalls, 1);
  });

  testWidgets('a guest is not shown a form that would collect a card', (
    tester,
  ) async {
    await _setSurface(tester);
    SupabaseService.debugSetSignedIn(false);
    final repository = _FakeSavedCardsRepository();
    await _pumpForm(tester, repository);

    expect(_field(S.cardNumber), findsNothing);
    expect(find.text(S.signInRequired), findsOneWidget);
    expect(repository.saveCalls, 0);
  });
}
