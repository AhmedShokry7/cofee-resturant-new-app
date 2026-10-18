import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/cart/presentation/views/widgets/promo_code_field.dart';

/// Cover for the clear button on the promo-code field.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  Future<void> pumpField(
    WidgetTester tester, {
    required TextEditingController controller,
    VoidCallback? onApply,
    VoidCallback? onClear,
  }) async {
    tester.view.physicalSize = const Size(360, 800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PromoCodeField(
                controller: controller,
                onApply: onApply ?? () {},
                onClear: onClear,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the clear button is absent until something is typed', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpField(tester, controller: controller);

    expect(find.byIcon(HugeIcons.strokeRoundedCancel01), findsNothing);

    await tester.enterText(find.byType(TextField), 'WELCOME200');
    await tester.pump();

    expect(find.byIcon(HugeIcons.strokeRoundedCancel01), findsOneWidget);
  });

  testWidgets('pressing clear empties the field and reports it', (tester) async {
    final controller = TextEditingController(text: 'WELCOME200');
    addTearDown(controller.dispose);
    var cleared = false;
    await pumpField(
      tester,
      controller: controller,
      onClear: () => cleared = true,
    );

    await tester.tap(find.byIcon(HugeIcons.strokeRoundedCancel01));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(cleared, isTrue);
    // The button hides itself again, so the field matches its empty state.
    expect(find.byIcon(HugeIcons.strokeRoundedCancel01), findsNothing);
  });

  testWidgets('a pre-filled controller shows the button on first build', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'COFFEE20');
    addTearDown(controller.dispose);
    await pumpField(tester, controller: controller);

    expect(find.byIcon(HugeIcons.strokeRoundedCancel01), findsOneWidget);
  });

  testWidgets('the keyboard done key applies without clearing first', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'COFFEE20');
    addTearDown(controller.dispose);
    var applied = 0;
    await pumpField(tester, controller: controller, onApply: () => applied++);

    // The keyboard action only reaches a focused field.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(applied, 1);
    // Applying is not clearing: the caller owns that decision.
    expect(controller.text, 'COFFEE20');
  });
}