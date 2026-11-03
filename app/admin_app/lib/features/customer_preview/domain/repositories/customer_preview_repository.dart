import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';

/// ما تقرأه المعاينة ولا تملك اللوحة عقدًا له أصلًا.
///
/// الباقات والبنرات والكتالوج تُقرأ من عقود صفحات الإدارة نفسها، فلا استعلام
/// مكرر في التطبيق لقاعدة واحدة. هذا العقد للجزء الذي لا تقرأه اللوحة من قبل:
/// شريط «الأكثر طلبًا» كما يرتبه الصف، وحرارة المكان الذي تقوم عليه توصيات
/// الزبون.
abstract interface class CustomerPreviewRepository {
  /// شريط «الأكثر طلبًا»: `public.get_featured(p_branch_id, p_limit)`.
  ///
  /// الترتيب قرار القاعدة لا القرار هنا — يمزج المثبّت يدويًا بالأكثر مبيعًا
  /// ويرجع كل صف بسعره المحسوب عند الفرع، فلا تُعيد المعاينة حساب الخصم.
  Future<List<PreviewProduct>> loadFeatured({String? branchId, int limit});

  /// الحرارة عند إحداثيات الفرع، من Open-Meteo بلا مفتاح.
  ///
  /// الزبون يسأل جهازه عن موقعه؛ اللوحة لا جهاز زبون أمامها، فأقرب مصدر ثقة
  /// لها هو إحداثيات الفرع المحفوظة في صفّه. يرمي التنفيذ عند تعذّر القراءة،
  /// فتسقط المعاينة إلى بلا طقس كما يسقط تطبيق الزبون إلى بلا مقطع موسمي.
  Future<double> loadTemperature({
    required double latitude,
    required double longitude,
  });
}
