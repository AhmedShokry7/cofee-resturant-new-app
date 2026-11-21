import 'dart:convert';
import 'dart:math';

enum StudioPreviewMessageType {
  previewReady('PREVIEW_READY'),
  previewInitialize('PREVIEW_INITIALIZE'),
  applyDesignConfig('APPLY_DESIGN_CONFIG'),
  loadPage('LOAD_PAGE'),
  selectElement('SELECT_ELEMENT'),
  propertyUpdated('PROPERTY_UPDATED'),
  elementSelected('ELEMENT_SELECTED'),
  componentTreeUpdated('COMPONENT_TREE_UPDATED'),
  previewError('PREVIEW_ERROR'),
  setLanguage('SET_LANGUAGE'),
  setThemeMode('SET_THEME_MODE'),
  setInteractiveMode('SET_INTERACTIVE_MODE');

  const StudioPreviewMessageType(this.wireName);
  final String wireName;

  static StudioPreviewMessageType? parse(Object? value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

class StudioPreviewMessage {
  const StudioPreviewMessage({
    required this.sessionId,
    required this.type,
    required this.payload,
    required this.messageId,
  });

  static const protocolVersion = '1.0';
  final String sessionId;
  final StudioPreviewMessageType type;
  final Map<String, Object?> payload;
  final String messageId;

  Map<String, Object?> toJson() => <String, Object?>{
    'protocolVersion': protocolVersion,
    'sessionId': sessionId,
    'messageId': messageId,
    'type': type.wireName,
    'payload': payload,
  };

  static StudioPreviewMessage? decode(
    Object? raw, {
    required String sessionId,
  }) {
    Object? value = raw;
    if (value is String) {
      if (value.length > 1024 * 1024) return null;
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is! Map ||
        value['protocolVersion'] != protocolVersion ||
        value['sessionId'] != sessionId ||
        value['messageId'] is! String ||
        (value['messageId'] as String).length > 128 ||
        value['payload'] is! Map) {
      return null;
    }
    final type = StudioPreviewMessageType.parse(value['type']);
    final payload = value['payload'] as Map;
    if (type == null ||
        payload.length > 256 ||
        payload.keys.any((key) => key is! String)) {
      return null;
    }
    return StudioPreviewMessage(
      sessionId: sessionId,
      type: type,
      payload: Map<String, Object?>.from(payload),
      messageId: value['messageId'] as String,
    );
  }
}

class StudioPreviewSession {
  StudioPreviewSession({String? id}) : id = id ?? _newSessionId();

  final String id;

  static String _newSessionId() {
    final random = Random.secure();
    return List<String>.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
  }
}
