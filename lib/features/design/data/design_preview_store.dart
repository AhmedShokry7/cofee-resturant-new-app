import 'package:flutter/foundation.dart';

/// مستند المعاينة الذي يدفع محرّر الأدمن إلى الهاتف.
///
/// هذا المتجر حصري لوضع المعاينة (main_preview.dart داخل إطار لوحة الأدمن).
/// لا يحتاجه الإنتاج إطلاقًا: قيمته null، والقارئ يكمل مصدره المعتاد من القاعدة.
///
/// لماذا طبقة بدل أن يكتب Cubit المستند مباشرة؟ لأن المعاينة يجب أن تمرّ عبر
/// خط الأنابيب نفسه الذي يرسم الهاتف به يوم النشر — تطبيق الطبقة، وإعادة بناء
/// الشاشة، وحالة `isLoaded` — حتى لا يرى الموظف في اللوحة شيئًا يرسمه الزبون
/// بطريقة أخرى. التطبيق هنا استدعائي بحت: لا يحفظ ولا يقرأ شبكة.
class DesignPreviewStore {
  DesignPreviewStore._();

  static final DesignPreviewStore instance = DesignPreviewStore._();

  final ValueNotifier<Map<String, dynamic>?> _document =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// المستند الجاري معاينته، أو null حين لا معاينة.
  Map<String, dynamic>? get document => _document.value;

  /// هل المعاينة تدفع مستندًا الآن.
  bool get hasOverride => _document.value != null;

  /// يقيم مستند المعاينة (أو يمسحه بـ null) ويبلغ المستمعين.
  void setDocument(Map<String, dynamic>? document) {
    _document.value = document;
  }

  Listenable get listenable => _document;
}
