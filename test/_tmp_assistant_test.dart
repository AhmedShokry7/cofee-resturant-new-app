import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/main.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_hints.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_fab.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';

class FakeLlmClient implements LlmClient {
  FakeLlmClient({this.reply});
  final LlmReply? reply;
  int calls = 0;

  @override
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,
  }) async {
    calls++;
    return reply;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});

  final AuthUser? user;

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithFacebook() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithApple() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser?> currentUser() async => user;
}

Finder get _fabImage => find.byKey(const ValueKey('assistant_fab_image'));

Widget _wrapWithScreenUtil(Widget child) => ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    );

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('intent detection', () {
    expect(detectIntent('track my order please'), AssistantIntent.orderStatus);
    expect(detectIntent('do you have coupons?'), AssistantIntent.showCoupons);
    expect(detectIntent('hello there'), AssistantIntent.greeting);
  });

  test('first name helper', () {
    expect(firstNameOf(null), isNull);
    expect(firstNameOf('   '), isNull);
    expect(firstNameOf('Ahmed Ali'), 'Ahmed');
    expect(firstNameOf('  Sara  '), 'Sara');
  });

  test('engine answers + memory learning', () {
    final memory = AssistantMemory();
    final morning = DateTime(2026, 1, 1, 9);
    final sweet = AssistantEngine.answer(
      'something sweet please',
      memory: memory,
      now: morning,
    );
    expect(
      sweet.products.map((product) => product.name),
      contains('Mocha'),
    );
    expect(AssistantEngine.answer('do you have coupons?', memory: memory, now: morning).navigateRoute, 'couponRoute');
    expect(
      AssistantEngine.answer('zxqv blarg', memory: memory, now: morning).text,
      contains('did not catch'),
    );

    memory.recordFeedback('x', true);
    memory.recordFeedback('x', true);
    expect(memory.sourceBoost('x'), 1.2);
    memory.recordCategory('Tea', 2);
    expect(memory.topCategory(), 'Tea');
  });

  testWidgets('hybrid escalates only unknown queries', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeLlmClient(
      reply: const LlmReply(text: 'LLM says hi'),
    );
    const config = LlmConfig(backendUrl: 'https://llm.test');
    final cubit = AssistantCubit(llmClient: fake, llmConfig: config);
    await cubit.start();

    Future<void> sendAndSettle(String text) async {
      final pending = cubit.sendMessage(text);
      await tester.pump(const Duration(milliseconds: 600));
      await pending;
    }

    await sendAndSettle('hello there');
    expect(fake.calls, 0);

    await sendAndSettle('zxqv blarg unknown words here');
    final texts = cubit.state.messages.map((m) => m.text).toList();
    expect(fake.calls, 1);
    expect(texts.last, 'LLM says hi');
    await cubit.close();
  });

  testWidgets('hybrid keeps fallback when llm fails', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeLlmClient(reply: null);
    const config = LlmConfig(backendUrl: 'https://llm.test');
    final cubit = AssistantCubit(llmClient: fake, llmConfig: config);
    await cubit.start();
    final pending = cubit.sendMessage('zxqv blarg unknown words here');
    await tester.pump(const Duration(milliseconds: 600));
    await pending;
    expect(
      cubit.state.messages.last.text,
      contains('did not catch'),
    );
    expect(cubit.state.typing, isFalse);
    await cubit.close();
  });

  testWidgets('home header greeting without name uses day/night image',
      (tester) async {
    await _setSurface(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrapWithScreenUtil(const HomeHeader()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(getGreeting(DateTime.now())), findsOneWidget);
    final expectedAsset =
        isDaytime(DateTime.now()) ? AppImages.sun : AppImages.moon;
    expect(find.image(AssetImage(expectedAsset)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home header greeting shows first name when present',
      (tester) async {
    await _setSurface(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (context, _) => RepositoryProvider<AuthRepository>(
          create: (_) => FakeAuthRepository(
            user: const AuthUser(id: '1', name: 'Ahmed Ali'),
          ),
          child: const MaterialApp(home: Scaffold(body: HomeHeader())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('${getGreeting(DateTime.now())}, Ahmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant fab fixed, hints and chat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setSurface(tester);

    await tester.pumpWidget(const MyApp(currentRoute: '4'));
    await tester.pump();

    expect(find.byType(AssistantFab), findsOneWidget);
    expect(_fabImage, findsOneWidget);

    final pos = find.byKey(const ValueKey('assistant_fab_pos'));
    final position = tester.widget<Positioned>(pos);
    expect(position.right, isNotNull);
    expect(position.bottom, isNotNull);
    expect(position.left, isNull);
    expect(position.top, isNull);

    await tester.pump(AssistantFab.hintCycle);
    expect(find.text(assistantHints[1]), findsOneWidget);
    final hintText = tester.widget<Text>(
      find.descendant(
        of: find.byType(AnimatedOpacity),
        matching: find.text(assistantHints[1]),
      ),
    );
    expect(hintText.style?.decoration, TextDecoration.none);

    await tester.pump(AssistantFab.hintVisible);
    expect(find.text(assistantHints[1]), findsNothing);

    await tester.tap(_fabImage);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Coffee Assistant'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'suggest a drink for me');
    await tester.tap(find.byIcon(HugeIcons.strokeRoundedSent));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('top picks'), findsOneWidget);

    await tester.tap(find.byIcon(HugeIcons.strokeRoundedThumbsUp).first);
    await tester.pump();
    expect(find.byIcon(HugeIcons.strokeRoundedThumbsUp), findsWidgets);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Coffee Assistant'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
