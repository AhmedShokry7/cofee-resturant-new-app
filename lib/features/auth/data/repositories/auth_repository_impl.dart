import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl();

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return AuthUser(id: email, email: email);
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return AuthUser(id: email, name: name, email: email);
  }

  @override
  Future<AuthUser> signInWithGoogle() => _socialSignIn("google");

  @override
  Future<AuthUser> signInWithFacebook() => _socialSignIn("facebook");

  @override
  Future<AuthUser> signInWithApple() => _socialSignIn("apple");

  Future<AuthUser> _socialSignIn(String provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return AuthUser(id: provider);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  @override
  Future<void> resetPassword({required String newPassword}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<AuthUser?> currentUser() async => null;
}
