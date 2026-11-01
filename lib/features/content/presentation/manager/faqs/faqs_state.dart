import 'package:flutter/foundation.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';

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
