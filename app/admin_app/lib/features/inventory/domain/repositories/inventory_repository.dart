import 'package:admin_app/features/inventory/domain/entities/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_material_save_outcome.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_movement_outcome.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_mutation_outcome.dart';

/// عقد قراءة المواد الخام وحركاتها وكتابة كليهما.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class InventoryRepository {
  /// يقرأ صفحة المواد المطابقة للبحث والتصفية بترتيب القاعدة.
  Future<AdminInventoryPage> loadPage({
    String? search,
    String? category,
    String? status,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  });

  /// يقرأ ملخص مؤشرات المخزون للفرع المختار.
  Future<AdminInventoryMetrics> loadMetrics({String? branchId});

  /// يقرأ قيم التصفية المتاحة (الفئات والفروع).
  Future<AdminInventoryFilters> loadFilters();

  /// يقرأ خيارات المواد كما تحتاجها حوارات الحركة.
  Future<List<AdminInventoryMaterialOption>> searchMaterials({
    String? search,
    String? branchId,
    int limit = 30,
  });

  /// يحفظ مادة خام ويعيد نتيجة القاعدة.
  Future<InventoryMaterialSaveOutcome> saveMaterial(AdminInventoryDraft draft);

  /// يحذف مادة خام ويعيد نتيجة العملية.
  Future<InventoryMutationOutcome> deleteMaterial(String materialId);

  /// يسجل حركة مخزون ويعيد نتيجة العملية.
  Future<InventoryMovementOutcome> recordMovement(
    AdminStockMovementDraft draft,
  );

  /// يقرأ صفحة الحركات المطابقة للبحث والتصفية.
  Future<AdminStockMovementPage> loadMovements({
    String? search,
    String? type,
    String? period,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  });

  /// يقرأ ملخص مؤشرات الحركات للفرع والفترة المختارين.
  Future<AdminStockMovementMetrics> loadMovementMetrics({
    String? branchId,
    String? period,
  });
}
