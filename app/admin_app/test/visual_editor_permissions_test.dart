import 'package:admin_app/features/shell/presentation/models/destinations/content_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visual editor entry uses design edit permission', () {
    final destination = contentDestinations.singleWhere(
      (item) => item.id == 'visualEditor',
    );
    expect(destination.permission, 'design.edit');
    expect(destination.requiredPermissions, isEmpty);
  });
}
