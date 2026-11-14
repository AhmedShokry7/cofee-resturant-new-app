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
/// لترسلها عبر postMessage. كل تعديل تركيبي أو في طبقة الشكل يترك أثرًا في
/// مكدس التراجع، ويُحفظ مؤجلًا كمسودة عبر الـ RPC، ويُنشر بعد تدقيق محلي ثم
/// تدقيق القاعدة. القوالب تطبَّق على المسودة لا على المنشور أبدًا.
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

  /// لقطة تراجع كاملة: المكوّنات وطبقة الشكل معًا — التراجع عن لون بلا
  /// ترتيب نصف تراجع، والاثنان يُنشران في مستند واحد.
  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];

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

  _EditorSnapshot _snapshot() => _EditorSnapshot(
    componentsByPage: {
      for (final entry in state.componentsByPage.entries)
        entry.key: List<EditableComponent>.from(entry.value),
    },
    theme: _theme,
  );

  void _restore(_EditorSnapshot snapshot) {
    _theme = snapshot.theme;
    emit(
      state.copyWith(
        componentsByPage: snapshot.componentsByPage,
        isDirty: true,
      ),
    );
    _syncPreview();
    _scheduleSave();
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

  /// إخوة المكوّن: نفس الصفحة ونفس الأب، بترتيبهم.
  List<EditableComponent> _siblings(
    Map<String, List<EditableComponent>> byPage,
    String pageId,
    String? parentId,
  ) =>
      (byPage[pageId] ?? const [])
          .where((c) => c.parentId == parentId)
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  /// إضافة مكوّن جديد من المكتبة — إلى صفحة أو داخل حاوية (`parentId`).
  void addComponent({
    required String pageId,
    required String componentType,
    String? parentId,
    int? index,
  }) {
    final entry = ComponentRegistry.get(componentType);
    if (entry == null) return;
    if (parentId != null &&
        !DesignDocumentCodec.canNest(
          childType: componentType,
          parentType: state.findComponent(parentId)?.componentType,
        )) {
      return;
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
    _dispatchToPreview(
      VisualEditorMessageType.addComponent,
      {
        'pageId': pageId,
        'component': DesignDocumentCodec.node(
          newComponent,
          _childrenByParent(pageComponents),
        ),
        'designDocument': _currentDocumentOrNull(),
      },
    );
    _scheduleSave();
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
    final siblings = components
        .where((c) => c.parentId == parentId)
        .toList()
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
        components
            .where((c) => !doomed.contains(c.componentId))
            .toList(),
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
    _dispatchToPreview(
      VisualEditorMessageType.removeComponent,
      {
        'componentId': componentId,
        'designDocument': _currentDocumentOrNull(),
      },
    );
    _scheduleSave();
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
    _scheduleSave();
  }

  List<EditableComponent> _subtreeOf(
    List<EditableComponent> components,
    String rootId,
  ) {
    final root = components
        .where((c) => c.componentId == rootId)
        .firstOrNull;
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
    final oldSiblingIndex = siblings
        .indexWhere((c) => c.componentId == componentId);
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

  // ---------- التخلص من المسودة ----------

  /// التخلص من المسودة عبر RPC — يمسح صف المسودة فقط، وما يراه الزبون
  /// لا يُلمس. عند الفشل تبقى الحالة المحلية كما هي: فقدان محلي عند عطل
  /// شبكة يخلق انطباعًا كاذبًا بأن المسودة ماتت.
  Future<bool> discardDraft() async {
    _saveDebounce?.cancel();
    try {
      await _repository.discardDraft();
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          errorMessage: 'تعذر التخلص من المسودة: $e',
        ),
      );
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
        emit(
          state.copyWith(
            errorMessage: 'القالب غير موجود',
          ),
        );
        return false;
      }
      final invalid = DesignDocumentCodec.validate(document);
      if (invalid != null) {
        emit(
          state.copyWith(
            errorMessage: 'قالب غير صالح للتطبيق: $invalid',
          ),
        );
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
      _scheduleSave();
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          errorMessage: 'تعذر تطبيق القالب: $e',
        ),
      );
      return false;
    }
  }

  /// حفظ المسودة الحالية كقالب جديد (228) — بنفس تدقيق النشر.
  Future<DesignTemplateInfo?> saveCurrentAsTemplate(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      emit(
        state.copyWith(
          errorMessage: 'اسم القالب مطلوب (1..60 حرفًا)',
        ),
      );
      return null;
    }
    final document = _currentDocumentOrNull();
    if (document == null) {
      emit(
        state.copyWith(
          errorMessage: 'لا يوجد تصميم لحفظه كقالب',
        ),
      );
      return null;
    }
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      emit(
        state.copyWith(
          errorMessage: 'التصميم غير صالح للحفظ كقالب: $invalid',
        ),
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
      emit(
        state.copyWith(
          errorMessage: 'تعذر حفظ القالب: $e',
        ),
      );
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
      emit(
        state.copyWith(
          errorMessage: 'تعذر حذف القالب: $e',
        ),
      );
      return false;
    }
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

  /// إعادة فهرسة كل مجموعة إخوة داخل القائمة المسطّحة (لا القائمة كلها):
  /// الجذور تسلسل من 0، وأبناء كل أب تسلسل من 0.
  List<EditableComponent> _reindexSiblings(
    List<EditableComponent> components,
  ) {
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

/// عدّاد صغير لإعادة الفهرسة.
class _Counter {
  int _value = 0;

  int next() => _value++;
}

/// لقطة تراجع: المكوّنات وطبقة الشكل معًا.
class _EditorSnapshot {
  const _EditorSnapshot({
    required this.componentsByPage,
    required this.theme,
  });

  final Map<String, List<EditableComponent>> componentsByPage;
  final DesignTheme theme;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
