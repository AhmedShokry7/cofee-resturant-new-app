import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';

/// On-device learning profile: what the user likes, what answers worked,
/// and what they recently asked. Persisted locally, no account needed.
class AssistantMemory {
  AssistantMemory({
    Map<String, double>? categoryScores,
    Map<String, double>? sourceScores,
    Map<String, int>? topicCounts,
    this.totalChats = 0,
    List<String>? recentQueries,
  })  : categoryScores = categoryScores ?? {},
        sourceScores = sourceScores ?? {},
        topicCounts = topicCounts ?? {},
        recentQueries = recentQueries ?? [];

  static const _storageKey = 'assistant_memory_v1';
  static const _maxRecent = 10;

  Map<String, double> categoryScores;
  Map<String, double> sourceScores;
  Map<String, int> topicCounts;
  int totalChats;
  List<String> recentQueries;

  static Future<AssistantMemory> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty) return AssistantMemory();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AssistantMemory(
        categoryScores: _toDoubleMap(json['categoryScores']),
        sourceScores: _toDoubleMap(json['sourceScores']),
        topicCounts: _toIntMap(json['topicCounts']),
        totalChats: (json['totalChats'] as num?)?.toInt() ?? 0,
        recentQueries: (json['recentQueries'] as List?)
                ?.map((dynamic item) => item.toString())
                .toList() ??
            [],
      );
    } catch (_) {
      return AssistantMemory();
    }
  }

  static Map<String, double> _toDoubleMap(dynamic value) {
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): (entry.value as num?)?.toDouble() ?? 0,
    };
  }

  static Map<String, int> _toIntMap(dynamic value) {
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
    };
  }

  Future<void> save() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode({
          'categoryScores': categoryScores,
          'sourceScores': sourceScores,
          'topicCounts': topicCounts,
          'totalChats': totalChats,
          'recentQueries': recentQueries,
        }),
      );
    } catch (_) {
      // Learning is best-effort: never break the chat if storage fails.
    }
  }

  void recordQuery(String query) {
    totalChats += 1;
    recentQueries = [...recentQueries, query];
    if (recentQueries.length > _maxRecent) {
      recentQueries = recentQueries.sublist(
        recentQueries.length - _maxRecent,
      );
    }
  }

  /// Positive weights for liked categories, negative drift for disliked ones.
  void recordCategory(String category, [double weight = 1]) {
    categoryScores[category] =
        ((categoryScores[category] ?? 0) + weight).clamp(-5, 5);
  }

  void recordTopic(String topic) {
    topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
  }

  /// Explicit feedback: +1 moves a source up, -1 moves it down.
  void recordFeedback(String sourceId, bool liked) {
    final delta = liked ? 1.0 : -1.5;
    sourceScores[sourceId] =
        ((sourceScores[sourceId] ?? 0) + delta).clamp(-5, 5);
  }

  /// Boost multiplier learned for a source: 0.5x (disliked) .. 1.5x (loved).
  double sourceBoost(String sourceId) {
    return 1 + ((sourceScores[sourceId] ?? 0) / 10);
  }

  String? topCategory() {
    if (categoryScores.isEmpty) return null;
    final sorted = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.value > 0 ? sorted.first.key : null;
  }
}
