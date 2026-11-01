import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';

/// Cover for delivery zones as geography and as a pricing rule.
///
/// Before 068 `core.delivery_zones.polygon` existed in the schema and in
/// DATABASE_SPEC, and was written by nothing and read by nothing. Zone choice
/// was a free-text dropdown and the fee was one flat column, so a customer far
/// outside the area could be told they were served and charged the flat amount
/// regardless of how far the courier had to drive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('DeliveryFeeMethod', () {
    test('reads the stored value', () {
      expect(DeliveryFeeMethod.fromWire('fixed'), DeliveryFeeMethod.fixed);
      expect(DeliveryFeeMethod.fromWire('per_km'), DeliveryFeeMethod.perKm);
      expect(DeliveryFeeMethod.fromWire('free'), DeliveryFeeMethod.free);
    });

    test('an unknown method never becomes free', () {
      // Charging nothing by accident is the one failure a shop cannot detect
      // from its own books.
      expect(DeliveryFeeMethod.fromWire('nonsense'), DeliveryFeeMethod.fixed);
      expect(DeliveryFeeMethod.fromWire(null), DeliveryFeeMethod.fixed);
    });
  });

  group('geometry', () {
    test('a radius zone reports that it has geography', () {
      final zone = DeliveryZone.fromDatabase({
        'id': 'z1',
        'name_en': 'Olaya',
        'delivery_fee': 20,
        'center_latitude': 24.69,
        'center_longitude': 46.68,
        'radius_km': 8,
      });
      expect(zone.hasGeography, isTrue);
      expect(zone.radiusKm, 8);
      expect(zone.centerLatitude, closeTo(24.69, 0.000001));
    });

    test('a legacy zone with no geometry still reports none, not zero', () {
      final zone = DeliveryZone.fromDatabase({
        'id': 'z1',
        'name_en': 'Legacy',
        'delivery_fee': 20,
      });
      expect(zone.hasGeography, isFalse);
      expect(zone.radiusKm, isNull);
      expect(zone.centerLatitude, isNull);
    });

    test('a null coordinate stays null instead of becoming 0', () {
      // 0,0 is a real place in the Atlantic; reading it as "no geometry" or as
      // a centre off West Africa would both be wrong.
      final zone = DeliveryZone.fromDatabase({
        'id': 'z1',
        'name_en': 'Z',
        'delivery_fee': 20,
        'center_latitude': null,
        'radius_km': 5,
      });
      expect(zone.centerLatitude, isNull);
      expect(zone.centerLongitude, isNull);
    });
  });

  group('pricing', () {
    test('a per-km zone carries the distance the server priced it at', () {
      final zone = DeliveryZone.fromDatabase({
        'id': 'z1',
        'name_en': 'Far',
        'delivery_fee': 32.5,
        'fee_method': 'per_km',
        'fee_per_km': 2,
        'distance_km': 16.25,
        'free_delivery_over': 100,
      });
      expect(zone.feeMethod, DeliveryFeeMethod.perKm);
      expect(zone.feePerKm, 2);
      expect(zone.deliveryFee, 32.5);
      expect(zone.distanceKm, closeTo(16.25, 0.000001));
      expect(zone.hasFreeDeliveryThreshold, isTrue);
    });

    test('a free zone is priced at zero however it was returned', () {
      final zone = DeliveryZone.fromDatabase({
        'id': 'z1',
        'name_en': 'Free',
        'delivery_fee': 0,
        'fee_method': 'free',
      });
      expect(zone.feeMethod, DeliveryFeeMethod.free);
      expect(zone.deliveryFee, 0);
    });

    test('a max fee is carried for display even when not reached', () {
      final zone = DeliveryZone.fromDatabase({
        'id': 'z1',
        'name_en': 'Capped',
        'delivery_fee': 15,
        'fee_method': 'per_km',
        'max_delivery_fee': 40,
      });
      expect(zone.maxDeliveryFee, 40);
    });
  });

  group('fromDatabase', () {
    test('survives a row that is mostly missing', () {
      final zone = DeliveryZone.fromDatabase(const {});
      expect(zone.id, isEmpty);
      // An unnamed zone falls back to its id rather than rendering a blank row.
      expect(zone.name, isEmpty);
      expect(zone.deliveryFee, 0);
      expect(zone.minOrderAmount, 0);
      expect(zone.feeMethod, DeliveryFeeMethod.fixed);
    });

    test('a non-numeric estimated_minutes does not throw', () {
      final zone = DeliveryZone.fromDatabase({
        'id': 'z1',
        'delivery_fee': 20,
        'estimated_minutes': 'thirty',
      });
      expect(zone.estimatedMinutes, isNull);
    });
  });

  group('fee wording', () {
    test('each method has its own label', () {
      expect(deliveryFeeLabelFor(DeliveryFeeMethod.fixed), S.deliveryFlatFee);
      expect(deliveryFeeLabelFor(DeliveryFeeMethod.perKm), S.deliveryPerKm);
      expect(deliveryFeeLabelFor(DeliveryFeeMethod.free), S.deliveryAlwaysFree);
    });
  });

  group('Db helpers the zone reader relies on', () {
    test('asIntOrNull distinguishes "no limit" from "a limit of zero"', () {
      // usage_limit null means unlimited; a null here would read as "used up".
      expect(Db.asIntOrNull(null), isNull);
      expect(Db.asIntOrNull(0), 0);
      expect(Db.asIntOrNull('5'), 5);
    });

    test('asDoubleOrNull keeps a genuine zero', () {
      expect(Db.asDoubleOrNull(0), 0.0);
      expect(Db.asDoubleOrNull(null), isNull);
    });
  });
}

/// Mirrors the label mapping the checkout UI applies, without importing a
/// widget into a pure unit test.
String deliveryFeeLabelFor(DeliveryFeeMethod method) => switch (method) {
  DeliveryFeeMethod.free => S.deliveryAlwaysFree,
  DeliveryFeeMethod.perKm => S.deliveryPerKm,
  DeliveryFeeMethod.fixed => S.deliveryFlatFee,
};
