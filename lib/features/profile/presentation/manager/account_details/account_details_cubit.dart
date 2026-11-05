import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

part 'account_details_state.dart';

/// Owns the edit-profile form: what the account currently says, and the two
/// writes the customer can make to it.
///
/// The page used to reach into [AuthRepository] itself, hold `_saving` in
/// `setState`, and swallow every failure. A read that failed left the form
/// blank and the customer had no way to tell an empty account from a broken
/// one; a failed save looked the same as a successful one for as long as the
/// button took to re-enable. Both belong here, where the state can say which
/// of the two happened.
class AccountDetailsCubit extends Cubit<AccountDetailsState> {
  AccountDetailsCubit({required this._repository})
    : super(const AccountDetailsState());

  final AuthRepository _repository;

  /// Reads the signed-in account and fills the form with it.
  ///
  /// A failure is reported instead of leaving the fields empty: the customer
  /// must not be able to save a blank name over a real one because the read
  /// never arrived.
  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.currentUser();
      if (isClosed) return;
      final draft = _draftOf(user);
      emit(
        state.copyWith(
          isLoading: false,
          firstName: draft.firstName,
          lastName: draft.lastName,
          phone: draft.phone,
          email: draft.email,
          clearEmail: draft.email == null,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: AppCopy.couldNotLoadAccountDetails,
        ),
      );
      addError(error, stackTrace);
    }
  }

  /// Saves the name and the phone number, and says whether the account was
  /// actually changed.
  ///
  /// The email is deliberately not sent: this app has no address-change call,
  /// and posting a field it cannot change would let the customer believe the
  /// address had moved.
  ///
  /// The number is put in the shape the provider accepts before the call, by the
  /// same rule the field validates with. Sending `0501234567` as typed would
  /// cost a round trip and come back as a failure the customer cannot act on.
  Future<bool> save({
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    final e164Phone = AuthFormRules.e164Of(phone);
    if (e164Phone == null) {
      emit(state.copyWith(isSaving: false, error: AppCopy.validPhoneNumber));
      return false;
    }
    emit(state.copyWith(isSaving: true, clearError: true));
    final fullName = '$firstName ${lastName ?? ''}'.trim();
    try {
      final updated = await _repository.updateProfile(
        fullName: fullName,
        phone: e164Phone,
      );
      if (isClosed) return false;
      final draft = _draftOf(updated);
      emit(
        state.copyWith(
          isSaving: false,
          firstName: draft.firstName,
          lastName: draft.lastName,
          phone: draft.phone,
          email: draft.email,
          clearEmail: draft.email == null,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false, error: AppCopy.profileUpdateFailed));
      addError(error, stackTrace);
      return false;
    }
  }

  /// Changes the account password, reporting that it could not be changed
  /// rather than the provider's message.
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    emit(state.copyWith(isChangingPassword: true, clearError: true));
    try {
      await _repository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (isClosed) return false;
      emit(state.copyWith(isChangingPassword: false));
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isChangingPassword: false,
          error: AppCopy.passwordChangeFailed,
        ),
      );
      addError(error, stackTrace);
      return false;
    }
  }

  /// Clears a consumed error so a later rebuild cannot resurface it.
  void clearError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  /// The account's single name field, as the form splits it into two inputs.
  ///
  /// Everything after the first word is the family name, because the account
  /// stores one string and the form has two fields; joining them again on save
  /// returns exactly what was read.
  static ({String firstName, String lastName, String phone, String? email})
  _draftOf(AuthUser? user) {
    final parts = (user?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return (
      firstName: parts.isEmpty ? '' : parts.first,
      lastName: parts.length < 2 ? '' : parts.sublist(1).join(' '),
      phone: user?.phone ?? '',
      email: user?.email,
    );
  }
}
