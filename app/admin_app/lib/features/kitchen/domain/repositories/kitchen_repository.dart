import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';

/// نتيجة تعديل تيكيتن المطبخ أو سطورها كما تعيدها القاعدة.
enum KitchenMutationOutcome {
  success,
  notFound,
  invalidStatus,
  invalidTransition,
  permissionDenied,
  failed,
}

/// عقد قراءة سبورة المطبخ ومؤشراتها وفلاترها وكتابة حالاتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class KitchenRepository {
  /// يقرأ تيكيتات المطبخ مع البحث والفرع والحد.
  Future<AdminKitchenBoard> loadBoard({
    String? search,
    String? branchId,
    int limit = 150,
  });

  /// يقرأ ملخص مؤشرات المطبخ لفرع معين أو لكل الفروع.
  Future<AdminKitchenMetrics> loadMetrics({String? branchId});

  /// يقرأ خيارات الفروع المتاحة للفلاتر.
  Future<AdminKitchenFilters> loadFilters();

  /// يغيّر حالة تيكيت ويعيد نتيجة العملية.
  Future<KitchenMutationOutcome> setTicketStatus(
    String ticketId,
    KitchenTicketStatus status,
  );

  /// يغيّر حالة سطر من سطور التيكيت ويعيد نتيجة العملية.
  Future<KitchenMutationOutcome> setItemStatus(
    String itemId,
    KitchenItemStatus status,
  );

  /// يوسم التيكيتات التي عرضتها السبورة بأنها قرئت، مرة واحدة لكل تيكيت.
  Future<void> markTicketsViewed(List<String> ticketIds);
}
