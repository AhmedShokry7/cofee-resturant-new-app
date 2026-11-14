// Preview mode communication with the Admin App (parent window).
//
// This file only exists for the preview entry point (main_preview.dart) that
// runs inside the Admin App's visual editor iframe. On Android/iOS the bridge
// is inert: `isActive` is false, no listener is attached, and nothing sends.
//
// This file holds the protocol contract only — pure Dart, safe on every
// platform. The implementation is picked conditionally: the web bridge owns
// `dart:js_interop`, and a stub keeps the phone build free of it.
//
// Protocol (both sides agree, protocolVersion 1.0):
//   { protocolVersion, messageId, sessionId, type, payload }
// Outbound: PREVIEW_READY, ELEMENT_SELECTED, PROPERTY_UPDATED,
//           COMPONENT_TREE_UPDATED, PREVIEW_ERROR.
// Inbound:  PREVIEW_INITIALIZE, LOAD_PAGE, SELECT_ELEMENT, UPDATE_PROPERTY,
//           ADD_COMPONENT, REMOVE_COMPONENT, REORDER_COMPONENT,
//           APPLY_DESIGN_CONFIG, PREVIEW_REFRESH, PREVIEW_ERROR.

import 'dart:convert';

export 'preview_bridge_stub.dart'
    if (dart.library.js_interop) 'preview_bridge_web.dart';

/// Message types for the preview communication protocol
enum PreviewMessageType {
  previewReady('PREVIEW_READY'),
  previewInitialize('PREVIEW_INITIALIZE'),
  loadPage('LOAD_PAGE'),
  selectElement('SELECT_ELEMENT'),
  elementSelected('ELEMENT_SELECTED'),
  updateProperty('UPDATE_PROPERTY'),
  propertyUpdated('PROPERTY_UPDATED'),
  componentTreeUpdated('COMPONENT_TREE_UPDATED'),
  addComponent('ADD_COMPONENT'),
  removeComponent('REMOVE_COMPONENT'),
  reorderComponent('REORDER_COMPONENT'),
  applyDesignConfig('APPLY_DESIGN_CONFIG'),
  previewError('PREVIEW_ERROR'),
  previewRefresh('PREVIEW_REFRESH'),
  saveRequest('SAVE_REQUEST');

  const PreviewMessageType(this.value);
  final String value;
}

/// Base message structure for preview communication
class PreviewMessage {
  PreviewMessage({
    String? messageId,
    required this.sessionId,
    required this.type,
    required this.payload,
  }) : messageId =
            messageId ?? DateTime.now().microsecondsSinceEpoch.toString();

  static const String protocolVersion = '1.0';

  final String messageId;
  final String sessionId;
  final PreviewMessageType type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'protocolVersion': protocolVersion,
    'messageId': messageId,
    'sessionId': sessionId,
    'type': type.value,
    'payload': payload,
  };

  String toJsonString() => jsonEncode(toJson());

  /// null = رسالة غير مفهومة: نوع مجهول أو شكل مخالف. المستقبل يتجاهلها.
  static PreviewMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    if (raw['protocolVersion'] != protocolVersion) return null;
    final sessionId = raw['sessionId'];
    final type = raw['type'];
    if (sessionId is! String || sessionId.isEmpty) return null;
    if (type is! String) return null;
    PreviewMessageType? kind;
    for (final candidate in PreviewMessageType.values) {
      if (candidate.value == type) kind = candidate;
    }
    if (kind == null) return null;
    final payload = raw['payload'];
    return PreviewMessage(
      sessionId: sessionId,
      type: kind,
      payload: payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{},
    );
  }
}
