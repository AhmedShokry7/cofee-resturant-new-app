class AdminDeliveryZone {
  const AdminDeliveryZone({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.deliveryFee,
    required this.minOrderAmount,
    this.estimatedMinutes,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
    required this.feeMethod,
    this.feePerKm,
    this.maxDeliveryFee,
    this.freeDeliveryOver,
    this.isActive = true,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final double deliveryFee;
  final double minOrderAmount;
  final int? estimatedMinutes;
  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;
  final String feeMethod;
  final double? feePerKm;
  final double? maxDeliveryFee;
  final double? freeDeliveryOver;
  final bool isActive;

  String nameFor(bool isArabic) => isArabic ? nameAr : nameEn;

  AdminDeliveryZone copyWith({String? id, bool? isActive}) => AdminDeliveryZone(
    id: id ?? this.id,
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
    isActive: isActive ?? this.isActive,
  );

  factory AdminDeliveryZone.fromJson(Map<String, dynamic> json) {
    return AdminDeliveryZone(
      id: '${json['id'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      centerLatitude: (json['center_latitude'] as num?)?.toDouble(),
      centerLongitude: (json['center_longitude'] as num?)?.toDouble(),
      radiusKm: (json['radius_km'] as num?)?.toDouble(),
      feeMethod: '${json['fee_method'] ?? 'flat'}',
      feePerKm: (json['fee_per_km'] as num?)?.toDouble(),
      maxDeliveryFee: (json['max_delivery_fee'] as num?)?.toDouble(),
      freeDeliveryOver: (json['free_delivery_over'] as num?)?.toDouble(),
      isActive: json['is_active'] != false,
    );
  }
}
