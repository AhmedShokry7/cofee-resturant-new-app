import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/shared/widgets/admin_help_button.dart';

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('opens localized, dismissible help content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: const Scaffold(
          body: AdminHelpButton(
            title: 'Points per SAR',
            message: 'Whole points are rounded down.',
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.tooltip, S.adminHelpTooltip);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Points per SAR'), findsOneWidget);
    expect(find.text('Whole points are rounded down.'), findsOneWidget);
    expect(find.text(S.close), findsOneWidget);
    await tester.tap(find.text(S.close));
    await tester.pumpAndSettle();
    expect(find.text('Whole points are rounded down.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the Arabic help tooltip and dialog action', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: const Scaffold(
          body: AdminHelpButton(title: 'معدل النقاط', message: 'معلومة مفيدة'),
        ),
      ),
    );

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).tooltip,
      'مساعدة',
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('معلومة مفيدة'), findsOneWidget);
    expect(find.text('إغلاق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
