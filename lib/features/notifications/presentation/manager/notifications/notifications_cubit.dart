import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'notifications_state.dart';

/// Server-owned notifications for the signed-in customer.
///
/// Guests have no notification rows: the old screen invented four of them and
/// stored read state for those inventions locally. An empty list is the only
/// honest signed-out answer.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required this._repository})
      : super(const NotificationsState()) {
    // Seeded from the same source the repository reads, so restoring the
    // session that is already present is not mistaken for a switch to it.
    _identity = SupabaseService.isReady
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange
          .listen(_onAuthStateChanged);
    }
    load();
  }

  final NotificationsRepository _repository;
  StreamSubscription<AuthState>? _authSubscription;

  /// Tail of the serialized load chain.
  ///
  /// Notification rows belong to one customer at a time, so a page-triggered
  /// "mark as read" must never overlap an automatic reload: the older answer
  /// would land last and put back an unread badge the server already cleared.
  Future<void> _pending = Future<void>.value();

  /// Identity whose rows are currently in state. Null means guest.
  String? _identity;

  /// Monotonic id of the newest load. Only the load holding the latest number
  /// may write state.
  ///
  /// Needed because an identity transition emits immediately, while a read that
  /// started under the previous identity is still queued behind it and would
  /// otherwise land afterwards and put the previous customer's titles and
  /// bodies back on screen.
  int _loadGeneration = 0;

  /// Records that the signed-in customer changed and drops what the previous
  /// one had on screen.
  ///
  /// Emits immediately, so the previous customer's notification text is never
  /// visible during the transition. If the new read then fails, the page shows
  /// its error or empty state instead of the previous customer's rows.
  ///
  /// Returns true when this really was a different identity. An ordinary
  /// refresh, a branch change or a token rotation leaves the rows alone.
  @visibleForTesting
  bool applyIdentityTransition(String? identity) {
    if (identity == _identity) return false;
    _identity = identity;
    // Invalidate anything already in flight under the previous identity.
    _loadGeneration++;
    emit(
      state.copyWith(
        notifications: const [],
        isLoading: true,
        clearError: true,
        // A signed-out customer has no rows at all, so say so straight away
        // rather than flashing a spinner over an empty list.
        signedOut: identity == null,
      ),
    );
    return true;
  }

  int get unreadCount =>
      state.notifications.where((item) => !item.isRead).length;

  Future<void> load() => _enqueue(markRead: false);

  Future<void> refresh() => _enqueue(markRead: false);

  /// Marks what is currently stored as seen.
  ///
  /// Safe to call any number of times: one read, a write of only the
  /// still-unread ids, then one more read so the list reflects the result.
  /// Callers own the decision of *when* to run it; this cubit only guarantees
  /// the read, the write and the follow-up read never interleave.
  Future<void> markAllRead() => _enqueue(markRead: true);

  /// Runs loads one after another rather than concurrently.
  ///
  /// The chain survives a failure, so one bad request cannot wedge every later
  /// refresh.
  Future<void> _enqueue({required bool markRead}) {
    final run = _pending.then((_) => _load(markRead: markRead));
    _pending = run.then<void>((_) {}, onError: (_, _) {});
    return run;
  }

  /// A notification list belongs to exactly one signed-in customer.
  ///
  /// `signedIn` means a different customer's rows are now readable, and
  /// `signedOut` means nothing of the previous customer may stay on screen, so
  /// both reload. `passwordRecovery` is grouped with `signedIn` because GoTrue
  /// emits it instead of `signedIn` when a recovery link establishes the
  /// session; skipping it would render the previous customer's notification
  /// titles and bodies. `initialSession` is deliberately ignored: the auth
  /// stream replays its latest event to every new listener, so subscribing here
  /// immediately replays the stored session, and the constructor load above
  /// already reads that same session. `tokenRefreshed`, `userUpdated` and
  /// `mfaChallengeVerified` rotate a token or a profile and cannot change which
  /// rows exist.
  @visibleForTesting
  bool shouldReloadOnAuthEvent(AuthState auth) =>
      auth.event == AuthChangeEvent.signedIn ||
      auth.event == AuthChangeEvent.passwordRecovery ||
      auth.event == AuthChangeEvent.signedOut;

  void _onAuthStateChanged(AuthState auth) {
    if (!shouldReloadOnAuthEvent(auth)) return;
    applyIdentityTransition(auth.session?.user.id);
    load();
  }

  Future<void> _load({required bool markRead}) async {
    final generation = ++_loadGeneration;
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
          if (isClosed || generation != _loadGeneration) return;
          notifications = await _repository.listNotifications();
        }
      }
      if (isClosed) return;
      // A newer load, or a newer identity, already owns the state.
      if (generation != _loadGeneration) return;
      emit(state.copyWith(
        notifications: notifications,
        isLoading: false,
        signedOut: false,
      ));
    } on NotificationSignInRequiredException {
      if (isClosed) return;
      if (generation != _loadGeneration) return;
      emit(state.copyWith(
        notifications: const [],
        isLoading: false,
        signedOut: true,
      ));
    } catch (error, stackTrace) {
      if (isClosed) return;
      if (generation != _loadGeneration) return;
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
