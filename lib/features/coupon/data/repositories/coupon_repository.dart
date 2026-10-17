import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-validated coupons.
///
/// Listing is public reference data. Applying always calls
/// `validate_coupon()`, which enforces windows, minimum spend, usage limits
/// and category scope. The UI never decides a discount from display text.
abstract class CouponRepository {
  Future<List<CouponModel>> activeCoupons();
  Future<ValidatedCoupon> validate({
    required String code,
    required double subtotal,
    String? branchId,
  });

  /// Validates against the exact server-priced cart snapshot in one request.
  /// The default keeps non-Supabase test and local implementations compatible.
  Future<ValidatedCoupon> validateForCart({
    required String code,
    required double subtotal,
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) => validate(code: code, subtotal: subtotal, branchId: branchId);
}

class CouponRepositoryImpl implements CouponRepository {
  const CouponRepositoryImpl({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  @override
  Future<List<CouponModel>> activeCoupons() async {
    final client = _client;
    if (client == null) {
      throw StateError('Coupons need a configured Supabase backend.');
    }

    final rows =
        await client
                .from('coupons')
                .select(
                  'id, code, title_ar, title_en, description_ar, description_en, '
                  'discount_type, discount_value, max_discount, min_order_amount, '
                  'is_active',
                )
                .eq('is_active', true)
                .order('min_order_amount')
                .limit(100)
            as List;
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) CouponModel.fromDatabase(row),
    ];
  }

  @override
  Future<ValidatedCoupon> validate({
    required String code,
    required double subtotal,
    String? branchId,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', 'must not be empty');
    }
    final client = _client;
    if (client == null) {
      throw StateError('Coupons need a configured Supabase backend.');
    }

    final rows = await client.rpc(
      'validate_coupon',
      params: {
        'p_code': normalized,
        'p_subtotal': subtotal,
        if (branchId != null && branchId.isNotEmpty) 'p_branch_id': branchId,
      },
    ) as List;
    return _parseValidation(
      client,
      normalized,
      rows,
      fallbackSubtotal: subtotal,
    );
  }

  @override
  Future<ValidatedCoupon> validateForCart({
    required String code,
    required double subtotal,
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', 'must not be empty');
    }
    final client = _client;
    if (client == null) {
      throw StateError('Coupons need a configured Supabase backend.');
    }
    final rows = await client.rpc(
      'validate_coupon_for_cart',
      params: <String, dynamic>{
        'p_branch_id': branchId,
        'p_code': normalized,
        'p_lines': [
          for (final line in lines)
            <String, dynamic>{
              'product_id': line.productId,
              'quantity': line.quantity,
              'note': line.note,
              'option_value_ids': line.optionValueIds,
              if (line.bundleId?.trim().isNotEmpty ?? false)
                'bundle_id': line.bundleId!.trim(),
            },
        ],
      },
    );
    return _parseValidation(client, normalized, rows);
  }

  Future<ValidatedCoupon> _parseValidation(
    SupabaseClient client,
    String normalized,
    dynamic rows, {
    double? fallbackSubtotal,
  }) async {
    if (rows is! List || rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw StateError('Coupon validation returned no answer.');
    }
    final row = rows.first as Map<String, dynamic>;
    final validatedSubtotal =
        (row['cart_subtotal'] as num?)?.toDouble() ?? fallbackSubtotal;
    final discount = (row['discount'] as num?)?.toDouble() ?? 0;
    final message = row['message']?.toString() ?? '';
    if (discount <= 0) {
      throw CouponRejectedException(
        message.isEmpty ? 'Invalid coupon' : message,
      );
    }
    final coupons = await activeCoupons();
    final coupon = coupons.firstWhere(
      (item) => item.code.toUpperCase() == normalized,
      orElse: () =>
          CouponModel(id: row['coupon_id']?.toString() ?? '', code: normalized),
    );
    return ValidatedCoupon(
      coupon: coupon,
      discount: discount,
      subtotal: validatedSubtotal ?? 0,
    );
  }
}

class CouponRejectedException implements Exception {
  const CouponRejectedException(this.message);

  final String message;

  @override
  String toString() => message;
}
