import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/di/staff_dependencies.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';
import 'package:admin_app/features/staff/domain/usecases/cancel_invitation.dart';
import 'package:admin_app/features/staff/domain/usecases/delete_staff_image_file.dart';
import 'package:admin_app/features/staff/domain/usecases/invite_staff.dart';
import 'package:admin_app/features/staff/domain/usecases/load_invitations.dart';
import 'package:admin_app/features/staff/domain/usecases/load_invite_options.dart';
import 'package:admin_app/features/staff/domain/usecases/load_permissions.dart';
import 'package:admin_app/features/staff/domain/usecases/load_staff.dart';
import 'package:admin_app/features/staff/domain/usecases/set_staff_image.dart';
import 'package:admin_app/features/staff/domain/usecases/set_staff_permission.dart';
import 'package:admin_app/features/staff/domain/usecases/update_staff.dart';
import 'package:admin_app/features/staff/domain/usecases/upload_staff_image.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_state.dart';

class AdminStaffCubit extends Cubit<AdminStaffState> {
  AdminStaffCubit({StaffRepository? repository})
    : this._withUseCases(repository ?? StaffDependencies.repository);

  AdminStaffCubit._withUseCases(StaffRepository repository)
    : _loadStaff = LoadStaffUseCase(repository),
      _loadPermissions = LoadPermissionsUseCase(repository),
      _setStaffPermission = SetStaffPermissionUseCase(repository),
      _updateStaff = UpdateStaffUseCase(repository),
      _setStaffImage = SetStaffImageUseCase(repository),
      _uploadStaffImage = UploadStaffImageUseCase(repository),
      _deleteStaffImageFile = DeleteStaffImageFileUseCase(repository),
      _loadInvitations = LoadInvitationsUseCase(repository),
      _loadInviteOptions = LoadInviteOptionsUseCase(repository),
      _inviteStaff = InviteStaffUseCase(repository),
      _cancelInvitation = CancelInvitationUseCase(repository),
      super(const AdminStaffState());

  final LoadStaffUseCase _loadStaff;
  final LoadPermissionsUseCase _loadPermissions;
  final SetStaffPermissionUseCase _setStaffPermission;
  final UpdateStaffUseCase _updateStaff;
  final SetStaffImageUseCase _setStaffImage;
  final UploadStaffImageUseCase _uploadStaffImage;
  final DeleteStaffImageFileUseCase _deleteStaffImageFile;
  final LoadInvitationsUseCase _loadInvitations;
  final LoadInviteOptionsUseCase _loadInviteOptions;
  final InviteStaffUseCase _inviteStaff;
  final CancelInvitationUseCase _cancelInvitation;

  Future<void> load() async {
    emit(state.copyWith(status: AdminStaffStatus.loading, clearError: true));
    try {
      final staff = await _loadStaff();
      emit(
        state.copyWith(
          status: AdminStaffStatus.ready,
          staff: staff,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminStaffStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadPermissions() => _loadPermissions();

  Future<void> setStaffPermission(String staffId, String code, bool granted) =>
      _setStaffPermission(staffId, code, granted);

  /// يغيّر بيانات حساب ثم يعيد قراءة الدليل، فيرى المدير ما كتبته القاعدة فعلًا
  /// لا ما أرسله هو — الاسم يُخزَّن حرفًا صغيرة في البريد مثلًا.
  Future<StaffEditOutcome> updateStaff({
    required String staffId,
    String? fullName,
    String? email,
    String? status,
  }) async {
    final outcome = await _updateStaff(
      staffId: staffId,
      fullName: fullName,
      email: email,
      status: status,
    );
    if (outcome == StaffEditOutcome.success) await load();
    return outcome;
  }

  Future<StaffEditOutcome> setStaffImage(String staffId, String? path) async {
    final outcome = await _setStaffImage(staffId, path);
    if (outcome == StaffEditOutcome.success) await load();
    return outcome;
  }

  Future<StaffEditOutcome> uploadStaffImage({
    required String staffId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String? replaces,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    final outcome = await _uploadStaffImage(
      staffId: staffId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      replaces: replaces,
      onPhase: onPhase,
    );
    if (outcome == StaffEditOutcome.success) await load();
    return outcome;
  }

  Future<void> deleteStaffImageFile(String? displayedUrl) =>
      _deleteStaffImageFile(displayedUrl);

  /// يقرأ الدعوات المعلَّقة دون أن يلمس حالة الدليل: الشاشة تعرضها فوق ما تعرفه
  /// عن الموظفين، لا بدلًا منه.
  Future<void> loadInvitations() async {
    try {
      final invitations = await _loadInvitations();
      emit(state.copyWith(invitations: invitations, clearError: true));
    } catch (error) {
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
    }
  }

  /// ما يجوز عرضه في نموذج الدعوة، ويقرره نطاق الموظف نفسه في القاعدة.
  Future<AdminInviteOptions> loadInviteOptions() => _loadInviteOptions();

  /// يكتب الدعوة ثم يعيد قراءة القائمة، فيظهر الرمز والحالة من ردّ القاعدة لا
  /// من ما كتبته الشاشة.
  Future<StaffInviteResult> inviteStaff({
    required String email,
    required String fullName,
    required String roleCode,
    String? branchId,
  }) async {
    final result = await _inviteStaff(
      email: email,
      fullName: fullName,
      roleCode: roleCode,
      branchId: branchId,
    );
    if (result.isSuccess) await loadInvitations();
    return result;
  }

  Future<StaffInviteOutcome> cancelInvitation(String invitationId) async {
    final outcome = await _cancelInvitation(invitationId);
    if (outcome == StaffInviteOutcome.success) await loadInvitations();
    return outcome;
  }
}
