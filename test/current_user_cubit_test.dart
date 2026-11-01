import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/current_user/current_user_cubit.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user, this.error});

  AuthUser? user;
  final Object? error;

  @override
  Future<AuthUser?> currentUser() async {
    if (error != null) throw error!;
    return user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _GatedAuthRepository implements AuthRepository {
  _GatedAuthRepository(this.gate);

  final Completer<AuthUser?> gate;

  @override
  Future<AuthUser?> currentUser() => gate.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('CurrentUserCubit', () {
    test('the name is read from the session', () async {
      final cubit = CurrentUserCubit(
        repository: _FakeAuthRepository(
          user: const AuthUser(id: 'u1', name: '  Ahmed  '),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.name, 'Ahmed');
      expect(cubit.state.isLoading, isFalse);
    });

    test('an unreadable session leaves no name and no spinner', () async {
      final cubit = CurrentUserCubit(
        repository: _FakeAuthRepository(error: StateError('offline')),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.name, isEmpty);
      expect(cubit.state.isLoading, isFalse);
    });

    test(
      'a signed-out customer clears the name a previous read left',
      () async {
        final repository = _FakeAuthRepository(
          user: const AuthUser(id: 'u1', name: 'Ahmed'),
        );
        final cubit = CurrentUserCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.name, 'Ahmed');

        repository.user = null;
        await cubit.load();
        expect(cubit.state.user, isNull);
        expect(cubit.state.name, isEmpty);
      },
    );

    test('a read that lands after the tab closed is dropped', () async {
      final gate = Completer<AuthUser?>();
      final cubit = CurrentUserCubit(repository: _GatedAuthRepository(gate));
      final loading = cubit.load();

      await cubit.close();
      gate.complete(const AuthUser(id: 'u1', name: 'Ahmed'));
      await loading;

      expect(cubit.state.user, isNull);
    });
  });
}
