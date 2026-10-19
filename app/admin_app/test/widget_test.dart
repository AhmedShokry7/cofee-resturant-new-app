import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/main.dart';

void main() {
  testWidgets('admin app boots to the startup page', (tester) async {
    await tester.pumpWidget(const AdminApp());
    await tester.pump();

    expect(find.text('Admin'), findsOneWidget);
  });
}
