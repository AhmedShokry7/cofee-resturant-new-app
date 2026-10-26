import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/repositories/dining_tables_repository.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';

/// The dining floor for one branch: tables, live statuses and bookings.
class DiningTablesCubit extends Cubit<DiningTablesState> {
  DiningTablesCubit({DiningTablesRepository? repository})
    : _repository = repository ?? DiningTablesRepository(),
      super(const DiningTablesState());

  final DiningTablesRepository _repository;
  int _requestId = 0;

  Future<void> load() async {
    if (state.isLoading) return;
    await _fetch(first: true);
  }

  Future<void> refresh() async {
    if (state.isLoading) return;
    await _fetch();
  }

  Future<void> setBranch(String branchId) async {
    if (branchId == state.branchId) return;
    if (!state.branches.any((branch) => branch.id == branchId)) return;
    emit(state.copyWith(branchId: branchId));
    await _fetch(first: true);
  }

  void updateSearch(String value) {
    final normalized = value.trim();
    if (normalized == state.search) return;
    emit(state.copyWith(search: normalized));
  }

  void setArea(DiningArea? area) {
    if (area == state.area) return;
    emit(state.copyWith(area: area, clearArea: area == null));
  }

  void setView(DiningView view) {
    if (view == state.view) return;
    emit(state.copyWith(view: view));
  }

  void clearFilters() {
    if (!state.hasActiveFilters) return;
    emit(state.copyWith(search: '', clearArea: true));
  }

  Future<DiningTableSaveOutcome> saveTable(DiningTableDraft draft) async {
    final outcome = await _repository.saveTable(draft);
    if (outcome == DiningTableSaveOutcome.saved) await _fetch();
    return outcome;
  }

  Future<DiningTableMutationOutcome> setTableActive(
    String tableId,
    bool active,
  ) async {
    final outcome = await _repository.setTableActive(tableId, active);
    if (outcome == DiningTableMutationOutcome.success) await _fetch();
    return outcome;
  }

  Future<DiningTableMutationOutcome> deleteTable(String tableId) async {
    final outcome = await _repository.deleteTable(tableId);
    if (outcome == DiningTableMutationOutcome.success) await _fetch();
    return outcome;
  }

  Future<DiningReservationSaveOutcome> saveReservation(
    DiningReservationDraft draft,
  ) async {
    final outcome = await _repository.saveReservation(draft);
    if (outcome == DiningReservationSaveOutcome.saved) await _fetch();
    return outcome;
  }

  Future<DiningReservationStatusOutcome> setReservationStatus(
    String reservationId,
    DiningReservationStatus status,
  ) async {
    final outcome = await _repository.setReservationStatus(
      reservationId,
      status.value,
    );
    if (outcome == DiningReservationStatusOutcome.success) await _fetch();
    return outcome;
  }

  Future<void> _fetch({bool first = false}) async {
    final request = ++_requestId;
    if (first) {
      emit(
        state.copyWith(
          status: DiningStatus.loading,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } else {
      emit(state.copyWith(isRefreshing: true, clearError: true));
    }

    try {
      final overview = await _repository.loadOverview(branchId: state.branchId);
      if (isClosed || request != _requestId) return;

      emit(
        state.copyWith(
          status: DiningStatus.ready,
          tables: overview.tables,
          reservations: overview.reservations,
          branches: overview.branches,
          metrics: overview.metrics,
          branchId: overview.branchId,
          clearBranch: overview.branchId == null,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on DiningLoadException catch (error) {
      _failFetch(request, error.message ?? error.failure.name);
    } catch (error) {
      _failFetch(request, '$error');
    }
  }

  void _failFetch(int request, String message) {
    if (isClosed || request != _requestId) return;
    emit(
      state.copyWith(
        status: state.hasData ? DiningStatus.ready : DiningStatus.failure,
        isRefreshing: false,
        errorMessage: message,
      ),
    );
  }
}
