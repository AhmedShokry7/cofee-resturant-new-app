import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/pos/domain/entities/pos_json.dart';

/// Where a POS customer record lives.
enum PosCustomerSource {
  /// A registered app customer, backed by identity.profiles.
  registered,

  /// A counter customer created by staff, backed by orders.pos_customers.
  walkIn;

  static PosCustomerSource fromValue(Object? value) =>
      '$value'.trim().toLowerCase() == 'registered'
      ? PosCustomerSource.registered
      : PosCustomerSource.walkIn;
}

/// A customer the cashier can attach to a counter order.
class PosCustomer {
  const PosCustomer({
    required this.id,
    this.source = PosCustomerSource.walkIn,
    this.fullName = '',
    this.email,
    this.phone,
    this.avatarUrl,
    this.isVip = false,
    this.ordersCount = 0,
    this.lastOrderAt,
    this.reused = false,
  });

  final String id;
  final PosCustomerSource source;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final bool isVip;
  final int ordersCount;
  final DateTime? lastOrderAt;

  /// True when a create call matched an existing counter customer by phone.
  final bool reused;

  bool get isRegistered => source == PosCustomerSource.registered;

  String displayName(AppLanguage language) {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final email = this.email?.trim() ?? '';
    if (email.isNotEmpty) return email;
    final phone = this.phone?.trim() ?? '';
    if (phone.isNotEmpty) return phone;
    return id;
  }

  String? get contactLine {
    final phone = this.phone?.trim() ?? '';
    if (phone.isNotEmpty) return phone;
    final email = this.email?.trim() ?? '';
    return email.isEmpty ? null : email;
  }

  factory PosCustomer.fromJson(Map<String, dynamic> json) {
    return PosCustomer(
      id: posText(json['id']),
      source: PosCustomerSource.fromValue(json['source']),
      fullName: posText(json['full_name']),
      email: posTextOrNull(json['email']),
      phone: posTextOrNull(json['phone']),
      avatarUrl: posTextOrNull(json['avatar_url']),
      isVip: posFlag(json['is_vip']),
      ordersCount: posInteger(json['orders_count']),
      lastOrderAt: posDate(json['last_order_at']),
      reused: posFlag(json['reused']),
    );
  }
}
