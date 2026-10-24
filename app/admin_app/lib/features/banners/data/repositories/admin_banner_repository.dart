import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/banners/data/models/admin_banner.dart';

class AdminBannerRepository {
  AdminBannerRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<List<AdminBanner>> loadBanners() async {
    final rows = await _supabase.from('banners').select().order('sort_order');
    return (rows as List)
        .whereType<Map>()
        .map((row) => AdminBanner.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<AdminBanner> createBanner(AdminBanner banner) async {
    final response = await _supabase
        .from('banners')
        .insert(banner.toJson())
        .select()
        .single();
    return AdminBanner.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> updateBanner(AdminBanner banner) async {
    await _supabase.from('banners').update(banner.toJson()).eq('id', banner.id);
  }

  Future<void> deleteBanner(String id) async {
    await _supabase.from('banners').delete().eq('id', id);
  }

  Future<void> setPublished(String id, bool value) async {
    await _supabase
        .from('banners')
        .update({'is_published': value})
        .eq('id', id);
  }

  Future<void> updateBannerImage(String bannerId, String? imageUrl) async {
    await _supabase
        .from('banners')
        .update({'image_url': imageUrl})
        .eq('id', bannerId);
  }

  Future<String> uploadBannerImage({
    String? bannerId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) throw Exception('Image is empty.');
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Image is bigger than 5 MB.');
    }
    final extension = _extensionOf(fileName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = 'products/banners/${bannerId ?? 'new'}/$stamp$extension';

    await _supabase.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final url =
        '${AppConfig.supabaseUrl}/storage/v1/object/public/product-images/$path';

    if (bannerId != null) {
      await updateBannerImage(bannerId, url);
    }
    return url;
  }

  Future<void> deleteBannerImageFile(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    final marker = '/product-images/';
    final idx = imageUrl.indexOf(marker);
    if (idx < 0) return;
    final path = imageUrl.substring(idx + marker.length);
    try {
      await _supabase.storage.from('product-images').remove([path]);
    } catch (_) {}
  }

  String _extensionOf(String fileName) {
    final name = fileName.toLowerCase();
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }
}
