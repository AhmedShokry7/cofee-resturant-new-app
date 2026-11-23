import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

/// Optional signup-confirmation operations, separate from email sign-in OTP.
abstract interface class SignupEmailOtpRepository {
  Future<void> resendSignupConfirmationCode({required String email});

  Future<AuthUser> verifySignupEmailCode({
    required String email,
    required String code,
  });
}

/// Keeps older/mock repositories compatible while real Supabase uses the
/// distinct `signup` OTP type.
extension SignupEmailOtpRepositoryAccess on AuthRepository {
  Future<void> resendSignupConfirmationCode({required String email}) {
    final repository = this;
    if (repository is SignupEmailOtpRepository) {
      return repository.resendSignupConfirmationCode(email: email);
    }
    return sendEmailCode(email: email);
  }

  Future<AuthUser> verifySignupEmailCode({
    required String email,
    required String code,
  }) {
    final repository = this;
    if (repository is SignupEmailOtpRepository) {
      return repository.verifySignupEmailCode(email: email, code: code);
    }
    return verifyEmailCode(email: email, code: code);
  }
}
