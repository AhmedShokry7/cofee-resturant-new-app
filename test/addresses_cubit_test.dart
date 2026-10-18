import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/addresses/presentation/manager/addresses/addresses_cubit.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';

class _FakeAddressRepository implements AddressRepository {
  _FakeAddressRepository({
    List<AddressModel>? addresses,
    this.failList = false,
    this.failAdd = false,
    this.failUpdate = false,
    this.failSetDefault = false,
    this.failRemove = false,
  }) : _addresses = addresses ?? const [];

  List<AddressModel> _addresses;
  bool failList;
  bool failAdd;
  bool failUpdate;
  bool failSetDefault;
  bool failRemove;

  int listCalls = 0;
  int setDefaultCalls = 0;
  int removeCalls = 0;

  /// Identity the next read is issued as. Null keeps the legacy behavior of
  /// returning `_addresses` regardless of session.
  String? sessionUserId;
  final Map<String, List<AddressModel>> _byUser = {};

  /// Holds the next read open until completed, to test in-flight reads.
  Completer<void>? gate;

  void seedUser(String userId, List<AddressModel> addresses) =>
      _byUser[userId] = List<AddressModel>.of(addresses);

  @override
  Future<List<AddressModel>> listAddresses() async {
    listCalls++;
    // What the server held at request time, captured before any await, the
    // way a real answer belongs to the request and not to the moment it
    // lands.
    final snapshot = sessionUserId == null
        ? List<AddressModel>.of(_addresses)
        : List<AddressModel>.of(_byUser[sessionUserId] ?? const []);
    final held = gate;
    if (held != null) {
      gate = null;
      await held.future;
    }
    if (failList) throw StateError('Addresses need a signed-in account.');
    return snapshot;
  }

  @override
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    if (failAdd) throw StateError('Could not save the address.');
    final saved = AddressModel(
      id: 'addr-${_addresses.length + 1}',
      label: label,
      details: details,
      latitude: latitude,
      longitude: longitude,
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
    if (failUpdate) throw StateError('Could not update the address.');
    final updated = AddressModel(
      id: id,
      label: label,
      details: details,
      latitude: latitude,
      longitude: longitude,
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

void main() {
  group('AddressesCubit', () {
    test('loads the signed-in customer addresses', () async {
      final repository = _FakeAddressRepository(
        addresses: [_address('a1'), _address('a2', isDefault: true)],
      );
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(repository.listCalls, 1);
      expect(cubit.state.addresses, hasLength(2));
      expect(cubit.state.isEmpty, isFalse);
      // The default address is shown first.
      expect(cubit.state.addresses.first.isDefault, isTrue);
    });

    test('an empty address book is an empty state, not an error', () async {
      final cubit = AddressesCubit(repository: _FakeAddressRepository());
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.error, isNull);
    });

    test('a repository failure surfaces an error state', () async {
      final cubit = AddressesCubit(
        repository: _FakeAddressRepository(failList: true),
      );
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => state.error != null);

      expect(cubit.state.error, contains('signed-in'));
      expect(cubit.state.addresses, isEmpty);
    });

    test('adding an address saves it through the repository', () async {
      final repository = _FakeAddressRepository();
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.addAddress(label: 'Work', details: 'Office tower');

      expect(repository.listCalls, 1);
      expect(cubit.state.addresses, hasLength(1));
      expect(cubit.state.addresses.single.label, 'Work');
      expect(cubit.state.addresses.single.id, isNotEmpty);
    });

    test('adding as default puts the address first', () async {
      final repository = _FakeAddressRepository(addresses: [_address('a1')]);
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.addAddress(label: 'Work', details: 'Office', isDefault: true);

      expect(cubit.state.addresses.first.label, 'Work');
      expect(cubit.state.addresses.first.isDefault, isTrue);
    });

    test('updating an address keeps its position', () async {
      final repository = _FakeAddressRepository(
        addresses: [_address('a1'), _address('a2')],
      );
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.updateAddress(
        _address('a2').copyWith(label: 'Updated'),
      );

      expect(cubit.state.addresses[1].label, 'Updated');
      expect(cubit.state.addresses[1].id, 'a2');
    });

    test('setting a default re-sorts without a reload', () async {
      final repository = _FakeAddressRepository(
        addresses: [_address('a1'), _address('a2')],
      );
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.setDefaultAddress('a2');

      expect(repository.setDefaultCalls, 1);
      expect(repository.listCalls, 1, reason: 'no reload needed');
      expect(cubit.state.addresses.first.id, 'a2');
      expect(cubit.state.addresses.where((a) => a.isDefault), hasLength(1));
    });

    test('removing an address deletes it through the repository', () async {
      final repository = _FakeAddressRepository(
        addresses: [_address('a1'), _address('a2')],
      );
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.removeAddress('a1');

      expect(repository.removeCalls, 1);
      expect(cubit.state.addresses.single.id, 'a2');
    });

    test('a failed delete keeps the list and reports the error', () async {
      final repository = _FakeAddressRepository(
        addresses: [_address('a1')],
        failRemove: true,
      );
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.removeAddress('a1');

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.addresses, hasLength(1));
    });

    test('a failed add reports the error and keeps the empty state', () async {
      final repository = _FakeAddressRepository(failAdd: true);
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.addAddress(label: 'Work', details: 'Office');

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.addresses, isEmpty);
    });

    test('a failed update reports the error and keeps the address', () async {
      final repository = _FakeAddressRepository(
        addresses: [_address('a1')],
        failUpdate: true,
      );
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.updateAddress(_address('a1').copyWith(label: 'Updated'));

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.addresses.single.label, 'Home a1');
    });

    test('a failed setDefault reports the error', () async {
      final repository = _FakeAddressRepository(
        addresses: [_address('a1'), _address('a2')],
        failSetDefault: true,
      );
      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.setDefaultAddress('a2');

      expect(cubit.state.error, isNotNull);
      expect(
        cubit.state.addresses.where((a) => a.isDefault),
        isEmpty,
      );
    });
  });

  group('account isolation', () {
    test('an identity transition drops the previous customer addresses at once', () async {
      final repository = _FakeAddressRepository()
        ..seedUser('user-a', [_address('a1')])
        ..seedUser('user-b', [_address('b1')]);
      repository.sessionUserId = 'user-a';

      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(cubit.state.addresses.single.id, 'a1');

      expect(cubit.applyIdentityTransition('user-b'), isTrue);
      expect(
        cubit.state.addresses,
        isEmpty,
        reason: 'the previous customer rows must not survive the transition',
      );
      expect(cubit.state.isLoading, isTrue);

      // The auth listener does applyIdentityTransition + load; mirror that.
      repository.sessionUserId = 'user-b';
      final settled = cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.load();
      await settled;
      expect(repository.listCalls, 2);
      expect(cubit.state.addresses.single.id, 'b1');
      expect(
        cubit.state.addresses.where((a) => a.id == 'a1'),
        isEmpty,
        reason: 'the list belongs to the new session only',
      );
    });

    test('a transition to the same customer keeps the list untouched', () async {
      final repository = _FakeAddressRepository()
        ..seedUser('user-a', [_address('a1')]);
      repository.sessionUserId = 'user-a';

      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      // Establish the identity first (the cubit seeds null locally).
      expect(cubit.applyIdentityTransition('user-a'), isTrue);
      final settled = cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.load();
      await settled;
      expect(cubit.state.addresses.single.id, 'a1');
      final listCalls = repository.listCalls;

      expect(cubit.applyIdentityTransition('user-a'), isFalse);
      expect(
        repository.listCalls,
        listCalls,
        reason: 'the same identity must not trigger a reload',
      );
      expect(
        cubit.state.addresses.single.id,
        'a1',
        reason: 'the same identity must not clear the list',
      );
    });

    test('a read parked under the previous identity cannot land afterwards', () async {
      final repository = _FakeAddressRepository()
        ..seedUser('user-a', [_address('a1')])
        ..seedUser('user-b', [_address('b1')]);
      repository.sessionUserId = 'user-a';

      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(cubit.state.addresses.single.id, 'a1');

      // A read is in flight under user-a's session...
      final gate = Completer<void>();
      repository.gate = gate;
      final stale = cubit.load();

      // ...while user-b takes over and gets a read of their own.
      expect(cubit.applyIdentityTransition('user-b'), isTrue);
      repository.sessionUserId = 'user-b';
      repository.gate = null;
      final seen = <List<String>>[];
      final sub = cubit.stream.listen(
        (state) => seen.add(state.addresses.map((a) => a.id).toList()),
      );
      final fresh = cubit.load();
      await fresh;

      // user-a's answer finally arrives, late.
      gate.complete();
      await stale;
      await sub.cancel();

      expect(
        seen.any((ids) => ids.contains('a1')),
        isFalse,
        reason: 'a stale in-flight read must never restore the previous customer',
      );
      expect(cubit.state.addresses.single.id, 'b1');
    });

    test('signing out clears the list before any new session loads', () async {
      final repository = _FakeAddressRepository()
        ..seedUser('user-a', [_address('a1')]);
      repository.sessionUserId = 'user-a';

      final cubit = AddressesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      // Sign in as user-a, then sign out.
      expect(cubit.applyIdentityTransition('user-a'), isTrue);
      final settled = cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.load();
      await settled;
      expect(cubit.state.addresses.single.id, 'a1');

      expect(cubit.applyIdentityTransition(null), isTrue);
      expect(cubit.state.addresses, isEmpty);
      expect(cubit.state.isLoading, isTrue);
    });
  });
}
