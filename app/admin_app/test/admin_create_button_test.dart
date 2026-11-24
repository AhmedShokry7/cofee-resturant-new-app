import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

void main() {
  testWidgets('renders a primary create action and invokes its callback', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: AdminCreateButton(
            label: 'Add item',
            onPressed: () => presses++,
          ),
        ),
      ),
    );

    expect(find.text('Add item'), findsOneWidget);
    final material = tester.widget<Material>(find.byType(Material).last);
    expect(material.color, AppColor.primaryColor);
    await tester.tap(find.text('Add item'));
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports busy and disabled states without invoking callback', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: Column(
            children: [
              AdminCreateButton(
                label: 'Creating',
                busy: true,
                onPressed: () => presses++,
              ),
              AdminCreateButton(label: 'Unavailable', onPressed: null),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Creating'));
    await tester.tap(find.text('Unavailable'));
    expect(presses, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon-only action exposes its tooltip', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: AdminCreateButton(
            iconOnly: true,
            tooltip: 'Add reservation',
            onPressed: () => presses++,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Add reservation'), findsOneWidget);
    await tester.tap(find.byTooltip('Add reservation'));
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });
}
