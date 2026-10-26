import 'package:admin_app/core/models/admin_delivery_zone.dart';

/// عقد قراءة مناطق التوصيل وفروعها وحفظ منطقة لفرع.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
/// يظل عقد `core` المشترك واجهة الاستهلاك بين الفيتشرات، فينفذ الفيتشر العقدين.
abstract interface class ZoneRepository {
  /// يقرأ كل مناطق التوصيل مرتبة بالاسم الإنجليزي.
  Future<List<AdminDeliveryZone>> loadZones();

  /// يقرأ ربط المناطق بالفروع كصفوف خام.
  Future<List<Map<String, dynamic>>> loadZoneBranches();

  /// يحفظ منطقة لفرع ويربطها به في نفس المعاملة.
  Future<AdminDeliveryZone> saveForBranch({
    required String branchId,
    required AdminDeliveryZone zone,
  });
}
