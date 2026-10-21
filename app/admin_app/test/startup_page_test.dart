import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/startup/presentation/views/startup_page.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(360, 690),
  builder: (context, _) => MaterialApp(home: child),
);

void main() {
  testWidgets('startup page renders the admin title', (tester) async {
    await tester.pumpWidget(_wrap(const StartupPage()));
    await tester.pump();

    expect(find.text('Admin'), findsOneWidget);
  });
}
