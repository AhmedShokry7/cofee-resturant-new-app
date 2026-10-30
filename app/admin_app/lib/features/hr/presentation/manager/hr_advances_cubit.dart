import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_directory_cubit.dart';

/// طلبات السلف ومسارها: مراجعة ثم صرف ثم تسوية داخل دورة الرواتب.
///
/// الصرف حركة مال لا علامة في العمود، فلا تُعرض «مدفوعة» حتى تقول القاعدة
/// ذلك؛ وتعديل قسط بعد الاعتماد يقلّب الجدولة كلها فيُعاد قراءتها لا تُعدَّل
/// محليًا.
class HrAdvancesCubit extends HrDirectoryCubit<HrAdvance> {
  HrAdvancesCubit({HrMoneyRepository? repository})
    : _repository = repository ?? HrDependencies.money;

  final HrMoneyRepository _repository;

  String? status;
  String? staffId;
  int limit = 60;

  Future<void> setStatus(String? value) async {
    status = value;
    await reload();
  }

  Future<void> setStaff(String? value) async {
    staffId = value;
    await reload();
  }

  @override
  Future<List<HrAdvance>> fetch() =>
      _repository.loadAdvances(status: status, staffId: staffId, limit: limit);

  Future<bool> review({
    required String advanceId,
    required bool approve,
    double? installment,
    String? note,
  }) => submit(
    () => _repository.reviewAdvance(
      advanceId: advanceId,
      approve: approve,
      installment: installment,
      note: note,
    ),
  );

  Future<bool> disburse({required String advanceId, String? note}) => submit(
    () => _repository.disburseAdvance(advanceId: advanceId, note: note),
  );

  Future<bool> cancel({required String advanceId, String? note}) =>
      submit(() => _repository.cancelAdvance(advanceId: advanceId, note: note));
}
