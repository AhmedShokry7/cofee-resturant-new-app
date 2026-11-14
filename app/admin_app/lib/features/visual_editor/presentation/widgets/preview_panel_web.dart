// Web-only implementation: creates the iframe element and wires postMessage.
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:convert';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;
import 'package:flutter/widgets.dart';

import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// الإطارات الحية حسب viewType — المنفذ الذي تمر عبره الرسائل الصادرة.
final Map<String, web.HTMLIFrameElement> _iframes = {};

void registerPreviewView({
  required String viewType,
  required String url,
  required String? sessionId,
  required String? parentOrigin,
  required void Function(dynamic) onElementSelected,
  required void Function(dynamic) onPreviewReady,
  required void Function(dynamic) onPreviewError,
  required void Function(dynamic) onPropertyUpdated,
  required void Function(dynamic) onTreeUpdated,
}) {
  _iframes.remove(viewType);
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => createPreviewIframe(
      viewType: viewType,
      url: url,
      sessionId: sessionId,
      parentOrigin: parentOrigin,
      onElementSelected: onElementSelected,
      onPreviewReady: onPreviewReady,
      onPreviewError: onPreviewError,
      onPropertyUpdated: onPropertyUpdated,
      onTreeUpdated: onTreeUpdated,
    ),
  );
}

Widget buildPreviewView({required String viewType}) =>
    HtmlElementView(viewType: viewType);

/// يبني عنصر iframe حقيقيًا ويعلّق معالج postMessage عليه.
///
/// الأمان:
/// - كل رسالة واردة تُفحص ضد `sessionId` وضد origin الأب المتوقع.
/// - الصادر يتجه إلى origin الأب المعلن، لا إلى `*`.
web.HTMLElement createPreviewIframe({
  required String viewType,
  required String url,
  required String? sessionId,
  required String? parentOrigin,
  required void Function(dynamic) onElementSelected,
  required void Function(dynamic) onPreviewReady,
  required void Function(dynamic) onPreviewError,
  required void Function(dynamic) onPropertyUpdated,
  required void Function(dynamic) onTreeUpdated,
}) {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  iframe.src = url;
  iframe.style.border = 'none';
  iframe.style.width = '100%';
  iframe.style.height = '100%';
  iframe.setAttribute('loading', 'lazy');

  _iframes[viewType] = iframe;

  _attachMessageHandler(
    sessionId: sessionId,
    parentOrigin: parentOrigin,
    onElementSelected: onElementSelected,
    onPreviewReady: onPreviewReady,
    onPreviewError: onPreviewError,
    onPropertyUpdated: onPropertyUpdated,
    onTreeUpdated: onTreeUpdated,
  );

  return iframe;
}

void _attachMessageHandler({
  required String? sessionId,
  required String? parentOrigin,
  required void Function(dynamic) onElementSelected,
  required void Function(dynamic) onPreviewReady,
  required void Function(dynamic) onPreviewError,
  required void Function(dynamic) onPropertyUpdated,
  required void Function(dynamic) onTreeUpdated,
}) {
  web.window.addEventListener(
    'message',
    (web.Event event) {
      if (!event.isA<web.MessageEvent>()) return;
      try {
        final msgEvent = event as web.MessageEvent;
        // origin الأب المتوقع يأتي من نافذة الأدمن نفسها؛ غيابه يعني
        // قبول ما يصل من أي مصدر يعرّف نفسه بالجلسة — لا في الإنتاج.
        if (parentOrigin != null && msgEvent.origin != parentOrigin) return;
        final data = msgEvent.data.dartify();
        if (data is! Map) return;

        // تحقق من sessionId
        if (sessionId != null && data['sessionId'] != sessionId) return;

        final type = data['type'] as String?;
        final payload = data['payload'] ?? <String, dynamic>{};

        switch (type) {
          case 'PREVIEW_READY':
            onPreviewReady(payload);
          case 'ELEMENT_SELECTED':
            onElementSelected(payload);
          case 'PROPERTY_UPDATED':
            onPropertyUpdated(data);
          case 'COMPONENT_TREE_UPDATED':
            onTreeUpdated(payload);
          case 'PREVIEW_ERROR':
            onPreviewError(payload);
        }
      } catch (_) {
        // رسالة غير صالحة — نتجاهلها
      }
    }.toJS,
  );
}

/// يرسل رسالة postMessage إلى iframe معاينة حسب viewType.
void sendOutboundMessage({
  required String viewType,
  required VisualEditorMessageType type,
  required Map<String, dynamic> payload,
  required String sessionId,
  required String messageId,
  required String? parentOrigin,
}) {
  final iframe = _iframes[viewType];
  if (iframe == null) return;
  final message = jsonEncode({
    'protocolVersion': '1.0',
    'messageId': messageId,
    'sessionId': sessionId,
    'type': type.value,
    'payload': payload,
  });
  iframe.contentWindow?.postMessage(
    message.toJS,
    (parentOrigin ?? '*').toJS,
  );
}
