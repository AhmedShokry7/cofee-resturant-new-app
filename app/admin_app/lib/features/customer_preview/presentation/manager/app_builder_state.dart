import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_validator.dart';

/// هل المحرّر يبني أم يشاهد؟
///
/// المشاهدة هي وضع الزبون: نقرات التنقل تعمل، ولا كتابة على بيانات أحد — لا
/// سلة تُضاف ولا طلب يُمرّ. التحرير وحده هو الذي يحرّك الشجرة.
enum AppBuilderMode { edit, preview }

/// أي مستند يُعرض داخل الهاتف: المسودة، أم المنشور، أم ملفّ إصدار قديم.
enum AppBuilderSource { draft, published, version }

enum AppBuilderStatus { loading, ready, failure }

/// حالة محرّر التصميم: شجرة، تحديد، سجل تراجع، ونشر.
class AppBuilderState {
  const AppBuilderState({
    this.status = AppBuilderStatus.loading,
    this.document,
    this.draftSaved,
    this.published,
    this.versions = const <DesignVersion>[],
    this.versionDocument,
    this.page = AppPage.home,
    this.selectedId,
    this.mode = AppBuilderMode.edit,
    this.source = AppBuilderSource.draft,
    this.canUndo = false,
    this.canRedo = false,
    this.isSaving = false,
    this.isPublishing = false,
    this.errorMessage,
  });

  final AppBuilderStatus status;

  /// ما يُحرَّر الآن: المسودة، أو نسخة منها بعد الرجوع إلى إصدار.
  final DesignDocument? document;

  /// آخر مسودة وصلت إلى القاعدة، لقياس «غير محفوظ».
  final DesignDocument? draftSaved;

  /// التصميم المنشور الذي يراه الزبون، وnull يعني لا منشور بعد.
  final DesignDocument? published;

  final List<DesignVersion> versions;

  /// ملفّ الإصدار المحدد في القائمة، لعرضه قبل الرجوع إليه.
  final DesignDocument? versionDocument;

  final AppPage page;

  /// العقدة المحددة في اللوحة والشجرة معًا؛ null يعني لا تحديد.
  final String? selectedId;

  final AppBuilderMode mode;
  final AppBuilderSource source;

  final bool canUndo;
  final bool canRedo;
  final bool isSaving;
  final bool isPublishing;
  final String? errorMessage;

  bool get isReady => status == AppBuilderStatus.ready;

  bool get isPreview => mode == AppBuilderMode.preview;

  /// المستند المعروض داخل الهاتف، بحسب [source]، مع رجوع آمن إلى المسودة حين
  /// لا منشور بعد: لا شاشة فارغة لأن الموظف ضغط «المنشور» قبل أول نشر.
  DesignDocument? get shown {
    switch (source) {
      case AppBuilderSource.published:
        return published ?? document;
      case AppBuilderSource.version:
        return versionDocument ?? document;
      case AppBuilderSource.draft:
        return document;
    }
  }

  DesignNode? get root => shown?.rootOf(page);

  DesignNode? get selected {
    final current = root;
    final id = selectedId;
    if (current == null || id == null) return null;
    return DesignTree.find(current, id);
  }

  /// ما لم يُحفظ بعد: مقارنة بالمحتوى، لا بعلامة تعديل تُنسى.
  bool get isDirty {
    final current = document;
    if (current == null) return false;
    return !current.hasSameContent(draftSaved);
  }

  /// التدقيق يُعاد مع كل عرض، لأن النشر لا يُسمح به وشجرة واحدة غير صالحة.
  DesignValidation? get validation {
    final current = document;
    if (current == null) return null;
    return DesignValidator.validate(current);
  }

  bool get canPublish => validation?.isPublishable ?? false;

  DesignVersion? get latestVersion => versions.isEmpty ? null : versions.first;

  AppBuilderState copyWith({
    AppBuilderStatus? status,
    DesignDocument? document,
    DesignDocument? draftSaved,
    bool clearDraftSaved = false,
    DesignDocument? published,
    bool clearPublished = false,
    List<DesignVersion>? versions,
    DesignDocument? versionDocument,
    bool clearVersionDocument = false,
    AppPage? page,
    String? selectedId,
    bool clearSelection = false,
    AppBuilderMode? mode,
    AppBuilderSource? source,
    bool? canUndo,
    bool? canRedo,
    bool? isSaving,
    bool? isPublishing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppBuilderState(
      status: status ?? this.status,
      document: document ?? this.document,
      draftSaved: clearDraftSaved ? null : (draftSaved ?? this.draftSaved),
      published: clearPublished ? null : (published ?? this.published),
      versions: versions ?? this.versions,
      versionDocument: clearVersionDocument
          ? null
          : (versionDocument ?? this.versionDocument),
      page: page ?? this.page,
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      mode: mode ?? this.mode,
      source: source ?? this.source,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isSaving: isSaving ?? this.isSaving,
      isPublishing: isPublishing ?? this.isPublishing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
