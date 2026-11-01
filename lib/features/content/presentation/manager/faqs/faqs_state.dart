part of 'faqs_cubit.dart';

@immutable
class FaqsState {
  const FaqsState({
    this.isLoading = true,
    this.faqs = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<FaqModel> faqs;

  /// Why the questions could not be read, in the customer's language.
  final String? errorMessage;

  /// Whether the last read failed, which is what decides the screen's copy -
  /// the reason itself is never shown to the customer.
  bool get hasError => errorMessage != null;

  FaqsState copyWith({
    bool? isLoading,
    List<FaqModel>? faqs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FaqsState(
      isLoading: isLoading ?? this.isLoading,
      faqs: faqs ?? this.faqs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
