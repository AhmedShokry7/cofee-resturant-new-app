import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/usecase/use_case.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// معطيات تسجيل الدخول.
final class SignInParams {
  const SignInParams({required this.email, required this.password});

  final String email;
  final String password;
}

/// تسجيل دخول موظف والتأكد من أن حسابه موظف نشط.
class SignInUseCase implements UseCase<AdminSession, SignInParams> {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AdminSession>> call(SignInParams input) {
    return _repository.signIn(email: input.email, password: input.password);
  }
}
