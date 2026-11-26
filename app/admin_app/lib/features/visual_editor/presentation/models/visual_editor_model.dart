import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Node representation for the visual editor tree.
class VisualNode {
  final String id;
  final String type;
  Map<String, dynamic> props;
  List<VisualNode> children;

  VisualNode({
    required this.id,
    required this.type,
    this.props = const {},
    this.children = const [],
  });

  factory VisualNode.fromJson(Map<String, dynamic> json) => VisualNode(
    id: json['id'] as String,
    type: json['type'] as String,
    props: Map<String, dynamic>.from(json['props'] ?? {}),
    children: (json['children'] as List<dynamic>? ?? [])
        .map((e) => VisualNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'props': props,
    'children': children.map((c) => c.toJson()).toList(),
  };
}

/// ChangeNotifier that holds the widget tree and notifies listeners on updates.
class VisualEditorModel extends ChangeNotifier {
  VisualNode root;

  VisualEditorModel(this.root);

  /// Update a node's properties by its id and notify listeners.
  void updateNode(String id, Map<String, dynamic> newProps) {
    bool update(VisualNode node) {
      if (node.id == id) {
        node.props = {...node.props, ...newProps};
        return true;
      }
      for (var child in node.children) {
        if (update(child)) return true;
      }
      return false;
    }

    if (update(root)) notifyListeners();
  }

  /// Export the full tree as a JSON string.
  String exportJson() => jsonEncode(root.toJson());

  /// Replace the whole tree from a JSON string.
  void importJson(String jsonStr) {
    root = VisualNode.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    notifyListeners();
  }
}
