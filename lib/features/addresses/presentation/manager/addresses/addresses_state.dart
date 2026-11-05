part of 'addresses_cubit.dart';

@immutable
class AddressesState {
  const AddressesState({
    this.addresses = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.readFailed = false,
    this.error,
  });

  final List<AddressModel> addresses;
  final bool isLoading;

  /// One address write is on its way, so a second tap cannot put two rows on
  /// the server, and the editor cannot close before this one is answered.
  final bool isSaving;

  /// [error] came from reading the book, not from a write.
  ///
  /// Without it a failed first save of an empty book would be drawn as "the
  /// addresses could not be loaded" with a retry button for a read that already
  /// succeeded.
  final bool readFailed;

  /// Why the last operation failed, held as a token rather than a sentence.
  ///
  /// The state outlives the language it was written in, so the words come from
  /// [AppCopy.copy] when the screen asks for them.
  final AppCopy? error;

  String? get errorCopy => error?.copy;

  bool get isEmpty => !isLoading && error == null && addresses.isEmpty;

  AddressesState copyWith({
    List<AddressModel>? addresses,
    bool? isLoading,
    bool? isSaving,
    bool? readFailed,
    AppCopy? error,
    bool clearError = false,
  }) => AddressesState(
    addresses: addresses ?? this.addresses,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    readFailed: readFailed ?? this.readFailed,
    error: clearError ? null : (error ?? this.error),
  );
}
