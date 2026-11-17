import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';

typedef HrJson = Map<String, dynamic>;

class HrEmployeeFile {
  const HrEmployeeFile({
    required this.staffId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.accountStatus,
    this.avatarUrl,
    this.acceptedAt,
    this.employment,
    this.roles = const <HrJson>[],
    this.branches = const <HrJson>[],
    this.attendance,
    this.leave = const <HrJson>[],
    this.compensation,
    this.payslips,
    this.advances,
    this.adjustments,
    this.cashierShifts,
  });

  final String staffId;
  final String userId;
  final String fullName;
  final String email;
  final String accountStatus;
  final String? avatarUrl;
  final DateTime? acceptedAt;
  final HrEmploymentDraft? employment;
  final List<HrJson> roles;
  final List<HrJson> branches;
  final List<HrJson>? attendance;
  final List<HrJson>? leave;
  final HrJson? compensation;
  final List<HrJson>? payslips;
  final List<HrJson>? advances;
  final List<HrJson>? adjustments;
  final List<HrJson>? cashierShifts;

  HrEmployeeFile withEmployment(HrEmploymentDraft value) => HrEmployeeFile(
    staffId: staffId,
    userId: userId,
    fullName: fullName,
    email: email,
    accountStatus: accountStatus,
    avatarUrl: avatarUrl,
    acceptedAt: acceptedAt,
    employment: value,
    roles: roles,
    branches: branches,
    attendance: attendance,
    leave: leave,
    compensation: compensation,
    payslips: payslips,
    advances: advances,
    adjustments: adjustments,
    cashierShifts: cashierShifts,
  );
}
