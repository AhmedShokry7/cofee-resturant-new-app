class HrAdvance {
  const HrAdvance({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.amount,
    required this.installmentAmount,
    required this.settledAmount,
    required this.outstanding,
    required this.currency,
    required this.status,
    required this.reason,
    this.reviewNote,
  });
  final String id, staffId, staffName, currency, status, reason;
  final double amount, installmentAmount, settledAmount, outstanding;
  final String? reviewNote;
  factory HrAdvance.fromJson(Map<String, dynamic> j) => HrAdvance(
    id: '${j['id'] ?? ''}',
    staffId: '${j['staff_id'] ?? ''}',
    staffName: '${j['staff_name'] ?? ''}',
    amount: _num(j['amount']),
    installmentAmount: _num(j['installment_amount']),
    settledAmount: _num(j['settled_amount']),
    outstanding: _num(j['outstanding']),
    currency: '${j['currency_code'] ?? 'SAR'}',
    status: '${j['status'] ?? ''}',
    reason: '${j['reason'] ?? ''}',
    reviewNote: _opt(j['review_note']),
  );
}

class HrAdjustment {
  const HrAdjustment({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.kind,
    required this.amount,
    required this.effectiveDate,
    required this.reason,
    required this.status,
    required this.sourceType,
    required this.claimed,
    this.reviewNote,
  });
  final String id,
      staffId,
      staffName,
      kind,
      effectiveDate,
      reason,
      status,
      sourceType;
  final double amount;
  final bool claimed;
  final String? reviewNote;
  factory HrAdjustment.fromJson(Map<String, dynamic> j) => HrAdjustment(
    id: '${j['id'] ?? ''}',
    staffId: '${j['staff_id'] ?? ''}',
    staffName: '${j['staff_name'] ?? ''}',
    kind: '${j['kind'] ?? ''}',
    amount: _num(j['amount']),
    effectiveDate: '${j['effective_date'] ?? ''}',
    reason: '${j['reason'] ?? ''}',
    status: '${j['status'] ?? ''}',
    sourceType: '${j['source_type'] ?? ''}',
    claimed: j['claimed'] == true,
    reviewNote: _opt(j['review_note']),
  );
}

class HrDiscrepancy {
  const HrDiscrepancy({
    required this.id,
    required this.branchId,
    required this.branchNameEn,
    required this.branchNameAr,
    required this.drawerCashierId,
    required this.drawerCashierName,
    required this.attributedStaffId,
    required this.attributedStaffName,
    required this.amount,
    required this.signedVariance,
    required this.currency,
    required this.status,
    required this.evidence,
    required this.reviewNote,
  });
  final String id,
      branchId,
      branchNameEn,
      branchNameAr,
      drawerCashierId,
      drawerCashierName,
      attributedStaffId,
      attributedStaffName,
      currency,
      status,
      evidence,
      reviewNote;
  final double amount, signedVariance;
  factory HrDiscrepancy.fromJson(Map<String, dynamic> j) => HrDiscrepancy(
    id: '${j['id'] ?? ''}',
    branchId: '${j['branch_id'] ?? ''}',
    branchNameEn: '${j['branch_name_en'] ?? ''}',
    branchNameAr: '${j['branch_name_ar'] ?? ''}',
    drawerCashierId: '${j['drawer_cashier_id'] ?? ''}',
    drawerCashierName: '${j['drawer_cashier_name'] ?? ''}',
    attributedStaffId: '${j['attributed_staff_id'] ?? ''}',
    attributedStaffName: '${j['attributed_staff_name'] ?? ''}',
    amount: _num(j['amount']),
    signedVariance: _num(j['signed_variance']),
    currency: '${j['currency_code'] ?? 'SAR'}',
    status: '${j['status'] ?? ''}',
    evidence: '${j['evidence'] ?? ''}',
    reviewNote: '${j['review_note'] ?? ''}',
  );
}

class HrFinanceEmployee {
  const HrFinanceEmployee({
    required this.id,
    required this.name,
    this.branchIds = const [],
  });
  final String id, name;
  final List<String> branchIds;
  factory HrFinanceEmployee.fromJson(Map<String, dynamic> j) =>
      HrFinanceEmployee(
        id: '${j['staff_id'] ?? ''}',
        name: '${j['full_name'] ?? j['email'] ?? j['staff_id'] ?? ''}',
        branchIds: j['branches'] is List
            ? (j['branches'] as List)
                  .whereType<Map>()
                  .map((e) => '${e['id'] ?? ''}')
                  .where((e) => e.isNotEmpty)
                  .toList()
            : const [],
      );
}

double _num(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String? _opt(Object? value) {
  final s = value?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}
