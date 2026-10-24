import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';

class AdminBranchException implements Exception {
  const AdminBranchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The branches of the brand the dashboard manages.
class AdminBranchRepository {
  AdminBranchRepository();

  SupabaseClient get _supabase => SupabaseService.client;

  /// Loads every branch the dashboard can see.
  Future<List<AdminBranch>> loadBranches() async {
    final rows = await _supabase.from('branches').select().order('name_ar');
    return (rows as List)
        .whereType<Map>()
        .map((row) => AdminBranch.fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  /// Creates a branch of the brand.
  Future<AdminBranch> createBranch({
    required String code,
    required String nameAr,
    required String nameEn,
    required String address,
    double? latitude,
    double? longitude,
    String? phone,
    String? opensAt,
    String? closesAt,
  }) async {
    final brandId = await _fetchBrandId();

    final response = await _supabase
        .from('branches')
        .insert(<String, dynamic>{
          'brand_id': brandId,
          'code': code,
          'name_ar': nameAr,
          'name_en': nameEn,
          'address': address,
          // The customer app prefers localized address columns. Keep them in
          // sync with the admin's saved pin/address so it cannot show stale
          // seed text after a branch is moved.
          'address_ar': address,
          'address_en': address,
          'latitude': latitude,
          'longitude': longitude,
          'phone': phone,
          'opens_at': opensAt,
          'closes_at': closesAt,
        })
        .select()
        .single();

    return AdminBranch.fromRow(response);
  }

  /// Updates a branch.
  Future<AdminBranch> updateBranch({
    required String branchId,
    required String code,
    required String nameAr,
    required String nameEn,
    required String address,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? phone,
    bool clearPhone = false,
    String? opensAt,
    bool clearOpensAt = false,
    String? closesAt,
    bool clearClosesAt = false,
  }) async {
    final update = <String, dynamic>{
      'code': code,
      'name_ar': nameAr,
      'name_en': nameEn,
      'address': address,
      'address_ar': address,
      'address_en': address,
    };
    if (clearLatitude) {
      update['latitude'] = null;
    } else if (latitude != null) {
      update['latitude'] = latitude;
    }
    if (clearLongitude) {
      update['longitude'] = null;
    } else if (longitude != null) {
      update['longitude'] = longitude;
    }
    if (clearPhone) {
      update['phone'] = null;
    } else if (phone != null) {
      update['phone'] = phone;
    }
    if (clearOpensAt) {
      update['opens_at'] = null;
    } else if (opensAt != null) {
      update['opens_at'] = opensAt;
    }
    if (clearClosesAt) {
      update['closes_at'] = null;
    } else if (closesAt != null) {
      update['closes_at'] = closesAt;
    }

    final response = await _supabase
        .from('branches')
        .update(update)
        .eq('id', branchId)
        .select()
        .single();

    return AdminBranch.fromRow(response);
  }

  /// Deletes a branch.
  Future<void> deleteBranch(String branchId) async {
    await _supabase.from('branches').delete().eq('id', branchId);
  }

  /// Activates or deactivates a branch.
  Future<void> setBranchActive(String branchId, bool isActive) async {
    await _supabase
        .from('branches')
        .update({'is_active': isActive})
        .eq('id', branchId);
  }

  Future<void> updateBranchImage(String branchId, String? imageUrl) async {
    await _supabase
        .from('branches')
        .update({'image_url': imageUrl})
        .eq('id', branchId);
  }

  Future<String> uploadBranchImage({
    required String branchId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    // Reuse product image checks
    if (bytes.isEmpty) throw const AdminBranchException('Image is empty.');
    if (bytes.length > 5 * 1024 * 1024) {
      throw const AdminBranchException('Image is bigger than 5 MB.');
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
    try {
      await updateBranchImage(branchId, url);
    } catch (error) {
      await _supabase.storage.from('product-images').remove([path]);
      rethrow;
    }
    return url;
  }

  Future<void> deleteBranchImageFile(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    final marker = '/product-images/';
    final idx = imageUrl.indexOf(marker);
    if (idx < 0) return;
    final path = imageUrl.substring(idx + marker.length);
    try {
      await _supabase.storage.from('product-images').remove([path]);
    } catch (_) {}
  }

  String _extOf(String fileName) {
    final name = fileName.toLowerCase();
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }

  String get _supabaseUrl => AppConfig.supabaseUrl;

  Future<String> _fetchBrandId() async {
    final row = await _supabase.from('brands').select('id').limit(1).single();
    return '${row['id']}';
  }
}
