part of 'account_details_cubit.dart';

/// The account details as they sit on the edit-profile form.
///
/// The email is read-only: this app has no way to move an account to a new
/// address, so the form shows it and never sends it.
@immutable
class AccountDetailsState {
  const AccountDetailsState({
    this.firstName = '',
    this.lastName = '',
    this.email,
    this.phone = '',
    this.isLoading = false,
    this.isSaving = false,
    this.isChangingPassword = false,
    this.error,
  });

  final String firstName;
  final String lastName;
  final String? email;
  final String phone;

  /// The read that fills the form. It separates "this account has no phone
  /// number" from "nothing has been read yet".
  final bool isLoading;

  final bool isSaving;

  final bool isChangingPassword;

  /// Why the last operation failed, already resolved to what the page shows.
  final String? error;

  AccountDetailsState copyWith({
    String? firstName,
    String? lastName,
    String? email,
    bool clearEmail = false,
    String? phone,
    bool? isLoading,
    bool? isSaving,
    bool? isChangingPassword,
    String? error,
    bool clearError = false,
  }) {
    return AccountDetailsState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: clearEmail ? null : (email ?? this.email),
      phone: phone ?? this.phone,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isChangingPassword: isChangingPassword ?? this.isChangingPassword,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
