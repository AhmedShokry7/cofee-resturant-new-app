import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_state.dart';

export 'visual_editor_state.dart';

/// يدير حالة المحرر المرئي ويرسل الأوامر إلى معاينة Customer App عبر الـ Bridge.
///
/// لا يصدر أوامر مباشرة للـ iframe؛ بل يغيّر الحالة وتلتقطها [PreviewPanel]
/// لترسلها عبر postMessage. كل تعديل تركيبي يترك أثرًا في مكدس التراجع،
/// ويُحفظ مؤجلًا كمسودة عبر الـ RPC، ويُنشر بعد تدقيق محلي ثم تدقيق القاعدة.
class VisualEditorCubit extends Cubit<VisualEditorState> {
  VisualEditorCubit({VisualEditorRepository? repository})
      : super(
          VisualEditorState(
            sessionId: _generateSessionId(),
          ),
        ) {
    _repository = repository ?? SupabaseVisualEditorRepository();
    ComponentRegistry.initialize();
    ComponentRegistry.all.forEach(DesignDocumentCodec.registerEntry);
  }

  late final VisualEditorRepository _repository;

  /// آخر رسالة صادرة للـ iframe — تلتقطها PreviewPanel بمراقبة الـ state.
  OutboundMessage? _pendingMessage;

  OutboundMessage? get pendingMessage => _pendingMessage;

  /// مكدسا التراجع والإعادة: لقطات كاملة لـ componentsByPage. حجم الشجرة
  /// صغير (سقف 400 عقدة بصفحة في العقد الحي)، واللقطات الكاملة أصدق من
  /// diffs هشّة على الحقول.
  final List<Map<String, List<EditableComponent>>> _undoStack = [];
  final List<Map<String, List<EditableComponent>>> _redoStack = [];

  /// طبقة الشكل الحالية للمسودة.
  DesignTheme _theme = DesignTheme.none;

  /// مؤجل الحفظ: تعديلات متتالية تكتب مسودة واحدة.
  Timer? _saveDebounce;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  DesignTheme get theme => _theme;

  static String _generateSessionId() {
    final rand = math.Random();
    return 've_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(9999)}';
  }

  // ---------- دورة حياة ----------

  /// تهيئة المحرر: يقرأ المسودة المحفوظة؛ بلا مسودة يبدأ من «تصميم اليوم»
  /// — ترتيب الصفحة كما في مصدر العميل، لا شجرة فارغة تدّعي لا شيء.
  Future<void> initialize() async {
    emit(state.copyWith(status: VisualEditorStatus.loading, clearError: true));
    try {
      final draft = await _repository.loadDraft();
      _theme = draft?.theme ?? DesignTheme.none;
      final components = draft?.componentsByPage ??
          {'home': DesignDocumentCodec.defaultHomeComponents()};
      emit(
        state.copyWith(
          componentsByPage: components,
          status: VisualEditorStatus.ready,
          isDirty: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: VisualEditorStatus.failure,
          errorMessage: 'تعذر تهيئة المحرر: $e',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _saveDebounce?.cancel();
    return super.close();
  }

  // ---------- معالجة رسائل المعاينة الواردة ----------

  /// المعاينة أعلنت جاهزيتها: نسلّمها المستند الحالي (إن وُجد) لترسم فورًا.
  void handlePreviewReady(dynamic data) {
    emit(state.copyWith(previewReady: true));
    final document = _currentDocumentOrNull();
    _dispatchToPreview(
      VisualEditorMessageType.previewInitialize,
      {
        'sessionId': state.sessionId,
        if (document != null) 'designDocument': document,
      },
    );
  }

  /// خطأ من المعاينة.
  void handlePreviewError(dynamic data) {
    final msg = data is Map ? data['error'] ?? 'خطأ في المعاينة' : 'خطأ في المعاينة';
    emit(
      state.copyWith(
        status: VisualEditorStatus.failure,
        errorMessage: msg.toString(),
      ),
    );
  }

  /// المستخدم ضغط على عنصر داخل المعاينة.
  void handleElementSelected(dynamic data) {
    if (data is! Map) return;
    final componentId = data['componentId'] as String?;
    if (componentId == null) return;
    final component = state.findComponent(componentId);
    if (component == null) return;
    emit(
      state.copyWith(
        selectedComponentId: componentId,
        selectedComponent: component,
      ),
    );
  }

  /// المعاينة أكدت تطبيق رسالة تحرير — الرسالة وصلت، والمحرّر يبقى مصدر
  /// الحقيقة لحالة المستند، فلا حالة إضافية يلزم تسجيلها هنا.
  void handlePropertyUpdated(dynamic data) {}

  /// المعاينة بثّت حالتها — تُزامن لوحة الطبقات مع ما يرسمه الهاتف فعليًا.
  void handleTreeUpdated(dynamic data) {
    if (data is! Map) return;
    final pageId = data['pageId'];
    final nodes = data['nodes'];
    if (pageId is! String || nodes is! List) return;
    // الشجرة الواردة تُسقط الأنواع التي لا يرسمها الهاتف؛ هذه معلومة لا
    // مرساة: لوحة الطبقات تبقى على مكوّنات المحرّر، والمزامنة تُسجّل فقط.
  }

  // ---------- تراجع وإعادة ----------

  void _pushUndo() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > _maxUndoDepth) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  static const int _maxUndoDepth = 50;

  Map<String, List<EditableComponent>> _snapshot() => {
    for (final entry in state.componentsByPage.entries)
      entry.key: List<EditableComponent>.from(entry.value),
  };

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    final previous = _undoStack.removeLast();
    emit(
      state.copyWith(
        componentsByPage: previous,
        isDirty: true,
      ),
    );
    _syncPreview();
    _scheduleSave();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    final next = _redoStack.removeLast();
    emit(
      state.copyWith(
        componentsByPage: next,
        isDirty: true,
      ),
    );
    _syncPreview();
    _scheduleSave();
  }

  /// تراجع عن كل ما لم يُنشر: الرجوع إلى ما يراه الزبون اليوم.
  Future<void> discardDraft() async {
    _undoStack.clear();
    _redoStack.clear();
    _saveDebounce?.cancel();
    emit(
      state.copyWith(
        status: VisualEditorStatus.loading,
        clearError: true,
      ),
    );
    await initialize();
  }

  // ---------- تحديث طبقة الشكل ----------

  /// تحديث دور لون أو مقياس في طبقة المسودة.
  void updateTheme(DesignTheme theme) {
    _theme = theme;
    emit(state.copyWith(isDirty: true));
    _syncPreview();
    _scheduleSave();
  }

  // ---------- تنقل الصفحات ----------

  /// تحميل صفحة جديدة في المعاينة.
  void loadPage(String pageId) {
    _dispatchToPreview(
      VisualEditorMessageType.loadPage,
      {'pageId': pageId},
    );
  }

  // ---------- تحديد المكوّنات ----------

  /// تحديد مكوّن من شجرة الطبقات — يرسل SELECT_ELEMENT للمعاينة أيضًا.
  void selectComponent(String componentId) {
    final component = state.findComponent(componentId);
    emit(
      state.copyWith(
        selectedComponentId: componentId,
        selectedComponent: component,
      ),
    );
    _dispatchToPreview(
      VisualEditorMessageType.selectElement,
      {'componentId': componentId},
    );
  }

  // ---------- إضافة وحذف ونسخ ----------

  /// إضافة مكوّن جديد من المكتبة.
  void addComponent({
    required String pageId,
    required String componentType,
    String? parentId,
    int? index,
  }) {
    final entry = ComponentRegistry.get(componentType);
    if (entry == null) return;
    final pageComponents = List<EditableComponent>.from(
      state.componentsByPage[pageId] ?? [],
    );
    final newComponent = EditableComponent(
      componentId:
          '${pageId}_${componentType}_${DateTime.now().millisecondsSinceEpoch}',
      componentType: componentType,
      pageId: pageId,
      parentId: parentId,
      index: index ?? pageComponents.length,
      classification: entry.classification,
      properties: Map<String, dynamic>.from(entry.defaultValues)
        ..['visible'] = true,
      defaultValues: entry.defaultValues,
      validationRules: entry.validationRules,
      allowedOperations: entry.allowedOperations,
      version: 1,
    );
    _pushUndo();
    final updated = [...pageComponents, newComponent];
    _updatePage(pageId, updated);
    _dispatchToPreview(
      VisualEditorMessageType.addComponent,
      {
        'pageId': pageId,
        'component': DesignDocumentCodec.node(newComponent),
        'designDocument': _currentDocumentOrNull(),
      },
    );
    _scheduleSave();
  }

  /// حذف مكوّن — محمي من حذف العناصر التي لا تحمل 'delete' في allowedOperations.
  void deleteComponent(String componentId) {
    final component = state.findComponent(componentId);
    if (component == null) return;
    if (!component.canDelete) return;
    _pushUndo();
    final updatedPages = <String, List<EditableComponent>>{};
    state.componentsByPage.forEach((pageId, components) {
      updatedPages[pageId] =
          components.where((c) => c.componentId != componentId).toList();
    });
    final wasSelected = state.selectedComponentId == componentId;
    emit(
      state.copyWith(
        componentsByPage: updatedPages,
        isDirty: true,
        clearSelectedComponent: wasSelected,
      ),
    );
    _dispatchToPreview(
      VisualEditorMessageType.removeComponent,
      {
        'componentId': componentId,
        'designDocument': _currentDocumentOrNull(),
      },
    );
    _scheduleSave();
  }

  /// نسخ مكوّن وإدراجه بعده مباشرة.
  void duplicateComponent(String componentId) {
    final component = state.findComponent(componentId);
    if (component == null || !component.canDuplicate) return;
    final pageComponents = List<EditableComponent>.from(
      state.componentsByPage[component.pageId] ?? [],
    );
    final oldIndex =
        pageComponents.indexWhere((c) => c.componentId == componentId);
    if (oldIndex < 0) return;
    _pushUndo();
    final newComponent = component.copyWith(
      componentId:
          '${component.pageId}_${component.componentType}_${DateTime.now().millisecondsSinceEpoch}',
      index: oldIndex + 1,
      version: component.version + 1,
    );
    final updated = List<EditableComponent>.from(pageComponents)
      ..insert(oldIndex + 1, newComponent);
    _updatePage(component.pageId, _reindex(updated));
    _dispatchToPreview(VisualEditorMessageType.addComponent, {
      'pageId': component.pageId,
      'component': DesignDocumentCodec.node(newComponent),
      'index': oldIndex + 1,
      'designDocument': _currentDocumentOrNull(),
    });
    _scheduleSave();
  }

  // ---------- إعادة الترتيب ----------

  /// إعادة ترتيب مكوّن إلى موضع جديد.
  void reorderComponent(String componentId, int newIndex) {
    final component = state.findComponent(componentId);
    if (component == null || !component.canReorder) return;
    final pageComponents = List<EditableComponent>.from(
      state.componentsByPage[component.pageId] ?? [],
    );
    final oldIndex =
        pageComponents.indexWhere((c) => c.componentId == componentId);
    if (oldIndex < 0) return;
    _pushUndo();
    final item = pageComponents.removeAt(oldIndex);
    final clamped = newIndex.clamp(0, pageComponents.length);
    pageComponents.insert(clamped, item);
    _updatePage(component.pageId, _reindex(pageComponents));
    _dispatchToPreview(VisualEditorMessageType.reorderComponent, {
      'componentId': componentId,
      'newIndex': clamped,
      'designDocument': _currentDocumentOrNull(),
    });
    _scheduleSave();
  }

  // ---------- إظهار وإخفاء ----------

  /// تبديل حالة ظهور مكوّن.
  void toggleComponentVisibility(String componentId) {
    final component = state.findComponent(componentId);
    if (component == null) return;
    final current = component.properties['visible'] as bool? ?? true;
    updateProperty(
      componentId: componentId,
      propertyKey: 'visible',
      value: !current,
    );
  }

  // ---------- خصائص ----------

  /// تحديث خاصية مكوّن محدد، بتدقيق قواعد السجل أولًا.
  void updateProperty({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  }) {
    final component = state.findComponent(componentId);
    if (component == null) return;
    if (!_isValidValue(component, propertyKey, value)) return;
    _pushUndo();
    final updatedProps = Map<String, dynamic>.from(component.properties)
      ..[propertyKey] = value;
    final updatedComponent = component.copyWith(properties: updatedProps);
    _replaceComponent(updatedComponent);
    _dispatchToPreview(VisualEditorMessageType.updateProperty, {
      'componentId': componentId,
      'propertyKey': propertyKey,
      'value': value,
      'designDocument': _currentDocumentOrNull(),
    });
    _scheduleSave();
  }

  bool _isValidValue(EditableComponent component, String key, Object? value) {
    final definition = ComponentRegistry
        .getEditableProperties(component.componentType)[key];
    if (definition == null) return key == 'visible';
    final validation = definition.validation;
    if (validation == null) return true;
    final min = validation['min'];
    final max = validation['max'];
    if (value is num) {
      if (min is num && value < min) return false;
      if (max is num && value > max) return false;
    }
    return true;
  }

  /// إعادة خاصية لقيمتها الافتراضية.
  void resetProperty({
    required String componentId,
    required String propertyKey,
  }) {
    final component = state.findComponent(componentId);
    if (component == null) return;
    final defaultValue = component.defaultValues[propertyKey];
    if (defaultValue == null) {
      if (propertyKey == 'visible') {
        updateProperty(
          componentId: componentId,
          propertyKey: 'visible',
          value: true,
        );
      }
      return;
    }
    updateProperty(
      componentId: componentId,
      propertyKey: propertyKey,
      value: defaultValue,
    );
  }

  // ---------- حفظ ونشر ----------

  /// حفظ مؤجل: تعديلات متتالية تكتب مسودة واحدة بعد سكون قصير.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDelay, () {
      if (!isClosed && state.isDirty) {
        saveDraft();
      }
    });
  }

  static const Duration _saveDebounceDelay = Duration(milliseconds: 800);

  Future<void> saveDraft() async {
    _saveDebounce?.cancel();
    try {
      await _repository.saveDraft(state.componentsByPage, theme: _theme);
      if (isClosed) return;
      emit(state.copyWith(isDirty: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          errorMessage: 'تعذر حفظ المسودة: $e',
        ),
      );
    }
  }

  /// نشر التصميم بعد تدقيق محلي. يرفض قبل أن ترفض القاعدة.
  Future<PublishedVersionInfo?> publish({String? note}) async {
    final document = _currentDocumentOrNull();
    if (document == null) {
      emit(
        state.copyWith(
          errorMessage: 'لا يوجد تصميم لنشره — أضف مكوّنًا أولًا',
        ),
      );
      return null;
    }
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      emit(
        state.copyWith(
          errorMessage: 'المستند غير صالح للنشر: $invalid',
        ),
      );
      return null;
    }
    try {
      final version = await _repository.publishDesign(document, note: note);
      if (isClosed) return version;
      emit(state.copyWith(isDirty: false, clearError: true));
      return version;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          errorMessage: 'تعذر النشر: $e',
        ),
      );
      return null;
    }
  }

  // ---------- سجل الإصدارات ----------

  /// تاريخ الإصدارات المنشورة، الأحدث أولًا.
  Future<List<PublishedVersionInfo>> loadVersions({int limit = 30}) =>
      _repository.listVersions(limit: limit);

  /// مستند إصدار سابق، لمعاينته قبل الاسترجاع.
  Future<Map<String, dynamic>?> versionDocument(String versionId) =>
      _repository.getVersionDocument(versionId);

  /// استرجاع إصدار سابق: إصدار جديد في السجل، والمسودة المحلية تتبعه.
  Future<PublishedVersionInfo?> restoreVersion(String versionId) async {
    try {
      final version = await _repository.restoreVersion(versionId);
      if (isClosed) return version;
      final document = await _repository.getVersionDocument(versionId);
      final components = DesignDocumentCodec.parseDocument(document);
      _pushUndo();
      _theme = document == null
          ? DesignTheme.none
          : DesignDocumentCodec.themeOf(document);
      emit(
        state.copyWith(
          componentsByPage: components,
          isDirty: false,
          clearError: true,
        ),
      );
      _syncPreview();
      return version;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          errorMessage: 'تعذر استرجاع الإصدار: $e',
        ),
      );
      return null;
    }
  }

  // ---------- الأدوات الداخلية ----------

  void _updatePage(String pageId, List<EditableComponent> components) {
    emit(
      state.copyWith(
        componentsByPage: {
          ...state.componentsByPage,
          pageId: components,
        },
        isDirty: true,
      ),
    );
  }

  void _replaceComponent(EditableComponent updated) {
    final updatedPages = <String, List<EditableComponent>>{};
    state.componentsByPage.forEach((pageId, components) {
      updatedPages[pageId] = components
          .map((c) => c.componentId == updated.componentId ? updated : c)
          .toList();
    });
    emit(
      state.copyWith(
        componentsByPage: updatedPages,
        selectedComponent:
            state.selectedComponent?.componentId == updated.componentId
                ? updated
                : state.selectedComponent,
        isDirty: true,
      ),
    );
  }

  List<EditableComponent> _reindex(List<EditableComponent> components) {
    return [
      for (var i = 0; i < components.length; i++)
        components[i].copyWith(index: i),
    ];
  }

  /// المستند الحالي كاملًا، أو null حين لا مكوّنات (لا نشر ولا إرسال فارغ).
  Map<String, dynamic>? _currentDocumentOrNull() {
    if (state.componentsByPage.isEmpty) return null;
    final hasContent = state.componentsByPage.values.any((c) => c.isNotEmpty);
    if (!hasContent) return null;
    return DesignDocumentCodec.document(
      state.componentsByPage,
      theme: _theme,
    );
  }

  /// إعادة إرسال المستند كاملًا إلى المعاينة — استُعمل بعد تراجع/استرجاع،
  /// حيث لا تكفي رسالة دلتا واحدة.
  void _syncPreview() {
    final document = _currentDocumentOrNull();
    if (document == null) return;
    _dispatchToPreview(
      VisualEditorMessageType.applyDesignConfig,
      {'designDocument': document},
    );
  }

  /// يضع رسالة صادرة في الحالة حتى تلتقطها PreviewPanel وترسلها عبر postMessage.
  void _dispatchToPreview(
    VisualEditorMessageType type,
    Map<String, dynamic> payload,
  ) {
    _pendingMessage = OutboundMessage(
      type: type,
      payload: payload,
      sessionId: state.sessionId,
      messageId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    // إعادة emit للحالة الحالية حتى يُبلَّغ الـ PreviewPanel بالتغيير
    emit(state.copyWith());
  }
}

/// رسالة صادرة ريثما تلتقطها PreviewPanel.
class OutboundMessage {
  const OutboundMessage({
    required this.type,
    required this.payload,
    required this.sessionId,
    required this.messageId,
  });

  final VisualEditorMessageType type;
  final Map<String, dynamic> payload;
  final String sessionId;
  final String messageId;
}
