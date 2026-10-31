import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';

/// عقد قراءة عدّادات الشريط الجانبي.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class NavRepository {
  /// يقرأ الأرقام التي يعرضها الشريط الجانبي دون فتح أي صفحة.
  ///
  /// [withNotifications] تطلب عدّاد الإشعارات أيضًا؛ لا يُقرأ لحساب لا يملك
  /// `notifications.read` لأن القاعدة ترفضه، فلا معنى لسؤاله في كل تحديث.
  Future<AdminNavCounts> loadCounts({bool withNotifications = false});
}
