import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/shared/utils/rate_limit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-validated coupons.
///
/// Listing is public reference data. Applying always calls
/// `validate_coupon()`, which enforces windows, minimum spend, usage limits
/// and category scope. The UI never decides a discount from display text.
abstract class CouponRepository {
  Future<List<CouponModel>> activeCoupons();

  /// How many times the signed-in customer has used each coupon and how many
  /// are left, keyed by coupon id. Never throws: an anonymous customer, a
  /// missing backend or an older deployed database all yield an empty map,
  /// which simply means the list shows no per-customer usage.
  ///
  /// Read-only. Applying a coupon records nothing; a redemption is written only
  /// when an order completes.
  Future<Map<String, CouponUsage>> usageForCustomer() async => const {};

  /// What each scoped coupon is limited to, keyed by coupon code.
  ///
  /// Best-effort: a deployment without the bridge returns an empty map, and a
  /// coupon then simply shows no scope rather than failing the whole list.
  Future<Map<String, CouponScope>> scopeForCoupons(
    List<CouponModel> coupons,
  ) async => const {};

  /// Which cart lines [code] discounts, and by how much.
  ///
  /// Lets the cart explain a discount that looks too small rather than showing
  /// one figure against a large subtotal. An empty list means the server could
  /// not break it down, which is not an error: the total is still right.
  Future<List<CouponLineDiscount>> lineBreakdown({
    required String code,
    required String branchId,
    required double subtotal,
    required List<PlaceOrderLine> lines,
  }) async => const [];

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
    final coupons = [
      for (final row in rows)
        if (row is Map<String, dynamic>) CouponModel.fromDatabase(row),
    ];
    if (coupons.isEmpty) return coupons;

    // Merged here rather than in the page so every caller of the list — the
    // coupons page and the checkout summary — sees the same availability and the
    // same scope.
    final usage = await usageForCustomer();
    final scoped = await scopeForCoupons(coupons);
    return coupons
        .map((coupon) => _merge(coupon, usage[coupon.id], scoped[coupon.code]))
        .where((coupon) => !coupon.usedUpByCustomer)
        .toList(growable: false);
  }

  /// One model carrying everything the card needs, built only from what the
  /// server actually answered. Missing pieces stay at their defaults.
  static CouponModel _merge(
    CouponModel base,
    CouponUsage? usage,
    CouponScope? scope,
  ) {
    if (usage == null && scope == null) return base;
    return base.withUsage(
      CouponModel(
        id: base.id,
        code: base.code,
        usedCount: usage?.usedCount ?? 0,
        perUserLimit: usage?.perUserLimit,
        usageLimit: usage?.usageLimit,
        totalUsed: usage?.totalUsed ?? 0,
        appliesTo: scope?.appliesTo ?? base.appliesTo,
        scopeCategoryIds: scope?.categoryIds ?? const [],
        scopeProductIds: scope?.productIds ?? const [],
        scopeNamesAr: scope?.namesAr ?? const [],
        scopeNamesEn: scope?.namesEn ?? const [],
      ),
    );
  }

  @override
  Future<Map<String, CouponScope>> scopeForCoupons(
    List<CouponModel> coupons,
  ) async {
    final client = _client;
    if (client == null || coupons.isEmpty) return const {};
    final result = <String, CouponScope>{};
    try {
      final rows = await client.rpc(
        'coupon_scopes',
        params: {'p_codes': coupons.map((coupon) => coupon.code).toList()},
      );
      if (rows is List) {
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          if (row is Map<String, dynamic>) {
            grouped.putIfAbsent(Db.text(row['coupon_code']), () => []).add(row);
          }
        }
        for (final coupon in coupons) {
          final couponRows = grouped[coupon.code];
          if (couponRows == null) continue;
          final categoryIds = <String>[];
          final productIds = <String>[];
          final namesAr = <String>[];
          final namesEn = <String>[];
          var appliesTo = 'all';
          for (final row in couponRows) {
            appliesTo = Db.text(row['applies_to'], 'all');
            final id = Db.text(row['scope_id']);
            if (id.isEmpty) continue;
            if (Db.text(row['scope_kind']) == 'product') {
              productIds.add(id);
            } else {
              categoryIds.add(id);
            }
            final ar = Db.textOrNull(row['name_ar']);
            final en = Db.textOrNull(row['name_en']);
            if (ar != null) namesAr.add(ar);
            if (en != null) namesEn.add(en);
          }
          // An 'all' coupon has no rows; record it only when the coupon is
          // genuinely scoped, so an unscoped coupon keeps an empty label.
          if (categoryIds.isEmpty && productIds.isEmpty) continue;
          result[coupon.code] = CouponScope(
            appliesTo: appliesTo,
            categoryIds: categoryIds,
            productIds: productIds,
            namesAr: namesAr,
            namesEn: namesEn,
          );
        }
      }
    } catch (_) {
      // A missing bridge must not empty the whole coupon list.
    }
    return result;
  }

  @override
  Future<Map<String, CouponUsage>> usageForCustomer() async {
    final client = _client;
    // Anonymous or unconfigured: no personal usage to report. Not an error —
    // the list just shows no per-customer counters.
    if (client == null || client.auth.currentUser == null) return const {};

    try {
      final rows = await client.rpc('coupon_availability');
      if (rows is! List) return const {};
      return {
        for (final row in rows)
          if (row is Map<String, dynamic>)
            row['coupon_id'].toString(): CouponUsage(
              usedCount: Db.asInt(row['used_count']),
              perUserLimit: Db.asIntOrNull(row['per_user_limit']),
              usageLimit: Db.asIntOrNull(row['usage_limit']),
              totalUsed: Db.asInt(row['total_used']),
            ),
      };
    } catch (_) {
      // The function is newer than some deployments. Falling back to "no
      // counters" keeps the list working; only the explanation is missing.
      return const {};
    }
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
    final allowed = await RateLimitClient().check('coupon_validation');
    if (!allowed) {
      throw StateError(
        'Coupon validation rate limit exceeded. Try again later.',
      );
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
      // A scoped coupon refused to apply, and the whole point of the reason code
      // is to say *which* scope. One extra request, on the failure path only,
      // turns "does not apply to your items" into "this coupon is for espresso".
      final reason = row['reason_code']?.toString() ?? '';
      final scopeLabel = await _scopeLabelFor(normalized);
      throw CouponRejectedException(
        reasonCode: reason,
        scopeLabel: scopeLabel,
        // Older deployments return no reason_code, only the server's own text.
        legacyMessage: message,
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

  @override
  Future<List<CouponLineDiscount>> lineBreakdown({
    required String code,
    required String branchId,
    required double subtotal,
    required List<PlaceOrderLine> lines,
  }) async {
    final client = _client;
    final branch = branchId.trim();
    if (client == null || branch.isEmpty || lines.isEmpty) return const [];
    try {
      final rows = await client.rpc(
        'coupon_line_breakdown',
        params: <String, dynamic>{
          'p_branch_id': branch,
          'p_code': code.trim().toUpperCase(),
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
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map<String, dynamic>) CouponLineDiscount.fromDatabase(row),
      ];
    } catch (_) {
      // The total is already approved and correct; only the explanation is
      // missing, so this must never fail an apply.
      return const [];
    }
  }

  /// Names of the categories or products [code] is limited to, or '' when the
  /// coupon is unscoped or the bridge is unavailable.
  Future<String> _scopeLabelFor(String code) async {
    try {
      final scope = (await scopeForCoupons([
        CouponModel(id: '', code: code),
      ]))[code];
      if (scope == null) return '';
      final ar = scope.namesAr.where((n) => n.trim().isNotEmpty).toList();
      final en = scope.namesEn.where((n) => n.trim().isNotEmpty).toList();
      final preferred = AppLocale.instance.isArabic
          ? (ar.isNotEmpty ? ar : en)
          : (en.isNotEmpty ? en : ar);
      return preferred.join(AppLocale.instance.isArabic ? '، ' : ', ');
    } catch (_) {
      // The generic wording is still correct, just less helpful.
      return '';
    }
  }
}

/// A coupon the server refused, with the reason it refused it.
class CouponRejectedException implements Exception {
  const CouponRejectedException({
    this.reasonCode = '',
    this.scopeLabel = '',
    this.legacyMessage = '',
  });

  /// Ready to show. Never raw provider text.
  ///
  /// Read on demand rather than stored: the refusal lands in the checkout's
  /// state, and the customer may switch language before they look at it again.
  String get message => S.couponRejectedReason(
    reasonCode,
    scopeLabel,
    legacyMessage: legacyMessage,
  );

  /// The machine reason, kept for callers that want to react differently.
  final String reasonCode;

  /// What the coupon *would* have applied to. Empty when unscoped or unknown.
  final String scopeLabel;

  /// The server's own text, used only by deployments that return no reason code.
  final String legacyMessage;

  @override
  String toString() => message;
}

/// One coupon's usage counters for the signed-in customer.
class CouponUsage {
  const CouponUsage({
    this.usedCount = 0,
    this.perUserLimit,
    this.usageLimit,
    this.totalUsed = 0,
  });

  final int usedCount;
  final int? perUserLimit;
  final int? usageLimit;
  final int totalUsed;
}

/// The categories or products a coupon is limited to.
class CouponScope {
  const CouponScope({
    this.appliesTo = 'all',
    this.categoryIds = const [],
    this.productIds = const [],
    this.namesAr = const [],
    this.namesEn = const [],
  });

  final String appliesTo;
  final List<String> categoryIds;
  final List<String> productIds;
  final List<String> namesAr;
  final List<String> namesEn;
}
