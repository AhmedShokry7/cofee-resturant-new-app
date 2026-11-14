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
    this.previewUrl,
    this.isDirty = false,
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

  /// عنوان URL للـ iframe (يُبنى وقت التهيئة).
  final String? previewUrl;

  /// هل هناك تعديلات لم تُحفظ كمسودة.
  final bool isDirty;

  VisualEditorState copyWith({
    VisualEditorStatus? status,
    String? errorMessage,
    String? sessionId,
    Map<String, List<EditableComponent>>? componentsByPage,
    String? selectedComponentId,
    EditableComponent? selectedComponent,
    bool? previewReady,
    String? previewUrl,
    bool? isDirty,
    bool clearError = false,
    bool clearSelectedComponent = false,
  }) =>
      VisualEditorState(
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
        previewUrl: previewUrl ?? this.previewUrl,
        isDirty: isDirty ?? this.isDirty,
      );

  /// جميع مكوّنات صفحة واحدة مرتبة بحسب الـ index.
  List<EditableComponent> getComponentsForPage(String pageId) {
    final list = List<EditableComponent>.from(
      componentsByPage[pageId] ?? const [],
    );
    list.sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

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
