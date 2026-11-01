import 'package:flutter/foundation.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

@immutable
class CouponsState {
  const CouponsState({
    this.isLoading = true,
    this.coupons = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<CouponModel> coupons;

  /// Why the list could not be read, in the customer's language.
  final String? errorMessage;

  CouponsState copyWith({
    bool? isLoading,
    List<CouponModel>? coupons,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CouponsState(
      isLoading: isLoading ?? this.isLoading,
      coupons: coupons ?? this.coupons,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
