import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/services/postgres_changes_feed.dart';
import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/di/shell_dependencies.dart';
import 'package:admin_app/features/shell/domain/repositories/nav_repository.dart';
import 'package:admin_app/features/shell/domain/usecases/load_counts.dart';

/// Builds the live feed of the counters, or null when there is nothing to
/// watch. The tables depend on the pages the staff may open, so the caller of
/// [AdminNavCubit.start] decides what the feed subscribes to.
typedef NavLiveFeedFactory = PostgresChangesFeed? Function({
  required bool watchOrders,
  required bool watchKitchen,
  required bool watchNotifications,
});

/// Keeps the sidebar counters in step with the server.
///
/// The counters are read from the database, never added up on the device, so a
/// duplicated event or two staff members on the same screen cannot make a
/// badge count the same work twice.
///
/// Realtime is the fast path: a new order, ticket or notification moves the
/// badge the moment it is written, and so does opening one. A slow timer is the
/// safety net for a blocked websocket or a project with realtime disabled. A
/// failed read keeps the last numbers: a busy dashboard must never show a zero
/// because one request failed.
class AdminNavCubit extends Cubit<AdminNavCounts> {
  AdminNavCubit({
    NavRepository? repository,
    NavLiveFeedFactory? liveFeed,
    this.refreshInterval = const Duration(seconds: 45),
  }) : _loadCounts = LoadCountsUseCase(
         repository ?? ShellDependencies.repository,
       ),
       _newLiveFeed = liveFeed ?? ShellDependencies.newLiveFeed,
       super(AdminNavCounts.empty);

  final LoadCountsUseCase _loadCounts;
  final NavLiveFeedFactory _newLiveFeed;
  final Duration refreshInterval;

  Timer? _timer;
  PostgresChangesFeed? _feed;
  bool _isWatching = false;
  bool _watchNotifications = false;
  bool _isRefreshing = false;

  /// Starts watching the counters for the destinations the caller may open.
  ///
  /// A destination the account cannot open is not watched and not read: the
  /// notifications counter in particular comes from an RPC the database refuses
  /// without `notifications.read`.
  void start({
    required bool watchOrders,
    required bool watchKitchen,
    bool watchNotifications = false,
  }) {
    _timer?.cancel();
    _watchNotifications = watchNotifications;
    _isWatching = watchOrders || watchKitchen || watchNotifications;
    if (!_isWatching) {
      unawaited(_closeFeed());
      if (state != AdminNavCounts.empty) emit(AdminNavCounts.empty);
      return;
    }
    _watchLive(
      watchOrders: watchOrders,
      watchKitchen: watchKitchen,
      watchNotifications: watchNotifications,
    );
    unawaited(refresh());
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  void _watchLive({
    required bool watchOrders,
    required bool watchKitchen,
    required bool watchNotifications,
  }) {
    if (_feed != null) return;
    final feed = _newLiveFeed(
      watchOrders: watchOrders,
      watchKitchen: watchKitchen,
      watchNotifications: watchNotifications,
    );
    if (feed == null) return;
    _feed = feed;
    feed.start(_onLiveChange);
  }

  void _onLiveChange() {
    if (isClosed) return;
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (isClosed || !_isWatching || _isRefreshing) return;
    _isRefreshing = true;
    try {
      final counts = await _loadCounts(withNotifications: _watchNotifications);
      if (!isClosed && counts != state) emit(counts);
    } catch (_) {
      // The last numbers stay until the next poll succeeds.
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _closeFeed() async {
    final feed = _feed;
    _feed = null;
    if (feed != null) await feed.dispose();
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    await _closeFeed();
    return super.close();
  }
}
