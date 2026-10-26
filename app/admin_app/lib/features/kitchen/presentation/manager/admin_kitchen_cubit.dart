import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/di/kitchen_dependencies.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';
import 'package:admin_app/features/kitchen/domain/usecases/load_board.dart';
import 'package:admin_app/features/kitchen/domain/usecases/load_filters.dart';
import 'package:admin_app/features/kitchen/domain/usecases/load_metrics.dart';
import 'package:admin_app/features/kitchen/domain/usecases/set_item_status.dart';
import 'package:admin_app/features/kitchen/domain/usecases/set_ticket_status.dart';
import 'package:admin_app/features/kitchen/data/services/kitchen_realtime_feed.dart';
import 'package:admin_app/features/kitchen/presentation/manager/admin_kitchen_state.dart';

class AdminKitchenCubit extends Cubit<AdminKitchenState> {
  AdminKitchenCubit({
    KitchenRepository? repository,
    KitchenRealtimeFeed? realtimeFeed,
    DateTime Function()? clock,
  }) : this._withUseCases(
         repository ?? KitchenDependencies.repository,
         realtimeFeed,
         clock,
       );

  AdminKitchenCubit._withUseCases(
    KitchenRepository repository,
    KitchenRealtimeFeed? realtimeFeed,
    DateTime Function()? clock,
  ) : _loadBoard = LoadBoardUseCase(repository),
      _loadMetrics = LoadMetricsUseCase(repository),
      _loadFilters = LoadFiltersUseCase(repository),
      _setTicketStatus = SetTicketStatusUseCase(repository),
      _setItemStatus = SetItemStatusUseCase(repository),
      _realtimeFeed = realtimeFeed ?? KitchenRealtimeFeed(),
      _clock = clock ?? DateTime.now,
      super(AdminKitchenState(now: (clock ?? DateTime.now)()));

  final LoadBoardUseCase _loadBoard;
  final LoadMetricsUseCase _loadMetrics;
  final LoadFiltersUseCase _loadFilters;
  final SetTicketStatusUseCase _setTicketStatus;
  final SetItemStatusUseCase _setItemStatus;
  final KitchenRealtimeFeed _realtimeFeed;
  final DateTime Function() _clock;

  Timer? _searchTimer;
  int _requestId = 0;
  bool _liveStarted = false;

  Future<void> load() async {
    if (state.isLoading) return;
    await _fetch(withSummary: true, first: true);
  }

  Future<void> refresh() => _fetch(withSummary: true);

  /// A quiet reload used by the live feed and the fallback poll, so the board
  /// never flashes a spinner while the kitchen is working.
  Future<void> refreshLive() => _fetch(withSummary: true, silent: true);

  void startLiveUpdates() {
    if (_liveStarted) return;
    _liveStarted = true;
    _realtimeFeed.start(_onRealtimeChange);
  }

  void _onRealtimeChange() {
    if (isClosed) return;
    refreshLive();
  }

  /// Moves the live elapsed timers forward; the page calls it every 30 s.
  void tick() {
    if (isClosed) return;
    emit(state.copyWith(now: _clock()));
  }

  void updateSearch(String value) {
    final normalized = value.trim();
    if (normalized == state.search) return;
    emit(state.copyWith(search: normalized));
    _searchTimer?.cancel();
    if (normalized.isEmpty) {
      _fetch(withSummary: false);
      return;
    }
    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => _fetch(withSummary: false),
    );
  }

  void setBranch(String? branchId) {
    if (branchId == state.branchId) return;
    emit(state.copyWith(branchId: branchId, clearBranch: branchId == null));
    _fetch(withSummary: true);
  }

  void clearFilters() {
    _searchTimer?.cancel();
    if (!state.hasActiveFilters) return;
    emit(state.copyWith(search: '', clearBranch: true));
    _fetch(withSummary: true);
  }

  Future<KitchenMutationOutcome> setTicketStatus(
    String ticketId,
    KitchenTicketStatus status,
  ) async {
    if (state.isTicketBusy(ticketId)) {
      return KitchenMutationOutcome.failed;
    }
    _setTicketBusy(ticketId, true);
    final outcome = await _setTicketStatus(ticketId, status);
    _setTicketBusy(ticketId, false);
    if (outcome == KitchenMutationOutcome.success) await refreshLive();
    return outcome;
  }

  Future<KitchenMutationOutcome> setItemStatus(
    String itemId,
    KitchenItemStatus status,
  ) async {
    if (state.isItemBusy(itemId)) {
      return KitchenMutationOutcome.failed;
    }
    _setItemBusy(itemId, true);
    final outcome = await _setItemStatus(itemId, status);
    _setItemBusy(itemId, false);
    if (outcome == KitchenMutationOutcome.success) await refreshLive();
    return outcome;
  }

  void _setTicketBusy(String id, bool busy) {
    if (isClosed) return;
    final ids = Set<String>.of(state.busyTicketIds);
    if (busy) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    emit(state.copyWith(busyTicketIds: ids));
  }

  void _setItemBusy(String id, bool busy) {
    if (isClosed) return;
    final ids = Set<String>.of(state.busyItemIds);
    if (busy) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    emit(state.copyWith(busyItemIds: ids));
  }

  Future<void> _fetch({
    required bool withSummary,
    bool first = false,
    bool silent = false,
  }) async {
    final request = ++_requestId;
    if (first) {
      emit(
        state.copyWith(
          status: AdminKitchenStatus.loading,
          clearError: true,
          isRefreshing: false,
        ),
      );
    } else if (!silent) {
      emit(state.copyWith(isRefreshing: true, clearError: true));
    }

    final boardFuture = _loadBoard(
      search: state.search,
      branchId: state.branchId,
    );
    final metricsFuture = withSummary
        ? _loadMetricsSafely()
        : Future<AdminKitchenMetrics?>.value(null);
    final filtersFuture = withSummary
        ? _loadFiltersSafely()
        : Future<AdminKitchenFilters?>.value(null);

    Object? failure;
    var board = const AdminKitchenBoard();
    try {
      board = await boardFuture;
    } catch (error) {
      failure = error;
    }
    final metrics = await metricsFuture;
    final filters = await filtersFuture;
    if (isClosed || request != _requestId) return;

    if (failure != null) {
      emit(
        state.copyWith(
          status: state.lastUpdatedAt != null
              ? AdminKitchenStatus.ready
              : AdminKitchenStatus.failure,
          metrics: metrics,
          filters: filters,
          isRefreshing: false,
          errorMessage: '$failure',
        ),
      );
      return;
    }

    final now = _clock();
    emit(
      state.copyWith(
        status: AdminKitchenStatus.ready,
        tickets: board.tickets,
        total: board.total,
        metrics: metrics,
        filters: filters,
        isRefreshing: false,
        lastUpdatedAt: now,
        now: now,
        clearError: true,
      ),
    );
  }

  Future<AdminKitchenMetrics?> _loadMetricsSafely() async {
    try {
      return await _loadMetrics(branchId: state.branchId);
    } catch (_) {
      return null;
    }
  }

  Future<AdminKitchenFilters?> _loadFiltersSafely() async {
    try {
      return await _loadFilters();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    _searchTimer?.cancel();
    _liveStarted = false;
    await _realtimeFeed.dispose();
    return super.close();
  }
}
