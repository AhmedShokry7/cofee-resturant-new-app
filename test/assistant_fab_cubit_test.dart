import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_hints.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant_fab/assistant_fab_cubit.dart';

/// The rotation is the behaviour under test, so the timers are made short;
/// the production durations live on `AssistantFab`.
AssistantFabCubit _cubit({
  Duration cycle = const Duration(milliseconds: 20),
  Duration visible = const Duration(milliseconds: 20),
}) {
  return AssistantFabCubit(
    hintCycle: cycle,
    hintVisible: visible,
    firstHintDelay: Duration.zero,
  );
}

/// A cubit that only has to answer the welcome question, so the rotation that
/// would otherwise replace it is parked far in the future.
AssistantFabCubit _oneShot() => _cubit(
  cycle: const Duration(minutes: 5),
  visible: const Duration(seconds: 30),
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  test('a first visit gets the welcome, not a hint', () async {
    final cubit = _oneShot();
    await cubit.start();

    expect(cubit.state.isReturningUser, isFalse);
    expect(cubit.state.welcomeText, contains('Welcome'));
    expect(cubit.bubbleText, cubit.state.welcomeText);

    await cubit.close();
  });

  test('a device that already reached Home is greeted as returning', () async {
    SharedPreferences.setMockInitialValues({
      AppConstant.routesKey: AppConstant.homeRoute,
    });

    final cubit = _oneShot();
    await cubit.start();

    expect(cubit.state.isReturningUser, isTrue);
    expect(cubit.state.welcomeText, contains('Welcome back'));

    await cubit.close();
  });

  test('the app language decides the bubble until a chat picks one', () async {
    final cubit = _oneShot();
    await cubit.start();
    expect(cubit.state.replyArabic, isFalse);
    await cubit.close();

    // Someone who already chatted in Arabic keeps Arabic bubbles even though
    // the app itself is showing English.
    SharedPreferences.setMockInitialValues({
      'assistant_memory_v1': jsonEncode({'totalChats': 2, 'replyArabic': true}),
    });
    final returning = _oneShot();
    await returning.start();

    expect(returning.state.replyArabic, isTrue);
    expect(returning.state.welcomeText, contains('أهلاً'));
    await returning.close();
  });

  test('the welcome gives way to a rotating hint', () async {
    final cubit = _cubit();
    await cubit.start();
    final welcome = cubit.state.welcomeText;

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(cubit.state.hasCycled, isTrue);
    expect(cubit.bubbleText, isNot(equals(welcome)));
    expect(assistantHints, contains(cubit.bubbleText));

    await cubit.close();
  });

  test('no bubble competes with the open chat sheet', () async {
    final cubit = _oneShot();
    await cubit.start();

    cubit.sheetOpened();
    cubit.showHint();
    expect(cubit.state.showHint, isFalse);

    cubit.sheetClosed();
    cubit.showHint();
    expect(cubit.state.showHint, isTrue);

    await cubit.close();
  });

  test('closing stops the rotation instead of leaving a live timer', () async {
    final cubit = _cubit();
    await cubit.start();
    final index = cubit.state.hintIndex;
    await cubit.close();

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(cubit.state.hintIndex, index);
  });
}
