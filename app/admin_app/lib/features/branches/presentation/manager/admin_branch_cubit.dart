import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/data/repositories/admin_branch_repository.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_state.dart';

class AdminBranchCubit extends Cubit<AdminBranchState> {
  AdminBranchCubit({AdminBranchRepository? repository})
    : _repository = repository ?? AdminBranchRepository(),
      super(const AdminBranchState());

  final AdminBranchRepository _repository;

  AdminBranchRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminBranchStatus.loading, clearError: true));
    try {
      final branches = await _repository.loadBranches();
      emit(
        state.copyWith(
          status: AdminBranchStatus.ready,
          branches: branches,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminBranchStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<AdminBranch> createBranch({
    required String code,
    required String nameAr,
    required String nameEn,
    required String address,
    double? latitude,
    double? longitude,
    String? phone,
    String? opensAt,
    String? closesAt,
  }) async {
    final branch = await _repository.createBranch(
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      address: address,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      opensAt: opensAt,
      closesAt: closesAt,
    );
    emit(
      state.copyWith(
        branches: <AdminBranch>[...state.branches, branch],
        clearError: true,
      ),
    );
    return branch;
  }

  Future<AdminBranch> updateBranch({
    required String branchId,
    required String code,
    required String nameAr,
    required String nameEn,
    required String address,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? phone,
    bool clearPhone = false,
    String? opensAt,
    bool clearOpensAt = false,
    String? closesAt,
    bool clearClosesAt = false,
  }) async {
    final updated = await _repository.updateBranch(
      branchId: branchId,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      address: address,
      latitude: latitude,
      clearLatitude: clearLatitude,
      longitude: longitude,
      clearLongitude: clearLongitude,
      phone: phone,
      clearPhone: clearPhone,
      opensAt: opensAt,
      clearOpensAt: clearOpensAt,
      closesAt: closesAt,
      clearClosesAt: clearClosesAt,
    );
    emit(
      state.copyWith(
        branches: state.branches
            .map((branch) => branch.id == branchId ? updated : branch)
            .toList(growable: false),
        clearError: true,
      ),
    );
    return updated;
  }

  Future<void> deleteBranch(String branchId) async {
    await _repository.deleteBranch(branchId);
    emit(
      state.copyWith(
        branches: state.branches
            .where((b) => b.id != branchId)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> toggleActive(AdminBranch branch) async {
    final next = !branch.isActive;
    await _repository.setBranchActive(branch.id, next);
    emit(
      state.copyWith(
        branches: state.branches
            .map((b) => b.id == branch.id ? b.copyWith(isActive: next) : b)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<String?> updateBranchImage(String branchId, String? imageUrl) async {
    await _repository.updateBranchImage(branchId, imageUrl);
    emit(
      state.copyWith(
        branches: state.branches
            .map(
              (b) => b.id == branchId
                  ? b.copyWith(
                      imageUrl: imageUrl,
                      clearImageUrl: imageUrl == null || imageUrl.isEmpty,
                    )
                  : b,
            )
            .toList(growable: false),
        clearError: true,
      ),
    );
    return imageUrl;
  }

  Future<String> uploadBranchImage({
    required String branchId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final url = await _repository.uploadBranchImage(
      branchId: branchId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    await updateBranchImage(branchId, url);
    return url;
  }

  Future<void> deleteBranchImageFile(String? imageUrl) async {
    await _repository.deleteBranchImageFile(imageUrl);
  }
}
