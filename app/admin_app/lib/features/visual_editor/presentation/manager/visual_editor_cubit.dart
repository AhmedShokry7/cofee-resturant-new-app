import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_state.dart';

export 'visual_editor_state.dart';

/// يدير حالة المحرر المرئي ويرسل الأوامر إلى معاينة Customer App عبر الـ Bridge.
///
/// لا يصدر أوامر مباشرة للـ iframe؛ بل يغيّر الحالة وتلتقطها [PreviewPanel]
/// لترسلها عبر postMessage. كل تعديل تركيبي أو في طبقة الشكل يترك أثرًا في
/// مكدس التراجع ويحدّث المعاينة الحية؛ لا تُكتب المسودة إلا بطلب حفظ صريح.
/// النشر يمرّ بتدقيق محلي ثم تدقيق القاعدة، والقوالب تطبّق على الحالة المحلية.
class VisualEditorCubit extends Cubit<VisualEditorState> {
  VisualEditorCubit({VisualEditorRepository? repository})
    : super(VisualEditorState(sessionId: _generateSessionId())) {
    _repository = repository ?? SupabaseVisualEditorRepository();
    ComponentRegistry.initialize();
    ComponentRegistry.all.forEach(DesignDocumentCodec.registerEntry);
  }

  late final VisualEditorRepository _repository;

  /// آخر رسالة صادرة للـ iframe — تلتقطها PreviewPanel بمراقبة الـ state.
  OutboundMessage? _pendingMessage;
  final _outbound = <OutboundMessage>[];
  int _messageSequence = 0;
  String _previewPageId = 'home';
  Map<String, dynamic>? _externalPreviewDocument;
  String? _unconfirmedPreviewId;
  Timer? _previewAckTimeout;

  List<OutboundMessage> takePreviewMessages() {
    final messages = List<OutboundMessage>.of(_outbound);
    _outbound.clear();
    return messages;
  }

  OutboundMessage? get pendingMessage => _pendingMessage;

  /// لقطة تراجع كاملة: المكوّنات وطبقة الشكل معًا — التراجع عن لون بلا
  /// ترتيب نصف تراجع، والاثنان يُنشران في مستند واحد.
  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];

  /// طبقة الشكل الحالية للمسودة.
  DesignTheme _theme = DesignTheme.none;

  /// تسلسل عمليات الحفظ اليدوي حتى لا يكتب طلب أقدم بعد الأحدث.
  Future<void> _saveQueue = Future<void>.value();
  int _editRevision = 0;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  DesignTheme get theme => _theme;

  Map<String, dynamic> get currentDesignDocument =>
      DesignDocumentCodec.document(state.componentsByPage, theme: _theme);

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
      if (isClosed) return;
      _theme = draft?.theme ?? DesignTheme.none;
      final saved = draft?.componentsByPage ?? const {};
      // الصفحات الغائبة عن المسودة تبدأ من «تصميم اليوم»: شاشات مدمجة
      // بعقدها الأصلية، وبقية الصفحات بشجرة فارغة يبني عليها الموظف. صفحة
      // في المسودة تبقى كما كُتبت — لا يعاد خلق عقد محوّل عليها.
      final components = <String, List<EditableComponent>>{
        for (final page in EditorPages.pages)
          page.pageId: saved[page.pageId] == null
              ? DesignDocumentCodec.defaultComponentsFor(page.pageId)
              : page.pageId == 'welcome'
              ? DesignDocumentCodec.migrateWelcomeCta(saved[page.pageId]!)
              : saved[page.pageId]!,
      };
      emit(
        state.copyWith(
          componentsByPage: components,
          status: VisualEditorStatus.ready,
          isDirty: false,
        ),
      );
      // PREVIEW_READY may arrive before the draft query completes. In that
      // order the first handshake has no document to send, so push the loaded
      // state now instead of leaving the iframe on the published snapshot.
      if (state.previewReady || draft != null) _syncPreview();
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: VisualEditorStatus.failure,
          errorMessage: 'تعذر تهيئة المحرر: $e',
        ),
      );
    }
  }

  // ---------- معالجة رسائل المعاينة الواردة ----------

  /// المعاينة أعلنت جاهزيتها: نسلّمها المستند الحالي (إن وُجد) لترسم فورًا.
  void handlePreviewReady(dynamic data) {
    emit(
      state.copyWith(
        previewReady: true,
        previewConnection: PreviewConnection.connected,
        clearPreviewStatusMessage: true,
      ),
    );
    final document = _currentDocumentOrNull();
    _dispatchToPreview(VisualEditorMessageType.previewInitialize, {
      'sessionId': state.sessionId,
      'pageId': _previewPageId,
      'designDocument': ?document,
      if (document != null) ...{
        'componentId': '__document__',
        'awaitPreviewAck': true,
      },
      ..._previewSettingsPayload(),
    });
  }

  /// Supplies an in-memory document to the client simulator without importing
  /// it into editor state or writing it to Supabase. Screen management pages
  /// use this to show unsaved changes inside the complete customer app.
  void setExternalPreviewDocument(
    Map<String, dynamic>? document, {
    String? pageId,
  }) {
    if (isClosed) return;
    _externalPreviewDocument = document == null
        ? null
        : (jsonDecode(jsonEncode(document)) as Map).cast<String, dynamic>();
    if (pageId != null) _previewPageId = pageId;
    _syncPreview();
    if (pageId != null && state.previewReady) {
      _dispatchToPreview(VisualEditorMessageType.loadPage, {'pageId': pageId});
    }
  }

  /// تبديل لغة تطبيق العميل داخل المعاينة فقط: لا مسودة ولا تراجع ولا نشر.
  void togglePreviewLanguage() =>
      setPreviewLanguage(state.previewLanguage.other);

  void setPreviewLanguage(PreviewLanguage language) {
    if (isClosed || state.previewLanguage == language) return;
    emit(state.copyWith(previewLanguage: language));
    _dispatchToPreview(VisualEditorMessageType.setLanguage, {
      'language': language.value,
    });
  }

  /// تبديل وضع تطبيق العميل (فاتح/داكن) داخل المعاينة فقط.
  void togglePreviewThemeMode() =>
      setPreviewThemeMode(state.previewThemeMode.other);

  void setPreviewThemeMode(PreviewThemeMode mode) {
    if (isClosed || state.previewThemeMode == mode) return;
    emit(state.copyWith(previewThemeMode: mode));
    _dispatchToPreview(VisualEditorMessageType.setThemeMode, {
      'mode': mode.value,
    });
  }

  /// لوحة المعاينة بلّغت بحالة قناة الاتصال: وصل/جارٍ الاتصال/انقطع/خطأ.
  void updatePreviewConnection(PreviewConnection connection, {String? reason}) {
    if (isClosed) return;
    emit(
      state.copyWith(
        previewReady: connection == PreviewConnection.connected,
        previewConnection: connection,
        previewStatusMessage: reason,
      ),
    );
  }

  /// خطأ من المعاينة.
  void handlePreviewError(dynamic data) {
    _previewAckTimeout?.cancel();
    _unconfirmedPreviewId = null;
    final msg = data is Map
        ? data['error'] ?? 'خطأ في المعاينة'
        : 'خطأ في المعاينة';
    emit(
      state.copyWith(
        // عطل قناة المعاينة لا يعني أن تحميل المحرر نفسه فشل؛ اترك القشرة
        // وأدوات إعادة الاتصال ظاهرة ليتمكن الموظف من المتابعة.
        errorMessage: msg.toString(),
        previewUpdatesPending: 0,
        previewConnection: PreviewConnection.error,
        previewStatusMessage: msg.toString(),
      ),
    );
  }

  /// المستخدم ضغط على عنصر داخل المعاينة — أبناء الأعمدة تحدد كأبنائها.
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

  /// تأكيد المعاينة أن المستند طُبّق. تبقى حالة المستند محلية، لكن فشل
  /// التطبيق يجب أن يصل للمحرر بدل ترك الموظف يظن أن التعديل ظهر.
  void handlePropertyUpdated(dynamic data) {
    if (data is! Map || data['payload'] is! Map) return;
    final payload = data['payload'] as Map;
    final requestId = payload['requestId'];
    if (_unconfirmedPreviewId == null || requestId != _unconfirmedPreviewId) {
      return;
    }
    _previewAckTimeout?.cancel();
    if (payload['success'] != true) {
      _reportPreviewApplyFailure();
      return;
    }
    _unconfirmedPreviewId = null;
    emit(
      state.copyWith(
        previewUpdatesPending: 0,
        previewConnection: PreviewConnection.connected,
        clearPreviewStatusMessage: true,
      ),
    );
  }

  void _reportPreviewApplyFailure() {
    if (isClosed) return;
    _previewAckTimeout?.cancel();
    _unconfirmedPreviewId = null;
    emit(
      state.copyWith(
        previewUpdatesPending: 0,
        previewConnection: PreviewConnection.error,
        previewStatusMessage:
            'تعذر تأكيد عرض آخر تعديل. أعد تحميل معاينة تطبيق العميل.',
      ),
    );
  }

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

  _EditorSnapshot _snapshot() => _EditorSnapshot(
    componentsByPage: {
      for (final entry in state.componentsByPage.entries)
        entry.key: List<EditableComponent>.from(entry.value),
    },
    theme: _theme,
  );

  void _restore(_EditorSnapshot snapshot) {
    _theme = snapshot.theme;
    final selected = _selectedIn(snapshot.componentsByPage);
    emit(
      state.copyWith(
        componentsByPage: snapshot.componentsByPage,
        selectedComponentId: selected?.componentId,
        selectedComponent: selected,
        clearSelectedComponent: selected == null,
        isDirty: true,
      ),
    );
    _syncPreview();
    _markEdited();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
  }

  // ---------- تحديث طبقة الشكل ----------

  /// تحديث طبقة الشكل كاملة — لون أو مقياس. أثر التراجع يسبق التطبيق.
  void updateTheme(DesignTheme theme) {
    _pushUndo();
    _theme = theme;
    emit(state.copyWith(isDirty: true));
    _syncPreview();
    _markEdited();
  }

  /// Replace the current design from the JSON source editor. The same
  /// contract validation used for publish runs before any editor state changes.
  String? importDesignDocument(Map<String, dynamic> document) {
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) return invalid;
    final parsed = DesignDocumentCodec.parseDocument(document);
    final components = <String, List<EditableComponent>>{
      for (final page in EditorPages.pages)
        page.pageId: parsed[page.pageId] ?? <EditableComponent>[],
    };
    _pushUndo();
    _theme = DesignDocumentCodec.themeOf(document);
    final selected = _selectedIn(components);
    emit(
      state.copyWith(
        componentsByPage: components,
        selectedComponentId: selected?.componentId,
        selectedComponent: selected,
        clearSelectedComponent: selected == null,
        isDirty: true,
        clearError: true,
      ),
    );
    _syncPreview();
    _markEdited();
    return null;
  }

  // ---------- تنقل الصفحات ----------

  /// تحميل صفحة جديدة في المعاينة.
  void loadPage(String pageId) {
    _previewPageId = pageId;
    // الاختيار خاص بالصفحة؛ لا نترك المفتش يعرض خصائص عنصر من صفحة أخرى.
    // صفحة الافتتاحية عقدة واحدة، فنحددها فورًا ليظهر محرّر الصورة واللون
    // بدل لوحة فارغة تحتاج نقرة إضافية لا يدري الموظف أنها مطلوبة.
    final pageComponents = state.getComponentsForPage(pageId);
    final onlyComponent = pageComponents.length == 1
        ? pageComponents.single
        : null;
    emit(
      state.copyWith(
        selectedComponentId: onlyComponent?.componentId,
        selectedComponent: onlyComponent,
        clearSelectedComponent: onlyComponent == null,
      ),
    );
    _dispatchToPreview(VisualEditorMessageType.loadPage, {'pageId': pageId});
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
    _dispatchToPreview(VisualEditorMessageType.selectElement, {
      'componentId': componentId,
    });
  }

  // ---------- إضافة وحذف ونسخ ----------

  /// إخوة المكوّن: نفس الصفحة ونفس الأب، بترتيبهم.
  List<EditableComponent> _siblings(
    Map<String, List<EditableComponent>> byPage,
    String pageId,
    String? parentId,
  ) =>
      (byPage[pageId] ?? const []).where((c) => c.parentId == parentId).toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  /// إضافة مكوّن جديد من المكتبة — إلى صفحة أو داخل حاوية (`parentId`).
  void addComponent({
    required String pageId,
    required String componentType,
    String? parentId,
    int? index,
  }) {
    final entry = ComponentRegistry.get(componentType);
    final page = EditorPages.findById(pageId);
    if (entry == null || page == null || !page.isEditable) return;
    if (!page.allowedComponentTypes.contains(componentType)) return;
    if (componentType == 'splashSettings') {
      final existing = state
          .getComponentsForPage(pageId)
          .where((component) => component.componentType == componentType);
      if (existing.isNotEmpty) {
        selectComponent(existing.first.componentId);
        return;
      }
    }
    if (parentId != null) {
      final parent = state.findComponent(parentId);
      if (parent == null || parent.pageId != pageId) return;
      if (!DesignDocumentCodec.canNest(
        childType: componentType,
        parentType: parent.componentType,
      )) {
        return;
      }
    }
    final siblings = _siblings(state.componentsByPage, pageId, parentId);
    final insertAt = (index ?? siblings.length).clamp(0, siblings.length);
    final newComponent = EditableComponent(
      componentId:
          '${pageId}_${componentType}_${DateTime.now().millisecondsSinceEpoch}',
      componentType: componentType,
      pageId: pageId,
      parentId: parentId,
      index: insertAt,
      classification: entry.classification,
      properties: Map<String, dynamic>.from(entry.defaultValues)
        ..['visible'] = true,
      defaultValues: entry.defaultValues,
      validationRules: entry.validationRules,
      allowedOperations: entry.allowedOperations,
      version: 1,
    );
    _pushUndo();
    // الأبناء يُدرجون في القائمة المسطّحة بعد آخر أبناء الأب مباشرة: ترتيب
    // القائمة هو الترتيب العمقي للمستند.
    final pageComponents = List<EditableComponent>.from(
      state.componentsByPage[pageId] ?? [],
    );
    final insertPosition = _flatInsertPosition(
      pageComponents,
      parentId,
      insertAt,
    );
    pageComponents.insert(insertPosition, newComponent);
    _updatePage(pageId, _reindexSiblings(pageComponents));
    emit(
      state.copyWith(
        selectedComponentId: newComponent.componentId,
        selectedComponent: newComponent,
      ),
    );
    _dispatchToPreview(VisualEditorMessageType.addComponent, {
      'pageId': pageId,
      'component': DesignDocumentCodec.node(
        newComponent,
        _childrenByParent(pageComponents),
      ),
      'designDocument': _currentDocumentOrNull(),
    });
    _markEdited();
  }

  /// موضع الإدراج في القائمة المسطّحة: آخر موضع يغطيه الأبناء السابقون
  /// للأب المطلوب، بترتيب المستند العمقي.
  int _flatInsertPosition(
    List<EditableComponent> components,
    String? parentId,
    int siblingIndex,
  ) {
    if (parentId == null) {
      // جذر الصفحة: بعد آخر مكون جذر وجميع أبنائه — أي نهاية القائمة.
      return components.length;
    }
    final siblings = components.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (siblings.isEmpty) return components.length;
    if (siblingIndex >= siblings.length) {
      // بعد آخر ابن: قبل الأخ الأبناء؟ لا — الأب قد يكون وسط قائمة أبيه،
      // فالإدراج بعد آخر ابن هو نهاية شجرة الأب في القائمة العمقية.
      final lastSibling = siblings.last;
      final lastPosition = components.indexOf(lastSibling);
      return _subtreeEnd(components, lastPosition) + 1;
    }
    final position = components.indexOf(siblings[siblingIndex]);
    return position;
  }

  /// نهاية شجرة مكوّن في القائمة المسطّحة: آخر سليل له قبل أول عنصر لا
  /// يخصّه. القائمة المسطّحة تحفظ الترتيب العمقي، فالشجرة متتالية دائمًا.
  int _subtreeEnd(List<EditableComponent> components, int start) {
    var end = start;
    final ancestors = <String>{components[start].componentId};
    for (var i = start + 1; i < components.length; i++) {
      final parent = components[i].parentId;
      if (parent != null && ancestors.contains(parent)) {
        ancestors.add(components[i].componentId);
        end = i;
        continue;
      }
      // عنصر ليس سليلًا للجذر: إذا لم يكن سليلًا لأي سجل في الأنساب، انتهت
      // الشجرة. بما أن القائمة عمقية، أول انقطاع هو النهاية.
      break;
    }
    return end;
  }

  Map<String, List<EditableComponent>> _childrenByParent(
    List<EditableComponent> components,
  ) {
    final byParent = <String, List<EditableComponent>>{};
    for (final component in components) {
      final parent = component.parentId;
      if (parent == null) continue;
      (byParent[parent] ??= []).add(component);
    }
    byParent.forEach((_, children) {
      children.sort((a, b) => a.index.compareTo(b.index));
    });
    return byParent;
  }

  /// حذف مكوّن — محمي من حذف العناصر التي لا تحمل 'delete' في
  /// allowedOperations، ويحذف أبناءه معه: عمود بلا أبناء يتيم أحسن من شجرة
  /// مكسورة، والحذف كله أو لا شيء.
  void deleteComponent(String componentId) {
    final component = state.findComponent(componentId);
    if (component == null) return;
    if (!component.canDelete) return;
    _pushUndo();
    final doomed = <String>{componentId};
    // جولة على الشجرة: أي ابن لأي محذوف يُحذف معه.
    var grew = true;
    while (grew) {
      grew = false;
      for (final pageComponents in state.componentsByPage.values) {
        for (final candidate in pageComponents) {
          if (candidate.parentId != null &&
              doomed.contains(candidate.parentId) &&
              doomed.add(candidate.componentId)) {
            grew = true;
          }
        }
      }
    }
    final updatedPages = <String, List<EditableComponent>>{};
    state.componentsByPage.forEach((pageId, components) {
      updatedPages[pageId] = _reindexSiblings(
        components.where((c) => !doomed.contains(c.componentId)).toList(),
      );
    });
    final wasSelected = doomed.contains(state.selectedComponentId);
    emit(
      state.copyWith(
        componentsByPage: updatedPages,
        isDirty: true,
        clearSelectedComponent: wasSelected,
      ),
    );
    _dispatchToPreview(VisualEditorMessageType.removeComponent, {
      'componentId': componentId,
      'designDocument': _currentDocumentOrNull(),
    });
    _markEdited();
  }

  /// نسخ مكوّن وإدراجه بعده مباشرة، مع كل أبنائه بمعرفّات جديدة.
  void duplicateComponent(String componentId) {
    final component = state.findComponent(componentId);
    if (component == null || !component.canDuplicate) return;
    _pushUndo();
    final pageComponents = List<EditableComponent>.from(
      state.componentsByPage[component.pageId] ?? [],
    );
    final subtree = _subtreeOf(pageComponents, componentId);
    if (subtree.isEmpty) return;
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final idMap = <String, String>{};
    for (final node in subtree) {
      idMap[node.componentId] =
          '${node.pageId}_${node.componentType}_$suffix'
          '_${idMap.length}';
    }
    final position = pageComponents.indexOf(subtree.last) + 1;
    final duplicates = <EditableComponent>[
      for (final node in subtree)
        node.copyWith(
          componentId: idMap[node.componentId]!,
          parentId: node.parentId == null
              ? null
              : idMap[node.parentId!] ?? node.parentId,
          index: node.index,
          version: node.version + 1,
        ),
    ];
    pageComponents.insertAll(position, duplicates);
    _updatePage(component.pageId, _reindexSiblings(pageComponents));
    final duplicateRoot = duplicates.first;
    _dispatchToPreview(VisualEditorMessageType.addComponent, {
      'pageId': component.pageId,
      'component': DesignDocumentCodec.node(
        duplicateRoot,
        _childrenByParent(pageComponents),
      ),
      'designDocument': _currentDocumentOrNull(),
    });
    _markEdited();
  }

  List<EditableComponent> _subtreeOf(
    List<EditableComponent> components,
    String rootId,
  ) {
    final root = components.where((c) => c.componentId == rootId).firstOrNull;
    if (root == null) return const [];
    final subtree = <EditableComponent>[root];
    final ancestors = <String>{rootId};
    // القائمة عمقية: كل سليل للجذر متتالٍ بعده.
    for (final candidate in components) {
      if (candidate.componentId == rootId) continue;
      if (candidate.parentId != null &&
          ancestors.contains(candidate.parentId)) {
        ancestors.add(candidate.componentId);
        subtree.add(candidate);
      }
    }
    return subtree;
  }

  // ---------- إعادة الترتيب ----------

  /// إعادة ترتيب مكوّن داخل مجموعة إخوته فقط — لا ينتقل بين الآباء إلا
  /// بقواعد السجل (canMoveToParent عبر السحب لاحقًا).
  void reorderComponent(String componentId, int newIndex) {
    final component = state.findComponent(componentId);
    if (component == null || !component.canReorder) return;
    final siblings = _siblings(
      state.componentsByPage,
      component.pageId,
      component.parentId,
    );
    final oldSiblingIndex = siblings.indexWhere(
      (c) => c.componentId == componentId,
    );
    if (oldSiblingIndex < 0) return;
    _pushUndo();
    final clamped = newIndex.clamp(0, siblings.length - 1);
    final reordered = List<EditableComponent>.from(siblings)
      ..removeAt(oldSiblingIndex)
      ..insert(clamped, component);
    // إعادة كتابة الفهارس بين الإخوة داخل القائمة المسطّحة بالترتيب الجديد.
    final siblingOrder = <String, int>{
      for (var i = 0; i < reordered.length; i++) reordered[i].componentId: i,
    };
    final pageComponents = state.componentsByPage[component.pageId]!
        .map(
          (c) => siblingOrder.containsKey(c.componentId)
              ? c.copyWith(index: siblingOrder[c.componentId]!)
              : c,
        )
        .toList();
    // ترتيب القائمة المسطّحة نفسه يتبع الترتيب العمقي الجديد: أعد بناءها
    // من المستند حتى تظل متتالية.
    final document = DesignDocumentCodec.document({
      component.pageId: pageComponents,
    });
    final pages = document['pages'] as List;
    if (pages.isEmpty) return;
    final reparsed = DesignDocumentCodec.parsePage(
      component.pageId,
      (pages.first as Map)['root']['children'],
    );
    _updatePage(component.pageId, reparsed);
    _dispatchToPreview(VisualEditorMessageType.reorderComponent, {
      'componentId': componentId,
      'newIndex': clamped,
      'designDocument': _currentDocumentOrNull(),
    });
    _markEdited();
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
  }) =>
      updateProperties(componentId: componentId, values: {propertyKey: value});

  /// Apply a related group of property changes as one undo step and one
  /// complete-document update to the live customer preview.
  void updateProperties({
    required String componentId,
    required Map<String, dynamic> values,
  }) {
    final component = state.findComponent(componentId);
    if (component == null) return;
    final validValues = Map<String, dynamic>.fromEntries(
      values.entries.where(
        (entry) => _isValidValue(component, entry.key, entry.value),
      ),
    );
    if (validValues.isEmpty) return;
    _pushUndo();
    final updatedProps = Map<String, dynamic>.from(component.properties);
    for (final entry in validValues.entries) {
      if (entry.value == null) {
        updatedProps.remove(entry.key);
      } else {
        updatedProps[entry.key] = entry.value;
      }
    }
    final updatedComponent = component.copyWith(properties: updatedProps);
    _replaceComponent(updatedComponent);
    // Send the complete document through the same protocol message used when
    // the preview is first initialized. Older deployed customer previews may
    // understand APPLY_DESIGN_CONFIG without implementing the incremental
    // UPDATE_PROPERTY message; sending the full document also guarantees that
    // image URLs and other nested screen settings repaint together.
    _dispatchToPreview(VisualEditorMessageType.applyDesignConfig, {
      'componentId': '__document__',
      'awaitPreviewAck': true,
      'designDocument': _currentDocumentOrNull(),
      ..._previewSettingsPayload(),
    });
    _markEdited();
  }

  bool _isValidValue(EditableComponent component, String key, Object? value) {
    final definition = ComponentRegistry.getEditableProperties(
      component.componentType,
    )[key];
    if (definition == null) {
      return key == 'visible' || component.properties.containsKey(key);
    }
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
      } else if (component.properties[propertyKey] != null) {
        // الخصائص الاختيارية (مثل maxLines والمقاس) ترجع للأصل بحذف
        // التجاوز؛ null قيمة صالحة في الذاكرة ويُسقطها codec من المستند.
        updateProperty(
          componentId: componentId,
          propertyKey: propertyKey,
          value: null,
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

  // ---------- التخلص من المسودة ----------

  /// التخلص من المسودة عبر RPC — يمسح صف المسودة فقط، وما يراه الزبون
  /// لا يُلمس. عند الفشل تبقى الحالة المحلية كما هي: فقدان محلي عند عطل
  /// شبكة يخلق انطباعًا كاذبًا بأن المسودة ماتت.
  Future<bool> discardDraft() async {
    try {
      await _repository.discardDraft();
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(errorMessage: 'تعذر التخلص من المسودة: $e'));
      return false;
    }
    _undoStack.clear();
    _redoStack.clear();
    await initialize();
    return true;
  }

  // ---------- القوالب ----------

  /// القوالب المحفوظة (228)، الأحدث أولًا.
  Future<List<DesignTemplateInfo>> loadTemplates() =>
      _repository.listTemplates();

  /// مستند قالب، لمعاينته قبل تطبيقه.
  Future<Map<String, dynamic>?> templateDocument(String templateId) =>
      _repository.getTemplateDocument(templateId);

  /// تطبيق قالب على المسودة فقط — بلمسة تراجع واحدة، ولا يلمس المنشور.
  Future<bool> applyTemplate(String templateId) async {
    try {
      final document = await _repository.getTemplateDocument(templateId);
      if (isClosed) return false;
      if (document == null) {
        emit(state.copyWith(errorMessage: 'القالب غير موجود'));
        return false;
      }
      final invalid = DesignDocumentCodec.validate(document);
      if (invalid != null) {
        emit(state.copyWith(errorMessage: 'قالب غير صالح للتطبيق: $invalid'));
        return false;
      }
      _pushUndo();
      _theme = DesignDocumentCodec.themeOf(document);
      emit(
        state.copyWith(
          componentsByPage: DesignDocumentCodec.parseDocument(document),
          isDirty: true,
          clearError: true,
        ),
      );
      _syncPreview();
      _markEdited();
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(errorMessage: 'تعذر تطبيق القالب: $e'));
      return false;
    }
  }

  /// حفظ المسودة الحالية كقالب جديد (228) — بنفس تدقيق النشر.
  Future<DesignTemplateInfo?> saveCurrentAsTemplate(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      emit(state.copyWith(errorMessage: 'اسم القالب مطلوب (1..60 حرفًا)'));
      return null;
    }
    final document = _currentDocumentOrNull();
    if (document == null) {
      emit(state.copyWith(errorMessage: 'لا يوجد تصميم لحفظه كقالب'));
      return null;
    }
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      emit(
        state.copyWith(errorMessage: 'التصميم غير صالح للحفظ كقالب: $invalid'),
      );
      return null;
    }
    try {
      final template = await _repository.saveTemplate(
        name: trimmed,
        document: document,
      );
      if (isClosed) return template;
      emit(state.copyWith(clearError: true));
      return template;
    } catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(errorMessage: 'تعذر حفظ القالب: $e'));
      return null;
    }
  }

  /// حذف قالب (228) — لا يلمس مسودة ولا منشورًا.
  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _repository.deleteTemplate(templateId);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(errorMessage: 'تعذر حذف القالب: $e'));
      return false;
    }
  }

  // ---------- حفظ ونشر ----------

  /// يسجل تعديلًا جديدًا دون كتابة أي شيء إلى الشبكة.
  void _markEdited() => _editRevision++;

  /// لا تُكتب المسودة إلا بطلب حفظ صريح.
  Future<void> saveDraft() async {
    final revision = _editRevision;
    final components = {
      for (final entry in state.componentsByPage.entries)
        entry.key: List<EditableComponent>.of(entry.value),
    };
    final theme = _theme;
    final previousSave = _saveQueue;
    final completer = Completer<void>();
    _saveQueue = completer.future;
    await previousSave.catchError((Object _) {});
    try {
      await _repository.saveDraft(components, theme: theme);
      if (!isClosed && revision == _editRevision) {
        emit(state.copyWith(isDirty: false, clearError: true));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'تعذر حفظ المسودة: $e'));
      }
    } finally {
      completer.complete();
    }
  }

  /// نشر التصميم بعد تدقيق محلي. يرفض قبل أن ترفض القاعدة.
  Future<PublishedVersionInfo?> publish({String? note}) async {
    final document = _currentDocumentOrNull();
    if (document == null) {
      emit(
        state.copyWith(errorMessage: 'لا يوجد تصميم لنشره — أضف مكوّنًا أولًا'),
      );
      return null;
    }
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      emit(state.copyWith(errorMessage: 'المستند غير صالح للنشر: $invalid'));
      return null;
    }
    try {
      final version = await _repository.publishDesign(document, note: note);
      if (isClosed) return version;
      // النشر لا يحفظ المسودة؛ لا تصبح التعديلات محفوظة إلا بطلب الحفظ.
      emit(state.copyWith(clearError: true));
      return version;
    } catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(errorMessage: _readablePublishError(e)));
      return null;
    }
  }

  /// رسالة نشر مفهومة من ردّ القاعدة.
  ///
  /// RPC النشر يرفض المستند برمز أوّل عيب (`page_key`، `node_duplicate`…).
  /// الرمز الخام يقول للموظف لا شيء؛ هذه ترجمة الأخطاء التي يراها فعلًا،
  /// ومعها ما يفعله. رموز لا تُعرف تُعرض كما هي مع نصّ الردّ — لا شاشة
  /// صامتة ولا رسالة تخمّن سببًا لم تقله القاعدة.
  String _readablePublishError(Object error) {
    final raw = error.toString();
    String? code;
    for (final candidate in const [
      'page_key',
      'page_duplicate',
      'page_count',
      'depth',
      'node_duplicate',
      'node_count',
      'property_value',
      'theme_key',
      'theme_color_role',
      'theme_color_value',
      'theme_text_scale',
      'theme_radius_scale',
      'brand_key',
      'brand_logo_url',
      'brand_name',
    ]) {
      if (raw.contains(candidate)) {
        code = candidate;
        break;
      }
    }
    if (raw.contains('missing permission: design.publish')) {
      return 'حسابك لا يملك صلاحية نشر تصميم التطبيق — اطلب من المالك منحك design.publish.';
    }
    if (raw.contains('not authenticated')) {
      return 'انتهت جلسة تسجيل الدخول — سجّل الدخول مجددًا ثم أعد النشر.';
    }
    return switch (code) {
      'page_key' || 'page_count' =>
        'قاعدة البيانات لم تُحدّث لدعم صفحات المحرر بعد — طبّق migration 244 '
            '(app_design_all_pages) على مشروع Supabase ثم أعد النشر.',
      'page_duplicate' =>
        'الصفحة مكرّرة في المستند — احذف التكرار ثم أعد النشر.',
      'depth' =>
        'التداخل أعمق من المسموح به — أخرج العناصر من الأعمدة المتداخلة.',
      'node_duplicate' =>
        'معرّف عنصر مكرّر — احذف العنصر المنسوخ يدويًا أو أعد إنشاءه.',
      'node_count' => 'عدد العناصر تجاوز الحد (400) — قلّل الأقسام.',
      'property_value' =>
        'خصيصة تحمل قيمة غير مسموحة — أعد ضبطها من لوحة الخصائص.',
      'theme_key' ||
      'theme_color_role' ||
      'theme_color_value' ||
      'theme_text_scale' ||
      'theme_radius_scale' =>
        'طبقة الشكل تحتوي قيمة لا يعرفها المدقق — راجع استوديو الثيم.',
      'brand_key' || 'brand_logo_url' || 'brand_name' =>
        'بيانات الهوية غير صالحة — الاسم حتى 80 حرفًا واللوجو رابط http(s).',
      _ => 'تعذر النشر: $raw',
    };
  }

  // ---------- سجل الإصدارات ----------

  /// تاريخ الإصدارات المنشورة، الأحدث أولًا.
  Future<List<PublishedVersionInfo>> loadVersions({int limit = 30}) =>
      _repository.listVersions(limit: limit);

  /// مستند إصدار سابق، لمعاينته قبل الاسترجاع.
  Future<Map<String, dynamic>?> versionDocument(String versionId) =>
      _repository.getVersionDocument(versionId);

  /// Load a previous release into the editor for preview before publishing.
  Future<bool> previewVersion(String versionId) async {
    try {
      final document = await _repository.getVersionDocument(versionId);
      if (isClosed) return false;
      if (document == null) {
        emit(state.copyWith(errorMessage: 'تعذر تحميل مستند الإصدار.'));
        return false;
      }
      final parsed = DesignDocumentCodec.parseDocument(document);
      final components = {
        for (final page in EditorPages.pages)
          page.pageId:
              parsed[page.pageId] ??
              DesignDocumentCodec.defaultComponentsFor(page.pageId),
      };
      _pushUndo();
      _theme = DesignDocumentCodec.themeOf(document);
      final selected = _selectedIn(components);
      emit(
        state.copyWith(
          componentsByPage: components,
          selectedComponentId: selected?.componentId,
          selectedComponent: selected,
          clearSelectedComponent: selected == null,
          isDirty: true,
          clearError: true,
        ),
      );
      _syncPreview();
      _markEdited();
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(errorMessage: 'تعذر تحميل الإصدار للمعاينة: $e'));
      return false;
    }
  }

  // ---------- الأدوات الداخلية ----------

  void _updatePage(String pageId, List<EditableComponent> components) {
    final pages = {...state.componentsByPage, pageId: components};
    final selected = _selectedIn(pages);
    emit(
      state.copyWith(
        componentsByPage: pages,
        selectedComponentId: selected?.componentId,
        selectedComponent: selected,
        clearSelectedComponent: selected == null,
        isDirty: true,
      ),
    );
  }

  EditableComponent? _selectedIn(Map<String, List<EditableComponent>> pages) {
    final id = state.selectedComponentId;
    if (id == null) return null;
    for (final components in pages.values) {
      for (final component in components) {
        if (component.componentId == id) return component;
      }
    }
    return null;
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
        selectedComponent: state.selectedComponentId == updated.componentId
            ? updated
            : state.selectedComponent,
        isDirty: true,
      ),
    );
  }

  /// إعادة فهرسة كل مجموعة إخوة داخل القائمة المسطّحة (لا القائمة كلها):
  /// الجذور تسلسل من 0، وأبناء كل أب تسلسل من 0.
  List<EditableComponent> _reindexSiblings(List<EditableComponent> components) {
    final rootCounter = _Counter();
    final childCounters = <String, _Counter>{};
    return [
      for (final component in components)
        component.copyWith(
          index: component.parentId == null
              ? rootCounter.next()
              : childCounters
                    .putIfAbsent(component.parentId!, _Counter.new)
                    .next(),
        ),
    ];
  }

  /// المستند الحالي كاملًا، أو null حين لا مكوّنات (لا نشر ولا إرسال فارغ).
  Map<String, dynamic>? _currentDocumentOrNull() {
    if (_externalPreviewDocument != null) return _externalPreviewDocument;
    if (state.componentsByPage.isEmpty) return null;
    final hasContent = state.componentsByPage.values.any((c) => c.isNotEmpty);
    if (!hasContent) return null;
    return DesignDocumentCodec.document(state.componentsByPage, theme: _theme);
  }

  /// إعادة إرسال المستند كاملًا إلى المعاينة — استُعمل بعد تراجع/استرجاع،
  /// حيث لا تكفي رسالة دلتا واحدة.
  void _syncPreview() {
    final document = _currentDocumentOrNull();
    if (document == null) return;
    _dispatchToPreview(VisualEditorMessageType.applyDesignConfig, {
      'designDocument': document,
      'componentId': '__document__',
      'awaitPreviewAck': true,
      ..._previewSettingsPayload(),
    });
  }

  /// إعدادات العرض التي تُرفق بكل مستند: الإطار الجديد لا يملك حالة المحرّر،
  /// فيحتاج اللغة والوضع مع أول مستند يرسمه بعد كل إعادة تحميل.
  Map<String, dynamic> _previewSettingsPayload() => {
    'previewLanguage': state.previewLanguage.value,
    'previewThemeMode': state.previewThemeMode.value,
  };

  /// يضع رسالة صادرة في الحالة حتى تلتقطها PreviewPanel وترسلها عبر postMessage.
  @override
  Future<void> close() {
    _previewAckTimeout?.cancel();
    return super.close();
  }

  void _dispatchToPreview(
    VisualEditorMessageType type,
    Map<String, dynamic> payload,
  ) {
    final requiresAck =
        payload['componentId'] is String &&
        (payload['componentId'] as String).isNotEmpty &&
        (payload['awaitPreviewAck'] == true ||
            type == VisualEditorMessageType.updateProperty ||
            type == VisualEditorMessageType.addComponent ||
            type == VisualEditorMessageType.removeComponent ||
            type == VisualEditorMessageType.reorderComponent);
    final message = OutboundMessage(
      type: type,
      payload: payload,
      sessionId: state.sessionId,
      messageId: '${state.sessionId}-${++_messageSequence}',
    );
    if (requiresAck) {
      _unconfirmedPreviewId = message.messageId;
      _previewAckTimeout?.cancel();
      _previewAckTimeout = Timer(
        const Duration(seconds: 20),
        _reportPreviewApplyFailure,
      );
    }
    _outbound.add(message);
    _pendingMessage = message;
    emit(
      state.copyWith(
        previewUpdatesPending: _unconfirmedPreviewId == null ? 0 : 1,
      ),
    );
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

/// عدّاد صغير لإعادة الفهرسة.
class _Counter {
  int _value = 0;

  int next() => _value++;
}

/// لقطة تراجع: المكوّنات وطبقة الشكل معًا.
class _EditorSnapshot {
  const _EditorSnapshot({required this.componentsByPage, required this.theme});

  final Map<String, List<EditableComponent>> componentsByPage;
  final DesignTheme theme;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
