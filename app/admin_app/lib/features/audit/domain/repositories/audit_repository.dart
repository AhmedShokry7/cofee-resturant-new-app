import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';

/// عقد قراءة سجلات التدقيق ومؤشراتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class AuditRepository {
  /// يقرأ صفحة السجلات مع فلاتر البحث والمجال والحرج والترقيم.
  Future<AdminAuditPage> loadPage({
    String? search,
    String? domain,
    bool criticalOnly = false,
    int page = 0,
    int pageSize = 20,
  });

  /// يقرأ ملخص مؤشرات التدقيق.
  Future<AdminAuditMetrics> loadMetrics();
}
