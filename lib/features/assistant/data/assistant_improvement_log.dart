import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';

/// Bounded, privacy-conscious log of assistant failures/clarifications.
/// Raw text is retained only in bounded form for later human review; no
/// automatic instruction or model changes are made from this data.
class AssistantImprovementLog {
  AssistantImprovementLog([List<Map<String, dynamic>>? entries])
      : _entries = entries ?? <Map<String, dynamic>>[];

  static const _storageKey = 'assistant_improvement_log_v1';
  static const _maxEntries = 100;
  static const _maxTextChars = 240;

  final List<Map<String, dynamic>> _entries;

  List<Map<String, dynamic>> get entries =>
      List.unmodifiable(_entries);

  static Future<AssistantImprovementLog> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty) return AssistantImprovementLog();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return AssistantImprovementLog();
      final entries = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      return AssistantImprovementLog(entries);
    } catch (_) {
      return AssistantImprovementLog();
    }
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(_entries),
      );
    } catch (_) {
      // Best-effort only.
    }
  }

  String _bound(String value) =>
      value.length <= _maxTextChars ? value : value.substring(0, _maxTextChars);

  Future<void> recordUnknown(String query, {String? locale}) async {
    _entries.add(<String, dynamic>{
      'type': 'unknown',
      'text': _bound(query.trim()),
      'locale': locale,
      'at': DateTime.now().toIso8601String(),
    });
    _trim();
    await _persist();
  }

  Future<void> recordClarification(String query) async {
    _entries.add(<String, dynamic>{
      'type': 'clarification',
      'text': _bound(query.trim()),
      'at': DateTime.now().toIso8601String(),
    });
    _trim();
    await _persist();
  }

  void _trim() {
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }
}
