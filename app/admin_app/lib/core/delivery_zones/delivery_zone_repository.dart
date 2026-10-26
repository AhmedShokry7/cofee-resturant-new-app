import 'package:admin_app/core/models/admin_delivery_zone.dart';

/// مناطق التوصيل كما تحتاجها شاشات الفروع.
///
/// التنفيذ الفعلي (Supabase) في طبقة بيانات فيتشر مناطق التوصيل، فلا يعرف
/// المستهلك أي مكتبة شبكة.
abstract interface class DeliveryZoneRepository {
  Future<List<AdminDeliveryZone>> loadZones();

  Future<List<Map<String, dynamic>>> loadZoneBranches();

  Future<AdminDeliveryZone> saveForBranch({
    required String branchId,
    required AdminDeliveryZone zone,
  });
}
