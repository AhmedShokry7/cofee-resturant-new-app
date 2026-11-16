import 'package:new_coffee/features/design/data/model/published_design.dart';

/// عقدة شاشة مدمجة في أقسام صفحة، بالترتيب المنشور.
///
/// الشاشات المدمجة (الترحيب، التعريف، الدخول) تقرأ من المستند عقدًا بنوع
/// `DesignWidgetTypes` المدمج — صورة الترحيب مثلًا — فتعدّل فوق أصلها:
/// خاصية فارغة أو غائبة تعني «كما هو»، و`visible: false` تعني إخفاء
/// المكوّن الأصلي. أول عقدة بالنوع هي المعتمدة، والبقية تُسقط.
PublishedSection? nativeSection(List<PublishedSection> sections, String type) {
  for (final section in sections) {
    if (section.type == type) return section;
  }
  return null;
}

/// هل عقدة شاشة مدمجة تطلب إخفاء المكوّن الأصلي؟
///
/// غياب العقدة يعني «كما هو» — الإخفاء قرار منشور لا غياب.
bool nativeHidden(PublishedSection? node) => node != null && !node.visible;
