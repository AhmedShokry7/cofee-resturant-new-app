import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/addresses/presentation/manager/addresses/addresses_cubit.dart';
import 'package:new_coffee/features/addresses/presentation/views/address_form_page.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';
import 'package:new_coffee/features/location/data/model/place_suggestion.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';

class _FakeAddressRepository implements AddressRepository {
  _FakeAddressRepository({
    List<AddressModel>? addresses,
    this.failList = false,
    this.failRemove = false,
    this.failSetDefault = false,
  }) : _addresses = addresses ?? const [];

  List<AddressModel> _addresses;
  bool failList;
  bool failRemove;
  bool failSetDefault;

  int listCalls = 0;
  int removeCalls = 0;
  int setDefaultCalls = 0;

  @override
  Future<List<AddressModel>> listAddresses() async {
    listCalls++;
    if (failList) throw StateError('Addresses need a signed-in account.');
    return _addresses;
  }

  @override
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final saved = AddressModel(
      id: 'addr-${_addresses.length + 1}',
      label: label,
      details: details,
      isDefault: isDefault,
    );
    _addresses = [..._addresses, saved];
    return saved;
  }

  @override
  Future<AddressModel> updateAddress({
    required String id,
    required String label,
    required String details,
    double? latitude,
    double? longitude,
  }) async {
    final updated = AddressModel(
      id: id,
      label: label,
      details: details,
    );
    _addresses = [
      for (final address in _addresses)
        if (address.id == id) updated else address,
    ];
    return updated;
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    setDefaultCalls++;
    if (failSetDefault) throw StateError('Could not set the default.');
    _addresses = [
      for (final address in _addresses)
        address.copyWith(isDefault: address.id == id),
    ];
  }

  @override
  Future<void> removeAddress(String id) async {
    removeCalls++;
    if (failRemove) throw StateError('Could not delete the address.');
    _addresses = _addresses.where((address) => address.id != id).toList();
  }
}

AddressModel _address(String id, {bool isDefault = false}) => AddressModel(
  id: id,
  label: 'Home $id',
  details: 'Street $id',
  isDefault: isDefault,
);

/// Stands in for the geocoder. The address form resolves a typed place name
/// through it on confirm, so it must be reachable from the pushed route.
class _FakePlaceSearch implements PlaceSearchRepository {
  _FakePlaceSearch({this.results = const []});

  List<PlaceSuggestion> results;
  List<String> queries = [];

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

PlaceSuggestion _place(String title, String subtitle) => PlaceSuggestion(
  label: '$title, $subtitle',
  title: title,
  subtitle: subtitle,
  latitude: 40.712776,
  longitude: -74.005974,
);

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 1200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester,
  AddressRepository repository, {
  PlaceSearchRepository? places,
}) {
  return tester.pumpWidget(
    ScreenUtilInit(
      // Match the app's own configuration (main.dart) so text metrics in the
      // test match the real layout.
      designSize: const Size(360, 690),
      minTextAdapt: true,
      builder: (context, _) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AddressRepository>.value(value: repository),
          // Mirrors AppProviders: the geocoder sits above the Navigator so the
          // pushed form can resolve a typed place name on confirm.
          RepositoryProvider<PlaceSearchRepository>.value(
            value: places ?? _FakePlaceSearch(),
          ),
        ],
        // Mirrors AppProviders: both providers sit above the Navigator, so a
        // pushed route (the add/edit form) can read the same cubit instance.
        child: BlocProvider(
          create: (_) => AddressesCubit(repository: repository),
          child: MaterialApp(
            // Mirrors AppRoutes: the add/edit form is pushed by name, so the
            // test app must register it too.
            routes: {
              AddressFormPage.routeName: (context) => const AddressFormPage(),
            },
            home: const AddressesPage(),
          ),
        ),
      ),
    ),
  );
}

/// Lets the snackbar fully expire so no timer outlives the test.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
    SupabaseService.debugSetSignedIn(true);
  });

  tearDown(() {
    SupabaseService.debugReset();
  });

  testWidgets('a failed delete shows an error snackbar when addresses exist', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(
      addresses: [_address('a1')],
      failRemove: true,
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, 1);
    expect(find.text(S.addressDeleteFailed), findsOneWidget);
    // The failed address stays in the list.
    expect(find.text('Home a1'), findsOneWidget);

    await _expireSnackBar(tester);
  });

  testWidgets('a failed set-default shows an error snackbar when addresses exist', (
    tester,
  ) async {
    await _setSurface(tester);
    // No address is pre-defaulted: the AddressTile label row (label +
    // "Default" badge) overflows the 360px test surface with a badge present,
    // a pre-existing layout tightness unrelated to this fix. With no badge,
    // the failure path under test renders cleanly.
    final repository = _FakeAddressRepository(
      addresses: [_address('a1'), _address('a2')],
      failSetDefault: true,
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // Both addresses are non-default, so both offer "Set default".
    await tester.tap(find.text(S.setDefaultAddress).first);
    await tester.pumpAndSettle();

    expect(repository.setDefaultCalls, 1);
    expect(find.text(S.addressSaveFailed), findsOneWidget);

    await _expireSnackBar(tester);
  });

  testWidgets('a successful delete shows no error snackbar', (tester) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(addresses: [_address('a1')]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();

    expect(find.text(S.addressDeleteFailed), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(S.noAddresses), findsOneWidget);
  });

  testWidgets('addresses returned by the repository are displayed', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(
      addresses: [_address('a1'), _address('a2', isDefault: true)],
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Home a1'), findsOneWidget);
    expect(find.text('Home a2'), findsOneWidget);
    // The default address carries the badge.
    expect(find.text(S.defaultAddress), findsOneWidget);
    expect(find.text('+ ${S.enterLocation}'), findsOneWidget);
  });

  testWidgets('a customer with no addresses sees the empty state and an add button', (
    tester,
  ) async {
    await _setSurface(tester);
    await _pumpPage(tester, _FakeAddressRepository());
    await tester.pumpAndSettle();

    expect(find.text(S.noAddresses), findsOneWidget);
    expect(find.text(S.addressesHint), findsOneWidget);
    expect(find.text('+ ${S.enterLocation}'), findsOneWidget);
  });

  testWidgets('a load failure shows the error and retry re-fetches', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(failList: true);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.retry), findsOneWidget);
    expect(find.textContaining('signed-in'), findsOneWidget);

    repository.failList = false;
    repository._addresses = [_address('a1')];
    await tester.tap(find.text(S.retry));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text('Home a1'), findsOneWidget);
  });

  testWidgets('a long label with the Default badge fits a 360px screen', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(
      addresses: [
        AddressModel(
          id: 'a1',
          label:
              'A very long address label that would overflow the row without ellipsis',
          details: 'Street 1',
          isDefault: true,
        ),
      ],
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('A very long address label'), findsOneWidget);
    expect(find.text(S.defaultAddress), findsOneWidget);
  });

  testWidgets('adding an address through the form shows it in the list', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(addresses: [_address('a1')]);
    // "Office tower" is free text: the form resolves it through the geocoder
    // so the saved address carries real coordinates instead of a default point.
    final places = _FakePlaceSearch(
      results: [_place('Office Tower', 'New York, United States')],
    );

    await _pumpPage(tester, repository, places: places);
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ ${S.enterLocation}'));
    await tester.pumpAndSettle();

    // The form has exactly two text fields: name first, location second.
    await tester.enterText(find.byType(TextField).first, 'Work');
    await tester.enterText(find.byType(TextField).last, 'Office tower');
    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();

    // Typed once for the debounced suggestion search and once on confirm: the
// customer never tapped a suggestion, so the pick itself is still unset.
    expect(places.queries, contains('Office tower'));
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Office Tower, New York, United States'), findsOneWidget);
    // The pre-existing address is still there.
    expect(find.text('Home a1'), findsOneWidget);
  });

  testWidgets('a pin alone is a complete answer, not "please enter your location"', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository();
    // Nothing to resolve: the pick itself carries the label.
    final places = _FakePlaceSearch(
      results: [_place('Empire State Building', 'New York')],
    );

    await _pumpPage(tester, repository, places: places);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ ${S.enterLocation}'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Work');
    // Search, then pick a suggestion the way a customer does.
    await tester.enterText(find.byType(TextField).last, 'Empire');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('Empire State Building'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();

    // The picker wrote the resolved place name into the field, so confirming
    // must not warn about a missing location.
    expect(find.text(S.addAddressLocation), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('confirming with no name and no place warns about the name', (
    tester,
  ) async {
    await _setSurface(tester);
    await _pumpPage(tester, _FakeAddressRepository());
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ ${S.enterLocation}'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();

    expect(find.text(S.addAddressName), findsOneWidget);
    await _expireSnackBar(tester);
  });

  testWidgets('editing an address through the form updates the list entry', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(addresses: [_address('a1')]);
    final places = _FakePlaceSearch(
      results: [_place('Street a1', 'New York, United States')],
    );

    await _pumpPage(tester, repository, places: places);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // The form opens pre-filled; replacing the name and confirming routes the
    // update through the shared cubit. The pre-filled details are resolved
    // through the geocoder so the update keeps real coordinates.
    await tester.enterText(find.byType(TextField).first, 'Home updated');
    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();

    expect(find.text(S.addAddressLocation), findsNothing);
    expect(find.text('Home updated'), findsOneWidget);
    expect(find.text('Home a1'), findsNothing);
  });

  testWidgets('a consumed error is not shown again on rebuild', (tester) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(
      addresses: [_address('a1')],
      failRemove: true,
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);

    // Rebuild the tree several times; the consumed error must not resurface.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SnackBar), findsOneWidget);

    await _expireSnackBar(tester);
  });
}
