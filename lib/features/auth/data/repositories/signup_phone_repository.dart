import 'package:new_coffee/features/auth/data/model/auth_user.dart';

/// Adds a customer supplied phone number to signup metadata without starting
/// Supabase's SMS verification flow.
abstract interface class SignupPhoneRepository {
  Future<AuthUser> signUpWithPhone({
    required String name,
    required String email,
    required String password,
    required String phone,
  });
}
