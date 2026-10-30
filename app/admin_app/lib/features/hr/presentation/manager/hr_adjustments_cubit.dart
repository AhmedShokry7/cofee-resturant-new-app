import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_directory_cubit.dart';

/// التسويات المالية: علاوة أو مكافأة أو خصم يُراجَع ثم يدخل لقطة الرواتب.
///
/// العكس وحده يُلغي أثر سطر معتمد، والحذف لا يوجد في العقد؛ وحين تدخل
/// التسوية لقطةً فهي حجر في كشف مرتّب، ترفض القاعدة المساس به برمز 23514.
class HrAdjustmentsCubit extends HrDirectoryCubit<HrAdjustment> {
  HrAdjustmentsCubit({HrMoneyRepository? repository})
    : _repository = repository ?? HrDependencies.money;

  final HrMoneyRepository _repository;

  String? status;
  String? staffId;
  String? sourceType;
  int limit = 60;

  Future<void> setStatus(String? value) async {
    status = value;
    await reload();
  }

  Future<void> setStaff(String? value) async {
    staffId = value;
    await reload();
  }

  Future<void> setSource(String? value) async {
    sourceType = value;
    await reload();
  }

  @override
  Future<List<HrAdjustment>> fetch() => _repository.loadAdjustments(
    status: status,
    staffId: staffId,
    sourceType: sourceType,
    limit: limit,
  );

  Future<bool> create({
    required String staffId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
    double? quantity,
  }) => submit(
    () => _repository.createAdjustment(
      staffId: staffId,
      kind: kind,
      amount: amount,
      reason: reason,
      effectiveDate: effectiveDate,
      quantity: quantity,
    ),
  );

  Future<bool> review({
    required String adjustmentId,
    required bool approve,
    String? note,
  }) => submit(
    () => _repository.reviewAdjustment(
      adjustmentId: adjustmentId,
      approve: approve,
      note: note,
    ),
  );

  Future<bool> reverse({
    required String adjustmentId,
    required String reason,
  }) => submit(
    () => _repository.reverseAdjustment(
      adjustmentId: adjustmentId,
      reason: reason,
    ),
  );
}
