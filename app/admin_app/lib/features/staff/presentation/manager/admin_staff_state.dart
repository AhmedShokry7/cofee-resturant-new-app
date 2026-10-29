import 'package:admin_app/features/staff/data/models/admin_staff.dart';

enum AdminStaffStatus { initial, loading, ready, failure }

class AdminStaffState {
  const AdminStaffState({
    this.status = AdminStaffStatus.initial,
    this.staff = const <AdminStaffMember>[],
    this.invitations = const <AdminStaffInvitation>[],
    this.errorMessage,
  });

  final AdminStaffStatus status;
  final List<AdminStaffMember> staff;

  /// الدعوات التي لم تُقبل بعد، كما قرأتها القاعدة آخر مرة.
  ///
  /// تبقى منفصلة عن `staff` لأن المدعو لم يصبح صفّ موظف بعد: الدمج بينهما
  /// يعني حالة وسيطة لا تعرفها القاعدة.
  final List<AdminStaffInvitation> invitations;
  final String? errorMessage;

  bool get isLoading => status == AdminStaffStatus.loading;
  bool get hasStaff => staff.isNotEmpty;

  /// كم دعوة ما زال يمكن إرسال رمزها.
  int get pendingInvitations =>
      invitations.where((invitation) => invitation.isPending).length;

  AdminStaffState copyWith({
    AdminStaffStatus? status,
    List<AdminStaffMember>? staff,
    List<AdminStaffInvitation>? invitations,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminStaffState(
      status: status ?? this.status,
      staff: staff ?? this.staff,
      invitations: invitations ?? this.invitations,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
