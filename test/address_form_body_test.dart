import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/presentation/views/widgets/address_form_body.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/location/data/model/place_suggestion.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class _FakePlaceSearch implements PlaceSearchRepository {
  List<PlaceSuggestion> results = [];
  final List<String> queries = [];

  @override
  Future<List<PlaceSuggestion>> search(String query, {int limit = 8}) async {
    queries.add(query);
    return results.take(limit).toList();
  }

  @override
  Future<PlaceSuggestion?> reverse({
    required double latitude,
    required double longitude,
  }) async => null;
}

PlaceSuggestion _place(String label) => PlaceSuggestion(
  label: label,
  title: label,
  subtitle: '',
  latitude: 24.71360,
  longitude: 46.67530,
);

/// The form and the picker each own a text field, so they are told apart by
/// the hint they were built with.
Finder _field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  late _FakePlaceSearch search;

  /// The form is pushed as a route so confirming can pop it, like the app does.
  ///
  /// [captured] records the draft the form hands over; [save] is what comes
  /// back to it, so a write the server refused can be drawn as it really is.
  Future<void> open(
    WidgetTester tester, {
    AddressModel? address,
    ValueChanged<AddressModel>? captured,
    Future<String?> Function(AddressModel draft)? save,
  }) async {
    tester.view.physicalSize = const Size(360, 800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    search = _FakePlaceSearch();
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('ROOT')),
        routes: {
          'form': (_) => RepositoryProvider<PlaceSearchRepository>.value(
            value: search,
            child: Scaffold(
              body: AddressFormBody(
                address: address,
                onSave: (draft) async {
                  captured?.call(draft);
                  return save == null ? null : await save(draft);
                },
              ),
            ),
          ),
        },
      ),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('form');
    await tester.pumpAndSettle();
  }

  Future<void> name(WidgetTester tester, String value) =>
      tester.enterText(_field(S.addressNameHint), value);

  Future<void> typedPlace(WidgetTester tester, String value) =>
      tester.enterText(_field(S.searchLocation), value);

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();
  }

  testWidgets('a label with no name saves nothing', (tester) async {
    AddressModel? saved;
    await open(tester, captured: (model) => saved = model);

    await confirm(tester);

    expect(saved, isNull);
    expect(find.text(S.addAddressName), findsOneWidget);
  });

  testWidgets('a name with no pin saves nothing', (tester) async {
    AddressModel? saved;
    await open(tester, captured: (model) => saved = model);
    await name(tester, 'Home');

    await confirm(tester);

    expect(saved, isNull);
    expect(find.text(S.addAddressLocation), findsOneWidget);
  });

  testWidgets('a place that resolves to bare coordinates is rejected', (
    tester,
  ) async {
    // OpenStreetMap sometimes answers with "24.71360, 46.67530" instead of a
    // street name. That used to be saved as the customer's address.
    AddressModel? saved;
    await open(tester, captured: (model) => saved = model);
    search.results = [_place('24.71360, 46.67530')];
    await name(tester, 'Home');
    await typedPlace(tester, 'Riyadh');

    await confirm(tester);

    expect(saved, isNull);
    expect(find.text(S.locationUnavailable), findsOneWidget);
  });

  testWidgets('a new address is handed over without an id', (tester) async {
    AddressModel? saved;
    await open(tester, captured: (model) => saved = model);
    search.results = [_place('King Fahd Road, Riyadh')];
    await name(tester, 'Home');
    await typedPlace(tester, 'Riyadh');

    await confirm(tester);

    expect(saved?.id, isEmpty);
    expect(saved?.label, 'Home');
    expect(saved?.details, 'King Fahd Road, Riyadh');
    expect(saved?.latitude, 24.71360);
  });

  testWidgets('editing keeps the stored id and the default flag', (
    tester,
  ) async {
    AddressModel? saved;
    await open(
      tester,
      address: const AddressModel(
        id: 'address-1',
        label: 'Home',
        details: 'Olaya Street',
        latitude: 24.69,
        longitude: 46.67,
        isDefault: true,
      ),
      captured: (model) => saved = model,
    );
    await name(tester, 'Flat');

    await confirm(tester);

    expect(saved?.id, 'address-1');
    expect(saved?.label, 'Flat');
    expect(saved?.isDefault, isTrue);
    // The pin came from the stored address, so nothing was re-geocoded.
    expect(search.queries, isEmpty);
  });

  testWidgets('a write the server refused keeps the draft on screen', (
    tester,
  ) async {
    AddressModel? saved;
    await open(
      tester,
      captured: (model) => saved = model,
      save: (_) async => S.addressSaveFailed,
    );
    await name(tester, 'Home');
    search.results = [_place('King Fahd Road, Riyadh')];
    await typedPlace(tester, 'Riyadh');

    await confirm(tester);

    expect(saved?.label, 'Home');
    // The form is still the screen the customer is on, with the reason shown.
    expect(find.text(S.addressSaveFailed), findsOneWidget);
    expect(find.byType(AddressFormBody), findsOneWidget);
  });

  testWidgets('an address the server took closes the form', (tester) async {
    await open(tester);
    await name(tester, 'Home');
    search.results = [_place('King Fahd Road, Riyadh')];
    await typedPlace(tester, 'Riyadh');

    await confirm(tester);

    expect(find.byType(AddressFormBody), findsNothing);
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('a second tap while the write is on its way sends one save', (
    tester,
  ) async {
    final gate = Completer<String?>();
    var saves = 0;
    await open(
      tester,
      save: (_) async {
        saves++;
        return gate.future;
      },
    );
    await name(tester, 'Home');
    search.results = [_place('King Fahd Road, Riyadh')];
    await typedPlace(tester, 'Riyadh');

    await tester.tap(find.text(S.confirm));
    await tester.pump();
    // The button became the wait it is covering, so a second tap has no action
    // to fire.
    expect(find.text(S.confirm), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(CustomBtn), warnIfMissed: false);
    await tester.pump();

    expect(saves, 1);

    gate.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(AddressFormBody), findsNothing);
    expect(saves, 1);
  });
}
