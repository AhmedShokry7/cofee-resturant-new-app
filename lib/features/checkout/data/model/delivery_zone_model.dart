import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// How a zone prices a delivery.
enum DeliveryFeeMethod {
  /// One price for the whole zone, whatever the distance.
  fixed('fixed'),

  /// `fee_per_km` times the distance from the branch to the address, capped by
  /// `maxDeliveryFee`.
  perKm('per_km'),

  /// Always zero.
  free('free');

  const DeliveryFeeMethod(this.wireValue);

  /// Value stored in `core.delivery_zones.fee_method`.
  final String wireValue;

  static DeliveryFeeMethod fromWire(String? value) {
    for (final method in values) {
      if (method.wireValue == value) return method;
    }
    // An unknown method must not become "free": charging nothing by accident is
    // the one failure a shop cannot detect from its own books.
    return DeliveryFeeMethod.fixed;
  }
}

/// A delivery zone the selected branch serves.
///
/// The zone may be geographic — a polygon or a radius around a centre — or
/// carry no geometry at all, in which case it covers the whole branch area.
/// That last case is the seeded legacy behaviour and is deliberately kept.
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.deliveryFee,
    this.minOrderAmount = 0,
    this.estimatedMinutes,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
    this.feeMethod = DeliveryFeeMethod.fixed,
    this.feePerKm,
    this.maxDeliveryFee,
    this.freeDeliveryOver,
    this.distanceKm,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  /// The zone's flat fee. Also the fallback for a per-km zone whose distance is
  /// unknown, so it is never null even when the rule is distance-based.
  final double deliveryFee;

  final double minOrderAmount;
  final int? estimatedMinutes;

  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;

  final DeliveryFeeMethod feeMethod;
  final double? feePerKm;
  final double? maxDeliveryFee;

  /// Subtotal at or above which this zone delivers free, whatever its method.
  final double? freeDeliveryOver;

  /// Distance from the branch to the address, when the zone was resolved from
  /// coordinates. Null for a zone chosen by hand.
  final double? distanceKm;

  String get name {
    final ar = nameAr.trim();
    final en = nameEn.trim();
    if (ar.isEmpty && en.isEmpty) return id;
    return pickText((ar: ar, en: en), isArabic: AppLocale.instance.isArabic);
  }

  /// True when this zone has real geography and can answer "do you serve
  /// here?". A zone without it is the legacy catch-all.
  bool get hasGeography =>
      radiusKm != null || (centerLatitude != null && centerLongitude != null);

  /// A zone delivered free once the order is big enough.
  bool get hasFreeDeliveryThreshold => freeDeliveryOver != null;

  factory DeliveryZone.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return DeliveryZone(
      id: Db.text(map['id']),
      nameAr: Db.text(map['name_ar']),
      nameEn: Db.text(map['name_en']),
      deliveryFee: Db.asDouble(map['delivery_fee']),
      minOrderAmount: Db.asDouble(map['min_order_amount']),
      // Db, not a raw cast: PostgREST can hand back a numeric column as a
      // string when it does not fit an int, and a raw `as num?` threw on that
      // instead of falling back.
      estimatedMinutes: Db.asIntOrNull(map['estimated_minutes']),
      centerLatitude: Db.asDoubleOrNull(map['center_latitude']),
      centerLongitude: Db.asDoubleOrNull(map['center_longitude']),
      radiusKm: Db.asDoubleOrNull(map['radius_km']),
      feeMethod: DeliveryFeeMethod.fromWire(map['fee_method']?.toString()),
      feePerKm: Db.asDoubleOrNull(map['fee_per_km']),
      maxDeliveryFee: Db.asDoubleOrNull(map['max_delivery_fee']),
      freeDeliveryOver: Db.asDoubleOrNull(map['free_delivery_over']),
      distanceKm: Db.asDoubleOrNull(map['distance_km']),
    );
  }

  DeliveryZone copyWith({double? distanceKm}) => DeliveryZone(
    id: id,
    nameAr: nameAr,
    nameEn: nameEn,
    deliveryFee: deliveryFee,
    minOrderAmount: minOrderAmount,
    estimatedMinutes: estimatedMinutes,
    centerLatitude: centerLatitude,
    centerLongitude: centerLongitude,
    radiusKm: radiusKm,
    feeMethod: feeMethod,
    feePerKm: feePerKm,
    maxDeliveryFee: maxDeliveryFee,
    freeDeliveryOver: freeDeliveryOver,
    distanceKm: distanceKm ?? this.distanceKm,
  );
}