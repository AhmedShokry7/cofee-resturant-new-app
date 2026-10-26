import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/data/models/admin_branch_draft.dart';
import 'package:admin_app/features/branches/data/models/admin_branch_metrics.dart';
import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';

class AdminBranchException implements Exception {
  const AdminBranchException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum BranchSaveOutcome {
  saved,
  duplicateCode,
  invalidCode,
  invalidName,
  invalidAddress,
  invalidHours,
  invalidLocation,
  invalidVatNumber,
  invalidLegalName,
  noBrand,
  notFound,
  permissionDenied,
  failed,
}

enum BranchMutationOutcome {
  success,
  notFound,
  hasOrders,
  hasUsage,
  hasStaff,
  lastActive,
  inUse,
  invalidUrl,
  permissionDenied,
  failed,
}

/// The branches of the brand the dashboard manages.
class AdminBranchRepository {
  AdminBranchRepository();

  SupabaseClient get _supabase => SupabaseService.client;

  /// Loads every branch with its staff, zone and order counters.
  Future<List<AdminBranch>> loadBranches() async {
    final response = await _supabase.rpc('admin_branches');
    if (response is! List) return const <AdminBranch>[];
    return response
        .whereType<Map>()
        .map((row) => AdminBranch.fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<AdminBranchMetrics> loadMetrics() async {
    final response = await _supabase.rpc('admin_branch_metrics');
    if (response is! Map) return AdminBranchMetrics.empty;
    return AdminBranchMetrics.fromJson(Map<String, dynamic>.from(response));
  }

  Future<BranchSaveOutcome> saveBranch(AdminBranchDraft draft) async {
    try {
      final response = await _supabase.rpc(
        'admin_save_branch',
        params: {'p_branch': draft.toJson()},
      );
      if (_isOk(response)) return BranchSaveOutcome.saved;
      return switch (_reason(response)) {
        'duplicate_code' => BranchSaveOutcome.duplicateCode,
        'invalid_code' => BranchSaveOutcome.invalidCode,
        'invalid_name' => BranchSaveOutcome.invalidName,
        'invalid_address' => BranchSaveOutcome.invalidAddress,
        'invalid_hours' => BranchSaveOutcome.invalidHours,
        'invalid_location' => BranchSaveOutcome.invalidLocation,
        'invalid_vat_number' => BranchSaveOutcome.invalidVatNumber,
        'invalid_legal_name' => BranchSaveOutcome.invalidLegalName,
        'no_brand' => BranchSaveOutcome.noBrand,
        'not_found' => BranchSaveOutcome.notFound,
        _ => BranchSaveOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? BranchSaveOutcome.permissionDenied
          : BranchSaveOutcome.failed;
    } catch (_) {
      return BranchSaveOutcome.failed;
    }
  }

  Future<BranchMutationOutcome> setBranchActive(
    String branchId,
    bool active,
  ) async {
    return _mutation(
      'admin_set_branch_active',
      params: {'p_branch_id': branchId, 'p_active': active},
    );
  }

  Future<BranchMutationOutcome> deleteBranch(String branchId) async {
    return _mutation('admin_delete_branch', params: {'p_branch_id': branchId});
  }

  Future<BranchMutationOutcome> setBranchImage(
    String branchId,
    String? imageUrl,
  ) async {
    return _mutation(
      'admin_set_branch_image',
      params: {'p_branch_id': branchId, 'p_image_url': imageUrl},
    );
  }

  Future<BranchMutationOutcome> uploadBranchImage({
    required String branchId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    if (bytes.isEmpty) throw AdminBranchException(S.imageIsEmpty);
    if (bytes.length > 5 * 1024 * 1024) {
      throw AdminBranchException(S.imageTooLarge);
    }

    final ext = _extOf(fileName);
    final path =
        'products/branch-$branchId/${DateTime.now().microsecondsSinceEpoch}$ext';

    onPhase?.call(AdminImageUploadPhase.uploading);
    await _supabase.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final url = '$_supabaseUrl/storage/v1/object/public/product-images/$path';

    onPhase?.call(AdminImageUploadPhase.saving);
    final outcome = await setBranchImage(branchId, url);
    if (outcome != BranchMutationOutcome.success) {
      await _removeFile(path);
    }
    return outcome;
  }

  Future<void> deleteBranchImageFile(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    final marker = '/product-images/';
    final idx = imageUrl.indexOf(marker);
    if (idx < 0) return;
    await _removeFile(imageUrl.substring(idx + marker.length));
  }

  Future<BranchMutationOutcome> _mutation(
    String function, {
    required Map<String, dynamic> params,
  }) async {
    try {
      final response = await _supabase.rpc(function, params: params);
      if (_isOk(response)) return BranchMutationOutcome.success;
      return switch (_reason(response)) {
        'not_found' => BranchMutationOutcome.notFound,
        'has_orders' => BranchMutationOutcome.hasOrders,
        'has_usage' => BranchMutationOutcome.hasUsage,
        'has_staff' => BranchMutationOutcome.hasStaff,
        'last_active' => BranchMutationOutcome.lastActive,
        'in_use' => BranchMutationOutcome.inUse,
        'invalid_url' => BranchMutationOutcome.invalidUrl,
        _ => BranchMutationOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? BranchMutationOutcome.permissionDenied
          : BranchMutationOutcome.failed;
    } catch (_) {
      return BranchMutationOutcome.failed;
    }
  }

  Future<void> _removeFile(String path) async {
    try {
      await _supabase.storage.from('product-images').remove([path]);
    } catch (_) {}
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';

  String _extOf(String fileName) {
    final name = fileName.toLowerCase();
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }

  String get _supabaseUrl => AppConfig.supabaseUrl;
}
