import 'package:admin_app/features/carts/data/models/admin_cart.dart';

/// عقد قراءة السلات المتروكة.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class CartRepository {
  /// يقرأ كل السلات المتروكة بترتيب القاعدة.
  Future<List<AdminCart>> loadCarts();
}
