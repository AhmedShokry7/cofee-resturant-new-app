import 'dart:typed_data';

import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_draft.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_metrics.dart';
import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/domain/entities/branch_save_outcome.dart';

/// عقد قراءة الفروع ومؤشراتها وكتابة بياناتها وصورها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class BranchRepository {
  /// يقرأ كل فرع بعدد موظفيه ومناطقه وطلباته.
  Future<List<AdminBranch>> loadBranches();

  /// يقرأ مؤشرات شاشة الفروع.
  Future<AdminBranchMetrics> loadMetrics();

  /// يحفظ فرعًا جديدًا أو تعديل فرع ويعيد نتيجة القاعدة.
  Future<BranchSaveOutcome> saveBranch(AdminBranchDraft draft);

  /// يفعّل الفرع أو يعطّله ويعيد نتيجة العملية.
  Future<BranchMutationOutcome> setBranchActive(String branchId, bool active);

  /// يحذف فرعًا ويعيد نتيجة العملية.
  Future<BranchMutationOutcome> deleteBranch(String branchId);

  /// يربط الفرع برابط صورته أو يمسحه ويعيد نتيجة العملية.
  Future<BranchMutationOutcome> setBranchImage(
    String branchId,
    String? imageUrl,
  );

  /// يرفع صورة الفرع ثم يربطها به، ويعيد نتيجة الربط.
  Future<BranchMutationOutcome> uploadBranchImage({
    required String branchId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  });

  /// يحذف ملف الصورة الذي لم يعد الفرع يستخدمه.
  Future<void> deleteBranchImageFile(String? imageUrl);
}
