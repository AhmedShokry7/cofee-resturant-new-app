import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';

/// عقد قراءة عدّادات الشريط الجانبي.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class NavRepository {
  /// يقرأ الرقمين اللذين يعرضهما الشريط الجانبي دون فتح أي صفحة.
  Future<AdminNavCounts> loadCounts();
}
