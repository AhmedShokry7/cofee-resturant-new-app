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
    this.isActive = true,
    this.opensAt,
    this.closesAt,
    this.imageUrl,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final bool isActive;

  /// Opening time in HH:mm:ss format, or null when unset.
  final String? opensAt;

  /// Closing time in HH:mm:ss format, or null when unset.
  final String? closesAt;

  /// URL of the branch picture, or null when none.
  final String? imageUrl;

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
      isActive: isActive ?? this.isActive,
      opensAt: clearOpensAt ? null : (opensAt ?? this.opensAt),
      closesAt: clearClosesAt ? null : (closesAt ?? this.closesAt),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
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
      isActive: row['is_active'] != false,
      opensAt: row['opens_at'] as String?,
      closesAt: row['closes_at'] as String?,
      imageUrl: row['image_url'] as String?,
    );
  }
}
