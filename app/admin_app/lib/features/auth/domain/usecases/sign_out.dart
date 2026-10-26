import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// إنهاء جلسة الموظف الحالية.
///
/// لا تعيد [Result] لأن الواجهة تخرج محليًا على أي حال، وفشل الإنهاء لا
/// يمنع مسح الجلسة من جهاز المستخدم.
class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}
