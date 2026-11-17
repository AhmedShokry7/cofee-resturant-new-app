import '../models/hr_finance_models.dart';

abstract interface class HrFinanceRepository {
  Future<List<HrAdvance>> loadAdvances();
  Future<List<HrAdjustment>> loadAdjustments();
  Future<List<HrDiscrepancy>> loadDiscrepancies();
  Future<List<HrFinanceEmployee>> loadEmployees();
  Future<bool> loadCashierDeductionEnabled();
  Future<void> reviewAdvance(
    String id,
    bool approve,
    double? installment,
    String? note,
  );
  Future<void> disburseAdvance(String id, String? note);
  Future<void> cancelAdvance(String id, String? note);
  Future<void> createAdjustment(
    String staffId,
    String kind,
    double amount,
    String reason,
    String? date,
  );
  Future<void> reviewAdjustment(String id, bool approve, String? note);
  Future<void> reverseAdjustment(String id, String reason);
  Future<void> reviewDiscrepancy({
    required String id,
    required String action,
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  });
}
