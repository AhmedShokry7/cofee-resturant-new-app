import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

/// Auth implementation used when the backend could not be reached at startup.
///
/// It never signs anybody in. The alternative — the old mock repository —
/// accepted any email and password, which in a store build would look like a
/// successful login while no account exists. Refusing every attempt is the
/// honest answer: the customer sees "the service is unavailable" instead of a
/// session that cannot place an order.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  static const String message = 'service_unavailable';

  Never _fail() => throw const AuthException(message);

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => _fail();

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async => _fail();

  @override
  Future<AuthUser> signInWithGoogle() async => _fail();

  @override
  Future<AuthUser> signInWithFacebook() async => _fail();

  @override
  Future<AuthUser> signInWithApple() async => _fail();

  @override
  Future<void> sendPhoneCode({required String phone}) async => _fail();

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) async => _fail();

  @override
  Future<void> sendPasswordResetEmail({required String email}) async => _fail();

  @override
  Future<void> resetPassword({required String newPassword}) async => _fail();

  @override
  Future<void> signOut() async {}

  /// Nobody is signed in while the backend is unreachable.
  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async => _fail();

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async => _fail();
}
