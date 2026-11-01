import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/location/data/services/location_permission_service.dart';

/// The rule the home shell relies on when it fires the prompt without waiting:
/// asking for location may fail, or take as long as the device likes, and it
/// must be asked at most once per install.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a device that cannot answer still gets marked as asked', () async {
    // Geolocator has no platform implementation in a test, so the permission
    // request fails inside the service. The failure must not escape, and the
    // marker must still be written - otherwise the shell would ask again on
    // every launch of a broken device.
    expect(await LocationPermissionService.hasBeenPrompted(), isFalse);

    await LocationPermissionService.requestOnFirstLaunch();

    expect(await LocationPermissionService.hasBeenPrompted(), isTrue);
  });
}
