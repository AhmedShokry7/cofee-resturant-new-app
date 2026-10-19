import 'dart:convert';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/assistant/data/assistant_order.dart';

/// On-device learning profile: what the user likes, what answers worked,
/// and what they recently asked. Persisted locally, no account needed.
class AssistantMemory {
  AssistantMemory({
    Map<String, double>? categoryScores,
    Map<String, double>? sourceScores,
    Map<String, int>? topicCounts,
    Map<String, double>? productScores,
    this.totalChats = 0,
    this.lastTopic,
    this.pendingQuestion,
    bool? replyArabic,
    this.pendingDessertSize,
    List<String>? recentQueries,
    List<String>? lastSuggestedIds,
    List<String>? dismissedIds,
    OrderDraft? draft,
  })  : categoryScores = categoryScores ?? {},
        sourceScores = sourceScores ?? {},
        topicCounts = topicCounts ?? {},
        productScores = productScores ?? {},
        recentQueries = recentQueries ?? [],
        lastSuggestedIds = lastSuggestedIds ?? [],
         dismissedIds = dismissedIds ?? [],
         draft = draft ?? OrderDraft(),
         replyArabic = replyArabic ?? AppLocale.instance.isArabic;

  static const _storageKey = 'assistant_memory_v1';
  static const _maxRecent = 10;

  Map<String, double> categoryScores;
  Map<String, double> sourceScores;
  Map<String, int> topicCounts;

  /// Per-product affection learned from views, taps and orders.
  Map<String, double> productScores;
  int totalChats;

  /// Topic of the latest bot answer — used for follow-up context.
  String? lastTopic;

  /// Reply language the user prefers (learned from their messages).
  /// True = Egyptian Arabic, false = English.
  bool replyArabic;

  /// Open slot the bot asked about and still waits for
  /// (e.g. 'taste' after a clarification question). Null when none.
  String? pendingQuestion;

  /// Size captured for a dessert type the bot is still asking about
  /// ("وطبق حلو صغير" → asks which dessert, remembers "small").
  String? pendingDessertSize;

  List<String> recentQueries;

  /// Product ids of the latest suggestion — enables "the first one" picks.
  List<String> lastSuggestedIds;

  /// Products the user explicitly rejected ("مش عايز لاتيه").
  /// Excluded from future suggestions until explicitly requested again.
  List<String> dismissedIds;

  /// The in-progress conversational order awaiting confirmation.
  OrderDraft draft;

  static Future<AssistantMemory> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty) {
        return AssistantMemory(replyArabic: AppLocale.instance.isArabic);
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AssistantMemory(
        categoryScores: _toDoubleMap(json['categoryScores']),
        sourceScores: _toDoubleMap(json['sourceScores']),
        topicCounts: _toIntMap(json['topicCounts']),
        productScores: _toDoubleMap(json['productScores']),
        totalChats: (json['totalChats'] as num?)?.toInt() ?? 0,
        lastTopic: json['lastTopic']?.toString(),
        pendingQuestion: json['pendingQuestion']?.toString(),
        replyArabic: (json['replyArabic'] as bool?) ?? AppLocale.instance.isArabic,
        pendingDessertSize: json['pendingDessertSize']?.toString(),
        recentQueries: (json['recentQueries'] as List?)
                ?.map((dynamic item) => item.toString())
                .toList() ??
            [],
        lastSuggestedIds: (json['lastSuggestedIds'] as List?)
                ?.map((dynamic item) => item.toString())
                .toList() ??
            [],
        dismissedIds: (json['dismissedIds'] as List?)
                ?.map((dynamic item) => item.toString())
                .toList() ??
            [],
        draft: OrderDraft.fromJson(json['draft']),
      );
    } catch (_) {
      return AssistantMemory(replyArabic: AppLocale.instance.isArabic);
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
          'productScores': productScores,
          'totalChats': totalChats,
          'lastTopic': lastTopic,
          'pendingQuestion': pendingQuestion,
          'replyArabic': replyArabic,
          'pendingDessertSize': pendingDessertSize,
          'recentQueries': recentQueries,
          'lastSuggestedIds': lastSuggestedIds,
          'dismissedIds': dismissedIds,
          'draft': draft.toJson(),
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
    lastTopic = topic;
  }

  /// Remembers a specific product the user engaged with
  /// (viewed, tapped in chat, ordered).
  void recordProduct(String productId, [double weight = 1]) {
    productScores[productId] =
        ((productScores[productId] ?? 0) + weight).clamp(-5, 10);
  }

  /// Rejects a product ("مش عايز لاتيه"). Kept small and persisted.
  void dismissProduct(String productId) {
    if (!dismissedIds.contains(productId)) {
      dismissedIds = [...dismissedIds, productId];
      if (dismissedIds.length > 20) {
        dismissedIds = dismissedIds.sublist(dismissedIds.length - 20);
      }
    }
  }

  /// Forgives a rejection when the user explicitly asks for it again.
  void undismissProduct(String productId) {
    dismissedIds = dismissedIds.where((id) => id != productId).toList();
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

  /// Id of the single most-loved product, if the bot learned one.
  String? topProductId() {
    if (productScores.isEmpty) return null;
    final sorted = productScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.value > 0 ? sorted.first.key : null;
  }

  /// One-line summary of what this customer likes, used to personalize
  /// suggestions ("Since you usually enjoy Hot Coffee...").
  String? preferenceSummary() {
    final category = topCategory();
    if (category == null) return null;
    return 'you usually enjoy $category';
  }

  /// DB-ready export of the learning profile (tastes + feedback).
  Map<String, dynamic> exportJson() => {
    'categoryScores': categoryScores,
    'productScores': productScores,
    'sourceScores': sourceScores,
    'topicCounts': topicCounts,
    'totalChats': totalChats,
    'replyArabic': replyArabic,
    'pendingQuestion': pendingQuestion,
    'recentQueries': recentQueries,
    'pendingDessertSize': pendingDessertSize,
    'lastSuggestedIds': lastSuggestedIds,
    'dismissedIds': dismissedIds,
    'draft': draft.toJson(),
  };
}
