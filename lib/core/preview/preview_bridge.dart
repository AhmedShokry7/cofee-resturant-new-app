// Preview mode JavaScript interop for postMessage communication
//
// This file handles the communication between the Admin App (parent)
// and the Customer App preview (iframe).

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:convert';

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
  final String protocolVersion = '1.0';
  final String messageId;
  final String sessionId;
  final PreviewMessageType type;
  final Map<String, dynamic> payload;

  PreviewMessage({
    required this.messageId,
    required this.sessionId,
    required this.type,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
    'protocolVersion': protocolVersion,
    'messageId': messageId,
    'sessionId': sessionId,
    'type': type.value,
    'payload': payload,
  };

  String toJsonString() => jsonEncode(toJson());

  static PreviewMessage? fromJsonString(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return PreviewMessage(
        messageId: map['messageId'] as String,
        sessionId: map['sessionId'] as String,
        type: PreviewMessageType.values.firstWhere(
          (e) => e.value == map['type'],
          orElse: () => throw ArgumentError('Unknown message type: ${map['type']}'),
        ),
        payload: map['payload'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Handles postMessage communication with the parent window
class PreviewBridge {
  static final PreviewBridge _instance = PreviewBridge._internal();
  factory PreviewBridge() => _instance;
  PreviewBridge._internal();

  String? _sessionId;
  final Map<String, void Function(PreviewMessage)> _handlers = {};
  JSObject? _messageListener;

  /// Initialize the bridge with a session ID
  void initialize(String sessionId) {
    _sessionId = sessionId;
    _attachMessageListener();
    _sendReady();
  }

  void _attachMessageListener() {
    if (JS('bool', 'typeof window === "undefined"')) return;

    _messageListener = JS('Object', '''
      (function(bridge) {
        return function(event) {
          if (event.origin !== window.parent.origin && event.origin !== "null") {
            return;
          }
          try {
            const message = JSON.parse(event.data);
            if (message && message.sessionId === bridge.sessionId) {
              bridge.handleMessage(message);
            }
          } catch (e) {
            console.warn('PreviewBridge: Invalid message', e);
          }
        };
      })(this)
    '''.toJS);

    JS('void', 'window.addEventListener("message", this[_messageListener])');
  }

  void _detachMessageListener() {
    if (_messageListener != null) {
      JS('void', 'window.removeEventListener("message", this[_messageListener])');
      _messageListener = null;
    }
  }

  @JS('handleMessage')
  external void handleMessage(JSObject message);

  void _sendReady() {
    if (_sessionId == null) return;
    final message = PreviewMessage(
      messageId: DateTime.now().microsecondsSinceEpoch.toString(),
      sessionId: _sessionId!,
      type: PreviewMessageType.previewReady,
      payload: {'userAgent': JS('String', 'navigator.userAgent')},
    );
    _postMessage(message);
  }

  void _postMessage(PreviewMessage message) {
    if (JS('bool', 'typeof window === "undefined"')) return;
    JS('void', 'window.parent.postMessage(this, "*")', message.toJsonString().toJS);
  }

  /// Send element selected event to parent
  void sendElementSelected({
    required String componentId,
    required String componentType,
    required String pageId,
    required Map<String, dynamic> properties,
    required Map<String, dynamic> editableProperties,
    String? parentId,
    int? index,
  }) {
    if (_sessionId == null) return;
    final message = PreviewMessage(
      messageId: DateTime.now().microsecondsSinceEpoch.toString(),
      sessionId: _sessionId!,
      type: PreviewMessageType.elementSelected,
      payload: {
        'componentId': componentId,
        'componentType': componentType,
        'pageId': pageId,
        'parentId': parentId,
        'index': index,
        'properties': properties,
        'editableProperties': editableProperties,
      },
    );
    _postMessage(message);
  }

  /// Send property updated confirmation to parent
  void sendPropertyUpdated({
    required String componentId,
    required String propertyKey,
    required dynamic value,
    bool success = true,
    String? error,
  }) {
    if (_sessionId == null) return;
    final message = PreviewMessage(
      messageId: DateTime.now().microsecondsSinceEpoch.toString(),
      sessionId: _sessionId!,
      type: PreviewMessageType.propertyUpdated,
      payload: {
        'componentId': componentId,
        'propertyKey': propertyKey,
        'value': value,
        'success': success,
        'error': error,
      },
    );
    _postMessage(message);
  }

  /// Register a handler for incoming messages
  void onMessage(PreviewMessageType type, void Function(PreviewMessage) handler) {
    _handlers[type.value] = handler;
  }

  void dispose() {
    _detachMessageListener();
    _handlers.clear();
  }
}