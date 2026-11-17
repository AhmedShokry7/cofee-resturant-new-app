class HrCompensationEmployee {
  const HrCompensationEmployee({
    required this.staffId,
    required this.fullName,
    required this.employeeNumber,
  });

  final String staffId;
  final String fullName;
  final String? employeeNumber;

  factory HrCompensationEmployee.fromJson(Map<String, dynamic> json) =>
      HrCompensationEmployee(
        staffId: '${json['staff_id'] ?? ''}',
        fullName: '${json['full_name'] ?? json['email'] ?? ''}',
        employeeNumber: json['employee_number']?.toString(),
      );
}

abstract interface class HrCompensationRepository {
  Future<List<HrCompensationEmployee>> loadEmployees();
  Future<Map<String, dynamic>?> loadEmployeeCompensation(String staffId);
  Future<void> addCompensation({
    required String staffId,
    required double basicSalary,
    required double housingAllowance,
    required double transportAllowance,
    required double otherAllowance,
    required DateTime effectiveFrom,
    required String note,
  });
}
