import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';

/// Visual Editor state status
enum VisualEditorStatus {
  initial,
  loading,
  ready,
  failure,
}

/// Visual Editor state
class VisualEditorState {
  final VisualEditorStatus status;
  final String? errorMessage;
  final String sessionId;
  final Map<String, List<EditableComponent>> componentsByPage;
  final String? selectedComponentId;
  final EditableComponent? selectedComponent;
  final bool previewReady;
  final String? previewUrl;

  const VisualEditorState({
    this.status = VisualEditorStatus.initial,
    this.errorMessage,
    required this.sessionId,
    this.componentsByPage = const {},
    this.selectedComponentId,
    this.selectedComponent,
    this.previewReady = false,
    this.previewUrl,
  });

  VisualEditorState copyWith({
    VisualEditorStatus? status,
    String? errorMessage,
    String? sessionId,
    Map<String, List<EditableComponent>>? componentsByPage,
    String? selectedComponentId,
    EditableComponent? selectedComponent,
    bool? previewReady,
    String? previewUrl,
    bool clearSelectedComponent = false,
  }) => VisualEditorState(
    status: status ?? this.status,
    errorMessage: errorMessage,
    sessionId: sessionId ?? this.sessionId,
    componentsByPage: componentsByPage ?? this.componentsByPage,
    selectedComponentId: clearSelectedComponent ? null : (selectedComponentId ?? this.selectedComponentId),
    selectedComponent: clearSelectedComponent ? null : (selectedComponent ?? this.selectedComponent),
    previewReady: previewReady ?? this.previewReady,
    previewUrl: previewUrl ?? this.previewUrl,
  );

  List<EditableComponent> getComponentsForPage(String pageId) {
    return componentsByPage[pageId] ?? [];
  }

  EditableComponent? findComponent(String componentId) {
    for (final components in componentsByPage.values) {
      for (final component in components) {
        if (component.componentId == componentId) return component;
      }
    }
    return null;
  }
}

/// Visual Editor Cubit - manages the editor state and communication with preview
class VisualEditorCubit extends Cubit<VisualEditorState> {
  VisualEditorCubit()
      : super(VisualEditorState(
          sessionId: _generateSessionId(),
          componentsByPage: _initialComponents(),
        )) {
    _repository = VisualEditorRepository();
  }

  late final VisualEditorRepository _repository;

  static String _generateSessionId() {
    return 've_${DateTime.now().millisecondsSinceEpoch}_${(Math.random() * 10000).floor()}';
  }

  static Map<String, List<EditableComponent>> _initialComponents() {
    // Load saved draft from repository
    return {};
  }

  /// Initialize the editor - load draft, connect to preview
  Future<void> initialize() async {
    emit(state.copyWith(status: VisualEditorStatus.loading));

    try {
      // Load saved draft
      final draft = await _repository.loadDraft(state.sessionId);
      if (draft != null) {
        emit(state.copyWith(
          componentsByPage: draft.componentsByPage,
          status: VisualEditorStatus.ready,
        ));
      } else {
        emit(state.copyWith(status: VisualEditorStatus.ready));
      }
    } catch (e) {
      emit(state.copyWith(
        status: VisualEditorStatus.failure,
        errorMessage: 'Failed to initialize editor: $e',
      ));
    }
  }

  /// Load a specific page in the preview
  void loadPage(String pageId) {
    // Send LOAD_PAGE message to preview
    _sendToPreview(VisualEditorMessageType.loadPage, {'pageId': pageId});
  }

  /// Handle preview ready signal
  void handlePreviewReady(dynamic data) {
    emit(state.copyWith(previewReady: true));
    // Send current design to preview
    _sendCurrentDesign();
  }

  /// Handle preview error
  void handlePreviewError(dynamic data) {
    emit(state.copyWith(
      status: VisualEditorStatus.failure,
      errorMessage: data['error'] ?? 'Preview error',
    ));
  }

  /// Handle element selected in preview
  void handleElementSelected(dynamic data) {
    final componentId = data['componentId'] as String?;
    if (componentId != null) {
      final component = state.findComponent(componentId);
      if (component != null) {
        emit(state.copyWith(
          selectedComponentId: componentId,
          selectedComponent: component,
        ));
      }
    }
  }

  /// Select a component in the tree
  void selectComponent(String componentId) {
    final component = state.findComponent(componentId);
    emit(state.copyWith(
      selectedComponentId: componentId,
      selectedComponent: component,
    ));
    // Tell preview to highlight
    _sendToPreview(VisualEditorMessageType.selectElement, {'componentId': componentId});
  }

  /// Add a new component
  void addComponent({
    required String pageId,
    required String componentType,
    String? parentId,
    int? index,
  }) {
    final pageComponents = List<EditableComponent>.from(state.componentsByPage[pageId] ?? []);
    final registryEntry = ComponentRegistry.get(componentType);
    if (registryEntry == null) return;

    final newComponent = EditableComponent(
      componentId: '${pageId}_${componentType}_${DateTime.now().millisecondsSinceEpoch}',
      componentType: componentType,
      pageId: pageId,
      parentId: parentId,
      index: index ?? pageComponents.length,
      classification: registryEntry.classification,
      properties: Map.from(registryEntry.defaultValues),
      defaultValues: registryEntry.defaultValues,
      validationRules: registryEntry.validationRules,
      allowedOperations: registryEntry.allowedOperations,
      version: 1,
    );

    if (parentId != null) {
      // Add as child of parent
      final updated = _addChildRecursive(pageComponents, parentId, newComponent);
      emit(state.copyWith(componentsByPage: {...state.componentsByPage, pageId: updated}));
    } else {
      // Add to page root
      final updated = [...pageComponents, newComponent];
      emit(state.copyWith(componentsByPage: {...state.componentsByPage, pageId: updated}));
    }

    _sendToPreview(VisualEditorMessageType.addComponent, {
      'pageId': pageId,
      'component': _componentToJson(newComponent),
    });
    _saveDraft();
  }

  /// Delete a component
  void deleteComponent(String componentId) {
    final updatedPages = <String, List<EditableComponent>>{};
    state.componentsByPage.forEach((pageId, components) {
      updatedPages[pageId] = _removeComponentRecursive(components, componentId);
    });
    emit(state.copyWith(
      componentsByPage: updatedPages,
      selectedComponentId: state.selectedComponentId == componentId ? null : state.selectedComponentId,
      selectedComponent: state.selectedComponentId == componentId ? null : state.selectedComponent,
    ));
    _sendToPreview(VisualEditorMessageType.removeComponent, {'componentId': componentId});
    _saveDraft();
  }

  /// Duplicate a component
  void duplicateComponent(String componentId) {
    final component = state.findComponent(componentId);
    if (component == null) return;

    final pageComponents = List<EditableComponent>.from(state.componentsByPage[component.pageId] ?? []);
    final index = pageComponents.indexWhere((c) => c.componentId == componentId);
    if (index < 0) return;

    final newComponent = component.copyWith(
      componentId: '${component.pageId}_${component.componentType}_${DateTime.now().millisecondsSinceEpoch}',
      version: component.version + 1,
    );

    final updated = [...pageComponents];
    updated.insert(index + 1, newComponent);
    emit(state.copyWith(componentsByPage: {...state.componentsByPage, component.pageId: updated}));

    _sendToPreview(VisualEditorMessageType.addComponent, {
      'pageId': component.pageId,
      'component': _componentToJson(newComponent),
      'parentId': component.parentId,
      'index': index + 1,
    });
    _saveDraft();
  }

  /// Reorder component
  void reorderComponent(String componentId, int newIndex) {
    final component = state.findComponent(componentId);
    if (component == null) return;

    final pageComponents = List<EditableComponent>.from(state.componentsByPage[component.pageId] ?? []);
    final oldIndex = pageComponents.indexWhere((c) => c.componentId == componentId);
    if (oldIndex < 0) return;

    final updated = [...pageComponents];
    final item = updated.removeAt(oldIndex);
    final clampedIndex = newIndex.clamp(0, updated.length);
    updated.insert(clampedIndex, item);

    // Update indices
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(index: i);
    }

    emit(state.copyWith(componentsByPage: {...state.componentsByPage, component.pageId: updated}));
    _sendToPreview(VisualEditorMessageType.reorderComponent, {
      'componentId': componentId,
      'newIndex': clampedIndex,
    });
    _saveDraft();
  }

  /// Toggle component visibility
  void toggleComponentVisibility(String componentId) {
    final component = state.findComponent(componentId);
    if (component == null) return;

    final updatedComponent = component.copyWith(
      properties: {...component.properties, 'visible': !(component.properties['visible'] as bool? ?? true)},
    );
    _updateComponentInState(updatedComponent);
    _sendToPreview(VisualEditorMessageType.updateProperty, {
      'componentId': componentId,
      'propertyKey': 'visible',
      'value': updatedComponent.properties['visible'],
    });
  }

  /// Update a property
  void updateProperty({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  }) {
    final component = state.findComponent(componentId);
    if (component == null) return;

    final updatedProperties = Map<String, dynamic>.from(component.properties);
    updatedProperties[propertyKey] = value;

    final updatedComponent = component.copyWith(properties: updatedProperties);
    _updateComponentInState(updatedComponent);

    _sendToPreview(VisualEditorMessageType.updateProperty, {
      'componentId': componentId,
      'propertyKey': propertyKey,
      'value': value,
    });
    _saveDraft();
  }

  /// Reset a property to default
  void resetProperty({
    required String componentId,
    required String propertyKey,
  }) {
    final component = state.findComponent(componentId);
    if (component == null) return;

    final defaultValue = component.defaultValues[propertyKey];
    if (defaultValue == null) return;

    updateProperty(componentId: componentId, propertyKey: propertyKey, value: defaultValue);
  }

  void _updateComponentInState(EditableComponent updatedComponent) {
    final updatedPages = <String, List<EditableComponent>>{};
    state.componentsByPage.forEach((pageId, components) {
      updatedPages[pageId] = components.map((c) {
        if (c.componentId == updatedComponent.componentId) return updatedComponent;
        return _updateChildRecursive(c, updatedComponent);
      }).toList();
    });

    emit(state.copyWith(
      componentsByPage: updatedPages,
      selectedComponent: state.selectedComponent?.componentId == updatedComponent.componentId
          ? updatedComponent
          : state.selectedComponent,
    ));
  }

  EditableComponent _updateChildRecursive(EditableComponent parent, EditableComponent target) {
    // For now, components don't have children in this model
    // This would be extended if we add nested children support
    return parent;
  }

  List<EditableComponent> _addChildRecursive(List<EditableComponent> components, String parentId, EditableComponent child) {
    return components.map((c) {
      if (c.componentId == parentId) {
        // In a real implementation, we'd add to parent's children
        // For now, just insert after parent
        return c;
      }
      return c;
    }).toList();
  }

  List<EditableComponent> _removeComponentRecursive(List<EditableComponent> components, String componentId) {
    return components.where((c) => c.componentId != componentId).toList();
  }

  void _sendCurrentDesign() {
    final designDoc = _buildDesignDocument();
    _sendToPreview(VisualEditorMessageType.applyDesignConfig, {
      'designDocument': designDoc,
    });
  }

  Map<String, dynamic> _buildDesignDocument() {
    final pages = <String, dynamic>{};
    state.componentsByPage.forEach((pageId, components) {
      pages[pageId] = {
        'root': _componentsToTree(components),
      };
    });
    return {
      'schemaVersion': 2,
      'theme': {},
      'pages': pages,
    };
  }

  dynamic _componentsToTree(List<EditableComponent> components) {
    // Build tree structure for the design document
    // For now, return flat list as children of page root
    return {
      'type': 'page.${components.first.pageId}',
      'children': components.map(_componentToJson).toList(),
    };
  }

  Map<String, dynamic> _componentToJson(EditableComponent component) {
    return {
      'id': component.componentId,
      'type': component.componentType,
      'visible': component.properties['visible'] ?? true,
      'properties': component.properties,
      'children': [],
    };
  }

  void _sendToPreview(VisualEditorMessageType type, Map<String, dynamic> payload) {
    // This would send via the PreviewPanel's bridge
    // Implementation depends on the bridge setup
  }

  Future<void> _saveDraft() async {
    await _repository.saveDraft(state.sessionId, state.componentsByPage);
  }

  /// Save as published version
  Future<void> publish() async {
    final designDoc = _buildDesignDocument();
    await _repository.publishDesign(state.sessionId, designDoc);
  }

  /// Load a published version
  Future<void> loadPublishedVersion(String versionId) async {
    final design = await _repository.getPublishedVersion(versionId);
    if (design != null) {
      // Parse and load design into state
      _loadDesignIntoState(design);
    }
  }

  void _loadDesignIntoState(Map<String, dynamic> design) {
    // Parse design document and populate componentsByPage
    // This would reconstruct the component tree
  }
}