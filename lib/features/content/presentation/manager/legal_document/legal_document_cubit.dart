import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';

import 'legal_document_state.dart';

/// One published legal document, read by its CMS slug.
class LegalDocumentCubit extends Cubit<LegalDocumentState> {
  LegalDocumentCubit({required this.repository, required this.slug})
    : super(const LegalDocumentState()) {
    load();
  }

  final ContentRepository repository;
  final String slug;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final document = await repository.legalDocument(slug);
      if (isClosed) return;
      emit(state.copyWith(document: document, isLoading: false));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
      addError(error, stackTrace);
    }
  }
}
