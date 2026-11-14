// Preview bridge — inert stub for non-web platforms.
//
// الهاتف (Android/iOS) لا يعمل داخل إطار أدمن أبدًا: `isActive` خاطئة
// دائمًا، والاستدعاءات كلها لا تُرسل شيئًا. يُختار عبر الشرط نفسه الذي
// يختار تنفيذ الويب، فيبقى ترجمة الهاتف بلا `dart:js_interop`.

import 'package:new_coffee/core/preview/preview_bridge.dart';

class PreviewBridge {
  static final PreviewBridge _instance = PreviewBridge._internal();
  factory PreviewBridge() => _instance;
  PreviewBridge._internal();

  /// دائمًا خاطئة خارج الويب: لا جلسة ولا مستمع ولا إرسال.
  bool get isActive => false;

  void initialize(String sessionId, {String? parentOrigin}) {}

  void sendElementSelected({
    required String componentId,
    required String componentType,
    required String pageId,
    Map<String, dynamic>? properties,
    String? parentId,
    int? index,
  }) {}

  void sendPropertyUpdated({
    required String componentId,
    required String propertyKey,
    required dynamic value,
    bool success = true,
    String? error,
  }) {}

  void sendTreeUpdated({
    required String pageId,
    required List<Map<String, dynamic>> nodes,
  }) {}

  void onMessage(
    PreviewMessageType type,
    void Function(PreviewMessage) handler,
  ) {}

  void dispose() {}
}
