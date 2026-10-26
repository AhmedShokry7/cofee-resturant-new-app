import 'package:admin_app/features/coupons/data/models/coupon_json.dart';

class AdminCouponMetrics {
  const AdminCouponMetrics({
    this.active = 0,
    this.expiringSoon = 0,
    this.scheduled = 0,
    this.paused = 0,
    this.expired = 0,
    this.exhausted = 0,
    this.total = 0,
    this.redemptions = 0,
    this.uniqueCustomers = 0,
    this.discountGiven = 0,
  });

  final int active;
  final int expiringSoon;
  final int scheduled;
  final int paused;
  final int expired;
  final int exhausted;
  final int total;
  final int redemptions;
  final int uniqueCustomers;
  final double discountGiven;

  static const empty = AdminCouponMetrics();

  factory AdminCouponMetrics.fromJson(Map<String, dynamic> json) =>
      AdminCouponMetrics(
        active: couponInt(json['active']),
        expiringSoon: couponInt(json['expiring_soon']),
        scheduled: couponInt(json['scheduled']),
        paused: couponInt(json['paused']),
        expired: couponInt(json['expired']),
        exhausted: couponInt(json['exhausted']),
        total: couponInt(json['total']),
        redemptions: couponInt(json['redemptions']),
        uniqueCustomers: couponInt(json['unique_customers']),
        discountGiven: couponDouble(json['discount_given']),
      );
}
