import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';

/// عقد قراءة الباقات وكتابة بياناتها وصورها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class BundleRepository {
  /// Loads all bundles with their components.
  Future<List<AdminBundle>> loadBundles();

  /// Loads all products (for the component picker).
  Future<List<Map<String, dynamic>>> loadProducts();

  /// Creates a bundle.
  Future<AdminBundle> createBundle(AdminBundle bundle);

  /// Updates a bundle.
  Future<AdminBundle> updateBundle(AdminBundle bundle);

  /// Deletes a bundle.
  Future<void> deleteBundle(String bundleId);

  /// Activates or deactivates a bundle.
  Future<void> setBundleActive(String bundleId, bool isActive);

  /// Points a bundle at another image url.
  Future<void> updateBundleImage(String bundleId, String? imageUrl);

  /// Uploads a picture of a bundle to the bucket and saves its url.
  Future<String> uploadBundleImage({
    String? bundleId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  });

  /// Removes the file of a bundle image.
  Future<void> deleteBundleImageFile(String? imageUrl);
}
