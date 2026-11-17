import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';

class AdminSubscriptionPlanRepository implements SubscriptionPlanRepository {
  AdminSubscriptionPlanRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminSubscriptionPlan>> loadPlans() async {
    final results = await Future.wait<Object?>([
      _supabase.rpc('admin_subscription_plans'),
      _supabase.rpc('admin_subscription_plan_images'),
    ]);
    final rows = results[0];
    final imageRows = results[1];
    final images = <String, String?>{
      if (imageRows is List)
        for (final row in imageRows.whereType<Map>())
          '${row['id'] ?? ''}': row['image_url'] as String?,
    };
    if (rows is List) {
      return rows
          .whereType<Map>()
          .map((row) {
            final data = Map<String, dynamic>.from(row);
            data['image_url'] = images['${data['id'] ?? ''}'];
            return AdminSubscriptionPlan.fromJson(data);
          })
          .toList(growable: false);
    }
    return const <AdminSubscriptionPlan>[];
  }

  @override
  Future<List<AdminSubscriptionPlanProduct>> loadProductOptions() async {
    final response = await _supabase.rpc('admin_subscription_product_options');
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) => AdminSubscriptionPlanProduct.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    }
    return const <AdminSubscriptionPlanProduct>[];
  }

  @override
  Future<SubscriptionPlanSaveOutcome> savePlan(
    AdminSubscriptionPlanDraft draft,
  ) async {
    final response = await _supabase.rpc(
      'admin_save_subscription_plan',
      params: {'p_plan': draft.toJson()},
    );
    if (response is! Map) return SubscriptionPlanSaveOutcome.failed;
    if (response['ok'] == true) return SubscriptionPlanSaveOutcome.saved;
    return switch ('${response['reason'] ?? ''}') {
      'duplicate_code' => SubscriptionPlanSaveOutcome.duplicateCode,
      'missing_products' => SubscriptionPlanSaveOutcome.missingProducts,
      'invalid_products' => SubscriptionPlanSaveOutcome.invalidProducts,
      'not_found' => SubscriptionPlanSaveOutcome.notFound,
      'invalid_code' ||
      'missing_name' ||
      'invalid_price' ||
      'invalid_currency' ||
      'invalid_duration' ||
      'invalid_cups' ||
      'invalid_bonus' ||
      'invalid_rollover' ||
      'invalid_renewal' ||
      'invalid_payload' => SubscriptionPlanSaveOutcome.invalidData,
      _ => SubscriptionPlanSaveOutcome.failed,
    };
  }

  @override
  Future<bool> setActive(String planId, bool active) async {
    final response = await _supabase.rpc(
      'admin_set_subscription_plan_active',
      params: {'p_plan_id': planId, 'p_active': active},
    );
    return response is Map && response['ok'] == true;
  }

  @override
  Future<void> updatePlanImage(String planId, String? imageUrl) async {
    final response = await _supabase.rpc(
      'admin_set_subscription_plan_image',
      params: {'p_plan_id': planId, 'p_image_url': imageUrl},
    );
    if (response is! Map || response['ok'] != true) {
      throw StateError('Could not update the subscription plan image.');
    }
  }

  @override
  Future<String> uploadPlanImage({
    required String planId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) throw StateError('The selected image is empty.');
    if (bytes.length > adminImageMaxBytes) {
      throw StateError('The selected image is larger than 5 MB.');
    }
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(contentType)) {
      throw StateError('The selected image type is not supported.');
    }

    final extension = _imageExtension(fileName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = 'products/subscription-plans/$planId/$stamp$extension';
    await _supabase.storage.from('product-images').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    final url = '${AppConfig.supabaseUrl}/storage/v1/object/public/'
        'product-images/$path';
    try {
      await updatePlanImage(planId, url);
      return url;
    } catch (_) {
      await _removeImage(path);
      rethrow;
    }
  }

  @override
  Future<void> deletePlanImageFile(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    // Only remove dashboard-owned files, and only after confirming that no
    // other plan still points at the same public URL.
    final plans = await loadPlans();
    if (plans.any((plan) => plan.imageUrl == imageUrl)) return;
    final marker = '/product-images/';
    final index = imageUrl.indexOf(marker);
    if (index < 0) return;
    final path = imageUrl.substring(index + marker.length);
    if (!path.startsWith('products/subscription-plans/')) return;
    await _removeImage(path);
  }

  Future<void> _removeImage(String path) async {
    try {
      await _supabase.storage.from('product-images').remove([path]);
    } catch (_) {}
  }

  String _imageExtension(String fileName) {
    final lower = fileName.toLowerCase();
    for (final extension in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (lower.endsWith(extension)) {
        return extension == '.jpeg' ? '.jpg' : extension;
      }
    }
    return '.jpg';
  }
}
