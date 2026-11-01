part of 'legal_document_cubit.dart';

@immutable
class LegalDocumentState {
  const LegalDocumentState({
    this.isLoading = true,
    this.document,
    this.errorMessage,
  });

  final bool isLoading;

  /// Null while loading and after a read that found no published document.
  final LegalDocumentModel? document;

  /// Why the document could not be read, in the customer's language.
  final String? errorMessage;

  /// Whether the last read failed, which is what decides the screen's copy -
  /// the reason itself is never shown to the customer.
  bool get hasError => errorMessage != null;

  LegalDocumentState copyWith({
    bool? isLoading,
    LegalDocumentModel? document,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LegalDocumentState(
      isLoading: isLoading ?? this.isLoading,
      document: document ?? this.document,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
