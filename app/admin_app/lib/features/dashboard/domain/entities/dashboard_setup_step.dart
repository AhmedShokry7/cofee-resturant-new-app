/// خطوة واحدة من خطوات بداية المتجر، كما تقيسها القاعدة.
///
/// المفتاح كلمة ثابتة ترسلها `admin_dashboard_metrics` (ترحيلة ٢٠٤) والنصّ
/// يملكه العرض وحده: القاعدة تعرف «هل وُجد منتج نشط»، أمّا «أضف أول منتج»
/// فعبارة تُترجم وتُعدَّل بلا ترحيلة. ولا خطوة هنا تُعلَّم «تمت» بيد الأدمن —
/// كل واحدة تُقرأ من جدول حقيقي، فلا عدّاد يُكذب على صاحبه.
class DashboardSetupStep {
  const DashboardSetupStep({required this.key, required this.done});

  /// أحد مفاتيح ٢٠٤: first_product، branch_image، revenue_target، first_order.
  final String key;
  final bool done;
}
