import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';

part 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit() : super(const FavoritesState(ids: {}));

  static const _storageKey = 'favorites_v1';

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty || isClosed) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      emit(
        FavoritesState(
          ids: decoded.map((item) => item.toString()).toSet(),
        ),
      );
    } catch (_) {
      // Favorites are best-effort: start empty rather than crash.
    }
  }

  void toggle(String productId) {
    final ids = {...state.ids};
    if (!ids.add(productId)) {
      ids.remove(productId);
    }
    emit(FavoritesState(ids: ids));
    _persist();
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(state.ids.toList()),
      );
    } catch (_) {
      // Best-effort: never break toggling if storage fails.
    }
  }
}
