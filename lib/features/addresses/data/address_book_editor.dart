import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';

/// Applies one saved-address write to the address book both address surfaces
/// show.
///
/// The checkout and the settings screen used to hold their own copy of these
/// rules — same repository calls, same list fold-in, different failure copy —
/// so a change in one place silently drifted from the other. Both now call
/// this editor and keep only what is genuinely theirs: the checkout decides
/// which address stays selected, the settings screen decides nothing.
class AddressBookEditor {
  const AddressBookEditor({required this._repository});

  final AddressRepository _repository;

  /// Adds an address. The first address of an empty book becomes the default
  /// whether or not the caller asked, because a customer with one address
  /// expects the app to use it.
  Future<AddressBookChange> add(
    List<AddressModel> addresses, {
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    try {
      final saved = await _repository.addAddress(
        label: label,
        details: details,
        latitude: latitude,
        longitude: longitude,
        isDefault: isDefault || addresses.isEmpty,
      );
      return AddressBookChange(
        addresses: sorted([...addresses, saved]),
        saved: saved,
      );
    } catch (error) {
      throw AddressBookFailure(AppCopy.addressSaveFailed, cause: error);
    }
  }

  Future<AddressBookChange> update(
    List<AddressModel> addresses,
    AddressModel address,
  ) async {
    try {
      final saved = await _repository.updateAddress(
        id: address.id,
        label: address.label,
        details: address.details,
        latitude: address.latitude,
        longitude: address.longitude,
      );
      return AddressBookChange(
        addresses: sorted([
          for (final item in addresses)
            if (item.id == saved.id) saved else item,
        ]),
        saved: saved,
      );
    } catch (error) {
      throw AddressBookFailure(AppCopy.addressSaveFailed, cause: error);
    }
  }

  Future<AddressBookChange> remove(
    List<AddressModel> addresses,
    String id,
  ) async {
    try {
      await _repository.removeAddress(id);
      return AddressBookChange(
        addresses: addresses.where((address) => address.id != id).toList(),
      );
    } catch (error) {
      throw AddressBookFailure(AppCopy.addressDeleteFailed, cause: error);
    }
  }

  /// Makes [id] the only default. The server owns the flag; the list is
  /// re-sorted here so the change is visible without another read.
  Future<AddressBookChange> setDefault(
    List<AddressModel> addresses,
    String id,
  ) async {
    try {
      await _repository.setDefaultAddress(id);
      return AddressBookChange(
        addresses: sorted([
          for (final address in addresses)
            address.copyWith(isDefault: address.id == id),
        ]),
      );
    } catch (error) {
      throw AddressBookFailure(AppCopy.addressSaveFailed, cause: error);
    }
  }

  /// Default address first, then the order the repository returned.
  ///
  /// Public because a cubit that reads the list sorts it the same way: a write
  /// that re-sorted differently would move the customer's default address
  /// under their finger.
  static List<AddressModel> sorted(List<AddressModel> addresses) {
    final sorted = [...addresses];
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return 0;
    });
    return sorted;
  }
}

/// The address book after one write, plus the row the server returned when the
/// write created or replaced one.
class AddressBookChange {
  const AddressBookChange({required this.addresses, this.saved});

  final List<AddressModel> addresses;
  final AddressModel? saved;
}

/// A failed write, carrying the reason the customer should be told.
///
/// The repository error stays in [cause] so the cubit can still report the real
/// failure to the bloc observer; the customer only ever sees [message], which is
/// read in the current language rather than frozen when the write failed.
class AddressBookFailure implements Exception {
  const AddressBookFailure(this.reason, {required this.cause});

  final AppCopy reason;
  final Object cause;

  String get message => reason.copy;

  @override
  String toString() => message;
}
