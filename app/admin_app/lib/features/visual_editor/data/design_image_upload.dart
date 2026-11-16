import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/admin_image_picker.dart';
import 'package:admin_app/core/services/supabase_service.dart';

/// رفع صورة من جهاز الموظف إلى دلو صور التصميم العام.
///
/// يعيد اختيار الصورة من الكمبيوتر (أداة المنتجات نفسها) ثم يرفعها إلى
/// دلو `product-images` في مسار `design/` ويعيد الرابط العام. يلغي الإلغاء
/// كـ null بلا خطأ — ألغى الموظف الاختيار فلا شيء يُقال.
class DesignImageUpload {
  const DesignImageUpload._();

  static Future<String?> pickAndUpload() async {
    final picked = await pickAdminImage();
    if (picked == null) return null;
    if (picked.isLink) return picked.url;
    final bytes = picked.bytes!;
    if (bytes.isEmpty) throw Exception('الصورة المختارة فارغة');
    if (bytes.length > adminImageMaxBytes) {
      throw Exception('الصورة أكبر من 5MB');
    }
    final path =
        'design/${DateTime.now().microsecondsSinceEpoch}${_extensionOf(picked.fileName ?? '')}';
    await SupabaseService.client.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: picked.contentType ?? 'image/jpeg',
            upsert: false,
          ),
        );
    return '${AppConfig.supabaseUrl}/storage/v1/object/public/product-images/$path';
  }

  static String _extensionOf(String fileName) {
    final name = fileName.toLowerCase();
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }
}
