import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';

/// Authentication that reconnects instead of giving up.
///
/// The repository used to be picked once, when the widget tree was built: if
/// Supabase had not started by then, every later attempt was refused with
/// "the service is unavailable" — for the rest of the session, even after the
/// network came back. A release build on a phone that woke up without a
/// connection was therefore permanently unable to sign in.
///
/// This implementation asks for a client before each call. When the backend
/// is reachable the request goes straight through; when it is not, the
/// connection is retried a few times and only then is the attempt refused.
class ResilientAuthRepository implements AuthRepository {
  ResilientAuthRepository({SupabaseAuthRepository? delegate})
    : _delegate = delegate ?? SupabaseAuthRepository();

  final SupabaseAuthRepository _delegate;

  /// Makes sure the backend is reachable, then returns the real repository.
  ///
  /// Throws [AuthException] with `service_unavailable` when the backend
  /// cannot be reached at all. The cubit turns that into one clear sentence
  /// instead of a raw provider error.
  Future<SupabaseAuthRepository> _ready() async {
    if (!SupabaseService.isReady) {
      final client = await SupabaseService.ensureReady();
      if (client == null) {
        throw const AuthException('service_unavailable');
      }
    }
    return _delegate;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final repository = await _ready();
    return repository.signIn(email: email, password: password);
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final repository = await _ready();
    return repository.signUp(name: name, email: email, password: password);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final repository = await _ready();
    return repository.signInWithGoogle();
  }

  @override
  Future<AuthUser> signInWithFacebook() async {
    final repository = await _ready();
    return repository.signInWithFacebook();
  }

  @override
  Future<AuthUser> signInWithApple() async {
    final repository = await _ready();
    return repository.signInWithApple();
  }

  @override
  Future<void> sendPhoneCode({required String phone}) async {
    final repository = await _ready();
    return repository.sendPhoneCode(phone: phone);
  }

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    final repository = await _ready();
    return repository.verifyPhoneCode(phone: phone, code: code);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final repository = await _ready();
    return repository.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> resetPassword({required String newPassword}) async {
    final repository = await _ready();
    return repository.resetPassword(newPassword: newPassword);
  }

  @override
  Future<void> signOut() async {
    // There is nothing to end when the backend was never reached.
    if (!SupabaseService.isReady) return;
    await _delegate.signOut();
  }

  @override
  Future<AuthUser?> currentUser() async {
    if (!SupabaseService.isReady) return null;
    return _delegate.currentUser();
  }

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final repository = await _ready();
    return repository.updateProfile(fullName: fullName, phone: phone);
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final repository = await _ready();
    return repository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }
}
