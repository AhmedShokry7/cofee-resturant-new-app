import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';

import 'faqs_state.dart';

/// The help-centre questions the app shows to the customer.
///
/// The page used to own the `Future`, so a rebuild re-issued the query and a
/// failure left the screen with nothing but a dead message.
class FaqsCubit extends Cubit<FaqsState> {
  FaqsCubit({required this.repository}) : super(const FaqsState()) {
    load();
  }

  final ContentRepository repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final faqs = await repository.faqs();
      if (isClosed) return;
      emit(state.copyWith(faqs: faqs, isLoading: false));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
      addError(error, stackTrace);
    }
  }
}
