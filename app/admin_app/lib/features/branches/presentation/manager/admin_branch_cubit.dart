import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/branches/di/branches_dependencies.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_draft.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_metrics.dart';
import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/domain/entities/branch_save_outcome.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';
import 'package:admin_app/features/branches/domain/usecases/delete_branch.dart';
import 'package:admin_app/features/branches/domain/usecases/delete_branch_image_file.dart';
import 'package:admin_app/features/branches/domain/usecases/load_branch_metrics.dart';
import 'package:admin_app/features/branches/domain/usecases/load_branches.dart';
import 'package:admin_app/features/branches/domain/usecases/save_branch.dart';
import 'package:admin_app/features/branches/domain/usecases/set_branch_active.dart';
import 'package:admin_app/features/branches/domain/usecases/set_branch_image.dart';
import 'package:admin_app/features/branches/domain/usecases/upload_branch_image.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_state.dart';

class AdminBranchCubit extends Cubit<AdminBranchState> {
  AdminBranchCubit({BranchRepository? repository})
    : this._withUseCases(repository ?? BranchesDependencies.repository);

  AdminBranchCubit._withUseCases(BranchRepository repository)
    : _loadBranches = LoadBranchesUseCase(repository),
      _loadBranchMetrics = LoadBranchMetricsUseCase(repository),
      _saveBranch = SaveBranchUseCase(repository),
      _setBranchActive = SetBranchActiveUseCase(repository),
      _deleteBranch = DeleteBranchUseCase(repository),
      _setBranchImage = SetBranchImageUseCase(repository),
      _uploadBranchImage = UploadBranchImageUseCase(repository),
      _deleteBranchImageFile = DeleteBranchImageFileUseCase(repository),
      super(const AdminBranchState());

  final LoadBranchesUseCase _loadBranches;
  final LoadBranchMetricsUseCase _loadBranchMetrics;
  final SaveBranchUseCase _saveBranch;
  final SetBranchActiveUseCase _setBranchActive;
  final DeleteBranchUseCase _deleteBranch;
  final SetBranchImageUseCase _setBranchImage;
  final UploadBranchImageUseCase _uploadBranchImage;
  final DeleteBranchImageFileUseCase _deleteBranchImageFile;
  int _requestId = 0;

  Future<void> load() async {
    emit(state.copyWith(status: AdminBranchStatus.loading, clearError: true));
    await _fetch();
  }

  /// Reloads the rows and metrics without replacing them with a spinner.
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final request = ++_requestId;
    try {
      final branches = await _loadBranches();
      var metrics = state.metrics;
      try {
        metrics = await _loadBranchMetrics();
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
    final outcome = await _saveBranch(draft);
    if (outcome == BranchSaveOutcome.saved) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> setActive(
    AdminBranch branch,
    bool active,
  ) async {
    final outcome = await _setBranchActive(branch.id, active);
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> deleteBranch(String branchId) async {
    final outcome = await _deleteBranch(branchId);
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> updateBranchImage(
    String branchId,
    String? imageUrl,
  ) async {
    final outcome = await _setBranchImage(branchId, imageUrl);
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<BranchMutationOutcome> uploadBranchImage({
    required String branchId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final outcome = await _uploadBranchImage(
      branchId: branchId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    if (outcome == BranchMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<void> deleteBranchImageFile(String? imageUrl) async {
    await _deleteBranchImageFile(imageUrl);
  }
}
