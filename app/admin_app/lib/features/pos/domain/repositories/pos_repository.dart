import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/domain/entities/pos_order_result.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

enum PosCatalogFailure { permissionDenied, noBranch, failed }

class PosCatalogException implements Exception {
  const PosCatalogException(this.failure, [this.message]);

  final PosCatalogFailure failure;
  final String? message;

  @override
  String toString() => message ?? failure.name;
}

enum PosTablesFailure { permissionDenied, noBranch, failed }

class PosTablesException implements Exception {
  const PosTablesException(this.failure, [this.message]);

  final PosTablesFailure failure;
  final String? message;

  @override
  String toString() => message ?? failure.name;
}

enum PosSeatOutcome {
  success,
  tooEarly,
  invalidStatus,
  tableBusy,
  invalidTable,
  notFound,
  permissionDenied,
  failed,
}

enum PosCustomerFailure { permissionDenied, invalid, failed }

class PosCustomerException implements Exception {
  const PosCustomerException(this.failure, [this.message]);

  final PosCustomerFailure failure;
  final String? message;

  @override
  String toString() => message ?? failure.name;
}

enum PosCheckoutFailure {
  permissionDenied,
  shiftRequired,
  tableUnavailable,
  stockUnavailable,
  productUnavailable,
  branchUnavailable,
  paymentUnavailable,
  customerUnavailable,
  invalid,
  conflict,
  failed,
}

class PosCheckoutException implements Exception {
  const PosCheckoutException(this.failure, [this.message]);

  final PosCheckoutFailure failure;
  final String? message;

  @override
  String toString() => message ?? failure.name;
}

enum PosShiftFailure {
  permissionDenied,
  branchUnavailable,
  notFound,
  alreadyClosed,
  insufficientDrawerCash,
  invalid,
  failed,
}

class PosShiftException implements Exception {
  const PosShiftException(this.failure, [this.message]);

  final PosShiftFailure failure;
  final String? message;

  @override
  String toString() => message ?? failure.name;
}

/// عقد قراءة كتالوج الكاشير وكتابة طلبات الطاولة وورديات الصندوق.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class PosRepository {
  /// يقرأ الفروع والأصناف والمنتجات ووسائل الدفع للفرع المختار.
  Future<PosCatalog> loadCatalog({String? branchId});

  /// يقرأ طاولات الفرع مع حالاتها الحيّة وحجوزاتها.
  Future<List<DiningTable>> loadTables(String branchId);

  /// يجلس ضيف الحجز في الطاولة ويعيد نتيجة العملية.
  Future<PosSeatOutcome> seatReservation(String reservationId);

  /// يرسل طلب الكاشير بمفتاح تكرار يمنع تكرار البيع.
  Future<PosOrderResult> placeOrder({
    required String branchId,
    required List<Map<String, Object?>> lines,
    required String fulfillmentType,
    required String paymentMethodId,
    required String idempotencyKey,
    String? tableId,
    String? note,
    String? customerId,
    List<Map<String, Object?>>? payments,
  });

  /// يقرأ العملاء المطابقين للبحث، وأحدث العملاء عند بحث فارغ.
  Future<List<PosCustomer>> searchCustomers({String? query});

  /// ينشئ عميل كاشير بعد فحص القاعدة ويعيده.
  Future<PosCustomer> createCustomer({
    required String fullName,
    String? phone,
    String? email,
    String? note,
  });

  /// يقرأ الوردية المفتوحة للفرع، أو null إن لم يكن هناك وردية.
  Future<PosShift?> loadOpenShift(String branchId);

  /// يفتح وردية الفرع برصيد افتتاحي ويعيد الوردية المفتوحة.
  Future<PosShift> openShift({
    required String branchId,
    required double openingFloat,
    String? note,
  });

  /// يحرّك نقدًا داخل الوردية (إيداع أو سحب) بعد سبب.
  Future<PosShift> recordCashMovement({
    required String shiftId,
    required PosCashMovementKind kind,
    required double amount,
    required String reason,
  });

  /// يغلق الوردية بعد عدّ الصندوق ويعيد تقرير الإغلاق.
  Future<PosShift> closeShift({
    required String shiftId,
    required double countedCash,
    String? closeNote,
  });

  /// يقرأ صفحة من تاريخ ورديات الفرع بترتيب القاعدة.
  Future<List<PosShift>> loadShiftHistory(
    String branchId, {
    int limit = 20,
    int offset = 0,
  });

  /// يقرأ تقرير وردية واحدة بكل حركاتها.
  Future<PosShift> loadShiftDetail(String shiftId);
}
