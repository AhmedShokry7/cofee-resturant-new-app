import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';
import 'package:admin_app/features/audit/di/audit_dependencies.dart';
import 'package:admin_app/features/audit/domain/repositories/audit_repository.dart';
import 'package:admin_app/features/audit/domain/usecases/load_metrics.dart';
import 'package:admin_app/features/audit/domain/usecases/load_page.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_state.dart';
import 'package:admin_app/features/audit/presentation/models/audit_filters.dart';

class AdminAuditCubit extends Cubit<AdminAuditState> {
  AdminAuditCubit({AuditRepository? repository})
    : this._withUseCases(repository ?? AuditDependencies.repository);

  AdminAuditCubit._withUseCases(AuditRepository repository)
    : _loadPage = LoadPageUseCase(repository),
      _loadMetrics = LoadMetricsUseCase(repository),
      super(const AdminAuditState());

  final LoadPageUseCase _loadPage;
  final LoadMetricsUseCase _loadMetrics;
  Timer? _searchTimer;
  int _requestId = 0;

  Future<void> load() async {
    if (state.isLoading) return;
    await _fetch(withSummary: true, first: true);
  }

  Future<void> refresh() => _fetch(withSummary: true);

  void updateSearch(String value) {
    final normalized = value.trim();
    if (normalized == state.search) return;
    emit(state.copyWith(search: normalized, page: 0));
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

  void setDomain(AuditDomainFilter domain) {
    if (domain == state.domain) return;
    emit(state.copyWith(domain: domain, page: 0));
    _fetch(withSummary: false);
  }

  void setCriticalOnly(bool value) {
    if (value == state.criticalOnly) return;
    emit(state.copyWith(criticalOnly: value, page: 0));
    _fetch(withSummary: false);
  }

  void setPage(int page) {
    final maxPage = state.pages == 0 ? 0 : state.pages - 1;
    final target = page.clamp(0, maxPage);
    if (target == state.page) return;
    emit(state.copyWith(page: target));
    _fetch(withSummary: false);
  }

  void clearFilters() {
    _searchTimer?.cancel();
    if (!state.hasActiveFilters) return;
    emit(
      state.copyWith(
        search: '',
        domain: AuditDomainFilter.all,
        criticalOnly: false,
        page: 0,
      ),
    );
    _fetch(withSummary: false);
  }

  Future<void> _fetch({required bool withSummary, bool first = false}) async {
    final request = ++_requestId;
    if (first) {
      emit(
        state.copyWith(
          status: AdminAuditStatus.loading,
          clearError: true,
          isRefreshingRows: false,
        ),
      );
    } else {
      emit(state.copyWith(isRefreshingRows: true, clearError: true));
    }

    final rowsFuture = _loadPage(
      search: state.search,
      domain: state.domain.value,
      criticalOnly: state.criticalOnly,
      page: state.page,
      pageSize: state.pageSize,
    );
    final summaryFuture = withSummary
        ? _loadMetricsSafely()
        : Future<AdminAuditMetrics?>.value(null);

    Object? pageFailure;
    var page = const AdminAuditPage();
    try {
      page = await rowsFuture;
    } catch (error) {
      pageFailure = error;
    }
    final metrics = await summaryFuture;
    if (isClosed || request != _requestId) return;

    if (pageFailure != null) {
      emit(
        state.copyWith(
          status: state.hasData
              ? AdminAuditStatus.ready
              : AdminAuditStatus.failure,
          metrics: metrics,
          isRefreshingRows: false,
          errorMessage: '$pageFailure',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AdminAuditStatus.ready,
        logs: page.rows,
        total: page.total,
        metrics: metrics,
        isRefreshingRows: false,
        clearError: true,
      ),
    );
  }

  Future<AdminAuditMetrics?> _loadMetricsSafely() async {
    try {
      return await _loadMetrics();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
