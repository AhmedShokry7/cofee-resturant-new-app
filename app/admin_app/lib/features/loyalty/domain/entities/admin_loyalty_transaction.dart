import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/loyalty/domain/entities/loyalty_json.dart';

class AdminLoyaltyTransaction {
  const AdminLoyaltyTransaction({
    required this.id,
    required this.userId,
    required this.points,
    required this.balanceAfter,
    required this.reason,
    this.customerName,
    this.customerEmail,
    this.avatarUrl,
    this.referenceType,
    this.referenceId,
    this.orderNumber,
    this.rewardProductNameAr,
    this.rewardProductNameEn,
    this.note,
    this.createdAt,
  });

  final String id;
  final String userId;
  final int points;
  final int balanceAfter;
  final String reason;
  final String? customerName;
  final String? customerEmail;

  /// رابط عرض موقّت للدلو الخاص، أو مسار لم يُقبل توقيعه. انظر AdminAvatarImage.
  final String? avatarUrl;
  final String? referenceType;
  final String? referenceId;
  final String? orderNumber;
  final String? rewardProductNameAr;
  final String? rewardProductNameEn;
  final String? note;
  final DateTime? createdAt;

  bool get isEarning => points > 0;
  bool get isRedemption => reason == 'redeem_reward';

  String displayName(AppLanguage language) {
    final name = customerName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final mail = customerEmail?.trim() ?? '';
    if (mail.isNotEmpty) return mail;
    return userId;
  }

  String? rewardProductNameFor(AppLanguage language) {
    final name = language.isArabic
        ? rewardProductNameAr?.trim()
        : rewardProductNameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic
        ? rewardProductNameEn?.trim()
        : rewardProductNameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  factory AdminLoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return AdminLoyaltyTransaction(
      id: '${json['id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      points: loyaltyInt(json['points']),
      balanceAfter: loyaltyInt(json['balance_after']),
      reason: '${json['reason'] ?? ''}',
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      orderNumber: json['order_number'] as String?,
      rewardProductNameAr: json['reward_product_name_ar'] as String?,
      rewardProductNameEn: json['reward_product_name_en'] as String?,
      note: json['note'] as String?,
      createdAt: loyaltyDate(json['created_at']),
    );
  }
}

class AdminLoyaltyTransactionFeed {
  const AdminLoyaltyTransactionFeed({
    this.rows = const <AdminLoyaltyTransaction>[],
    this.total = 0,
  });

  static const empty = AdminLoyaltyTransactionFeed();

  final List<AdminLoyaltyTransaction> rows;
  final int total;

  factory AdminLoyaltyTransactionFeed.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    return AdminLoyaltyTransactionFeed(
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => AdminLoyaltyTransaction.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminLoyaltyTransaction>[],
      total: loyaltyInt(json['total']),
    );
  }
}
