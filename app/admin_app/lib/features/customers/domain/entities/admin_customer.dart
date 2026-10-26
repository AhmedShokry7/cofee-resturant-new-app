import 'package:admin_app/core/locale/app_locale.dart';

class AdminCustomer {
  const AdminCustomer({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.language = 'ar',
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
    this.lastOrderAt,
    this.ordersCount = 0,
    this.totalSpent = 0,
    this.isVip = false,
    this.isBlacklisted = false,
    this.adminNotes,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String language;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastOrderAt;
  final int ordersCount;
  final double totalSpent;
  final bool isVip;
  final bool isBlacklisted;
  final String? adminNotes;

  String displayName(AppLanguage language) {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }
    return id;
  }

  factory AdminCustomer.fromJson(Map<String, dynamic> json) {
    return AdminCustomer(
      id: '${json['id'] ?? ''}',
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      language: '${json['language'] ?? 'ar'}',
      lastSeenAt: _toDateTime(json['last_seen_at']),
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
      lastOrderAt: _toDateTime(json['last_order_at']),
      ordersCount: (json['orders_count'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      isVip: json['is_vip'] == true,
      isBlacklisted: json['is_blacklisted'] == true,
      adminNotes: json['admin_notes'] as String?,
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
