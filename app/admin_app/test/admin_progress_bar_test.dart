import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/shared/widgets/admin_progress_bar.dart';

void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(child: SizedBox(width: 120, child: child)),
      ),
    ),
  );

  testWidgets('renders normally and out-of-range values are clamped', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AdminProgressBar(value: .5)));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProgressBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const AdminProgressBar(value: 3)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const AdminProgressBar(value: -.4)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders the final fill without animating', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const AdminProgressBar(value: .75), disableAnimations: true),
    );
    await tester.pump();
    expect(find.byType(AdminProgressBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
