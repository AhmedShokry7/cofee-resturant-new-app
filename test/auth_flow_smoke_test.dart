import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  bool get lastSignUpNeedsEmailConfirmation => false;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => throw const AuthException('invalid login credentials');
  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async => throw UnimplementedError();
  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<AuthUser> signInWithFacebook() => throw UnimplementedError();
  @override
  Future<AuthUser> signInWithApple() => throw UnimplementedError();
  @override
  Future<void> sendPhoneCode({required String phone}) async {}
  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) async => throw UnimplementedError();
  @override
  Future<void> sendEmailCode({required String email}) async {}
  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async => throw UnimplementedError();
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
  @override
  Future<void> resetPassword({required String newPassword}) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<AuthUser?> currentUser() async => null;
  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async => throw UnimplementedError();
  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('login failure shows centered dialog', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>(
        create: (_) => _FakeAuthRepository(),
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.byType(CustomBtn));
    await tester.pumpAndSettle();

    expect(
      find.text('Wrong email or password. Please check and try again.'),
      findsOneWidget,
    );
  });
}
