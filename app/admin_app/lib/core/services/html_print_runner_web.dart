// This file is only compiled for the web target; the stub covers other
// platforms, so the web-only library is intentional.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Prints [document] from a hidden frame so the browser keeps the print
/// dialog tied to the admin tab and no popup blocker is involved.
Future<bool> printHtmlDocument(String document) async {
  final body = html.document.body;
  if (body == null) return false;

  final frame = html.IFrameElement()
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.left = '-10000px'
    ..style.width = '1024px'
    ..style.height = '768px'
    ..style.border = '0'
    ..srcdoc = document;
  body.append(frame);

  await Future.any([
    frame.onLoad.first,
    Future<void>.delayed(const Duration(seconds: 2)),
  ]);

  final frameWindow = frame.contentWindow as html.Window?;
  if (frameWindow == null) {
    frame.remove();
    return false;
  }
  try {
    frameWindow.print();
  } catch (_) {
    frame.remove();
    return false;
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
  frame.remove();
  return true;
}
