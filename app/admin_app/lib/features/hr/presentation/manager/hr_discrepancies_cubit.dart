import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_directory_cubit.dart';
import 'package:admin_app/features/hr/presentation/models/hr_discrepancy_action.dart';

/// فروق صناديق الكاشير: توضيح وتسوية وإثبات ورفض وإغلاق، ثم خصم صريح.
///
/// ظهور الفرق لا يمسّ راتب أحد: الخصم إجراءٌ مستقلّ باسمه، لا يفتحه إلا سطر
/// مثبَّت، ولا ينفذه إلا من يملك `hr.finance.adjust`، وترفضه القاعدة إن كانت
/// الخصومات معطّلة أو تجاوزت السقف أو نُسِبَت إلى المراجع نفسه.
class HrDiscrepanciesCubit extends HrDirectoryCubit<HrDiscrepancy> {
  HrDiscrepanciesCubit({HrMoneyRepository? repository})
    : _repository = repository ?? HrDependencies.money;

  final HrMoneyRepository _repository;

  String? status;
  String? branchId;
  int limit = 60;

  Future<void> setStatus(String? value) async {
    status = value;
    await reload();
  }

  Future<void> setBranch(String? value) async {
    branchId = value;
    await reload();
  }

  @override
  Future<List<HrDiscrepancy>> fetch() => _repository.loadDiscrepancies(
    status: status,
    branchId: branchId,
    limit: limit,
  );

  Future<bool> review({
    required String discrepancyId,
    required HrDiscrepancyAction action,
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  }) => submit(
    () => _repository.reviewDiscrepancy(
      discrepancyId: discrepancyId,
      action: action.wire,
      note: note,
      evidence: evidence,
      attributedStaffId: attributedStaffId,
      deductionAmount: deductionAmount,
    ),
  );
}
