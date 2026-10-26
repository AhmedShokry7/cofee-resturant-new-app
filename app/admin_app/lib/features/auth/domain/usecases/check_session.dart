import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/usecase/use_case.dart';
import 'package:admin_app/features/auth/domain/entities/admin_session.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// استعادة الجلسة المحفوظة عند فتح التطبيق.
class CheckSessionUseCase implements UseCase<AdminSession?, NoParams> {
  const CheckSessionUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AdminSession?>> call(NoParams input) {
    return _repository.restoreSession();
  }
}
