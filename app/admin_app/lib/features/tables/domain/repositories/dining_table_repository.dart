import 'package:admin_app/features/tables/domain/entities/dining_overview.dart';
import 'package:admin_app/features/tables/domain/entities/dining_reservation_draft.dart';
import 'package:admin_app/features/tables/domain/entities/dining_table_draft.dart';

enum DiningLoadFailure { permissionDenied, noBranch, failed }

class DiningLoadException implements Exception {
  const DiningLoadException(this.failure, [this.message]);

  final DiningLoadFailure failure;
  final String? message;

  @override
  String toString() => message ?? failure.name;
}

enum DiningTableSaveOutcome {
  saved,
  invalidName,
  invalidArea,
  invalidCapacity,
  invalidNote,
  invalidBranch,
  duplicateName,
  notFound,
  permissionDenied,
  failed,
}

enum DiningTableMutationOutcome {
  success,
  notFound,
  inUse,
  hasHistory,
  permissionDenied,
  failed,
}

enum DiningReservationSaveOutcome {
  saved,
  invalidName,
  invalidPhone,
  invalidParty,
  invalidDuration,
  invalidNote,
  invalidTime,
  invalidTable,
  partyTooLarge,
  overlap,
  closedReservation,
  seatedTableLocked,
  notFound,
  permissionDenied,
  failed,
}

enum DiningReservationStatusOutcome {
  success,
  invalidStatus,
  invalidTable,
  tableBusy,
  tooEarly,
  notFound,
  permissionDenied,
  failed,
}

/// عقد قراءة طاولات الصالة وحجوزاتها وكتابة تعديلاتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class DiningTableRepository {
  /// يقرأ نظرة الفرع: الطاولات والحجوزات والمؤشرات والفروع.
  Future<DiningOverview> loadOverview({String? branchId});

  /// ينشئ طاولة أو يحدّثها ويعيد نتيجة الحفظ.
  Future<DiningTableSaveOutcome> saveTable(DiningTableDraft draft);

  /// يفعّل الطاولة أو يعطّلها بعد فحص القاعدة.
  Future<DiningTableMutationOutcome> setTableActive(
    String tableId,
    bool active,
  );

  /// يحذف الطاولة ويعيد نتيجة العملية.
  Future<DiningTableMutationOutcome> deleteTable(String tableId);

  /// ينشئ حجزًا أو يحدّثه ويعيد نتيجة الحفظ.
  Future<DiningReservationSaveOutcome> saveReservation(
    DiningReservationDraft draft,
  );

  /// يغيّر حالة الحجز (تأكيد أو إلغاء أو مقاعد شاغرة) ويعيد النتيجة.
  Future<DiningReservationStatusOutcome> setReservationStatus(
    String reservationId,
    String status,
  );
}
