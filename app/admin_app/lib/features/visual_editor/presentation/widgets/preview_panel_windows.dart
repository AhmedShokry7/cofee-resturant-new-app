// Windows implementation of the live preview channel: WebView2 (Edge) via
// the `webview_windows` plugin, embedded in the editor's preview panel.
//
// نفس عقد الطبقة الويب حرفيًا: نفس البروتوكول، نفس طابور الصادر، نفس فحص
// المصدر والجلسة. الفرق الوحيد قناة النقل:
// - الصادر من المحرر يُحقن في الصفحة عبر executeScript → window.postMessage
//   فيستقبله جسر العميل كما يستقبل رسائل الأب على الويب.
// - الوارد من العميل: العميل يرسل إلى `window.parent` (الصفحة نفسها داخل
//   WebView2) — سكربت مُحقن يعيد تمرير كل حدث message إلى المضيف عبر قناة
//   `chrome.webview.postMessage` الخاصة بـWebView2، والغلاف يحمل origin
//   المرسل فبقى فحص المصدر كما هو.
// الأمان كما هو: كل رسالة واردة تُفحص ضد origin تطبيق العميل ثم ضد
// `sessionId` قبل أن تلمس المحرر.
import 'dart:async';
import 'dart:convert' show jsonEncode;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// هل تدار قناة المعاينة الحية (WebView2) على هذه المنصة؟
/// ويندوز فقط: ماك ولينكس والموبايل تبقى على الرسم الأصلي.
final bool supportsLiveWebview = Platform.isWindows;

/// متحكمات WebView2 لكل viewType — تُنشأ مرة وتُعاد استخدامها مع كل زيارة
/// للوحة المعاينة، كما عنصر iframe يبقى على الويب.
final Map<String, WebviewController> _controllers = {};

/// جاهزية كل متحكم: الودجت يظهر بعد اكتمال initialize فلا لحظة فارغة.
final Map<String, ValueNotifier<bool>> _controllerReady = {};

final Map<String, StreamSubscription<dynamic>> _subscriptions = {};

/// origin تطبيق العميل لكل إطار: معيار قبول الوارد.
final Map<String, String> _previewOrigins = {};
final Map<String, String?> _sessionIds = {};
final Map<String, void Function(PreviewConnection, [String?])> _reporters =
    {};
final Map<String, _Handlers> _handlers = {};
final Map<String, PreviewOutboundQueue<String>> _queues = {};

/// روابط طُلبت قبل اكتمال تهيئة المتحكم (زر إعادة التحميل أثناء الإقلاع
/// أو ساعة الانقطاع) — تُحمّل فور اكتمال التهيئة بدل مساومة على تأكيد
/// الحزمة `isInitialized` في الحزمة.
final Map<String, String> _pendingUrls = {};

class _Handlers {
  const _Handlers({
    required this.onElementSelected,
    required this.onPreviewReady,
    required this.onPreviewError,
    required this.onPropertyUpdated,
    required this.onTreeUpdated,
  });

  final void Function(dynamic) onElementSelected;
  final void Function(dynamic) onPreviewReady;
  final void Function(dynamic) onPreviewError;
  final void Function(dynamic) onPropertyUpdated;
  final void Function(dynamic) onTreeUpdated;
}

/// يمرر كل حدث message داخل الصفحة إلى مضيف WebView2 مع origin المرسل.
/// العميل يبعث رسائله إلى `window.parent` — وفي WebView2 الأب هو الصفحة
/// نفسها، فبلا هذا الممرّر لا تصل رسائل العميل إلى المحرر أبدًا.
const String _forwarderScript = '''
(function () {
  if (window.__previewBridgeForwarder) return;
  window.__previewBridgeForwarder = true;
  window.addEventListener('message', function (e) {
    try {
      window.chrome.webview.postMessage(
        JSON.stringify({ src: e.origin, data: e.data }));
    } catch (_) {}
  });
})();
''';

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
  void Function(PreviewConnection connection, String? reason)?
      onConnectionState,
}) {
  if (!supportsLiveWebview) return;

  void report(PreviewConnection state, [String? reason]) {
    onConnectionState?.call(state, reason);
  }

  final previewOrigin = previewOriginOf(url);
  if (previewOrigin == null) {
    report(PreviewConnection.error, 'رابط المعاينة غير صالح: $url');
    return;
  }

  _previewOrigins[viewType] = previewOrigin;
  _sessionIds[viewType] = sessionId;
  _handlers[viewType] = _Handlers(
    onElementSelected: onElementSelected,
    onPreviewReady: onPreviewReady,
    onPreviewError: onPreviewError,
    onPropertyUpdated: onPropertyUpdated,
    onTreeUpdated: onTreeUpdated,
  );
  _reporters[viewType] = report;
  (_queues[viewType] ??= PreviewOutboundQueue<String>())
      .reset(keepPending: true);

  final controller = _controllers[viewType];
  if (controller == null) {
    final fresh = WebviewController();
    _controllers[viewType] = fresh;
    (_controllerReady[viewType] ??= ValueNotifier<bool>(false));
    unawaited(_initController(viewType, fresh, url));
  } else if (controller.value.isInitialized) {
    // زيارة ثانية للوحة: المتحكم حي — نعيد تحميل الجلسة فقط.
    unawaited(controller.loadUrl(_cacheBusted(url)));
  } else {
    // التهيئة ما زالت جارية: الرابط ينتظر اكتمالها.
    _pendingUrls[viewType] = _cacheBusted(url);
  }
}

Future<void> _initController(
  String viewType,
  WebviewController controller,
  String url,
) async {
  final ready = _controllerReady[viewType]!;
  final report = _reporters[viewType];
  try {
    final runtime = await WebviewController.getWebViewVersion();
    if (runtime == null || runtime.isEmpty) {
      report?.call(
        PreviewConnection.error,
        'WebView2 Runtime غير مثبت على هذا الجهاز — ثبّته من Microsoft ثم أعد فتح المعاينة',
      );
      return;
    }
    await controller.initialize();
    await controller.setBackgroundColor(const Color(0x00000000));
    // السكربت يُحقن قبل كل صفحة، فإعادة التحميل لا تفقد الممرّر أبدًا.
    await controller.addScriptToExecuteOnDocumentCreated(_forwarderScript);
    await controller.loadUrl(_cacheBusted(url));

    _subscriptions[viewType]?.cancel();
    _subscriptions[viewType] = controller.webMessage.listen(
      (value) => _onWebMessage(viewType, value),
    );
    ready.value = true;
    // رابط طُلب أثناء التهيئة؟ يُحمّل الآن مكانه.
    final pending = _pendingUrls.remove(viewType);
    await controller.loadUrl(pending ?? _cacheBusted(url));
    report?.call(PreviewConnection.connecting);
  } catch (error) {
    report?.call(
      PreviewConnection.error,
      'تعذّر تشغيل WebView: $error',
    );
  }
}

String _cacheBusted(String url) {
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}_r=${DateTime.now().millisecondsSinceEpoch}';
}

void _onWebMessage(String viewType, Object? value) {
  final handlers = _handlers[viewType];
  final report = _reporters[viewType];
  final queue = _queues[viewType];
  if (handlers == null || queue == null) return;

  // القيمة قد تكون نصًا (WebMessageAsJson لسلسلة) أو كائنًا مباشرة —
  // الغلاف {src, data} موحّد في الحالين.
  String? senderOrigin;
  Object? data;
  if (value is String) {
    final envelope = decodePreviewPayload(value);
    if (envelope == null) return;
    senderOrigin = envelope['src'] as String?;
    data = envelope['data'];
  } else if (value is Map) {
    senderOrigin = value['src'] as String?;
    data = value['data'];
  } else {
    return;
  }

  final decoded = decodePreviewPayload(data);
  final allowed = isPreviewMessageAllowed(
    senderOrigin: senderOrigin,
    expectedOrigin: _previewOrigins[viewType],
    data: decoded,
    expectedSessionId: _sessionIds[viewType],
  );
  if (!allowed || decoded == null) return;

  final payload = decoded['payload'] ?? <String, dynamic>{};
  switch (decoded['type'] as String?) {
    case 'PREVIEW_READY':
      // تسجيل الجاهزية ثم صرف المعلق بالترتيب — كما على الويب.
      queue.markReady();
      for (final pending in queue.drain()) {
        _postToPage(viewType, pending);
      }
      report?.call(PreviewConnection.connected);
      handlers.onPreviewReady(payload);
    case 'ELEMENT_SELECTED':
      handlers.onElementSelected(payload);
    case 'PROPERTY_UPDATED':
      handlers.onPropertyUpdated(decoded);
    case 'COMPONENT_TREE_UPDATED':
      handlers.onTreeUpdated(payload);
    case 'PREVIEW_ERROR':
      report?.call(
        PreviewConnection.error,
        payload is Map && payload['error'] != null
            ? payload['error'].toString()
            : 'خطأ من المعاينة',
      );
      handlers.onPreviewError(payload);
    default:
      // صدى رسائل الصادر تمر بهذه القناة أيضًا — لا حالة لها، تُهمَل.
      break;
  }
}

Widget buildPreviewView({required String viewType}) {
  final controller = _controllers[viewType];
  final ready = _controllerReady[viewType];
  if (controller == null || ready == null) return const SizedBox.shrink();
  return ValueListenableBuilder<bool>(
    valueListenable: ready,
    builder: (context, isReady, _) =>
        isReady ? Webview(controller) : const SizedBox.shrink(),
  );
}

void sendOutboundMessage({
  required String viewType,
  required VisualEditorMessageType type,
  required Map<String, dynamic> payload,
  required String sessionId,
  required String messageId,
  required String? parentOrigin,
}) {
  final queue = _queues[viewType];
  if (queue == null) return;
  final message = jsonEncode({
    'protocolVersion': '1.0',
    'messageId': messageId,
    'sessionId': sessionId,
    'type': type.value,
    'payload': payload,
  });
  // التحقق من الجاهزية هنا كما على الويب: قناة جاهزة تمرر فورًا، وغير
  // جاهزة تُقبض الرسالة بالترتيب حتى أول PREVIEW_READY.
  if (!queue.offer(message)) return;
  _postToPage(viewType, message);
}

void _postToPage(String viewType, String message) {
  final controller = _controllers[viewType];
  if (controller == null || !controller.value.isInitialized) return;
  // الرسالة نص JSON، يُمرر كسلسلة JS سليمة بلا خطر كسر الاقتباسات.
  unawaited(
    controller.executeScript('window.postMessage(${jsonEncode(message)});'),
  );
}

void reloadPreviewView({
  required String viewType,
  required String url,
}) {
  final controller = _controllers[viewType];
  (_queues[viewType] ??= PreviewOutboundQueue<String>())
      .reset(keepPending: true);
  if (controller == null) {
    // إعادة تحميل قبل أول تسجيل للإطار: أنشئ المتحكم وابدأ التهيئة.
    final fresh = WebviewController();
    _controllers[viewType] = fresh;
    (_controllerReady[viewType] ??= ValueNotifier<bool>(false));
    unawaited(_initController(viewType, fresh, url));
    return;
  }
  final busted = _cacheBusted(url);
  if (!controller.value.isInitialized) {
    // التهيئة لم تكتمل بعد: لا مساومة على التأكيد — الرابط ينتظر مكانه.
    _pendingUrls[viewType] = busted;
    return;
  }
  unawaited(controller.loadUrl(busted));
}
