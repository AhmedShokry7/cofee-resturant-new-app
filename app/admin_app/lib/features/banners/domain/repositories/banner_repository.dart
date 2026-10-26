import 'dart:typed_data';

import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';

/// عقد قراءة البنرات وكتابة بياناتها وصورها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class BannerRepository {
  /// يقرأ كل البنرات بترتيب العرض.
  Future<List<AdminBanner>> loadBanners();

  /// ينشئ بنرًا ويعيد الصف المحفوظ من القاعدة.
  Future<AdminBanner> createBanner(AdminBanner banner);

  /// يعدل بيانات بنر قائم.
  Future<void> updateBanner(AdminBanner banner);

  /// يحذف بنرًا قائمًا.
  Future<void> deleteBanner(String id);

  /// ينشر البنر أو يخفيه.
  Future<void> setPublished(String id, bool value);

  /// يحدث رابط صورة البنر.
  Future<void> updateBannerImage(String bannerId, String? imageUrl);

  /// يرفع صورة البنر ويعيد رابطها العام.
  Future<String> uploadBannerImage({
    String? bannerId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  /// يحذف ملف الصورة المرتبط بالبنر إن وُجد.
  Future<void> deleteBannerImageFile(String? imageUrl);
}
