import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('a storage path never becomes a broken request', (tester) async {
    // `identity.profiles.avatar_url` holds a path inside the private avatars
    // bucket; the dashboard must show the placeholder instead of fetching it.
    await tester.pumpWidget(
      wrap(const AdminAvatarImage(url: 'a1b2-c3d4/avatar.jpg')),
    );

    expect(find.byIcon(AppIcons.user), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty or missing value shows the placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AdminAvatarImage()));
    expect(find.byIcon(AppIcons.user), findsOneWidget);

    await tester.pumpWidget(wrap(const AdminAvatarImage(url: '   ')));
    expect(find.byIcon(AppIcons.user), findsOneWidget);
  });

  testWidgets('the circle keeps the size the caller asked for', (tester) async {
    await tester.pumpWidget(wrap(const AdminAvatarImage(url: null, size: 32)));
    final size = tester.getSize(find.byType(AdminAvatarImage));
    expect(size.width, 32);
    expect(size.height, 32);
  });
}
