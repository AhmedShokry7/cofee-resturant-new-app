import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// The card of the first skeleton row on screen.
BoxDecoration _firstCard(WidgetTester tester) {
  final container = tester.widget<Container>(find.byType(Container).first);
  return container.decoration! as BoxDecoration;
}

Future<void> _pump(WidgetTester tester, Brightness brightness) async {
  tester.view.physicalSize = const Size(360, 900) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(body: OrdersSkeleton()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('skeleton surfaces', () {
    testWidgets('a loading card is white while the app is light', (
      tester,
    ) async {
      await _pump(tester, Brightness.light);
      expect(_firstCard(tester).color, AppColor.whiteColor);
      expect(_firstCard(tester).border!.top.color, AppColor.borderColor);
    });

    testWidgets('a loading card does not stay white once the theme is dark', (
      tester,
    ) async {
      await _pump(tester, Brightness.dark);
      expect(_firstCard(tester).color, AppColor.darkCard);
      expect(_firstCard(tester).border!.top.color, AppColor.darkBorder);
    });
  });
}
