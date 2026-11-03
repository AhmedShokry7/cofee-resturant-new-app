/// إصدار منشور واحد من تصميم تطبيق العميل.
///
/// المحرّر ينشر نسخة كاملة ولا يبدّل صفًا: رقم الإصدار يتزايد، والرجوع إصدارًا
/// سابقًا إعادة نشر لملفّه كما هو، فلا يُترك التطبيق بين شكلين نصفين.
class DesignVersion {
  const DesignVersion({
    required this.id,
    required this.number,
    required this.publishedAt,
    required this.schemaVersion,
    this.note,
  });

  final String id;

  /// الرقم المطبوع للوحة: «الإصدار ٧» لا معرّف قاعدة.
  final int number;

  final DateTime publishedAt;

  /// نسخة مخطط المستند المنشور؛ تطبيق عميل لا يعرفها يرث ما قبله.
  final int schemaVersion;

  final String? note;
}
