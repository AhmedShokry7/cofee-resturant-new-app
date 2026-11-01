part of 'addresses_cubit.dart';

@immutable
class AddressesState {
  const AddressesState({
    this.addresses = const [],
    this.isLoading = true,
    this.error,
  });

  final List<AddressModel> addresses;
  final bool isLoading;
  final String? error;

  bool get isEmpty => !isLoading && error == null && addresses.isEmpty;

  AddressesState copyWith({
    List<AddressModel>? addresses,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => AddressesState(
    addresses: addresses ?? this.addresses,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
