import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_windows/webview_windows.dart';

/// Live-preview probe against the deployed customer preview app on GitHub
/// Pages: initialize WebView2, load the preview entry, and wait for
/// PREVIEW_READY — with inside-the-page diagnostics on timeout.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('github pages preview reaches PREVIEW_READY inside webview2',
      (tester) async {
    const base =
        'https://ahmedshokry7.github.io/cofee-resturant-new-app/preview';
    const url =
        '$base/?mode=preview&sessionId=probe-session'
        '&parentOrigin=https%3A%2F%2Fahmedshokry7.github.io';

    final controller = WebviewController();
    final ready = Completer<String>();
    final messages = <String>[];
    final timeline = Stopwatch()..start();

    await controller.initialize();
    await controller.setBackgroundColor(const Color(0x00000000));
    await controller.addScriptToExecuteOnDocumentCreated('''
(function () {
  window.__injectedMarker = 'yes';
  window.__jsErrors = [];
  window.addEventListener('error', function (e) {
    window.__jsErrors.push(String(e.message) + ' @ ' + String(e.filename) + ':' + String(e.lineno));
  });
  window.addEventListener('unhandledrejection', function (e) {
    window.__jsErrors.push('rejection: ' + String(e.reason));
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
      messages.add('@${timeline.elapsedMilliseconds}ms ${text.substring(0, text.length > 140 ? 140 : text.length)}');
      if (text.contains('PREVIEW_READY') && !ready.isCompleted) {
        ready.complete(text);
      }
    });

    await controller.loadUrl(url);
    print('PROBE url loaded, waiting for PREVIEW_READY…');

    final message = await ready.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => '',
    );

    if (message.isEmpty) {
      final injected = await controller.executeScript(
        'String(window.__injectedMarker)',
      );
      final errors = await controller.executeScript(
        'JSON.stringify(window.__jsErrors || [])',
      );
      final resources = await controller.executeScript(
        "JSON.stringify(performance.getEntriesByType('resource').map(function (r) { return r.name.split('/').slice(-1)[0] + ':' + Math.round(r.transferSize) + 'B:' + (r.responseStatus || 0); }).slice(0, 12))",
      );
      final hasFlutterLoader = await controller.executeScript(
        'String(!!window._flutter)',
      );
      final bodyHtml = await controller.executeScript(
        'document.body ? document.body.innerHTML.slice(0, 200) : "no-body"',
      );
      final hasView = await controller.executeScript(
        "!!document.querySelector('flutter-view')",
      );
      print('PROBE injected=$injected hasFlutterLoader=$hasFlutterLoader '
          'hasView=$hasView');
      print('PROBE jsErrors=$errors');
      print('PROBE resources=$resources');
      print('PROBE body=$bodyHtml');
    }

    print('PROBE messages=${messages.take(8)}');
    print('PROBE result @${timeline.elapsedMilliseconds}ms: '
        '${message.isEmpty ? 'TIMEOUT — no PREVIEW_READY' : 'PREVIEW_READY received'}');

    expect(message, isNotEmpty,
        reason: 'PREVIEW_READY never arrived from the deployed preview app');
    await controller.dispose();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
