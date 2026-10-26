import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';

/// نتيجة تعديل مراجعة (نشر أو حذف) كما تعيدها القاعدة.
enum ReviewMutationOutcome { success, notFound, failed }

/// عقد قراءة المراجعات وكتابة حالة النشر والحذف.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class ReviewRepository {
  /// يقرأ كل المراجعات بترتيب القاعدة.
  Future<List<AdminReview>> loadReviews();

  /// يقرأ ملخص مؤشرات المراجعات.
  Future<AdminReviewMetrics> loadMetrics();

  /// ينشر المراجعة أو يخفيها ويعيد نتيجة العملية.
  Future<ReviewMutationOutcome> setPublished(String reviewId, bool published);

  /// يحذف المراجعة ويعيد نتيجة العملية.
  Future<ReviewMutationOutcome> deleteReview(String reviewId);
}
