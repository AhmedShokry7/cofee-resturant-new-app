import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/main.dart';

void main() {
  testWidgets('admin app boots to the staff sign in page when unauthenticated',
      (tester) async {
    await tester.pumpWidget(const AdminApp());
    await tester.pumpAndSettle();

    expect(find.text('Staff sign in'), findsOneWidget);
  });
}
