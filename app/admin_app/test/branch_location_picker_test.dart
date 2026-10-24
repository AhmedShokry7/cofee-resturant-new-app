import 'package:admin_app/features/branches/presentation/widgets/branch_location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('typing an address does not invent branch coordinates', (
    tester,
  ) async {
    LatLng? pickedPoint;
    String? typedAddress;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminLocationPicker(
            onPicked: (point, _) => pickedPoint = point,
            onAddressChanged: (value) => typedAddress = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'عنوان فرع جدة');

    expect(typedAddress, 'عنوان فرع جدة');
    expect(pickedPoint, isNull);
  });
}
