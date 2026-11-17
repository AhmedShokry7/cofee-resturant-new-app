import 'hr_payroll_models.dart';

abstract interface class HrPayrollRepository {
  Future<List<HrPayrollRun>> loadRuns();
  Future<HrJson> loadRun(String id);
  Future<HrPayrollPreview> preview(int year, int month);
  Future<void> generate(int year, int month, String? note);
  Future<void> approve(String runId, String? note);
  Future<void> markPaid(String runId, String? reference);
  Future<void> cancel(String runId, String reason);
  Future<void> closePeriod(String runId, String? note);
  Future<void> correction({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  });
}
