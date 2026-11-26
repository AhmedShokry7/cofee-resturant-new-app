import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Operations registered for an assistant tool router. A preview is stored on
/// the server against the current user and expires after five minutes; confirm
/// accepts only the opaque id held by this service, never a model-made payload.
class AdminAssistantCatalogActionService {
  AdminAssistantCatalogActionService({
    required this.client,
    required this.session,
  });

  final SupabaseClient client;
  final AdminSession? session;
  String? _pendingPreviewId;

  Future<AdminAssistantActionPreview> prepareProductSave(
    AdminProduct proposed, {
    AdminProduct? current,
    String? branchId,
    int? approvedStockQuantity,
  }) async {
    _requirePermission('catalog.product.write');
    if (current == null && !proposed.isDraft) {
      throw const AdminAssistantActionException('product_current_required');
    }
    if (current != null && current.id != proposed.id) {
      throw const AdminAssistantActionException('product_identity_mismatch');
    }
    if (current != null &&
        _productDiff(
          current,
          proposed,
          stockQuantity: approvedStockQuantity,
        ).isEmpty) {
      throw const AdminAssistantActionException('no_product_changes');
    }
    if (approvedStockQuantity != null) {
      _requirePermission('inventory.adjust');
      if ((branchId ?? '').isEmpty) {
        throw const AdminAssistantActionException('stock_branch_required');
      }
    }
    final payload = _productPayload(
      proposed,
      stockQuantity: approvedStockQuantity,
    );
    final response = await _prepare(
      'admin_assistant_prepare_product',
      {
        'p_product_id': current?.id,
        'p_payload': payload,
        'p_branch_id': branchId,
      },
      actionType: 'catalog.product.save',
      title: current == null
          ? _ar
                ? 'إضافة منتج'
                : 'Create product'
          : _ar
          ? 'تعديل منتج'
          : 'Update product',
      details: _productDiff(
        current,
        proposed,
        stockQuantity: approvedStockQuantity,
      ),
    );
    return response;
  }

  Future<AdminAssistantActionPreview> prepareCategorySave(
    AdminCategory proposed, {
    AdminCategory? current,
  }) async {
    _requirePermission('catalog.category.write');
    if (current != null && current.id != proposed.id) {
      throw const AdminAssistantActionException('category_identity_mismatch');
    }
    if (current != null && _categoryDiff(current, proposed).isEmpty) {
      throw const AdminAssistantActionException('no_category_changes');
    }
    final payload = <String, Object?>{
      'name_ar': proposed.nameAr,
      'name_en': proposed.nameEn,
      'description_ar': proposed.descriptionAr,
      'description_en': proposed.descriptionEn,
    };
    return _prepare(
      'admin_assistant_prepare_category',
      {'p_category_id': current?.id, 'p_payload': payload},
      actionType: 'catalog.category.save',
      title: current == null
          ? _ar
                ? 'إضافة تصنيف'
                : 'Create category'
          : _ar
          ? 'تعديل تصنيف'
          : 'Update category',
      details: _categoryDiff(current, proposed),
    );
  }

  Future<AdminAssistantActionPreview> prepareCouponSave(
    AdminCouponDraft proposed, {
    AdminCoupon? current,
  }) async {
    _requirePermission('settings.write');
    if (proposed.id != current?.id) {
      throw const AdminAssistantActionException('coupon_current_required');
    }
    final payload = proposed.toJson();
    final effectiveActive = current?.isActive ?? false;
    payload['is_active'] = effectiveActive;
    return _prepare(
      'admin_assistant_prepare_coupon',
      {'p_coupon': payload},
      actionType: 'marketing.coupon.save',
      title: current == null
          ? _ar
                ? 'إنشاء كوبون'
                : 'Create coupon'
          : _ar
          ? 'تعديل كوبون'
          : 'Update coupon',
      details: _couponDiff(current, proposed, isActive: effectiveActive),
    );
  }

  Future<AdminAssistantActionPreview> prepareCouponActivation(
    AdminCoupon current, {
    required bool active,
  }) async {
    _requirePermission('settings.write');
    if (current.isActive == active) {
      throw const AdminAssistantActionException('coupon_already_in_state');
    }
    return _prepare(
      'admin_assistant_prepare_coupon_activation',
      {'p_coupon_id': current.id, 'p_active': active},
      actionType: 'marketing.coupon.activate',
      title: active
          ? _ar
                ? 'تفعيل كوبون'
                : 'Activate coupon'
          : _ar
          ? 'إيقاف كوبون'
          : 'Pause coupon',
      details: <String>[
        '${current.code}: ${current.isActive ? (_ar ? 'مفعّل' : 'active') : (_ar ? 'متوقف' : 'paused')} → ${active ? (_ar ? 'مفعّل' : 'active') : (_ar ? 'متوقف' : 'paused')}',
      ],
    );
  }

  Future<AdminAssistantActionResult> confirmPreparedAction() async {
    final previewId = _pendingPreviewId;
    if (previewId == null) {
      throw const AdminAssistantActionException('no_pending_preview');
    }
    late final Object? action;
    try {
      action = await client
          .rpc(
            'admin_assistant_execute_catalog_action',
            params: {'p_preview_id': previewId},
          )
          .timeout(const Duration(seconds: 12));
    } on PostgrestException catch (error) {
      if (error.code == '40001' || error.code == '42501') {
        _pendingPreviewId = null;
      }
      throw AdminAssistantActionException(
        error.code == '40001'
            ? 'preview_expired_or_data_changed'
            : error.code == '42501'
            ? 'permission_denied'
            : 'execution_failed',
      );
    }
    final result = _asMap(action);
    _pendingPreviewId = null;
    if (result['ok'] == false) {
      return AdminAssistantActionResult.failed(
        '${result['reason'] ?? 'operation_rejected'}',
      );
    }
    return AdminAssistantActionResult.success(
      actionType: '${result['action_type'] ?? ''}',
      entityId: '${result['id'] ?? ''}',
    );
  }

  Future<void> cancelPreparedAction() async {
    final previewId = _pendingPreviewId;
    if (previewId == null) return;
    try {
      await client
          .rpc(
            'admin_assistant_cancel_action',
            params: {'p_preview_id': previewId},
          )
          .timeout(const Duration(seconds: 5));
    } finally {
      _pendingPreviewId = null;
    }
  }

  Future<AdminAssistantActionPreview> _prepare(
    String rpc,
    Map<String, Object?> params, {
    required String actionType,
    required String title,
    required List<String> details,
  }) async {
    if (_pendingPreviewId != null) {
      throw const AdminAssistantActionException(
        'pending_preview_must_be_confirmed_or_cancelled',
      );
    }
    try {
      final response = await client
          .rpc(rpc, params: params)
          .timeout(const Duration(seconds: 10));
      final data = _asMap(response);
      final previewId = '${data['preview_id'] ?? ''}';
      final expiresAt = DateTime.tryParse('${data['expires_at'] ?? ''}');
      if (previewId.isEmpty || expiresAt == null) {
        throw const AdminAssistantActionException('invalid_preview_response');
      }
      final oldValues = data['old_values'];
      _pendingPreviewId = previewId;
      return AdminAssistantActionPreview(
        id: previewId,
        actionType: actionType,
        title: title,
        details: details,
        oldValues: oldValues is Map
            ? Map<String, dynamic>.from(oldValues)
            : oldValues,
        expiresAt: expiresAt,
      );
    } on AdminAssistantActionException {
      rethrow;
    } on PostgrestException catch (error) {
      throw AdminAssistantActionException(
        error.code == '42501' ? 'permission_denied' : 'preview_failed',
      );
    } catch (_) {
      throw const AdminAssistantActionException('preview_failed');
    }
  }

  void _requirePermission(String permission) {
    if (!(session?.hasPermission(permission) ?? false)) {
      throw AdminAssistantActionException('permission_denied:$permission');
    }
  }

  bool get _ar => AppLocale.instance.isArabic;

  static Map<String, Object?> _productPayload(
    AdminProduct product, {
    int? stockQuantity,
  }) => <String, Object?>{
    'name_ar': product.nameAr,
    'name_en': product.nameEn,
    'description_ar': product.descriptionAr,
    'description_en': product.descriptionEn,
    'sku': product.sku,
    'slug': product.slug,
    'base_price': product.basePrice,
    'compare_at_price': product.compareAtPrice,
    'category_id': product.categoryId,
    'image_url': product.imageUrl,
    'is_featured': product.isFeatured,
    'is_active': product.isActive,
    'prep_minutes': product.prepMinutes,
    'discount_percentage': product.discountPercentage,
    'discount_starts_at': product.discountStartsAt?.toIso8601String(),
    'discount_ends_at': product.discountEndsAt?.toIso8601String(),
    'calories': product.calories,
    'allergens': product.allergens,
    ...?(stockQuantity == null ? null : {'stock_quantity': stockQuantity}),
  };

  List<String> _productDiff(
    AdminProduct? old,
    AdminProduct next, {
    int? stockQuantity,
  }) {
    final fields = <(String, Object?, Object?)>[
      (_ar ? 'الاسم العربي' : 'Arabic name', old?.nameAr, next.nameAr),
      (_ar ? 'الاسم الإنجليزي' : 'English name', old?.nameEn, next.nameEn),
      (_ar ? 'رمز المنتج' : 'SKU', old?.sku, next.sku),
      (_ar ? 'الرابط المختصر' : 'Slug', old?.slug, next.slug),
      (_ar ? 'السعر الأساسي' : 'Base price', old?.basePrice, next.basePrice),
      (
        _ar ? 'سعر المقارنة' : 'Compare-at price',
        old?.compareAtPrice,
        next.compareAtPrice,
      ),
      (
        _ar ? 'الوصف العربي' : 'Arabic description',
        old?.descriptionAr,
        next.descriptionAr,
      ),
      (
        _ar ? 'الوصف الإنجليزي' : 'English description',
        old?.descriptionEn,
        next.descriptionEn,
      ),
      (
        _ar ? 'التصنيف' : 'Category',
        old?.categoryNameFor(AppLocale.instance.language),
        next.categoryNameFor(AppLocale.instance.language),
      ),
      (_ar ? 'رابط الصورة' : 'Image URL', old?.imageUrl, next.imageUrl),
      (_ar ? 'مميّز' : 'Featured', old?.isFeatured, next.isFeatured),
      (_ar ? 'التوفر' : 'Availability', old?.isActive, next.isActive),
      (
        _ar ? 'وقت التحضير بالدقائق' : 'Prep time (minutes)',
        old?.prepMinutes,
        next.prepMinutes,
      ),
      (
        _ar ? 'الخصم المباشر' : 'Direct discount',
        old?.discountPercentage,
        next.discountPercentage,
      ),
      (
        _ar ? 'بداية الخصم' : 'Discount starts',
        old?.discountStartsAt,
        next.discountStartsAt,
      ),
      (
        _ar ? 'نهاية الخصم' : 'Discount ends',
        old?.discountEndsAt,
        next.discountEndsAt,
      ),
      (_ar ? 'السعرات' : 'Calories', old?.calories, next.calories),
      (
        _ar ? 'مسببات الحساسية' : 'Allergens',
        old?.allergens.join(', '),
        next.allergens.join(', '),
      ),
      if (stockQuantity != null) ...[
        (_ar ? 'المخزون' : 'Stock', old?.stockQuantity, stockQuantity),
      ],
    ];
    if (old == null) {
      return fields.map((field) => '${field.$1}: ${field.$3}').toList();
    }
    return fields
        .where((field) => field.$2 != field.$3)
        .map((field) => '${field.$1}: ${field.$2} → ${field.$3}')
        .toList(growable: false);
  }

  List<String> _categoryDiff(AdminCategory? old, AdminCategory next) {
    final fields = <(String, Object?, Object?)>[
      (_ar ? 'الاسم العربي' : 'Arabic name', old?.nameAr, next.nameAr),
      (_ar ? 'الاسم الإنجليزي' : 'English name', old?.nameEn, next.nameEn),
      (
        _ar ? 'الوصف العربي' : 'Arabic description',
        old?.descriptionAr,
        next.descriptionAr,
      ),
      (
        _ar ? 'الوصف الإنجليزي' : 'English description',
        old?.descriptionEn,
        next.descriptionEn,
      ),
    ];
    if (old == null) {
      return fields.map((field) => '${field.$1}: ${field.$3}').toList();
    }
    return fields
        .where((field) => field.$2 != field.$3)
        .map((field) => '${field.$1}: ${field.$2} → ${field.$3}')
        .toList(growable: false);
  }

  List<String> _couponDiff(
    AdminCoupon? old,
    AdminCouponDraft next, {
    required bool isActive,
  }) {
    final details = <String>[
      '${_ar ? 'الكود' : 'Code'}: ${next.code.toUpperCase()}',
      '${_ar ? 'قيمة الخصم' : 'Discount'}: ${next.discountValue} ${next.discountType.wireValue}',
      '${_ar ? 'الحد الأقصى للخصم' : 'Maximum discount'}: ${next.maxDiscount ?? (_ar ? 'غير محدد' : 'not set')}',
      '${_ar ? 'النطاق' : 'Scope'}: ${next.scope.wireValue} · ${next.scope == AdminCouponScope.category
          ? next.categoryIds.join(', ')
          : next.scope == AdminCouponScope.product
          ? next.productIds.join(', ')
          : (_ar ? 'كل المنتجات' : 'all products')}',
      '${_ar ? 'العنوان' : 'Title'}: ${_ar ? next.titleAr : next.titleEn}',
      '${_ar ? 'الحد الأدنى للطلب' : 'Minimum order'}: ${next.minOrderAmount}',
      '${_ar ? 'الحد الأقصى للاستخدام' : 'Usage limit'}: ${next.usageLimit ?? (_ar ? 'بلا حد' : 'unlimited')}',
      '${_ar ? 'حد الاستخدام لكل عميل' : 'Per-customer limit'}: ${next.perUserLimit}',
      '${_ar ? 'الفترة' : 'Window'}: ${next.startsAt?.toLocal() ?? (_ar ? 'الآن' : 'now')} → ${next.endsAt?.toLocal() ?? (_ar ? 'بدون نهاية' : 'no end')}',
      '${_ar ? 'الحالة بعد الحفظ' : 'Status after save'}: ${isActive ? (_ar ? 'مفعّل' : 'active') : (_ar ? 'مسودة/متوقف' : 'draft/paused')}',
    ];
    if (old != null) {
      details.insert(
        0,
        '${_ar ? 'الحالي' : 'Current'}: ${old.code} · ${old.discountValue} · ${old.isActive ? 'active' : 'paused'}',
      );
    }
    return details;
  }

  static Map<String, dynamic> _asMap(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
}

class AdminAssistantActionPreview {
  const AdminAssistantActionPreview({
    required this.id,
    required this.actionType,
    required this.title,
    required this.details,
    required this.oldValues,
    required this.expiresAt,
  });

  final String id;
  final String actionType;
  final String title;
  final List<String> details;

  /// Authoritative server snapshot at preview creation. Integrators should
  /// show this alongside [details] before displaying the confirm affordance.
  final Object? oldValues;
  final DateTime expiresAt;
}

class AdminAssistantActionResult {
  const AdminAssistantActionResult._({
    required this.succeeded,
    this.actionType = '',
    this.entityId = '',
    this.reason = '',
  });

  factory AdminAssistantActionResult.success({
    required String actionType,
    required String entityId,
  }) => AdminAssistantActionResult._(
    succeeded: true,
    actionType: actionType,
    entityId: entityId,
  );
  factory AdminAssistantActionResult.failed(String reason) =>
      AdminAssistantActionResult._(succeeded: false, reason: reason);

  final bool succeeded;
  final String actionType;
  final String entityId;
  final String reason;
}

class AdminAssistantActionException implements Exception {
  const AdminAssistantActionException(this.code);
  final String code;
}
