import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_coffee/main.dart';
import 'package:new_coffee/features/welcome/presentation/view/welcome_view.dart';

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('App boots to the saved entry route', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _setSurface(tester);

    // Fresh install -> welcome flow.
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox());
  });
}
