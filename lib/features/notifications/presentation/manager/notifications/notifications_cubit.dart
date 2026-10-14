import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/notifications/data/notifications_list.dart';

part 'notifications_state.dart';

/// Tracks which notifications were read. Anything not marked read counts
/// as unread (like the cart badge counter).
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit() : super(const NotificationsState());

  static const _storageKey = 'notifications_read_v1';

  int get unreadCount {
    final ids = getNotificationsList().map((item) => item.id).toSet();
    return ids.difference(state.readIds).length;
  }

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty || isClosed) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      emit(
        NotificationsState(
          readIds: decoded.map((item) => item.toString()).toSet(),
        ),
      );
    } catch (_) {
      // Best-effort: everything counts as unread rather than crash.
    }
  }

  void markAllRead() {
    final ids = getNotificationsList().map((item) => item.id).toSet();
    if (state.readIds.containsAll(ids) || isClosed) return;
    emit(NotificationsState(readIds: {...state.readIds, ...ids}));
    _persist();
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(state.readIds.toList()),
      );
    } catch (_) {
      // Best-effort: never break navigation if storage fails.
    }
  }
}
