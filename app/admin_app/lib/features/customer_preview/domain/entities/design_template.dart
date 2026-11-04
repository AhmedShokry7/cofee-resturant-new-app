/// قالب تصميم حفظه الموظف من المحرّر.
///
/// الصف يحمل المستند كاملًا، لكن اللوحة تعرض الاسم والتاريخ دونهما: قائمة
/// بأربعين قالبًا تجرّ أربعين شجرة هي أبطأ طريقة لعرض أربعين اسمًا — نفس ما
/// تفعله قائمة الإصدارات.
class DesignTemplate {
  const DesignTemplate({
    required this.id,
    required this.name,
    required this.schemaVersion,
    required this.updatedAt,
  });

  /// معرّف الصف كما ترجعه القاعدة؛ به تُقرأ نسخة القالب وبه تُحذف.
  final String id;

  /// كما كتبه صاحبه، بلا ترجمة مخترعة.
  final String name;

  /// نسخة المستند المحفوظ، للقول هل يقرأه هذا الباني أم لا.
  final int schemaVersion;

  final DateTime updatedAt;
}
