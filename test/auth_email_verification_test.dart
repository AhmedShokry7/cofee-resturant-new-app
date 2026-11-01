import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/resilient_auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/sign_up_page_body.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A backend that answers whether the address it just signed up still has to
/// confirm its email.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.needsEmailConfirmation});

  final bool needsEmailConfirmation;

  @override
  bool get lastSignUpNeedsEmailConfirmation => needsEmailConfirmation;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async => const AuthUser(id: 'u-1', name: 'Ahmed', email: 'a@b.com');

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

/// The real repository with only the confirmation answer swapped, so no
/// network is involved.
class _FakeSupabaseAuthRepository extends SupabaseAuthRepository {
  _FakeSupabaseAuthRepository({required this.needsEmailConfirmation});

  final bool needsEmailConfirmation;

  @override
  bool get lastSignUpNeedsEmailConfirmation => needsEmailConfirmation;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('email confirmation after sign-up', () {
    Future<void> signUp(WidgetTester tester, {required bool needs}) async {
      final repository = _FakeAuthRepository(needsEmailConfirmation: needs);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => RepositoryProvider<AuthRepository>(
            create: (_) => repository,
            child: BlocProvider(
              create: (_) => AuthCubit(repository),
              child: const MaterialApp(home: Scaffold(body: SignUpPageBody())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ahmed');
      await tester.enterText(fields.at(1), 'a@b.com');
      await tester.enterText(fields.at(2), 'secret');
      await tester.enterText(fields.at(3), 'secret');
      await tester.tap(find.byType(CustomBtn));
      await tester.pumpAndSettle();
    }

    testWidgets('asks the repository, so an unconfirmed customer is not '
        'dropped into the app', (tester) async {
      await signUp(tester, needs: true);

      expect(find.text(S.signUpEmailVerification), findsOneWidget);
      expect(find.byType(SignUpPageBody), findsOneWidget);
    });

    testWidgets('a confirmed address gets no verification dialog', (
      tester,
    ) async {
      await signUp(tester, needs: false);

      expect(find.text(S.signUpEmailVerification), findsNothing);
    });

    test('the offline-safe decorator forwards the answer', () {
      for (final needs in [true, false]) {
        final repository = ResilientAuthRepository(
          delegate: _FakeSupabaseAuthRepository(needsEmailConfirmation: needs),
        );
        expect(
          repository.lastSignUpNeedsEmailConfirmation,
          needs,
          reason: 'a decorator in front of the real repository must not turn '
              'the question into its own answer',
        );
      }
    });
  });
}
