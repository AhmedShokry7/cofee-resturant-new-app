// The edit-profile screen: what it reads, what it saves, and what it says when
// either fails.
//
// The form used to fill itself from `AuthRepository.currentUser()` inside
// `initState`, swallow that read, and pop the route before asking for the
// messenger that shows the confirmation. The cubit owns the read and the two
// writes now, so these tests pin the failure states that replace the silence.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/profile/presentation/manager/account_details/account_details_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';

/// The account the tests hand back, in the shape the server stores it.
const AuthUser _ahmed = AuthUser(
  id: 'u1',
  name: 'Ahmed Shokry',
  email: 'ahmed@example.com',
  phone: '+966500000000',
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user = _ahmed});

  AuthUser? user;

  /// Makes `currentUser()` fail, standing in for a session that cannot be read.
  bool failRead = false;
  bool failSave = false;
  bool failPasswordChange = false;

  /// Held open to keep the save in flight, the way a slow server would.
  Completer<void>? saveGate;

  /// The last name and phone the screen sent for saving.
  String? savedFullName;
  String? savedPhone;
  int updateCalls = 0;

  @override
  Future<AuthUser?> currentUser() async {
    if (failRead) throw StateError('session unavailable');
    return user;
  }

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    updateCalls++;
    if (failSave) throw StateError('update rejected');
    await saveGate?.future;
    savedFullName = fullName;
    savedPhone = phone;
    final updated = AuthUser(
      id: user?.id ?? 'u1',
      name: fullName,
      email: user?.email,
      phone: phone,
    );
    user = updated;
    return updated;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (failPasswordChange) throw StateError('password rejected');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The cubit on its own, with no widget around the read.
AccountDetailsCubit _cubit(AuthRepository repository) {
  final cubit = AccountDetailsCubit(repository: repository);
  addTearDown(cubit.close);
  return cubit;
}

Future<_FakeAuthRepository> _openEditor(
  WidgetTester tester,
  _FakeAuthRepository repository,
) async {
  await tester.pumpWidget(_harness(repository));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repository;
}

Widget _harness(AuthRepository repository) {
  return RepositoryProvider<AuthRepository>.value(
    value: repository,
    child: MaterialApp(
      routes: {EditProfilePage.routeName: (_) => const EditProfilePage()},
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(EditProfilePage.routeName),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// The four inputs of the form, in the order the screen lays them out.
Finder _field(int index) => find.byType(TextFormField).at(index);

/// The text editor inside one of those inputs. `readOnly` and the current
/// value both live there, not on the form field.
Finder _editor(int index) => find
    .descendant(of: _field(index), matching: find.byType(EditableText))
    .first;

void main() {
  setUp(() => SupabaseService.debugSetSignedIn(true));
  tearDown(() => SupabaseService.debugSetSignedIn(false));

  group('the account read', () {
    test('one stored name becomes the two fields the form shows', () async {
      final cubit = _cubit(_FakeAuthRepository());
      await cubit.load();

      expect(cubit.state.firstName, 'Ahmed');
      expect(cubit.state.lastName, 'Shokry');
      expect(cubit.state.email, 'ahmed@example.com');
      expect(cubit.state.phone, '+966500000000');
    });

    test('a name with no family part leaves the second field empty', () async {
      final cubit = _cubit(
        _FakeAuthRepository(
          user: const AuthUser(id: 'u1', name: '  Ahmed '),
        ),
      );
      await cubit.load();

      expect(cubit.state.firstName, 'Ahmed');
      expect(cubit.state.lastName, isEmpty);
    });

    test('a read that fails is a failure, not an empty account', () async {
      final cubit = _cubit(_FakeAuthRepository()..failRead = true);
      await cubit.load();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.error, S.couldNotLoadAccountDetails);
    });

    test('a refused change password says it was refused', () async {
      final cubit = _cubit(_FakeAuthRepository()..failPasswordChange = true);

      final changed = await cubit.changePassword(
        oldPassword: 'old',
        newPassword: 'new',
      );

      expect(changed, isFalse);
      expect(cubit.state.error, S.passwordChangeFailed);
      expect(cubit.state.isChangingPassword, isFalse);
    });
  });

  group('the form', () {
    testWidgets('a failed read offers a retry instead of blank fields', (
      tester,
    ) async {
      final repository = _FakeAuthRepository()..failRead = true;
      await _openEditor(tester, repository);

      expect(find.text(S.couldNotLoadAccountDetails), findsOneWidget);
      // The failure owns the screen: no form behind it, and the same message
      // does not also arrive as a snackbar over the top.
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text(S.save), findsNothing);

      repository.failRead = false;
      await tester.tap(find.text(S.retry));
      await tester.pumpAndSettle();

      expect(find.text(S.save), findsOneWidget);
      expect(tester.widget<EditableText>(_editor(0)).controller.text, 'Ahmed');
    });

    testWidgets('the email is shown to be read, not edited', (tester) async {
      await _openEditor(tester, _FakeAuthRepository());

      // Index 2 is the email input of the four the form lays out in order.
      expect(tester.widget<EditableText>(_editor(2)).readOnly, isTrue);
      expect(
        tester.widget<EditableText>(_editor(2)).controller.text,
        'ahmed@example.com',
      );
      expect(find.text(S.emailNotEditableHere), findsOneWidget);
    });

    testWidgets('saving sends the name as the account stores it', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await _openEditor(tester, repository);

      await tester.enterText(_field(0), 'Ahmed');
      await tester.enterText(_field(1), 'Shokry');
      await tester.enterText(_field(3), '+966511111111');
      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();

      expect(repository.savedFullName, 'Ahmed Shokry');
      expect(repository.savedPhone, '+966511111111');
    });

    testWidgets('a saved account leaves the screen once and says so', (
      tester,
    ) async {
      await _openEditor(tester, _FakeAuthRepository());

      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();

      // The confirmation is still up after the route went away: the messenger
      // was taken before the pop, so the message reaches the screen the
      // customer is now looking at.
      expect(find.text('open'), findsOneWidget);
      expect(find.text(S.profileUpdated), findsOneWidget);
    });

    testWidgets('a refused save keeps the customer on the form', (
      tester,
    ) async {
      final repository = _FakeAuthRepository()..failSave = true;
      await _openEditor(tester, repository);

      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();

      expect(find.text(S.save), findsOneWidget);
      expect(find.text(S.profileUpdateFailed), findsOneWidget);
      expect(find.text('open'), findsNothing);
    });

    testWidgets('an empty first name is refused before anything is sent', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await _openEditor(tester, repository);

      await tester.enterText(_field(0), '');
      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, isZero);
      expect(find.text(S.nameRequired), findsOneWidget);
    });

    testWidgets(
      'the save waits for the server instead of taking a second tap',
      (tester) async {
        final repository = _FakeAuthRepository()..saveGate = Completer<void>();
        await _openEditor(tester, repository);

        await tester.tap(find.text(S.save));
        await tester.pump();

        // The button is spinning, which detaches its callback: a second tap
        // cannot put a second write on the way.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        repository.saveGate!.complete();
        await tester.pumpAndSettle();

        expect(repository.updateCalls, 1);
        expect(find.text('open'), findsOneWidget);
      },
    );
  });
}
