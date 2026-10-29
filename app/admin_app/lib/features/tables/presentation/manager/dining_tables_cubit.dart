import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/features/tables/di/tables_dependencies.dart';
import 'package:admin_app/features/tables/domain/entities/dining_reservation_draft.dart';
import 'package:admin_app/features/tables/domain/entities/dining_table_draft.dart';
import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';
import 'package:admin_app/features/tables/domain/usecases/delete_table.dart';
import 'package:admin_app/features/tables/domain/usecases/load_overview.dart';
import 'package:admin_app/features/tables/domain/usecases/save_reservation.dart';
import 'package:admin_app/features/tables/domain/usecases/save_table.dart';
import 'package:admin_app/features/tables/domain/usecases/set_reservation_status.dart';
import 'package:admin_app/features/tables/domain/usecases/set_table_active.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';

/// The dining floor for one branch: tables, live statuses and bookings.
class DiningTablesCubit extends Cubit<DiningTablesState> {
  DiningTablesCubit({DiningTableRepository? repository})
    : this._withUseCases(repository ?? TablesDependencies.repository);

  DiningTablesCubit._withUseCases(DiningTableRepository repository)
    : _loadOverview = LoadOverviewUseCase(repository),
      _saveTable = SaveTableUseCase(repository),
      _setTableActive = SetTableActiveUseCase(repository),
      _deleteTable = DeleteTableUseCase(repository),
      _saveReservation = SaveReservationUseCase(repository),
      _setReservationStatus = SetReservationStatusUseCase(repository),
      super(const DiningTablesState());

  final LoadOverviewUseCase _loadOverview;
  final SaveTableUseCase _saveTable;
  final SetTableActiveUseCase _setTableActive;
  final DeleteTableUseCase _deleteTable;
  final SaveReservationUseCase _saveReservation;
  final SetReservationStatusUseCase _setReservationStatus;
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
    final outcome = await _saveTable(draft);
    if (outcome == DiningTableSaveOutcome.saved) await _fetch();
    return outcome;
  }

  Future<DiningTableMutationOutcome> setTableActive(
    String tableId,
    bool active,
  ) async {
    final outcome = await _setTableActive(tableId, active);
    if (outcome == DiningTableMutationOutcome.success) await _fetch();
    return outcome;
  }

  Future<DiningTableMutationOutcome> deleteTable(String tableId) async {
    final outcome = await _deleteTable(tableId);
    if (outcome == DiningTableMutationOutcome.success) await _fetch();
    return outcome;
  }

  Future<DiningReservationSaveOutcome> saveReservation(
    DiningReservationDraft draft,
  ) async {
    final outcome = await _saveReservation(draft);
    if (outcome == DiningReservationSaveOutcome.saved) await _fetch();
    return outcome;
  }

  Future<DiningReservationStatusOutcome> setReservationStatus(
    String reservationId,
    DiningReservationStatus status,
  ) async {
    final outcome = await _setReservationStatus(reservationId, status.value);
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
          clearLoadFailure: true,
        ),
      );
    } else {
      emit(state.copyWith(isRefreshing: true, clearLoadFailure: true));
    }

    try {
      final overview = await _loadOverview(branchId: state.branchId);
      if (isClosed || request != _requestId) return;

      emit(
        state.copyWith(
          status: DiningStatus.ready,
          tables: overview.tables,
          reservations: overview.reservations,
          branches: overview.branches,
          metrics: overview.metrics,
          branchId: overview.branchId,
          isRefreshing: false,
          clearLoadFailure: true,
        ),
      );
    } on DiningLoadException catch (error) {
      _failFetch(request, error.failure);
    } catch (_) {
      _failFetch(request, DiningLoadFailure.failed);
    }
  }

  void _failFetch(int request, DiningLoadFailure failure) {
    if (isClosed || request != _requestId) return;
    emit(
      state.copyWith(
        status: state.hasData ? DiningStatus.ready : DiningStatus.failure,
        isRefreshing: false,
        loadFailure: failure,
      ),
    );
  }
}
