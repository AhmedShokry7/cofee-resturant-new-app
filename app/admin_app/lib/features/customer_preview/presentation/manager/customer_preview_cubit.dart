import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:admin_app/features/customer_preview/data/models/preview_draft.dart';

enum PreviewScreen { home, categories, product, cart, account }

enum PreviewViewport { small, medium, large }

class CustomerPreviewState {
  const CustomerPreviewState({
    required this.published,
    required this.draft,
    required this.screen,
    required this.viewport,
    required this.customerAppUrl,
    required this.refreshToken,
    required this.isDirty,
    this.isSaving = false,
  });

  final PreviewDraftSettings published;
  final PreviewDraftSettings draft;
  final PreviewScreen screen;
  final PreviewViewport viewport;
  final String customerAppUrl;
  final int refreshToken;
  final bool isDirty;
  final bool isSaving;

  factory CustomerPreviewState.initial() => const CustomerPreviewState(
        published: PreviewDraftSettings.defaults,
        draft: PreviewDraftSettings.defaults,
        screen: PreviewScreen.home,
        viewport: PreviewViewport.medium,
        customerAppUrl: 'http://localhost:8080',
        refreshToken: 0,
        isDirty: false,
      );

  CustomerPreviewState copyWith({
    PreviewDraftSettings? published,
    PreviewDraftSettings? draft,
    PreviewScreen? screen,
    PreviewViewport? viewport,
    String? customerAppUrl,
    int? refreshToken,
    bool? isDirty,
    bool? isSaving,
  }) {
    return CustomerPreviewState(
      published: published ?? this.published,
      draft: draft ?? this.draft,
      screen: screen ?? this.screen,
      viewport: viewport ?? this.viewport,
      customerAppUrl: customerAppUrl ?? this.customerAppUrl,
      refreshToken: refreshToken ?? this.refreshToken,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  bool get hasDraftChanges => draft != published;
}

class CustomerPreviewCubit extends Cubit<CustomerPreviewState> {
  CustomerPreviewCubit() : super(CustomerPreviewState.initial()) {
    _loadSavedDraft();
  }

  static const _draftKey = 'customer_preview_draft';

  Future<void> _loadSavedDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;
      // Stored as hex string: primary|secondary|background|surface
      final parts = raw.split('|');
      if (parts.length != 4) return;
      final loaded = PreviewDraftSettings(
        primaryColor: _parse(parts[0]),
        secondaryColor: _parse(parts[1]),
        backgroundColor: _parse(parts[2]),
        surfaceColor: _parse(parts[3]),
      );
      emit(state.copyWith(published: loaded, draft: loaded));
    } catch (_) {}
  }

  Color _parse(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(value ?? 0xFF1D4ED8);
  }

  String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  void updateCustomerAppUrl(String value) =>
      emit(state.copyWith(customerAppUrl: value));

  void updatePrimaryColor(Color color) =>
      emit(state.copyWith(draft: state.draft.copyWith(primaryColor: color), isDirty: true));

  void updateSecondaryColor(Color color) =>
      emit(state.copyWith(draft: state.draft.copyWith(secondaryColor: color), isDirty: true));

  void updateBackgroundColor(Color color) =>
      emit(state.copyWith(draft: state.draft.copyWith(backgroundColor: color), isDirty: true));

  void updateSurfaceColor(Color color) =>
      emit(state.copyWith(draft: state.draft.copyWith(surfaceColor: color), isDirty: true));

  void updateScreen(PreviewScreen screen) =>
      emit(state.copyWith(screen: screen));

  void updateViewport(PreviewViewport viewport) =>
      emit(state.copyWith(viewport: viewport));

  void resetDraft() =>
      emit(state.copyWith(draft: state.published, isDirty: false));

  Future<void> saveDraft() async {
    emit(state.copyWith(isSaving: true));
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          '${_hex(state.draft.primaryColor)}|${_hex(state.draft.secondaryColor)}|'
          '${_hex(state.draft.backgroundColor)}|${_hex(state.draft.surfaceColor)}';
      await prefs.setString(_draftKey, encoded);
      emit(state.copyWith(published: state.draft, isDirty: false, isSaving: false));
    } catch (_) {
      emit(state.copyWith(isSaving: false));
    }
  }

  void refresh() => emit(state.copyWith(refreshToken: state.refreshToken + 1));
}
