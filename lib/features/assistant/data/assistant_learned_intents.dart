import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_language.dart';

/// Training on conversations, the honest way.
///
/// Every question the offline engine managed to ground — including ones the
/// keyword scorer missed and only typo-recovery or conversation context
/// rescued — is filed here as `normalized query → intent`. The next time the
/// customer phrases it the same way (or near-identically), the intent is
/// replayed before any scoring, so a lesson is never paid for twice.
///
/// Deliberately bounded and conservative:
/// - exact normalized matches replay instantly;
/// - near matches need ≥0.93 whole-sentence similarity, so "امسح ذاكرتي"
///   never leaks into "اسال ذاكرتي"-shaped questions;
/// - the store holds a bounded number of entries, oldest dropped first;
/// - nothing is written from failed answers, so a wrong reading never gets
///   rehearsed into a habit.
class AssistantLearnedIntents {
  AssistantLearnedIntents([Map<String, String>? entries])
    : _entries = entries ?? <String, String>{};

  static const _storageKey = 'assistant_learned_intents_v1';
  static const _maxEntries = 300;
  static const _minSimilarity = 0.93;

  final Map<String, String> _entries;

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;

  static Future<AssistantLearnedIntents> load() async {
    final raw = await SharedPref.getValue(key: _storageKey);
    if (raw == null || raw.isEmpty) return AssistantLearnedIntents();
    try {
      final decoded = _decodeMap(raw);
      return AssistantLearnedIntents(decoded);
    } catch (_) {
      return AssistantLearnedIntents();
    }
  }

  /// The intent this exact (or near-identical) phrasing was answered with
  /// before, or null when nothing learned applies.
  AssistantIntent? lookup(String query) {
    final normalized = normalizeText(query);
    if (normalized.length < 4 || _entries.isEmpty) return null;
    final exact = _entries[normalized];
    if (exact != null) return _intentFromName(exact);
    // Near-identical phrasing: one small typo away from a question that was
    // answered correctly before. Whole-sentence similarity, not token overlap,
    // so a longer unrelated question cannot borrow a short lesson.
    for (final entry in _entries.entries) {
      if ((entry.key.length - normalized.length).abs() > 3) continue;
      if (similarity(normalized, entry.key) >= _minSimilarity) {
        return _intentFromName(entry.value);
      }
    }
    return null;
  }

  /// Files a successful answer under the phrasing that produced it.
  Future<void> record(String query, AssistantIntent intent) async {
    final normalized = normalizeText(query);
    if (normalized.length < 4) return;
    final name = intent.name;
    if (_entries[normalized] == name) return;
    _entries.remove(normalized);
    _entries[normalized] = name;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(key: _storageKey, value: jsonEncode(_entries));
    } catch (_) {
      // Best-effort only.
    }
  }
}

Map<String, String> _decodeMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return const {};
  return decoded.map((key, value) => MapEntry('$key', '$value'));
}

AssistantIntent? _intentFromName(String name) {
  for (final intent in AssistantIntent.values) {
    if (intent.name == name) return intent;
  }
  return null;
}
