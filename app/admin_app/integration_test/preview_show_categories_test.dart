import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_windows/webview_windows.dart';

/// Shows the customer app's real home page in a real window (WebView2):
/// loads the deployed preview build, waits for PREVIEW_READY, then emulates
/// the editor exactly — sends PREVIEW_INITIALIZE with the published design
/// document and opens the home page — so the screenshot shows the home the
/// customer app renders.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('show the customer categories page in the preview', (tester) async {
    const base =
        'https://ahmedshokry7.github.io/cofee-resturant-new-app/preview';
    const origin = 'https://ahmedshokry7.github.io';
    // كسر كاش: WebView2 يحتفظ بـ main.dart.js القديم حتى بعد النشر.
    final bust = DateTime.now().millisecondsSinceEpoch;
    final url =
        '$base/?mode=preview&sessionId=categories-show&v=$bust'
        '&parentOrigin=https%3A%2F%2Fahmedshokry7.github.io';

    // The published design document (as the editor would send it).
    final document = File(
      'C:/Users/Ahmed/AppData/Local/Temp/design_published_new.json',
    ).readAsStringSync();

    final controller = WebviewController();
    final ready = Completer<void>();
    final acked = Completer<void>();
    // مجلد بيانات WebView2 جديد لكل تشغيل — الكاش المحفوظ على القرص
    // يخدم main.dart.js القديم حتى بعد النشر فيُختبر كود قديم بلا قصد.
    final profile = Directory.systemTemp.createTempSync('webview_profile_');
    await WebviewController.initializeEnvironment(userDataPath: profile.path);
    await controller.initialize();
    await controller.setBackgroundColor(const Color(0xFFFFFFFF));
    await controller.addScriptToExecuteOnDocumentCreated('''
(function () {
  function forward(level, args) {
    try {
      window.chrome.webview.postMessage(
        JSON.stringify({ src: 'console', level: level, text: Array.from(args).map(String).join(' ') }));
    } catch (_) {}
  }
  ['error', 'warn'].forEach(function (level) {
    var orig = console[level];
    console[level] = function () { forward(level, arguments); orig.apply(console, arguments); };
  });
  window.addEventListener('error', function (e) {
    forward('window.onerror', [e.message, e.filename, e.lineno]);
  });
  window.addEventListener('unhandledrejection', function (e) {
    forward('unhandledrejection', [String(e.reason)]);
  });
  window.addEventListener('message', function (e) {
    try {
      window.chrome.webview.postMessage(
        JSON.stringify({ src: e.origin, data: e.data }));
    } catch (_) {}
  });
})();
''');
    controller.webMessage.listen((value) {
      final text = value is String ? value : value.toString();
      if (text.contains('PREVIEW_READY') && !ready.isCompleted) {
        ready.complete();
      }
      if (text.contains('PROPERTY_UPDATED') && !acked.isCompleted) {
        acked.complete();
      }
      // أخطاء كونسول المعاينة تُطبع في سجل الاختبار لتشخيص الشاشات البيضاء.
      if (text.contains('"src":"console"')) {
        print('PROBE CONSOLE ${text.substring(0, text.length.clamp(0, 600))}');
      }
    });

    await controller.loadUrl(url);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Webview(controller)),
        ),
      ),
    );

    await ready.future.timeout(const Duration(seconds: 90));
    print('PROBE PREVIEW_READY — sending the editor initialize message…');

    Future<void> send(String type, Map<String, dynamic> payload) async {
      final message = jsonEncode({
        'protocolVersion': '1.0',
        'messageId': DateTime.now().microsecondsSinceEpoch.toString(),
        'sessionId': 'categories-show',
        'type': type,
        'payload': payload,
      });
      await controller.executeScript(
        'window.postMessage(${jsonEncode(message)}, "$origin");',
      );
    }

    await send('PREVIEW_INITIALIZE', {
      'designDocument': jsonDecode(document),
    });
    await acked.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => print('PROBE initialize ack not seen (may be fine)'),
    );
    await send('LOAD_PAGE', {'pageId': 'categories'});
    print('PROBE initialize sent — rendering the categories page…');

    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      if (i == 5) print('PROBE READY_STABLE');
    }
    print('PROBE done');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
