import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('error dialog renders and dismisses', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AuthMessageDialog.show(
              context,
              type: AuthMessageType.error,
              message: 'boom',
              title: 'Oops',
            ),
            child: const Text('show'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    expect(find.text('Oops'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    expect(find.text(S.ok), findsOneWidget);

    await tester.tap(find.text(S.ok));
    await tester.pumpAndSettle();

    expect(find.text('boom'), findsNothing);
  });

  testWidgets('success and info render', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () => AuthMessageDialog.show(
                  context,
                  type: AuthMessageType.success,
                  message: 'done',
                ),
                child: const Text('s'),
              ),
              ElevatedButton(
                onPressed: () => AuthMessageDialog.show(
                  context,
                  type: AuthMessageType.info,
                  message: 'info',
                ),
                child: const Text('i'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('s'));
    await tester.pumpAndSettle();
    expect(find.text('done'), findsOneWidget);
    await tester.tap(find.text(S.ok));
    await tester.pumpAndSettle();

    await tester.tap(find.text('i'));
    await tester.pumpAndSettle();
    expect(find.text('info'), findsOneWidget);
  });

  testWidgets('arabic rtl renders without overflow', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AuthMessageDialog.show(
              context,
              type: AuthMessageType.error,
              message: 'رسالة خطأ طويلة جداً ' * 3,
            ),
            child: const Text('show'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
