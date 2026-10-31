import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/model/notification_preferences.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/data/repositories/push_repository.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthChangeEvent,
        AuthState,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel;

part 'notifications_state.dart';

/// Server-owned notifications for the signed-in customer.
///
/// Guests have no notification rows: the old screen invented four of them and
/// stored read state for those inventions locally. An empty list is the only
/// honest signed-out answer.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required this._repository,
    PushRepository? pushRepository,
    Future<bool> Function(bool enabled)? pushSwitch,
  }) : _pushRepository = pushRepository ?? const PushRepositoryImpl(),
       _pushSwitch = pushSwitch ?? PushService.setEnabled,
       super(const NotificationsState()) {
    // Seeded from the same source the repository reads, so restoring the
    // session that is already present is not mistaken for a switch to it.
    _identity = SupabaseService.isReady
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        _onAuthStateChanged,
      );
      // The session can already be there when the cubit is created, in which
      // case the stream replays it and opens the channel. This covers the
      // moment between the two, when the customer is signed in but the
      // cubit does not know it yet.
      final currentUserId = SupabaseService.client.auth.currentUser?.id;
      if (currentUserId != null) {
        _openRealtimeChannel(currentUserId);
      }
    }
    // A push that arrives while the app is open changes the list too, and
    // the customer sees it without opening the screen.
    _pushSubscription = PushService.onForegroundMessage.listen((_) {
      load();
    });
    load();
  }

  final NotificationsRepository _repository;
  final PushRepository _pushRepository;

  /// Turns the push on or off.
  ///
  /// It is a function so a test can decide what the system answers without
  /// a real Firebase behind it.
  final Future<bool> Function(bool enabled) _pushSwitch;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<RemoteMessage>? _pushSubscription;

  /// The realtime channel that tells the app about a new notification.
  ///
  /// The database is the source of truth, so the row is read again when the
  /// channel reports one. The channel belongs to one customer at a time and
  /// is closed when that customer signs out.
  RealtimeChannel? _channel;

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
        // The switches belong to the customer too: the next one must not see
        // the switches of the previous one while their own read is in flight.
        preferences: const NotificationPreferences(),
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
    // The realtime channel belongs to the customer, and it is opened for every
    // event that carries a session, not only for a sign-in: the session of a
    // returning customer is restored after the app started, and that event
    // is the one that has to open the channel.
    if (auth.event == AuthChangeEvent.signedOut) {
      _closeRealtimeChannel();
    } else if (auth.session != null) {
      _openRealtimeChannel(auth.session!.user.id);
    }

    if (!shouldReloadOnAuthEvent(auth)) return;
    applyIdentityTransition(auth.session?.user.id);
    load();
  }

  /// Subscribes to the notifications of the customer.
  ///
  /// Without this the list only changes when the customer opens the screen,
  /// so the badge on the bell would be wrong until then. The channel is
  /// filtered by the customer, and the row is read again from the database
  /// when it arrives, so the screen shows what the database holds.
  void _openRealtimeChannel(String? userId) {
    _closeRealtimeChannel();
    if (userId == null || !SupabaseService.isReady) return;
    try {
      _channel = SupabaseService.client
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'engagement',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => load(),
          )
          .subscribe();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[NotificationsCubit] realtime failed: $error');
      }
    }
  }

  void _closeRealtimeChannel() {
    final channel = _channel;
    _channel = null;
    if (channel == null || !SupabaseService.isReady) return;
    try {
      SupabaseService.client.removeChannel(channel);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[NotificationsCubit] realtime close failed: $error');
      }
    }
  }

  /// The push switches of the signed-in customer.
  Future<void> loadPushState() async {
    try {
      final switches = await _pushRepository.preferences();
      if (isClosed) return;
      emit(state.copyWith(preferences: switches));
    } catch (_) {
      // A customer who is not signed in has no switches yet. The screen shows
      // the switches of a fresh account, which is the honest answer.
      if (isClosed) return;
      emit(state.copyWith(preferences: const NotificationPreferences()));
    }
  }

  /// Turns the push on or off for this customer.
  ///
  /// Turning it on needs the permission of the system, so it can fail: the
  /// switch then stays where it was.
  Future<void> setPushEnabled(bool enabled) async {
    final changed = await _pushSwitch(enabled);
    if (isClosed) return;
    emit(state.copyWith(pushEnabled: changed));
  }

  /// Turns one kind of push on or off, and says whether the server kept it.
  ///
  /// The switches belong to the customer's row, so the state takes what the
  /// write returned rather than what was asked for. A caller that gets false
  /// back has to leave the switch where the server left it and say why.
  Future<bool> setTypePreference(
    NotificationPreferenceKey key,
    bool enabled,
  ) async {
    try {
      final saved = switch (key) {
        NotificationPreferenceKey.orderStatus =>
          await _pushRepository.setPreferences(orderStatus: enabled),
        NotificationPreferenceKey.promo => await _pushRepository.setPreferences(
          promo: enabled,
        ),
        NotificationPreferenceKey.loyalty =>
          await _pushRepository.setPreferences(loyalty: enabled),
        NotificationPreferenceKey.system =>
          await _pushRepository.setPreferences(system: enabled),
      };
      if (isClosed) return false;
      emit(state.copyWith(preferences: saved));
      return saved.valueOf(key) == enabled;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load({required bool markRead}) async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      if (_identity == null && SupabaseService.isReady) {
        if (isClosed || generation != _loadGeneration) return;
        emit(
          state.copyWith(
            notifications: const [],
            isLoading: false,
            signedOut: true,
            clearError: true,
          ),
        );
        return;
      }
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
      emit(
        state.copyWith(
          notifications: notifications,
          isLoading: false,
          signedOut: false,
        ),
      );
    } on NotificationSignInRequiredException {
      if (isClosed) return;
      if (generation != _loadGeneration) return;
      emit(
        state.copyWith(
          notifications: const [],
          isLoading: false,
          signedOut: true,
        ),
      );
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
    _pushSubscription?.cancel();
    _pushSubscription = null;
    _closeRealtimeChannel();
    return super.close();
  }
}
