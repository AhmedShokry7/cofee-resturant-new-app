// This file is only compiled for the web target; the stub covers other
// platforms, so the web-only library is intentional.
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The panel prints through the browser, so the channel exists on this target.
const bool browserPrintingAvailable = true;

/// Opens the browser print dialog with [document] and reports whether the
/// print call was dispatched.
///
/// The document is written into an off-screen frame instead of a popup: a
/// popup is blocked outside a click handler and would need its own window
/// handle. `Window.print()` blocks the script until the dialog is closed, so
/// the frame is still alive while the job is spooled and is removed right
/// after — a fixed timer here used to blank the page mid-print.
Future<bool> printHtmlDocument(String document) async {
  final body = web.document.body;
  if (body == null) return false;

  final frame = web.HTMLIFrameElement()
    ..setAttribute('title', 'print')
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.left = '-10000px'
    ..style.width = '1024px'
    ..style.height = '768px'
    ..style.border = '0';
  frame.srcdoc = document.toJS;

  final loaded = Completer<void>();
  void handleLoad(web.Event _) => _complete(loaded);
  final JSFunction loadedCallback = handleLoad.toJS;
  frame.addEventListener('load', loadedCallback);
  body.append(frame);

  try {
    await loaded.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => _complete(loaded),
    );
    final view = frame.contentWindow;
    if (view == null) return false;
    view.print();
    return true;
  } catch (_) {
    return false;
  } finally {
    frame.removeEventListener('load', loadedCallback);
    frame.remove();
  }
}

void _complete(Completer<void> completer) {
  if (!completer.isCompleted) completer.complete();
}
