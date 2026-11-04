import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_template.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';

/// قراءة ونشر مستند تصميم تطبيق العميل.
///
/// المسار واحد: اللوحة والزبون يقرآن نفس الصف، فلا نسخة في التطبيق ولا في
/// التخزين المحلي. النشر عند القاعدة ذرّيًا وبعدها تُقفل الصلاحيات على من يملك
/// «تحرير التصميم» و«نشره»، لا على زرّ مخفي في الواجهة.
abstract interface class AppBuilderRepository {
  /// المسودة المحفوظة، أو null حين لم يُحرَّر شيء بعد.
  Future<DesignDocument?> loadDraft();

  /// التصميم الذي يراه الزبون الآن، أو null حين لا منشور بعد.
  Future<DesignDocument?> loadPublished();

  /// الإصدارات المنشورة، أحدثها أولًا، بلا ملفّاتها الثقيلة.
  Future<List<DesignVersion>> loadVersions();

  /// ملفّ إصدار واحد، لاستعراضه في المعاينة قبل الرجوع إليه.
  Future<DesignDocument?> loadVersion(String versionId);

  /// حفظ المسودة: لا تمسّ ما يراه الزبون.
  Future<void> saveDraft(DesignDocument document);

  /// نشر بعد أن وافق الخادم على المخطط والنسخة، فيرجع الإصدار الجديد.
  Future<DesignVersion> publish(DesignDocument document);

  /// رجوع: إعادة نشر ملفّ إصدار سابق، برقم جديد حتى يبقى السجل صادقًا.
  Future<DesignVersion> restoreVersion(String versionId);

  /// تجاهل المسودة والرجوع إلى المنشور.
  Future<void> discardDraft();

  /// القوالب التي حفظها الموظف، أحدثها أولًا، بأسمائها لا بملفّاتها.
  Future<List<DesignTemplate>> loadTemplates();

  /// مستند قالب واحد، حين يقرّر الموظف أن يفتحه.
  Future<DesignDocument?> loadTemplate(String id);

  /// حفظ قالب باسم: بـ[templateId] يُستبدل قالب موجود، وبلاّه يُنشأ جديد.
  /// ترفض القاعدة مستندًا لا يُنشر، فلا يقعد في المعرض قالب يعطب عند النشر.
  Future<DesignTemplate> saveTemplate(
    String name,
    DesignDocument document, {
    String? templateId,
  });

  Future<void> deleteTemplate(String id);
}
