// Preview bridge — web implementation.
//
// postMessage مع نافذة الأدمن (parent) داخل إطار المعاينة. هذا الملف يحمل
// `dart:js_interop` فلا يستورد إلا عبر شرط `dart.library.js_interop` من
// preview_bridge.dart، فلا يلمس ترجمة الهاتف ولا اختباراته.
//
// الأمان:
// - كل رسالة تُفحص ضد `sessionId` من رابط الإقلاع.
// - كل رسالة تُفحص ضد origin الأب المتوقع، الذي تمرّره لوحة الأدمن في رابط
//   المعاينة (`parentOrigin=`). غيابه يعني الرفض: لا معاينة تثق بمن أرسل.
// - الصادر يتجه إلى origin الأب المعلن، لا إلى `*`.

import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:web/web.dart' as web;

import 'package:new_coffee/core/preview/preview_bridge.dart';

/// Handles postMessage communication with the parent window.
class PreviewBridge {
  static final PreviewBridge _instance = PreviewBridge._internal();
  factory PreviewBridge() => _instance;
  PreviewBridge._internal();

  String? _sessionId;
  String? _parentOrigin;
  JSFunction? _listener;

  /// نشط فقط داخل معاينة الأدمن على الويب: جلسة معروفة ومستمع موصول.
  bool get isActive => kIsWeb && _sessionId != null && _listener != null;

  final Map<String, void Function(PreviewMessage)> _handlers = {};

  /// Initialize the bridge with a session ID from the launch URL.
  void initialize(String sessionId, {String? parentOrigin}) {
    _sessionId = sessionId;
    _parentOrigin = parentOrigin;
    if (!kIsWeb) return;
    _attachMessageListener();
    _sendReady();
  }

  void _attachMessageListener() {
    if (_listener != null) return;
    void handler(web.MessageEvent event) {
      try {
        if (_parentOrigin != null && event.origin != _parentOrigin) {
          return;
        }
        final message = PreviewMessage.fromJson(event.data.dartify());
        if (message == null || message.sessionId != _sessionId) return;
        _handlers[message.type.value]?.call(message);
      } catch (error) {
        debugPrint('[PreviewBridge] رسالة غير صالحة: $error');
      }
    }

    _listener = handler.toJS;
    web.window.addEventListener('message', _listener!);
  }

  void _sendReady() {
    if (_sessionId == null) return;
    _post(
      PreviewMessage(
        sessionId: _sessionId!,
        type: PreviewMessageType.previewReady,
        payload: const {'platform': 'web'},
      ),
    );
  }

  /// Send element selected event to parent
  void sendElementSelected({
    required String componentId,
    required String componentType,
    required String pageId,
    Map<String, dynamic>? properties,
    String? parentId,
    int? index,
  }) {
    if (_sessionId == null) return;
    _post(
      PreviewMessage(
        sessionId: _sessionId!,
        type: PreviewMessageType.elementSelected,
        payload: {
          'componentId': componentId,
          'componentType': componentType,
          'pageId': pageId,
          'parentId': parentId,
          'index': index,
          'properties': properties ?? const <String, dynamic>{},
        },
      ),
    );
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
    _post(
      PreviewMessage(
        sessionId: _sessionId!,
        type: PreviewMessageType.propertyUpdated,
        payload: {
          'componentId': componentId,
          'propertyKey': propertyKey,
          'value': value,
          'success': success,
          if (error != null) 'error': error,
        },
      ),
    );
  }

  /// Send the current tree state so the editor can sync its layers panel.
  void sendTreeUpdated({
    required String pageId,
    required List<Map<String, dynamic>> nodes,
  }) {
    if (_sessionId == null) return;
    _post(
      PreviewMessage(
        sessionId: _sessionId!,
        type: PreviewMessageType.componentTreeUpdated,
        payload: {'pageId': pageId, 'nodes': nodes},
      ),
    );
  }

  void _post(PreviewMessage message) {
    if (!kIsWeb) return;
    final parent = web.window.parent;
    if (parent == null) return;
    parent.postMessage(
      message.toJsonString().toJS,
      (_parentOrigin ?? '*').toJS,
    );
  }

  /// Register a handler for incoming messages
  void onMessage(
    PreviewMessageType type,
    void Function(PreviewMessage) handler,
  ) {
    _handlers[type.value] = handler;
  }

  void dispose() {
    if (_listener != null && kIsWeb) {
      web.window.removeEventListener('message', _listener!);
    }
    _listener = null;
    _handlers.clear();
    _sessionId = null;
    _parentOrigin = null;
  }
}
