import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/admin_error_message.dart';
import 'hr_dashboard_repository.dart';

enum HrDashboardStatus { initial, loading, ready, failure }

class HrDashboardState {
  const HrDashboardState({
    this.status = HrDashboardStatus.initial,
    this.data = const {},
    this.branches = const [],
    this.branchId,
    this.error,
  });
  final HrDashboardStatus status;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> branches;
  final String? branchId;
  final String? error;

  HrDashboardState copyWith({
    HrDashboardStatus? status,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? branches,
    String? branchId,
    bool clearBranch = false,
    String? error,
    bool clearError = false,
  }) => HrDashboardState(
    status: status ?? this.status,
    data: data ?? this.data,
    branches: branches ?? this.branches,
    branchId: clearBranch ? null : branchId ?? this.branchId,
    error: clearError ? null : error ?? this.error,
  );
}

class HrDashboardCubit extends Cubit<HrDashboardState> {
  HrDashboardCubit({HrDashboardRepository? repository})
    : _repository = repository ?? SupabaseHrDashboardRepository(),
      super(const HrDashboardState());

  final HrDashboardRepository _repository;

  Future<void> load({String? branchId, bool clearBranch = false}) async {
    emit(
      state.copyWith(
        status: HrDashboardStatus.loading,
        branchId: branchId,
        clearBranch: clearBranch,
        clearError: true,
      ),
    );
    try {
      final data = await _repository.load(
        branchId: clearBranch ? null : branchId ?? state.branchId,
      );
      final branches = data['_branches'] is List
          ? (data['_branches'] as List).cast<Map<String, dynamic>>()
          : const <Map<String, dynamic>>[];
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrDashboardStatus.ready,
            data: Map<String, dynamic>.from(data)..remove('_branches'),
            branches: branches,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrDashboardStatus.failure,
            error: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<void> setBranch(String? id) =>
      load(branchId: id, clearBranch: id == null);
}
