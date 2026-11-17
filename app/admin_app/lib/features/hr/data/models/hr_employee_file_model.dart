import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';

class HrEmployeeFileModel extends HrEmployeeFile {
  const HrEmployeeFileModel({
    required super.staffId,
    required super.userId,
    required super.fullName,
    required super.email,
    required super.accountStatus,
    super.avatarUrl,
    super.acceptedAt,
    super.employment,
    super.roles,
    super.branches,
    super.attendance,
    super.leave,
    super.compensation,
    super.payslips,
    super.advances,
    super.adjustments,
    super.cashierShifts,
  });

  factory HrEmployeeFileModel.fromJson(Map<String, dynamic> json) {
    List<HrJson>? rows(String key) {
      final raw = json[key];
      if (raw == null) return null;
      if (raw is! List) return const <HrJson>[];
      return raw
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    HrJson? object(String key) {
      final raw = json[key];
      return raw is Map ? Map<String, dynamic>.from(raw) : null;
    }

    return HrEmployeeFileModel(
      staffId: '${json['staff_id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      fullName: '${json['full_name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      accountStatus: '${json['account_status'] ?? ''}',
      avatarUrl: json['avatar_url'] as String?,
      acceptedAt: _dateTime(json['accepted_at']),
      employment: json['employment'] is Map
          ? HrEmploymentDraft.fromJson(
              Map<String, dynamic>.from(json['employment'] as Map),
            )
          : null,
      roles: rows('roles') ?? const <HrJson>[],
      branches: rows('branches') ?? const <HrJson>[],
      attendance: rows('attendance'),
      leave: rows('leave') ?? const <HrJson>[],
      compensation: object('compensation'),
      payslips: rows('payslips'),
      advances: rows('advances'),
      adjustments: rows('adjustments'),
      cashierShifts: rows('cashier_shifts'),
    );
  }

  static DateTime? _dateTime(Object? value) =>
      value == null ? null : DateTime.tryParse('$value');
}
