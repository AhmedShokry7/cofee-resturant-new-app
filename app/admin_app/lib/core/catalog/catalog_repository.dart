import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';

/// قراءة صفحة من الكتالوج.
///
/// التنفيذ الفعلي (Supabase) في طبقة البيانات، فلا يعرف المجال أي مكتبة شبكة.
abstract interface class CatalogRepository {
  /// يقرأ صفحة واحدة؛ القصّ يحدث في القاعدة فلا تطلب اللوحة الكتالوج كله دفعة واحدة.
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  });
}
