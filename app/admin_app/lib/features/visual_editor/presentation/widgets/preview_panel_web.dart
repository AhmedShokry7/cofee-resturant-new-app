// Web-only implementation: creates the iframe element and wires postMessage.
// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;
import 'package:flutter/widgets.dart';

import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// الإطارات الحية حسب viewType — المنفذ الذي تمر عبره الرسائل الصادرة.
final Map<String, web.HTMLIFrameElement> _iframes = {};

/// origin تطبيق العميل لكل إطار: عنوان الإرسال الصادر، ومعيار قبول الوارد.
final Map<String, String> _previewOrigins = {};

/// مستمعو النوافذ حسب viewType — يُزالون قبل إعادة الربط فلا تُعالج الرسالة
/// الواحدة مرتين.
final Map<String, JSFunction> _listeners = {};

/// طابور كل إطار: ما يُرسل قبل PREVIEW_READY ينتظر بالترتيب.
final Map<String, PreviewOutboundQueue<String>> _queues = {};

/// ساعات الانقطاع حسب الإطار: بلا إشارة حياة تُعلن Disconnect ثم يعاد
/// الاتصال تلقائيًا، وبعد المحاولات تُعلن Error.
final Map<String, PreviewWatchdog> _watchdogs = {};

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
      onConnectionState = _defaultConnectionSink,
}) {
  // مستخدم قديم (بلا معالج حالات)؟ لا ينهار — الحالات تراقب بصمت.
  void report(PreviewConnection state, [String? reason]) {
    onConnectionState?.call(state, reason);
  }

  final previewOrigin = previewOriginOf(url);
  if (previewOrigin == null) {
    report(
      PreviewConnection.error,
      'رابط المعاينة غير صالح: $url',
    );
    return;
  }

  _listeners.remove(viewType)?.callAsFunction();
  _iframes.remove(viewType);
  _previewOrigins[viewType] = previewOrigin;
  final queue =
      (_queues[viewType] ??= PreviewOutboundQueue<String>())
        ..reset(keepPending: true);

  void armWatchdog() {
    (_watchdogs[viewType] ??= PreviewWatchdog(
      timeout: const Duration(seconds: 45),
      onExpired: () {
        if (queue.isReady) return;
        report(
          PreviewConnection.error,
          'لم تعلن المعاينة جاهزيتها — تأكد أن تطبيق العميل يعمل على '
          '$previewOrigin ثم أعد تحميل المعاينة',
        );
      },
    ))
      ..arm();
  }

  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => createPreviewIframe(
      viewType: viewType,
      url: url,
      sessionId: sessionId,
      parentOrigin: parentOrigin,
      previewOrigin: previewOrigin,
      queue: queue,
      report: report,
      armWatchdog: armWatchdog,
      onElementSelected: onElementSelected,
      onPreviewReady: onPreviewReady,
      onPreviewError: onPreviewError,
      onPropertyUpdated: onPropertyUpdated,
      onTreeUpdated: onTreeUpdated,
    ),
  );
}

void _defaultConnectionSink(PreviewConnection _, String? __) {}

Widget buildPreviewView({required String viewType}) =>
    HtmlElementView(viewType: viewType);

/// يبني عنصر iframe حقيقيًا ويعلّق معالج postMessage عليه.
///
/// الأمان:
/// - الصادر يتجه إلى origin تطبيق العميل (origin رابط الإطار) — لا إلى
///   origin الأدمن ولا إلى `*`.
/// - كل رسالة واردة تُفحص ضد origin الإطار نفسه ثم ضد `sessionId`.
web.HTMLElement createPreviewIframe({
  required String viewType,
  required String url,
  required String? sessionId,
  required String? parentOrigin,
  required String previewOrigin,
  required PreviewOutboundQueue<String> queue,
  required void Function(PreviewConnection, [String?]) report,
  required void Function() armWatchdog,
  required void Function(dynamic data) onElementSelected,
  required void Function(dynamic data) onPreviewReady,
  required void Function(dynamic data) onPreviewError,
  required void Function(dynamic data) onPropertyUpdated,
  required void Function(dynamic data) onTreeUpdated,
}) {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  iframe.src = url;
  iframe.style.border = 'none';
  iframe.style.width = '100%';
  iframe.style.height = '100%';
  iframe.setAttribute('loading', 'lazy');

  _iframes[viewType] = iframe;

  _listeners.remove(viewType)?.callAsFunction();
  void handler(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;
    try {
      final msgEvent = event as web.MessageEvent;
      // مصدر الوارد هو الإطار (origin تطبيق العميل) — التحقق هنا معيار
      // رابط المعاينة لا origin الأدمن، وإلا رفضنا كل ما يأتي من التطبيق
      // الحقيقي وظهرت الشاشة بيضاء بلا سبب مفهوم.
      // المرسل يبعث نص JSON فيصل Dart سلسلة — الفكّ قبل فحص الشكل.
      final decoded = decodePreviewPayload(msgEvent.data.dartify());
      final allowed = isPreviewMessageAllowed(
        senderOrigin: msgEvent.origin,
        expectedOrigin: previewOrigin,
        data: decoded,
        expectedSessionId: sessionId,
      );
      if (!allowed || decoded == null) return;
      final data = decoded;
      final type = data['type'] as String?;
      final payload = data['payload'] ?? <String, dynamic>{};

      switch (type) {
        case 'PREVIEW_READY':
          // 1) تسجيل الجاهزية فتُصرف الرسائل المعلقة بالترتيب الذي وُلدت
          // به، 2) إبلاغ المحرّر (فيرسل PREVIEW_INITIALIZE بأحدث مستند) —
          // آخر ما يُطبق دائمًا أحدث حالة، فلا تعديل يضيع قبل الجاهزية
          // ولا بعدها.
          queue.markReady();
          for (final pending in queue.drain()) {
            iframe.contentWindow?.postMessage(
              pending.toJS,
              previewOrigin.toJS,
            );
          }
          report(PreviewConnection.connected);
          onPreviewReady(payload);
        case 'ELEMENT_SELECTED':
          onElementSelected(payload);
        case 'PROPERTY_UPDATED':
          onPropertyUpdated(data);
        case 'COMPONENT_TREE_UPDATED':
          onTreeUpdated(payload);
        case 'PREVIEW_ERROR':
          report(
            PreviewConnection.error,
            payload['error']?.toString() ?? 'خطأ من المعاينة',
          );
          onPreviewError(payload);
      }
    } catch (_) {
      // رسالة غير صالحة — نتجاهلها
    }
  }

  _listeners[viewType] = handler.toJS;
  web.window.addEventListener('message', _listeners[viewType]!);

  armWatchdog();
  report(PreviewConnection.connecting);
  return iframe;
}

/// يرسل رسالة postMessage إلى iframe معاينة حسب viewType.
///
/// إطار غير جاهز لا يستقبل: الرسالة تُقبض في الطابور بالترتيب وتُصرف
/// أول ما تعلن المعاينة جاهزيتها — فلا تعديل يضيع أثناء تحميل التطبيق.
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
  final queue =
      (_queues[viewType] ??= PreviewOutboundQueue<String>());
  final message = jsonEncode({
    'protocolVersion': '1.0',
    'messageId': messageId,
    'sessionId': sessionId,
    'type': type.value,
    'payload': payload,
  });
  // التحقق من الجاهزية هنا لا عند المرسل: رسالة وصلت إلى قناة جاهزة تمر
  // فورًا، ووصلت إلى قناة صامتة تنتظر — والترتيب لا يُكسر في الحالين.
  if (!queue.offer(message)) return;
  final previewOrigin = _previewOrigins[viewType];
  if (previewOrigin == null) return;
  _postTo(iframe, message, previewOrigin);
}

void _postTo(web.HTMLIFrameElement iframe, String message, String origin) {
  iframe.contentWindow?.postMessage(message.toJS, origin.toJS);
}

/// إعادة تحميل المعاينة من طرف زر الموظف أو ساعة الانقطاع.
///
/// الطابور يُحفظ لا يُمسح: آخر مستند يظل في آخر رسالة معلقة، وأول
/// PREVIEW_READY من الإطار الجديد يصرف كل ما مضى بالترتيب ثم يصل
/// PREVIEW_INITIALIZE بأحدث مستند من المحرّر.
void reloadPreviewView({
  required String viewType,
  required String url,
}) {
  final iframe = _iframes[viewType];
  if (iframe == null) return;
  final queue =
      (_queues[viewType] ??= PreviewOutboundQueue<String>())
        ..reset(keepPending: true);
  (_watchdogs[viewType] ??= PreviewWatchdog(
    timeout: const Duration(seconds: 45),
    onExpired: () {
      if (queue.isReady) return;
    },
  ))
    ..arm();
  // معلمة تحطيم الكاش: نفس الرابط قد لا يعيد المتصفح تحميله، والمعلمة
  // الجديدة لا تلمس الجلسة ولا الأصل.
  final separator = url.contains('?') ? '&' : '?';
  iframe.src = '$url${separator}_r=${DateTime.now().millisecondsSinceEpoch}';
}
