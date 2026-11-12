import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';

import 'support/in_memory_profile_photo_repository.dart';

import 'package:new_coffee/features/profile/presentation/views/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  bool get lastSignUpNeedsEmailConfirmation => false;

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithFacebook() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithApple() => throw UnimplementedError();

  @override
  Future<void> sendPhoneCode({required String phone}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<void> sendEmailCode({required String email}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({required String fullName, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) => throw UnimplementedError();
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 1200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _settingsApp({Widget? child}) {
  return MaterialApp(
    // Mirrors main.dart: the whole app listens to AppLocale so a language
    // selection rebuilds every screen.
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  testWidgets('settings shows the Language and My Addresses entries', (
    tester,
  ) async {
    await _setSurface(tester);
    await tester.pumpWidget(
      _settingsApp(
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  ProfileCubit(repository: InMemoryProfilePhotoRepository()),
            ),
          ],
          child: RepositoryProvider<AuthRepository>(
            create: (_) => _FakeAuthRepository(),
            child: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(S.language), findsOneWidget);
    expect(find.text(S.myAddresses), findsOneWidget);
    // The tile shows the currently selected language.
    expect(find.text(S.languageValue(true)), findsOneWidget);
  });

  testWidgets('selecting English in the dialog updates locale and persists', (
    tester,
  ) async {
    await _setSurface(tester);
    await tester.pumpWidget(
      _settingsApp(
        child: AnimatedBuilder(
          animation: AppLocale.instance,
          builder: (context, _) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    ProfileCubit(repository: InMemoryProfilePhotoRepository()),
              ),
            ],
            child: RepositoryProvider<AuthRepository>(
              create: (_) => _FakeAuthRepository(),
              // Not const: a const instance is canonicalized, so Flutter would
              // skip rebuilding the page when AppLocale notifies. main.dart
              // recreates MaterialApp (new locale) which forces the rebuild;
              // the test mirrors that with a fresh instance.
              child: SettingsPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.language));
    await tester.pumpAndSettle();

    // The tile's own subtitle now shows the current language too, and in the
    // Arabic UI that value is the same word as the dialog's first option, so
    // the options are asserted inside the dialog rather than across the tree.
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text(S.arabicLanguage)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(S.englishLanguage)),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: dialog, matching: find.text(S.englishLanguage)),
    );
    await tester.pumpAndSettle();

    expect(AppLocale.instance.language, AppLanguage.english);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_language'), 'en');

    // The tile behind the dialog now shows the new current language.
    expect(find.text(S.languageValue(false)), findsOneWidget);
    expect(find.text(S.language), findsOneWidget);
  });

  testWidgets('the Language entry sits directly below Notifications', (
    tester,
  ) async {
    await _setSurface(tester);
    await tester.pumpWidget(
      _settingsApp(
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  ProfileCubit(repository: InMemoryProfilePhotoRepository()),
            ),
          ],
          child: RepositoryProvider<AuthRepository>(
            create: (_) => _FakeAuthRepository(),
            child: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The settings tile shows the preferences wording, not the page title.
    final notificationsY = tester
        .getTopLeft(find.text(S.notificationPreferences))
        .dy;
    final languageY = tester.getTopLeft(find.text(S.language)).dy;
    final helpY = tester.getTopLeft(find.text(S.help)).dy;

    expect(languageY, greaterThan(notificationsY));
    expect(helpY, greaterThan(languageY));
  });

  test('the Website feature is gone from Settings and the routes', () {
    expect(AppRoutes.routes.keys, isNot(contains('websiteRoute')));
  });
}
