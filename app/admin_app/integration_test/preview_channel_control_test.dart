import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_windows/webview_windows.dart';

/// Transport control: does the webview_windows webMessage channel deliver at
/// all, and what does the customer preview page look like from the inside?
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('webMessage channel delivers a simple page message', (tester) async {
    const url =
        'http://localhost:5000/?mode=preview&sessionId=probe-session'
        '&parentOrigin=http%3A%2F%2Flocalhost%3A5000';

    final controller = WebviewController();
    final messages = <String>[];
    final simple = Completer<bool>();
    final timeline = Stopwatch()..start();

    await controller.initialize();
    await controller.setBackgroundColor(const Color(0x00000000));
    await controller.addScriptToExecuteOnDocumentCreated('''
(function () {
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
      messages.add('@${timeline.elapsedMilliseconds}ms $text');
      if (text.contains('__transport_probe_ok') && !simple.isCompleted) {
        simple.complete(true);
      }
    });

    // Load a tiny control page first: a page that immediately posts to
    // window.parent — the same path the Flutter preview uses.
    const controlPage =
        'data:text/html,<html><body><script>'
        'window.parent.postMessage(JSON.stringify({'
        "type:'PROBE',payload:{ok:'__transport_probe_ok'}}),'*');"
        '</script>control</body></html>';
    await controller.loadUrl(controlPage);
    final delivered = await simple.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );
    print('PROBE control page delivered: $delivered, messages=$messages');

    // Now the real preview page.
    await controller.loadUrl(url);
    await Future<void>.delayed(const Duration(seconds: 25));

    final title = await controller.executeScript('document.title');
    final readyState = await controller.executeScript('document.readyState');
    final hasFlutter = await controller.executeScript(
      "!!document.querySelector('flutter-view, flutter-view > flutter-view, gt, body > flutter-view')",
    );
    final bodyLen = await controller.executeScript(
      'document.body ? document.body.childElementCount : -1',
    );
    final hasChrome = await controller.executeScript(
      'typeof window.chrome !== "undefined" && !!window.chrome.webview',
    );
    final bridgeMarker = await controller.executeScript(
      'String(window.__previewBridgeForwarder)',
    );
    final firstChild = await controller.executeScript(
      'document.body && document.body.firstElementChild ? document.body.firstElementChild.tagName : "none"',
    );

    print('PROBE title=$title readyState=$readyState');
    print('PROBE hasFlutter=$hasFlutter bodyChildren=$bodyLen '
        'chromeWebview=$hasChrome forwarder=$bridgeMarker '
        'firstChild=$firstChild');
    print('PROBE messages so far=$messages');

    expect(delivered, isTrue,
        reason: 'even the trivial control page message never arrived');
    await controller.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
