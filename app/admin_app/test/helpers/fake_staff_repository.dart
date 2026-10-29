import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// دليل موظفين يكتب ما يُرسل إليه لا ما يرسله أحد، ودعوات تجيب بأسباب القاعدة.
///
/// الشاشة لا تملك ساعة ولا نطاقًا: الحالة والرمز والسبب كلها تمرّ من هنا، فيبقى
/// ما تراه الحوار نسخة مما قالته الدالة لا مما ظنته.
class FakeStaffRepository implements StaffRepository {
  FakeStaffRepository({
    this.members = const <AdminStaffMember>[],
    this.options = const AdminInviteOptions(),
    this.invitations = const <AdminStaffInvitation>[],
    this.editOutcome = StaffEditOutcome.success,
    this.inviteOutcome = StaffInviteOutcome.failed,
    this.inviteCode,
    this.cancelOutcome = StaffInviteOutcome.failed,
  });

  List<AdminStaffMember> members;
  AdminInviteOptions options;
  List<AdminStaffInvitation> invitations;
  StaffEditOutcome editOutcome;

  /// سبب الرفض أو النجاح الذي تجيب به `admin_invite_staff`.
  StaffInviteOutcome inviteOutcome;

  /// الرمز الذي يصل كاتب الدعوة مرة واحدة، أو null حين لا نجاح.
  String? inviteCode;

  StaffInviteOutcome cancelOutcome;

  /// حين تُضبط تعيد قراءة القائمة هذا الاستثناء بدل الصفوف: جدار صلاحية أو
  /// انقطاع، والشاشة تفرّق بين «لا دعوات» و«لم تصل الدعوات».
  Object? invitationsError;

  /// كل محاولة كتابة، بترتيبها: ما وصل القاعدة لا ما ظنته الشاشة.
  final List<Map<String, String?>> edits = <Map<String, String?>>[];

  /// كل دعوة أُرسلت، بأربعة حقولها كما وصلت.
  final List<Map<String, String?>> invites = <Map<String, String?>>[];

  /// كل دعوة سُحبت، بمعرّفها لا بصفحتها.
  final List<String> cancellations = <String>[];

  /// كم مرة أعيدت قراءة القائمة: النجاح وحده يستدعي إعادة القراءة.
  int invitationsReads = 0;

  @override
  Future<List<AdminStaffMember>> loadStaff() async => members;

  @override
  Future<List<Map<String, dynamic>>> loadPermissions() async => const [];

  @override
  Future<void> setStaffPermission(
    String staffId,
    String permissionCode,
    bool granted,
  ) async {}

  @override
  Future<StaffEditOutcome> updateStaff({
    required String staffId,
    String? fullName,
    String? email,
    String? status,
  }) async {
    edits.add({
      'staff': staffId,
      'name': fullName,
      'email': email,
      'status': status,
    });
    if (editOutcome == StaffEditOutcome.success) {
      members = [
        for (final member in members)
          if (member.id == staffId)
            AdminStaffMember(
              id: member.id,
              userId: member.userId,
              fullName: fullName ?? member.fullName,
              email: email ?? member.email,
              status: status ?? member.status,
              avatarUrl: member.avatarUrl,
              createdAt: member.createdAt,
              roles: member.roles,
              permissions: member.permissions,
            )
          else
            member,
      ];
    }
    return editOutcome;
  }

  @override
  Future<StaffEditOutcome> setStaffImage(String staffId, String? path) async {
    if (editOutcome == StaffEditOutcome.success) {
      members = [
        for (final member in members)
          if (member.id == staffId)
            AdminStaffMember(
              id: member.id,
              userId: member.userId,
              fullName: member.fullName,
              email: member.email,
              status: member.status,
              avatarUrl: path == null
                  ? null
                  : 'https://signed/$path?token=fresh',
              createdAt: member.createdAt,
              roles: member.roles,
              permissions: member.permissions,
            )
          else
            member,
      ];
    }
    return editOutcome;
  }

  @override
  Future<StaffEditOutcome> uploadStaffImage({
    required String staffId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String? replaces,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) => setStaffImage(staffId, 'staff/$staffId/$fileName');

  @override
  Future<void> deleteStaffImageFile(String? displayedUrl) async {}

  @override
  Future<List<AdminStaffInvitation>> loadInvitations() async {
    invitationsReads++;
    final failure = invitationsError;
    if (failure != null) throw failure;
    return invitations;
  }

  @override
  Future<AdminInviteOptions> loadInviteOptions() async => options;

  @override
  Future<StaffInviteResult> inviteStaff({
    required String email,
    required String fullName,
    required String roleCode,
    String? branchId,
  }) async {
    invites.add({
      'email': email,
      'name': fullName,
      'role': roleCode,
      'branch': branchId,
    });
    if (inviteOutcome != StaffInviteOutcome.success) {
      return StaffInviteResult.refused(inviteOutcome);
    }
    return StaffInviteResult(
      outcome: StaffInviteOutcome.success,
      invitationId: 'inv-${invites.length}',
      code: inviteCode,
      email: email,
    );
  }

  @override
  Future<StaffInviteOutcome> cancelInvitation(String invitationId) async {
    cancellations.add(invitationId);
    return cancelOutcome;
  }
}
