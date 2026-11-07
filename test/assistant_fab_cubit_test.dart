import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant_fab/assistant_fab_cubit.dart';

/// The entry point only needs a name and a session marker from the session, so
/// the fake answers those two questions and nothing else.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.name);

  final String? name;

  @override
  Future<AuthUser?> currentUser() async =>
      name == null ? null : AuthUser(id: 'u-1', name: name);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

AssistantFabCubit _cubit({String? name = 'Ahmed Shokry'}) =>
    AssistantFabCubit(auth: _FakeAuthRepository(name));

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  test('a device that never reached Home is a first visit', () async {
    final cubit = _cubit();
    await cubit.start();

    expect(cubit.state.isReturningUser, isFalse);
    await cubit.close();
  });

  test('a device that already reached Home is recognised as returning', () async {
    SharedPreferences.setMockInitialValues({
      AppConstant.routesKey: AppConstant.homeRoute,
    });

    final cubit = _cubit();
    await cubit.start();

    expect(cubit.state.isReturningUser, isTrue);
    await cubit.close();
  });

  test('the signed-in first name is carried into the chat', () async {
    final cubit = _cubit(name: 'Ahmed Shokry');
    await cubit.start();

    expect(cubit.state.firstName, 'Ahmed');
    await cubit.close();
  });

  test('a guest or a failing session still leaves a usable state', () async {
    final cubit = _cubit(name: null);
    await cubit.start();

    expect(cubit.state.firstName, isNull);
    expect(cubit.state.isReturningUser, isFalse);
    await cubit.close();
  });
}
