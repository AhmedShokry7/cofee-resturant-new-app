import 'package:admin_app/core/locale/app_locale.dart';

/// A branch of the brand.
class AdminBranch {
  const AdminBranch({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.legalName,
    this.vatNumber,
    this.isActive = true,
    this.opensAt,
    this.closesAt,
    this.imageUrl,
    this.staffCount = 0,
    this.zoneCount = 0,
    this.orders30d = 0,
    this.lastOrderAt,
    this.createdAt,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? phone;

  /// The seller identity printed on the ZATCA simplified tax invoice.
  final String? legalName;
  final String? vatNumber;
  final bool isActive;

  /// Opening time in HH:mm:ss format, or null when unset.
  final String? opensAt;

  /// Closing time in HH:mm:ss format, or null when unset.
  final String? closesAt;

  /// URL of the branch picture, or null when none.
  final String? imageUrl;

  /// Active staff members whose role is scoped to this branch.
  final int staffCount;

  /// Active delivery zones assigned to this branch.
  final int zoneCount;

  /// Orders placed at this branch in the last 30 days, excluding cancellations.
  final int orders30d;

  final DateTime? lastOrderAt;
  final DateTime? createdAt;

  bool get hasLocation => latitude != null && longitude != null;

  bool get needsSetup => !hasLocation || zoneCount == 0;

  String nameFor(AppLanguage language) {
    return language.isArabic ? nameAr : nameEn;
  }

  AdminBranch copyWith({
    String? id,
    String? code,
    String? nameAr,
    String? nameEn,
    String? address,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? phone,
    bool clearPhone = false,
    String? legalName,
    bool clearLegalName = false,
    String? vatNumber,
    bool clearVatNumber = false,
    bool? isActive,
    String? opensAt,
    bool clearOpensAt = false,
    String? closesAt,
    bool clearClosesAt = false,
    String? imageUrl,
    bool clearImageUrl = false,
  }) {
    return AdminBranch(
      id: id ?? this.id,
      code: code ?? this.code,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      address: address ?? this.address,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      phone: clearPhone ? null : (phone ?? this.phone),
      legalName: clearLegalName ? null : (legalName ?? this.legalName),
      vatNumber: clearVatNumber ? null : (vatNumber ?? this.vatNumber),
      isActive: isActive ?? this.isActive,
      opensAt: clearOpensAt ? null : (opensAt ?? this.opensAt),
      closesAt: clearClosesAt ? null : (closesAt ?? this.closesAt),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      staffCount: staffCount,
      zoneCount: zoneCount,
      orders30d: orders30d,
      lastOrderAt: lastOrderAt,
      createdAt: createdAt,
    );
  }

  factory AdminBranch.fromRow(Map<String, dynamic> row) {
    return AdminBranch(
      id: '${row['id'] ?? ''}',
      code: '${row['code'] ?? ''}',
      nameAr: '${row['name_ar'] ?? ''}',
      nameEn: '${row['name_en'] ?? ''}',
      address: '${row['address'] ?? ''}',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      phone: row['phone'] as String?,
      legalName: row['legal_name'] as String?,
      vatNumber: row['vat_number'] as String?,
      isActive: row['is_active'] != false,
      opensAt: row['opens_at'] as String?,
      closesAt: row['closes_at'] as String?,
      imageUrl: row['image_url'] as String?,
      staffCount: _count(row['staff_count']),
      zoneCount: _count(row['zone_count']),
      orders30d: _count(row['orders_30d']),
      lastOrderAt: _date(row['last_order_at']),
      createdAt: _date(row['created_at']),
    );
  }

  static int _count(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
