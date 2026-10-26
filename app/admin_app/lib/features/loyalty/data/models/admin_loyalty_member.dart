import 'package:admin_app/features/loyalty/data/models/loyalty_json.dart';

class AdminLoyaltyMember {
  const AdminLoyaltyMember({
    required this.userId,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.pointsBalance = 0,
    this.lifetimePoints = 0,
    this.tier = 'bronze',
    this.redemptionsCount = 0,
    this.lastActivityAt,
    this.updatedAt,
  });

  final String userId;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final int pointsBalance;
  final int lifetimePoints;
  final String tier;
  final int redemptionsCount;
  final DateTime? lastActivityAt;
  final DateTime? updatedAt;

  bool get hasPoints => pointsBalance > 0;

  String get displayName {
    final name = fullName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final mail = email?.trim() ?? '';
    if (mail.isNotEmpty) return mail;
    return userId;
  }

  String? get contactLine {
    final name = displayName;
    final mail = email?.trim() ?? '';
    if (mail.isNotEmpty && mail != name) return mail;
    final number = phone?.trim() ?? '';
    if (number.isNotEmpty && number != name) return number;
    return null;
  }

  factory AdminLoyaltyMember.fromJson(Map<String, dynamic> json) {
    return AdminLoyaltyMember(
      userId: '${json['user_id'] ?? ''}',
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      pointsBalance: loyaltyInt(json['points_balance']),
      lifetimePoints: loyaltyInt(json['lifetime_points']),
      tier: '${json['tier'] ?? 'bronze'}',
      redemptionsCount: loyaltyInt(json['redemptions_count']),
      lastActivityAt: loyaltyDate(json['last_activity_at']),
      updatedAt: loyaltyDate(json['updated_at']),
    );
  }
}
