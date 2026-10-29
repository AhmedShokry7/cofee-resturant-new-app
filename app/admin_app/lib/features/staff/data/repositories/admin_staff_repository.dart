import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// The staff accounts of the dashboard and the writing done on them.
class AdminStaffRepository implements StaffRepository {
  AdminStaffRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminStaffMember>> loadStaff() async {
    // The picture of a staff account is a path in the private `avatars` bucket
    // (migration 209), so it is signed here — the same way the customer photos
    // are since 208 — and never reaches a widget as a path it cannot fetch.
    final response = await AdminAvatarLinks.signTree(
      await _supabase.rpc('admin_staff'),
      client: _supabase,
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) => AdminStaffMember.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminStaffMember>[];
  }

  @override
  Future<List<Map<String, dynamic>>> loadPermissions() async {
    final response = await _supabase.rpc('admin_permissions');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<void> setStaffPermission(
    String staffId,
    String permissionCode,
    bool granted,
  ) async {
    await _supabase.rpc(
      'admin_set_staff_permission',
      params: {
        'p_staff_id': staffId,
        'p_permission_code': permissionCode,
        'p_granted': granted,
      },
    );
  }

  @override
  Future<StaffEditOutcome> updateStaff({
    required String staffId,
    String? fullName,
    String? email,
    String? status,
  }) async {
    return _mutation(
      'admin_update_staff',
      params: {
        'p_staff_id': staffId,
        'p_full_name': fullName,
        'p_email': email,
        'p_status': status,
      },
    );
  }

  @override
  Future<StaffEditOutcome> setStaffImage(String staffId, String? path) async {
    return _mutation(
      'admin_set_staff_image',
      params: {'p_staff_id': staffId, 'p_avatar_url': path},
    );
  }

  @override
  Future<StaffEditOutcome> uploadStaffImage({
    required String staffId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String? replaces,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    if (bytes.isEmpty) throw AdminProductException(S.imageIsEmpty);
    if (bytes.length > adminImageMaxBytes) {
      throw AdminProductException(S.imageTooLarge);
    }

    // The folder is the staff id and nothing else, which is the shape the
    // column constraint and `admin_set_staff_image` both insist on.
    final path =
        'staff/$staffId/${DateTime.now().microsecondsSinceEpoch}${_extOf(fileName)}';

    onPhase?.call(AdminImageUploadPhase.uploading);
    await _supabase.storage
        .from(AdminAvatarLinks.bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    onPhase?.call(AdminImageUploadPhase.saving);
    final outcome = await setStaffImage(staffId, path);
    if (outcome != StaffEditOutcome.success) {
      // The row kept its old picture, so the file that was never named is
      // dropped: a bucket full of unreferenced bytes is invisible clutter.
      await _removeFile(path);
      return outcome;
    }

    // Only after the row names the new file may the old one go: the other
    // order leaves the account pointing at bytes that are already gone.
    final previous = _pathOf(replaces);
    if (previous != null && previous != path) await _removeFile(previous);
    return outcome;
  }

  @override
  Future<void> deleteStaffImageFile(String? displayedUrl) async {
    final path = _pathOf(displayedUrl);
    if (path == null) return;
    await _removeFile(path);
  }

  @override
  Future<List<AdminStaffInvitation>> loadInvitations() async {
    // الحالة هنا من القاعدة لا من الساعة المحلية: `admin_staff_invitations()`
    // هي التي تقرر أن صفًا `pending` قد تجاوز أجله فهو `expired` عند القارئ.
    final response = await _supabase.rpc('admin_staff_invitations');
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) =>
                AdminStaffInvitation.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminStaffInvitation>[];
  }

  @override
  Future<AdminInviteOptions> loadInviteOptions() async {
    final response = await _supabase.rpc('admin_staff_invite_options');
    if (response is Map) {
      return AdminInviteOptions.fromJson(Map<String, dynamic>.from(response));
    }
    return const AdminInviteOptions();
  }

  @override
  Future<StaffInviteResult> inviteStaff({
    required String email,
    required String fullName,
    required String roleCode,
    String? branchId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_invite_staff',
        params: {
          'p_email': email,
          'p_full_name': fullName,
          'p_role_code': roleCode,
          'p_branch_id': branchId,
        },
      );
      if (response is! Map) {
        return const StaffInviteResult.refused(StaffInviteOutcome.failed);
      }
      if (response['ok'] == true) {
        // الرمز لا يصل إلا هنا، ومن القاعدة إلى هذه الشاشة مرة واحدة:
        // القائمة تخبئه عن كل من لم يكتب الدعوة.
        return StaffInviteResult(
          outcome: StaffInviteOutcome.success,
          invitationId: '${response['invitation_id'] ?? ''}',
          code: '${response['token'] ?? ''}',
          email: '${response['email'] ?? ''}',
        );
      }
      return StaffInviteResult(
        outcome: _inviteReason('${response['reason']}'),
        invitationId: response['invitation_id'] == null
            ? null
            : '${response['invitation_id']}',
      );
    } on PostgrestException catch (error) {
      return StaffInviteResult.refused(
        error.code == '42501'
            ? StaffInviteOutcome.permissionDenied
            : StaffInviteOutcome.failed,
      );
    } catch (_) {
      return const StaffInviteResult.refused(StaffInviteOutcome.failed);
    }
  }

  @override
  Future<StaffInviteOutcome> cancelInvitation(String invitationId) async {
    try {
      final response = await _supabase.rpc(
        'admin_cancel_invitation',
        params: {'p_invitation_id': invitationId},
      );
      if (response is Map && response['ok'] == true) {
        return StaffInviteOutcome.success;
      }
      return _inviteReason('${response is Map ? response['reason'] : ''}');
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? StaffInviteOutcome.permissionDenied
          : StaffInviteOutcome.failed;
    } catch (_) {
      return StaffInviteOutcome.failed;
    }
  }

  /// The object path behind whatever the screen holds: the signed link of
  /// `AdminAvatarLinks`, or the stored path when signing failed.
  static String? _pathOf(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.startsWith('staff/')) return text;
    const marker = '/object/sign/${AdminAvatarLinks.bucket}/';
    final index = text.indexOf(marker);
    if (index < 0) return null;
    final tail = text.substring(index + marker.length);
    final cut = tail.indexOf('?');
    return cut < 0 ? tail : tail.substring(0, cut);
  }

  Future<StaffEditOutcome> _mutation(
    String function, {
    required Map<String, dynamic> params,
  }) async {
    try {
      final response = await _supabase.rpc(function, params: params);
      if (response is Map && response['ok'] == true) {
        return StaffEditOutcome.success;
      }
      return switch ('${response is Map ? response['reason'] : ''}') {
        'self_status' => StaffEditOutcome.selfStatus,
        'invalid_name' => StaffEditOutcome.invalidName,
        'invalid_email' => StaffEditOutcome.invalidEmail,
        'duplicate_email' => StaffEditOutcome.duplicateEmail,
        'invalid_status' => StaffEditOutcome.invalidStatus,
        'invalid_path' => StaffEditOutcome.invalidPath,
        _ => StaffEditOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? StaffEditOutcome.permissionDenied
          : StaffEditOutcome.failed;
    } catch (_) {
      return StaffEditOutcome.failed;
    }
  }

  /// سبب رفض الدعوة كما تسميه القاعدة، أو `failed` لما لا تعرفه الشاشة.
  static StaffInviteOutcome _inviteReason(String reason) => switch (reason) {
    'invalid_email' => StaffInviteOutcome.invalidEmail,
    'invalid_name' => StaffInviteOutcome.invalidName,
    'unknown_role' => StaffInviteOutcome.unknownRole,
    'owner_only' => StaffInviteOutcome.ownerOnly,
    'not_your_branch' => StaffInviteOutcome.notYourBranch,
    'unknown_branch' => StaffInviteOutcome.unknownBranch,
    'already_invited' => StaffInviteOutcome.alreadyInvited,
    'already_staff' => StaffInviteOutcome.alreadyStaff,
    'not_found' => StaffInviteOutcome.notFound,
    'not_pending' => StaffInviteOutcome.notPending,
    _ => StaffInviteOutcome.failed,
  };

  Future<void> _removeFile(String path) async {
    try {
      await _supabase.storage.from(AdminAvatarLinks.bucket).remove([path]);
    } catch (_) {}
  }

  String _extOf(String fileName) {
    final name = fileName.toLowerCase();
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }
}
