import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/studio_registry.dart';
import '../../data/repositories/studio_draft_repository.dart';

/// Editable projection of the customer's PublishedSection contract.
class StudioNode {
  const StudioNode({
    required this.id,
    required this.type,
    this.props = const <String, Object?>{},
    this.visible = true,
    this.children = const <StudioNode>[],
  });

  final String id;
  final String type;
  final Map<String, Object?> props;
  final bool visible;
  final List<StudioNode> children;

  StudioNode copyWith({
    String? id,
    String? type,
    Map<String, Object?>? props,
    bool? visible,
    List<StudioNode>? children,
  }) => StudioNode(
    id: id ?? this.id,
    type: type ?? this.type,
    props: props ?? this.props,
    visible: visible ?? this.visible,
    children: children ?? this.children,
  );

  StudioNode set(String key, Object value) =>
      copyWith(props: <String, Object?>{...props, key: value});

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type,
    'visible': visible,
    'properties': props,
    if (children.isNotEmpty)
      'children': children.map((node) => node.toJson()).toList(),
  };

  static StudioNode? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['type'] is! String) {
      return null;
    }
    final rawProperties = raw['properties'] ?? raw['props'];
    if (rawProperties != null && rawProperties is! Map) return null;
    final children = <StudioNode>[];
    if (raw['children'] is List) {
      for (final child in raw['children'] as List) {
        final parsed = fromJson(child);
        if (parsed != null) children.add(parsed);
      }
    }
    return StudioNode(
      id: raw['id'] as String,
      type: raw['type'] as String,
      visible: raw['visible'] is bool ? raw['visible'] as bool : true,
      props: rawProperties is Map
          ? Map<String, Object?>.from(rawProperties)
          : const {},
      children: children,
    );
  }
}

class StudioState {
  const StudioState({
    required this.pageId,
    required this.nodes,
    this.selectedNodeId,
    this.dirty = false,
    this.saving = false,
    this.lastSaved,
    this.canUndo = false,
    this.canRedo = false,
    this.validationError,
    this.loading = false,
  });

  final String pageId;
  final List<StudioNode> nodes;
  final String? selectedNodeId;
  final bool dirty;
  final bool saving;
  final DateTime? lastSaved;
  final bool canUndo;
  final bool canRedo;
  final String? validationError;
  final bool loading;

  StudioNode? findNode(String? id) => _find(nodes, id);
  StudioNode? get selectedNode => findNode(selectedNodeId);

  StudioState copyWith({
    String? pageId,
    List<StudioNode>? nodes,
    String? selectedNodeId,
    bool clearSelection = false,
    bool? dirty,
    bool? saving,
    DateTime? lastSaved,
    bool? canUndo,
    bool? canRedo,
    String? validationError,
    bool clearValidation = false,
    bool? loading,
  }) => StudioState(
    pageId: pageId ?? this.pageId,
    nodes: nodes ?? this.nodes,
    selectedNodeId: clearSelection
        ? null
        : (selectedNodeId ?? this.selectedNodeId),
    dirty: dirty ?? this.dirty,
    saving: saving ?? this.saving,
    lastSaved: lastSaved ?? this.lastSaved,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    validationError: clearValidation
        ? null
        : (validationError ?? this.validationError),
    loading: loading ?? this.loading,
  );
}

StudioNode? _find(List<StudioNode> nodes, String? id) {
  if (id == null) return null;
  for (final node in nodes) {
    if (node.id == id) return node;
    final nested = _find(node.children, id);
    if (nested != null) return nested;
  }
  return null;
}

class _Snapshot {
  const _Snapshot(this.nodes, this.selectedNodeId);
  final List<StudioNode> nodes;
  final String? selectedNodeId;
}

class StudioCubit extends Cubit<StudioState> {
  StudioCubit(this._repository)
    : super(const StudioState(pageId: 'home', nodes: [], loading: true));
  final StudioDraftRepository _repository;
  final Map<String, List<_Snapshot>> _history = {};
  final Map<String, int> _historyCursor = {};
  final Map<String, bool> _loaded = {};
  Timer? _saveTimer;

  bool get canEditCurrentPage => studioPages.any(
    (page) => page.id == state.pageId && page.support == 'Partially Editable',
  );

  Map<String, Object?> get previewDocument => <String, Object?>{
    'schema_version': 2,
    'theme': <String, Object?>{},
    'pages': <Map<String, Object?>>[
      <String, Object?>{
        'page': state.pageId,
        'root': <String, Object?>{
          'id': 'studio-${state.pageId}-root',
          'type': 'page.home',
          'children': state.nodes.map((node) => node.toJson()).toList(),
        },
      },
    ],
  };

  Future<void> restore() => _loadPage(state.pageId);

  Future<void> _loadPage(String id) async {
    emit(state.copyWith(loading: true, clearValidation: true));
    try {
      final draft = await _repository.load(id);
      final parsed = <StudioNode>[];
      final rawNodes = draft?['nodes'];
      if (rawNodes is List) {
        for (final raw in rawNodes) {
          final node = StudioNode.fromJson(raw);
          if (node != null) parsed.add(node);
        }
      }
      _loaded[id] = true;
      _seedHistory(id, parsed);
      emit(
        state.copyWith(
          pageId: id,
          nodes: parsed,
          clearSelection: true,
          dirty: false,
          saving: false,
          loading: false,
          clearValidation: true,
          canUndo: false,
          canRedo: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loading: false,
          validationError: 'Draft load failed: $error',
        ),
      );
    }
  }

  Future<void> selectPage(String id) async {
    if (id == state.pageId || !studioPages.any((page) => page.id == id)) return;
    await saveDraft();
    if (state.dirty || state.saving) return;
    if (_loaded[id] == true) {
      final cursor = _historyCursor[id] ?? 0;
      final snapshots = _history[id] ?? const <_Snapshot>[];
      final snapshot = snapshots.isEmpty
          ? const _Snapshot([], null)
          : snapshots[cursor];
      emit(
        state.copyWith(
          pageId: id,
          nodes: snapshot.nodes,
          selectedNodeId: snapshot.selectedNodeId,
          clearSelection: snapshot.selectedNodeId == null,
          dirty: false,
          canUndo: cursor > 0,
          canRedo: cursor < snapshots.length - 1,
          clearValidation: true,
        ),
      );
    } else {
      await _loadPage(id);
    }
  }

  void selectNode(String? id) =>
      emit(state.copyWith(selectedNodeId: id, clearSelection: id == null));

  StudioComponentDefinition? definitionFor(StudioNode node) {
    for (final definition in studioComponents) {
      if (definition.type == node.type) return definition;
    }
    return null;
  }

  void updateProperty(String key, Object value) {
    final node = state.selectedNode;
    final definition = node == null ? null : definitionFor(node);
    final property = definition?.properties
        .where((item) => item.key == key)
        .firstOrNull;
    if (node == null || property == null) return;
    final validation = validateStudioValue(property, value);
    if (validation != null) {
      emit(state.copyWith(validationError: validation));
      return;
    }
    _commit(
      _replaceNode(state.nodes, node.id, (current) => current.set(key, value)),
    );
  }

  void toggleVisibility(String id) {
    final node = state.findNode(id);
    if (node == null || !canEditCurrentPage) return;
    _commit(
      _replaceNode(
        state.nodes,
        id,
        (current) => current.copyWith(visible: !current.visible),
      ),
    );
  }

  void addNode(String type, {String? parentId}) {
    if (!canEditCurrentPage) return;
    final definition = studioComponents
        .where((item) => item.type == type)
        .firstOrNull;
    if (definition == null) return;
    if (parentId != null) {
      final parent = state.findNode(parentId);
      if (parent == null) return;
      if (!studioComponents.any(
        (item) =>
            item.type == parent.type && item.allowedChildren.contains(type),
      )) {
        return;
      }
    }
    final id = '$type-${DateTime.now().microsecondsSinceEpoch}';
    final props = <String, Object?>{
      for (final property in definition.properties)
        if (!_chromePropertyKeys.contains(property.key))
          property.key: property.initialValue,
    };
    if (type == 'section.button') props['action'] = 'navigateHome';
    if (type == 'section.heading') props.addAll({'title': 'Section heading'});
    final node = StudioNode(id: id, type: type, props: props);
    if (parentId == null) {
      _commit([...state.nodes, node], selectedNodeId: id);
    } else {
      _commit(
        _replaceNode(
          state.nodes,
          parentId,
          (parent) => parent.copyWith(children: [...parent.children, node]),
        ),
        selectedNodeId: id,
      );
    }
  }

  void removeSelected() {
    final id = state.selectedNodeId;
    if (!canEditCurrentPage || id == null) return;
    _commit(_removeNode(state.nodes, id), clearSelection: true);
  }

  void duplicateSelected() {
    final source = state.selectedNode;
    if (!canEditCurrentPage || source == null) return;
    final copy = _cloneWithNewIds(source);
    _commit(
      _insertAfterNode(state.nodes, source.id, copy),
      selectedNodeId: copy.id,
    );
  }

  void moveSelected(int delta) {
    final id = state.selectedNodeId;
    if (!canEditCurrentPage || id == null || delta == 0) return;
    final moved = _moveNode(state.nodes, id, delta);
    if (moved != null) _commit(moved);
  }

  void undo() => _travelHistory(-1);
  void redo() => _travelHistory(1);

  void _travelHistory(int delta) {
    final snapshots = _history[state.pageId] ?? const <_Snapshot>[];
    final cursor = _historyCursor[state.pageId] ?? 0;
    final next = cursor + delta;
    if (next < 0 || next >= snapshots.length) return;
    _historyCursor[state.pageId] = next;
    final snapshot = snapshots[next];
    emit(
      state.copyWith(
        nodes: snapshot.nodes,
        selectedNodeId: snapshot.selectedNodeId,
        clearSelection: snapshot.selectedNodeId == null,
        dirty: true,
        canUndo: next > 0,
        canRedo: next < snapshots.length - 1,
        clearValidation: true,
      ),
    );
    _scheduleSave();
  }

  void _commit(
    List<StudioNode> nodes, {
    String? selectedNodeId,
    bool clearSelection = false,
  }) {
    final snapshot = _Snapshot(
      nodes,
      clearSelection ? null : (selectedNodeId ?? state.selectedNodeId),
    );
    final snapshots = [...?_history[state.pageId]];
    final cursor = _historyCursor[state.pageId] ?? snapshots.length - 1;
    if (cursor + 1 < snapshots.length) {
      snapshots.removeRange(cursor + 1, snapshots.length);
    }
    snapshots.add(snapshot);
    if (snapshots.length > 100) snapshots.removeAt(0);
    _history[state.pageId] = snapshots;
    _historyCursor[state.pageId] = snapshots.length - 1;
    emit(
      state.copyWith(
        nodes: nodes,
        selectedNodeId: selectedNodeId,
        clearSelection: clearSelection,
        dirty: true,
        canUndo: snapshots.length > 1,
        canRedo: false,
        clearValidation: true,
      ),
    );
    _scheduleSave();
  }

  void _seedHistory(String pageId, List<StudioNode> nodes) {
    _history[pageId] = [_Snapshot(nodes, null)];
    _historyCursor[pageId] = 0;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), saveDraft);
  }

  Future<void> saveDraft() async {
    if (!state.dirty || state.saving) return;
    final error = validateDocument(state.nodes);
    if (error != null) {
      emit(state.copyWith(validationError: error));
      return;
    }
    final pageId = state.pageId;
    final nodes = state.nodes;
    emit(state.copyWith(saving: true, clearValidation: true));
    try {
      await _repository.save(pageId, <String, Object?>{
        'schemaVersion': 2,
        'pageId': pageId,
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (state.pageId == pageId) {
        emit(
          state.copyWith(
            dirty: false,
            saving: false,
            lastSaved: DateTime.now(),
          ),
        );
      }
    } catch (error) {
      if (state.pageId == pageId) {
        emit(
          state.copyWith(
            saving: false,
            validationError: 'Local save failed: $error',
          ),
        );
      }
    }
  }

  String? validateDocument(List<StudioNode> nodes) {
    for (final node in nodes) {
      final definition = definitionFor(node);
      if (definition == null) return 'Unsupported component type: ${node.type}';
      for (final entry in node.props.entries) {
        final property = definition.properties
            .where((item) => item.key == entry.key)
            .firstOrNull;
        if (property == null) {
          return 'Unsupported property ${entry.key} on ${node.type}';
        }
        final error = validateStudioValue(property, entry.value ?? '');
        if (error != null) return '${definition.title}.${property.key}: $error';
      }
      if (node.children.isNotEmpty && definition.allowedChildren.isEmpty) {
        return '${node.type} cannot contain children';
      }
      for (final child in node.children) {
        if (!definition.allowedChildren.contains(child.type)) {
          return '${node.type} cannot contain ${child.type}';
        }
      }
      final childError = validateDocument(node.children);
      if (childError != null) return childError;
    }
    return null;
  }

  @override
  Future<void> close() {
    _saveTimer?.cancel();
    return super.close();
  }
}

List<StudioNode> _replaceNode(
  List<StudioNode> nodes,
  String id,
  StudioNode Function(StudioNode) update,
) => [
  for (final node in nodes)
    if (node.id == id)
      update(node)
    else
      node.copyWith(children: _replaceNode(node.children, id, update)),
];

List<StudioNode> _removeNode(List<StudioNode> nodes, String id) => [
  for (final node in nodes)
    if (node.id != id) node.copyWith(children: _removeNode(node.children, id)),
];

List<StudioNode>? _moveNode(List<StudioNode> nodes, String id, int delta) {
  final index = nodes.indexWhere((node) => node.id == id);
  if (index >= 0) {
    final target = (index + delta).clamp(0, nodes.length - 1);
    if (target == index) return null;
    final result = [...nodes];
    final item = result.removeAt(index);
    result.insert(target, item);
    return result;
  }
  for (var i = 0; i < nodes.length; i++) {
    final nested = _moveNode(nodes[i].children, id, delta);
    if (nested != null) {
      final result = [...nodes];
      result[i] = result[i].copyWith(children: nested);
      return result;
    }
  }
  return null;
}

List<StudioNode> _insertAfterNode(
  List<StudioNode> nodes,
  String id,
  StudioNode copy,
) {
  final result = <StudioNode>[];
  for (final node in nodes) {
    result.add(node);
    if (node.id == id) {
      result.add(copy);
    } else {
      final nested = _insertAfterNode(node.children, id, copy);
      if (nested.length != node.children.length) {
        result[result.length - 1] = node.copyWith(children: nested);
      }
    }
  }
  return result;
}

StudioNode _cloneWithNewIds(StudioNode node) {
  final id =
      '${node.type}-${DateTime.now().microsecondsSinceEpoch}-${node.id.hashCode.abs()}';
  return node.copyWith(
    id: id,
    children: node.children.map(_cloneWithNewIds).toList(),
  );
}

const _chromePropertyKeys = <String>{
  'width',
  'height',
  'padTop',
  'padBottom',
  'padLeft',
  'padRight',
  'marginTop',
  'marginBottom',
  'marginLeft',
  'marginRight',
  'backgroundColor',
  'borderColor',
  'borderWidth',
  'radiusTL',
  'radiusTR',
  'radiusBL',
  'radiusBR',
  'opacity',
};
