import 'package:admin_app/features/dashboard/domain/repositories/dashboard_repository.dart';

/// كتابة هدف الشهر، ومسحه حين تأتي القيمة فارغة.
///
/// الحفظ لا يعيد الرقم المحفوظ: القاعدة هي التي تقرّره (تقريب إلى منزلتين)،
/// فيقرأ الكوبيت اللوحة بعدها بدل أن يثق بما أرسله.
class SaveRevenueTargetUseCase {
  const SaveRevenueTargetUseCase(this._repository);

  final DashboardRepository _repository;

  Future<void> call(double? value) => _repository.saveRevenueTarget(value);
}
