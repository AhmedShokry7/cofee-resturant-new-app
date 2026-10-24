import 'package:admin_app/features/staff/data/models/admin_staff.dart';

enum AdminStaffStatus { initial, loading, ready, failure }

class AdminStaffState {
  const AdminStaffState({
    this.status = AdminStaffStatus.initial,
    this.staff = const <AdminStaffMember>[],
    this.errorMessage,
  });

  final AdminStaffStatus status;
  final List<AdminStaffMember> staff;
  final String? errorMessage;

  bool get isLoading => status == AdminStaffStatus.loading;
  bool get hasStaff => staff.isNotEmpty;

  AdminStaffState copyWith({
    AdminStaffStatus? status,
    List<AdminStaffMember>? staff,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminStaffState(
      status: status ?? this.status,
      staff: staff ?? this.staff,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
