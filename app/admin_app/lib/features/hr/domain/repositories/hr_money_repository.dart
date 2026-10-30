import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';

/// عقد المال: السلف، والتسويات، وفروق الكاشير.
///
/// الثلاثة كلها تمر بمعلق → معتمد، ولا يكتب أي منها حسمًا في الراتب قبل
/// الاعتماد؛ هذا هو الفرق بين تسوية HR وخصم عشوائي في كشف الراتب.
abstract interface class HrMoneyRepository {
  /// طلب سلفة من الموظف نفسه — لا يملك المدير أن يطلبها باسمه.
  Future<HrReceipt> requestAdvance({
    required double amount,
    double? installment,
    required String reason,
  });

  Future<List<HrAdvance>> loadAdvances({
    String? status,
    String? staffId,
    int limit = 50,
  });

  /// الموافقة تحمل قسط الاسترداد؛ null يبقي ما قررته القاعدة.
  Future<HrReceipt> reviewAdvance({
    required String advanceId,
    required bool approve,
    double? installment,
    String? note,
  });

  /// الصرف نقلة مستقلة عن الاعتماد: معتمدة لم تُصرف بعدُ لا تُخصم من راتب.
  Future<HrReceipt> disburseAdvance({required String advanceId, String? note});

  Future<HrReceipt> cancelAdvance({required String advanceId, String? note});

  Future<List<HrAdjustment>> loadAdjustments({
    String? status,
    String? staffId,
    String? sourceType,
    int limit = 60,
  });

  /// تسوية يدوية. `quantity` للأوزان والكميات التي لا تُقوَّم بمبلغ وحده.
  Future<HrReceipt> createAdjustment({
    required String staffId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
    double? quantity,
  });

  Future<HrReceipt> reviewAdjustment({
    required String adjustmentId,
    required bool approve,
    String? note,
  });

  /// العكس تسوية مضادة لا حذف: الصف يبقى والشاشة ترى السبب.
  Future<HrReceipt> reverseAdjustment({
    required String adjustmentId,
    required String reason,
  });

  Future<List<HrDiscrepancy>> loadDiscrepancies({
    String? status,
    String? branchId,
    int limit = 60,
  });

  /// قرار الفرع: `explain` و`reconcile` و`confirm` و`reject` و`deduct` و`close`.
  /// لا يُنشئ أيٌّ منها حسمًا إلا `deduct` بعد `confirm`، وبمبلغ لا يتجاوز الفرق،
  /// وبموظف منسوب غير المراجع، وحين تسمح `hr.settings` بذلك.
  Future<HrDiscrepancy> reviewDiscrepancy({
    required String discrepancyId,
    required String action,
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  });
}
