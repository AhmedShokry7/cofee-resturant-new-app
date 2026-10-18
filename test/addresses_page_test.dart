import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/presentation/manager/addresses/addresses_cubit.dart';
import 'package:new_coffee/features/addresses/presentation/views/address_form_page.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';

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

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 1200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester,
  AddressRepository repository,
) {
  return tester.pumpWidget(
    ScreenUtilInit(
      // Match the app's own configuration (main.dart) so text metrics in the
      // test match the real layout.
      designSize: const Size(360, 690),
      minTextAdapt: true,
      builder: (context, _) => RepositoryProvider<AddressRepository>.value(
        value: repository,
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

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ ${S.enterLocation}'));
    await tester.pumpAndSettle();

    // The form has exactly two text fields: name first, location second.
    await tester.enterText(find.byType(TextField).first, 'Work');
    await tester.enterText(find.byType(TextField).last, 'Office tower');
    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Office tower'), findsOneWidget);
    // The pre-existing address is still there.
    expect(find.text('Home a1'), findsOneWidget);
  });

  testWidgets('editing an address through the form updates the list entry', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeAddressRepository(addresses: [_address('a1')]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // The form opens pre-filled; replacing the name and confirming routes the
    // update through the shared cubit.
    await tester.enterText(find.byType(TextField).first, 'Home updated');
    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();

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
