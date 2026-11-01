import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/data/address_book_editor.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';

/// The rows the customer sees after a write come from here, not from either
/// cubit, so these tests are the contract both screens share.
class _FakeAddresses implements AddressRepository {
  _FakeAddresses({this.failAdd = false, this.failRemove = false});

  final bool failAdd;
  final bool failRemove;

  /// The flags the server was last asked to store.
  bool? lastIsDefault;
  String? lastRemovedId;

  @override
  Future<List<AddressModel>> listAddresses() async => const [];

  @override
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    if (failAdd) throw StateError('Addresses need a signed-in account.');
    lastIsDefault = isDefault;
    return AddressModel(
      id: 'a-new',
      label: label,
      details: details,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }

  @override
  Future<AddressModel> updateAddress({
    required String id,
    required String label,
    required String details,
    double? latitude,
    double? longitude,
  }) async => AddressModel(id: id, label: label, details: details);

  @override
  Future<void> setDefaultAddress(String id) async {}

  @override
  Future<void> removeAddress(String id) async {
    if (failRemove) throw StateError('Could not delete the address.');
    lastRemovedId = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

AddressModel _address(String id, {bool isDefault = false}) => AddressModel(
  id: id,
  label: 'Home $id',
  details: 'Street $id',
  isDefault: isDefault,
);

void main() {
  group('AddressBookEditor', () {
    test('the first address of an empty book becomes the default', () async {
      final repository = _FakeAddresses();
      final editor = AddressBookEditor(repository: repository);

      final change = await editor.add(
        const [],
        label: 'Home',
        details: 'Street 1',
      );

      expect(repository.lastIsDefault, isTrue);
      expect(change.saved?.isDefault, isTrue);
    });

    test('a later address is not made the default on its own', () async {
      final repository = _FakeAddresses();
      final editor = AddressBookEditor(repository: repository);

      await editor.add(
        [_address('a1', isDefault: true)],
        label: 'Work',
        details: 'Street 2',
      );

      expect(repository.lastIsDefault, isFalse);
    });

    test(
      'the saved address is shown first, ahead of the existing rows',
      () async {
        final editor = AddressBookEditor(repository: _FakeAddresses());

        final change = await editor.add(
          [_address('a1')],
          label: 'Work',
          details: 'Street 2',
          isDefault: true,
        );

        expect(change.addresses.map((a) => a.id), ['a-new', 'a1']);
      },
    );

    test('an update replaces the row it edited and keeps the others', () async {
      final editor = AddressBookEditor(repository: _FakeAddresses());

      final change = await editor.update(
        _list([_address('a1'), _address('a2', isDefault: true)]),
        _address('a1').copyWith(label: 'Cabin'),
      );

      expect(change.saved?.label, 'Cabin');
      expect(
        change.addresses.map((a) => a.label),
        containsAllInOrder(['Home a2', 'Cabin']),
      );
    });

    test('a delete drops the row and reports the delete copy', () async {
      final editor = AddressBookEditor(repository: _FakeAddresses());

      final change = await editor.remove(
        _list([_address('a1'), _address('a2')]),
        'a1',
      );

      expect(change.addresses.map((a) => a.id), ['a2']);
      expect(change.saved, isNull);
    });

    test('setting a default moves exactly one flag and re-sorts', () async {
      final editor = AddressBookEditor(repository: _FakeAddresses());

      final change = await editor.setDefault(
        _list([_address('a1', isDefault: true), _address('a2')]),
        'a2',
      );

      expect(change.addresses.where((a) => a.isDefault).map((a) => a.id), [
        'a2',
      ]);
      expect(change.addresses.first.id, 'a2');
    });

    test(
      'a failed write carries the localized copy and the real cause',
      () async {
        final editor = AddressBookEditor(
          repository: _FakeAddresses(failAdd: true),
        );

        Object? thrown;
        try {
          await editor.add(const [], label: 'Home', details: 'Street 1');
        } catch (error) {
          thrown = error;
        }

        expect(thrown, isA<AddressBookFailure>());
        expect((thrown as AddressBookFailure).message, S.addressSaveFailed);
        expect(thrown.cause, isA<StateError>());
      },
    );

    test('a failed delete uses the delete copy', () async {
      final editor = AddressBookEditor(
        repository: _FakeAddresses(failRemove: true),
      );

      await expectLater(
        editor.remove(_list([_address('a1')]), 'a1'),
        throwsA(
          isA<AddressBookFailure>().having(
            (f) => f.message,
            'message',
            S.addressDeleteFailed,
          ),
        ),
      );
    });
  });
}

/// A mutable list, the way a cubit hands its own state to the editor.
List<AddressModel> _list(List<AddressModel> addresses) => [...addresses];
