import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// حالات دورة حياة المحرر المرئي.
enum VisualEditorStatus { initial, loading, ready, failure }

/// الحالة الكاملة للمحرر المرئي.
///
/// تحمل قائمة المكوّنات لكل صفحة، والمكوّن المحدد حاليًا، وحالة الاتصال
/// بالمعاينة، ومعرف الجلسة الذي يربط Admin بالـ iframe.
class VisualEditorState {
  const VisualEditorState({
    this.status = VisualEditorStatus.initial,
    this.errorMessage,
    required this.sessionId,
    this.componentsByPage = const {},
    this.selectedComponentId,
    this.selectedComponent,
    this.previewReady = false,
    this.previewUpdatesPending = 0,
    this.previewUrl,
    this.isDirty = false,
    this.conflict,
    this.previewConnection = PreviewConnection.connecting,
    this.previewStatusMessage,
    this.previewLanguage = PreviewLanguage.arabic,
    this.previewThemeMode = PreviewThemeMode.light,
  });

  final VisualEditorStatus status;
  final String? errorMessage;

  /// معرف الجلسة المشترك بين Admin وCustomer Preview.
  final String sessionId;

  /// مكوّنات كل صفحة بمفتاح pageId.
  final Map<String, List<EditableComponent>> componentsByPage;

  /// معرف المكوّن المحدد حاليًا في الشجرة أو المعاينة.
  final String? selectedComponentId;

  /// المكوّن المحدد مع خصائصه الكاملة.
  final EditableComponent? selectedComponent;

  /// هل أرسل الـ iframe رسالة PREVIEW_READY.
  final bool previewReady;

  /// Number of document updates awaiting acknowledgement from the customer
  /// preview. A preview failure clears this status; it does not block saving
  /// or publishing a valid design document.
  final int previewUpdatesPending;

  /// حالة قناة المعاينة كما يراها الموظف — أصدق من مؤشر ثنائي.
  final PreviewConnection previewConnection;

  /// سبب آخر انتقال، لرسالة تشخيص مفهومة تحت المؤشر.
  final String? previewStatusMessage;

  /// عنوان URL للـ iframe (يُبنى وقت التهيئة).
  final String? previewUrl;

  /// لغة تطبيق العميل داخل المعاينة فقط — لا تغيّر لغة لوحة الأدمن ولا
  /// الحفظ المنشور. تُرسل مع كل مستند وفي رابط الإطار عند إعادة تحميله.
  final PreviewLanguage previewLanguage;

  /// الوضع الفاتح/الداكن لتطبيق العميل داخل المعاينة فقط.
  final PreviewThemeMode previewThemeMode;

  /// هل هناك تعديلات لم تُحفظ كمسودة.
  final bool isDirty;

  /// تعارض مراجعة صفحة: القاعدة تحمل نسخة أحدث من مرجع المحرّر.
  /// الحوار المعروض للموظف يقرر: تحميل نسخة القاعدة أو الإجبار.
  final PageConflict? conflict;

  VisualEditorState copyWith({
    VisualEditorStatus? status,
    String? errorMessage,
    String? sessionId,
    Map<String, List<EditableComponent>>? componentsByPage,
    String? selectedComponentId,
    EditableComponent? selectedComponent,
    bool? previewReady,
    int? previewUpdatesPending,
    String? previewUrl,
    bool? isDirty,
    PageConflict? conflict,
    PreviewConnection? previewConnection,
    String? previewStatusMessage,
    PreviewLanguage? previewLanguage,
    PreviewThemeMode? previewThemeMode,
    bool clearError = false,
    bool clearSelectedComponent = false,
    bool clearPreviewStatusMessage = false,
    bool clearConflict = false,
  }) => VisualEditorState(
    status: status ?? this.status,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    sessionId: sessionId ?? this.sessionId,
    componentsByPage: componentsByPage ?? this.componentsByPage,
    selectedComponentId: clearSelectedComponent
        ? null
        : (selectedComponentId ?? this.selectedComponentId),
    selectedComponent: clearSelectedComponent
        ? null
        : (selectedComponent ?? this.selectedComponent),
    previewReady: previewReady ?? this.previewReady,
    previewUpdatesPending: previewUpdatesPending ?? this.previewUpdatesPending,
    previewUrl: previewUrl ?? this.previewUrl,
    isDirty: isDirty ?? this.isDirty,
    conflict: clearConflict ? null : (conflict ?? this.conflict),
    previewConnection: previewConnection ?? this.previewConnection,
    previewStatusMessage: clearPreviewStatusMessage
        ? null
        : (previewStatusMessage ?? this.previewStatusMessage),
    previewLanguage: previewLanguage ?? this.previewLanguage,
    previewThemeMode: previewThemeMode ?? this.previewThemeMode,
  );

  /// هل هناك تعارض مراجعة معروض للموظف.
  bool get hasConflict => conflict != null;

  /// جميع مكوّنات صفحة واحدة بترتيبها العمقي كما هو مخزّن — ترتيب القائمة
  /// المسطّحة هو ترتيب المستند نفسه (الجذر يتبعه أبناءه)، فرز إضافي بالفهرس
  /// يكسر هذا الترتيب بيفصل الأبناء عن أبائهم.
  List<EditableComponent> getComponentsForPage(String pageId) =>
      List<EditableComponent>.from(componentsByPage[pageId] ?? const []);

  /// بحث عن مكوّن بمعرفه في جميع الصفحات.
  EditableComponent? findComponent(String componentId) {
    for (final components in componentsByPage.values) {
      for (final c in components) {
        if (c.componentId == componentId) return c;
      }
    }
    return null;
  }
}

/// تعارض مراجعة صفحة معروض للموظف — مرجع الحوار الذي يقرر المصير:
/// تحميل نسخة القاعدة (تفقد التعديلات المحلية) أو الإجبار فوق المراجعة الأحدث.
class PageConflict {
  const PageConflict({
    required this.pageId,
    required this.serverRevision,
    required this.knownRevision,
  });

  final String pageId;
  final int serverRevision;
  final int knownRevision;
}
