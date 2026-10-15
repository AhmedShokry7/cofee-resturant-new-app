import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';

part 'notifications_state.dart';

/// Server-owned notifications for the signed-in customer.
///
/// Guests have no notification rows: the old screen invented four of them and
/// stored read state for those inventions locally. An empty list is the only
/// honest signed-out answer.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required this._repository})
      : super(const NotificationsState()) {
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService
          .client.auth.onAuthStateChange
          .listen((_) => load());
    }
    load();
  }

  final NotificationsRepository _repository;
  StreamSubscription<dynamic>? _authSubscription;

  int get unreadCount =>
      state.notifications.where((item) => !item.isRead).length;

  Future<void> load() => _load(markRead: false);

  Future<void> refresh() => _load(markRead: false);

  Future<void> markAllRead() => _load(markRead: true);

  Future<void> _load({required bool markRead}) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      var notifications = await _repository.listNotifications();
      if (markRead) {
        final unread = notifications
            .where((item) => !item.isRead)
            .map((item) => item.id)
            .toList(growable: false);
        if (unread.isNotEmpty) {
          await _repository.markRead(unread);
          notifications = await _repository.listNotifications();
        }
      }
      if (isClosed) return;
      emit(state.copyWith(
        notifications: notifications,
        isLoading: false,
        signedOut: false,
      ));
    } on NotificationSignInRequiredException {
      if (isClosed) return;
      emit(state.copyWith(
        notifications: const [],
        isLoading: false,
        signedOut: true,
      ));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }
}
