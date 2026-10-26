import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/data/models/admin_branch_draft.dart';
import 'package:admin_app/features/branches/data/models/admin_branch_metrics.dart';
import 'package:admin_app/features/branches/data/repositories/admin_branch_repository.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_state.dart';

class AdminBranchCubit extends Cubit<AdminBranchState> {
  AdminBranchCubit({AdminBranchRepository? repository})
    : _repository = repository ?? AdminBranchRepository(),
      super(const AdminBranchState());

  final AdminBranchRepository _repository;
  int _requestId = 0;

  AdminBranchRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminBranchStatus.loading, clearError: true));
    await _fetch();
  }

  /// Reloads the rows and metrics without replacing them with a spinner.
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final request = ++_requestId;
    try {
      final branches = await _repository.loadBranches();
      var metrics = state.metrics;
      try {
        metrics = await _repository.loadMetrics();
      } catch (_) {
        metrics = AdminBranchMetrics.empty;
      }
      if (isClosed || request != _requestId) return;
      emit(
        state.copyWith(
          status: AdminBranchStatus.ready,
          branches: branches,
          metrics: metrics,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed || request != _requestId) return;
      emit(
        state.copyWith(
          status: AdminBranchStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<BranchSaveOutcome> saveBranch(AdminBranchDraft draft) async {
    final outcome = await _repository.saveBranch(draft);
    if (outcome == BranchSaveOutcome.saved) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> setActive(
    AdminBranch branch,
    bool active,
  ) async {
    final outcome = await _repository.setBranchActive(branch.id, active);
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> deleteBranch(String branchId) async {
    final outcome = await _repository.deleteBranch(branchId);
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> updateBranchImage(
    String branchId,
    String? imageUrl,
  ) async {
    final outcome = await _repository.setBranchImage(branchId, imageUrl);
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> uploadBranchImage({
    required String branchId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final outcome = await _repository.uploadBranchImage(
      branchId: branchId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<void> deleteBranchImageFile(String? imageUrl) async {
    await _repository.deleteBranchImageFile(imageUrl);
  }
}
