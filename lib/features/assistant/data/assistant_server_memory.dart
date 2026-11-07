import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversation_log.dart';

/// What the assistant is allowed to keep about one customer, on the server.
///
/// The device store (`AssistantMemory`) holds scores and the draft of the
/// current order; it dies with the app data and cannot follow the customer to
/// another phone. This store is the durable half: one island per account,
/// guarded by a consent flag, reviewed and deleted by the customer.
///
/// Everything here fails open. The assistant answers from the local engine
/// first, so a memory read that times out or an insert the server refuses must
/// cost a personalisation, never a reply.

/// How a stored sentence is to be read. The distinction is the point: a
/// preference is not a fact, and an assumption is neither.
enum AssistantMemoryKind {
  fact('fact'),
  preference('preference'),
  opinion('opinion'),
  assumption('assumption');

  const AssistantMemoryKind(this.wire);

  final String wire;

  static AssistantMemoryKind fromWire(String? value) =>
      AssistantMemoryKind.values.firstWhere(
        (kind) => kind.wire == value,
        orElse: () => AssistantMemoryKind.assumption,
      );
}

/// Where a memory came from.
enum AssistantMemorySource {
  userSaid('user_said'),
  assistantAsked('assistant_asked'),
  orderHistory('order_history'),
  feedback('feedback'),
  imported('imported');

  const AssistantMemorySource(this.wire);

  final String wire;

  static AssistantMemorySource fromWire(String? value) =>
      AssistantMemorySource.values.firstWhere(
        (source) => source.wire == value,
        orElse: () => AssistantMemorySource.userSaid,
      );
}

class AssistantMemoryItem {
  const AssistantMemoryItem({
    required this.id,
    required this.kind,
    required this.key,
    required this.value,
    required this.confidence,
    required this.source,
    required this.lastSeen,
  });

  factory AssistantMemoryItem.fromRow(Map<String, dynamic> row) {
    return AssistantMemoryItem(
      id: Db.text(row['id'], ''),
      kind: AssistantMemoryKind.fromWire(Db.textOrNull(row['kind'])),
      key: Db.text(row['memory_key'], ''),
      value: Db.textOrNull(row['value']) ?? '',
      confidence: Db.asDouble(row['confidence'], fallback: 0.5),
      source: AssistantMemorySource.fromWire(Db.textOrNull(row['source'])),
      lastSeen:
          DateTime.tryParse(Db.text(row['last_seen'], '')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final AssistantMemoryKind kind;
  final String key;

  /// Empty for a secret: the server keeps those encrypted and never returns
  /// them as text, so the list shows the key and the customer deletes it.
  final String value;
  final double confidence;
  final AssistantMemorySource source;
  final DateTime lastSeen;

  bool get isReadable => value.isNotEmpty;
}

class AssistantMemoryConsent {
  const AssistantMemoryConsent({
    this.memoryEnabled = false,
    this.webSearchEnabled = false,
    this.version = '',
  });

  final bool memoryEnabled;
  final bool webSearchEnabled;
  final String version;

  bool get isEmpty => version.isEmpty;
}

/// The last conversation this customer was having, and its lines.
///
/// The id is what lets a chat opened tomorrow continue the one from today
/// instead of starting an island the assistant cannot find again.
class AssistantTranscript {
  const AssistantTranscript({this.conversationId, this.messages = const []});

  final String? conversationId;

  /// Oldest first, ready to be used as prompt history.
  final List<LoggedMessage> messages;

  bool get isEmpty => conversationId == null && messages.isEmpty;
}

abstract interface class AssistantMemoryStore {
  Future<AssistantMemoryConsent> consent();
  Future<void> setConsent({required bool memory, bool webSearch = false});
  Future<List<AssistantMemoryItem>> recall({String query, int limit});
  Future<String?> remember({
    required AssistantMemoryKind kind,
    required String key,
    required String value,
    AssistantMemorySource source = AssistantMemorySource.userSaid,
    double confidence = 0.8,
    bool isSecret = false,
    String? conversationId,
    String? locale,
  });
  Future<int> forget({String? id, String? key});
  Future<void> erase();
  Future<({String conversationId, String messageId})?> logMessage({
    String? conversationId,
    required String role,
    required String text,
    String? topic,
    List<String> sources = const [],
  });
  Future<AssistantTranscript> recentTranscript({int limit});
  Future<void> recordFeedback({
    String? messageId,
    String? conversationId,
    required int rating,
    String? correction,
  });
}

/// The store used while the customer is signed out, or when the server has no
/// memory at all. Every call is a no-op with the same empty answers, so no
/// caller has to branch on "is there a server".
class NoAssistantMemoryStore implements AssistantMemoryStore {
  const NoAssistantMemoryStore();

  @override
  Future<AssistantMemoryConsent> consent() async =>
      const AssistantMemoryConsent();

  @override
  Future<void> setConsent({
    required bool memory,
    bool webSearch = false,
  }) async {}

  @override
  Future<List<AssistantMemoryItem>> recall({
    String query = '',
    int limit = 12,
  }) async => const [];

  @override
  Future<String?> remember({
    required AssistantMemoryKind kind,
    required String key,
    required String value,
    AssistantMemorySource source = AssistantMemorySource.userSaid,
    double confidence = 0.8,
    bool isSecret = false,
    String? conversationId,
    String? locale,
  }) async => null;

  @override
  Future<int> forget({String? id, String? key}) async => 0;

  @override
  Future<void> erase() async {}

  @override
  Future<({String conversationId, String messageId})?> logMessage({
    String? conversationId,
    required String role,
    required String text,
    String? topic,
    List<String> sources = const [],
  }) async => null;

  @override
  Future<AssistantTranscript> recentTranscript({int limit = 8}) async =>
      const AssistantTranscript();

  @override
  Future<void> recordFeedback({
    String? messageId,
    String? conversationId,
    required int rating,
    String? correction,
  }) async {}
}

/// The Postgres-backed store. It talks to the `public.assistant_*` functions
/// only: the `ai` schema is closed to this role, and each function re-checks
/// that the caller owns the rows it touches.
class ServerAssistantMemoryStore implements AssistantMemoryStore {
  ServerAssistantMemoryStore(this._client, {this.encryptionKey});

  final SupabaseClient _client;

  /// Set only when a secret memory is actually being stored; it never reaches
  /// the database as a stored value, it only encrypts on the way in.
  final String? encryptionKey;

  String? get _userId => _client.auth.currentUser?.id;

  bool get _signedIn => _userId != null;

  Future<T> _call<T>(Future<T> Function() body, {required T fallback}) async {
    if (!_signedIn) return fallback;
    try {
      return await body();
    } catch (_) {
      // Memory is an enhancement. A refused or unreachable call is not a
      // reason to leave the customer without the answer they already have.
      return fallback;
    }
  }

  /// A write nobody is waiting for: the caller has the answer already, so the
  /// only honest result type here is "it happened, or it did not".
  Future<void> _ignore(Future<void> Function() body) async {
    if (!_signedIn) return;
    try {
      await body();
    } catch (_) {
      // Same rule as _call, with nothing to fall back to.
    }
  }

  /// One RPC that returns a table, read as rows.
  Future<List<Map<String, dynamic>>> _rows(
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    final result = await _client.rpc<List<dynamic>>(function, params: params);
    return [for (final row in result) (row as Map).cast<String, dynamic>()];
  }

  @override
  Future<AssistantMemoryConsent> consent() {
    return _call(() async {
      final rows = await _rows('assistant_get_consent');
      if (rows.isEmpty) return const AssistantMemoryConsent();
      final row = rows.first;
      return AssistantMemoryConsent(
        memoryEnabled: Db.asBool(row['memory_enabled']),
        webSearchEnabled: Db.asBool(row['web_search_enabled']),
        version: Db.text(row['version'], ''),
      );
    }, fallback: const AssistantMemoryConsent());
  }

  @override
  Future<void> setConsent({required bool memory, bool webSearch = false}) {
    return _ignore(() async {
      await _client.rpc(
        'assistant_set_consent',
        params: {'p_memory_enabled': memory, 'p_web_search_enabled': webSearch},
      );
    });
  }

  @override
  Future<List<AssistantMemoryItem>> recall({
    String query = '',
    int limit = 12,
  }) {
    return _call(() async {
      final rows = await _rows('assistant_recall_memory', {
        'p_query': query,
        'p_limit': limit,
      });
      return [for (final row in rows) AssistantMemoryItem.fromRow(row)];
    }, fallback: const []);
  }

  @override
  Future<String?> remember({
    required AssistantMemoryKind kind,
    required String key,
    required String value,
    AssistantMemorySource source = AssistantMemorySource.userSaid,
    double confidence = 0.8,
    bool isSecret = false,
    String? conversationId,
    String? locale,
  }) {
    return _call<String?>(() async {
      final id = await _client.rpc<dynamic>(
        'assistant_remember',
        params: {
          'p_kind': kind.wire,
          'p_memory_key': key,
          'p_value': value,
          'p_source': source.wire,
          'p_confidence': confidence,
          'p_is_secret': isSecret,
          'p_encryption_key': isSecret ? encryptionKey : null,
          'p_conversation_id': conversationId,
          'p_locale': locale,
        },
      );
      return id is String && id.isNotEmpty ? id : null;
    }, fallback: null);
  }

  @override
  Future<int> forget({String? id, String? key}) {
    return _call(() async {
      final count = await _client.rpc<dynamic>(
        'assistant_forget',
        params: {'p_memory_id': id, 'p_memory_key': key},
      );
      return Db.asInt(count);
    }, fallback: 0);
  }

  @override
  Future<void> erase() {
    return _ignore(() async {
      await _client.rpc('assistant_erase');
    });
  }

  @override
  Future<({String conversationId, String messageId})?> logMessage({
    String? conversationId,
    required String role,
    required String text,
    String? topic,
    List<String> sources = const [],
  }) {
    return _call<({String conversationId, String messageId})?>(() async {
      final rows = await _rows('assistant_log_message', {
        'p_conversation_id': conversationId,
        'p_role': role,
        'p_text': text,
        'p_topic': topic,
        'p_sources': sources.isEmpty ? null : sources,
      });
      if (rows.isEmpty) return null;
      final row = rows.first;
      final conversation = Db.text(row['conversation_id'], '');
      final message = Db.text(row['message_id'], '');
      if (conversation.isEmpty || message.isEmpty) return null;
      return (conversationId: conversation, messageId: message);
    }, fallback: null);
  }

  @override
  Future<AssistantTranscript> recentTranscript({int limit = 8}) {
    return _call(() async {
      final rows = await _rows('assistant_recent_messages', {'p_limit': limit});
      if (rows.isEmpty) return const AssistantTranscript();
      String? conversationId;
      final messages = <LoggedMessage>[];
      // Newest first from the server: reverse it so the prompt reads the way a
      // conversation happened.
      for (final row in rows.reversed) {
        conversationId ??= Db.textOrNull(row['conversation_id']);
        messages.add(
          LoggedMessage(
            id: Db.text(row['id'], ''),
            role: Db.text(row['role'], 'user'),
            text: Db.text(row['text'], ''),
            at:
                DateTime.tryParse(Db.text(row['created_at'], '')) ??
                DateTime.now(),
          ),
        );
      }
      return AssistantTranscript(
        conversationId: conversationId,
        messages: messages,
      );
    }, fallback: const AssistantTranscript());
  }

  @override
  Future<void> recordFeedback({
    String? messageId,
    String? conversationId,
    required int rating,
    String? correction,
  }) {
    return _ignore(() async {
      await _client.rpc(
        'assistant_record_feedback',
        params: {
          'p_message_id': messageId,
          'p_conversation_id': conversationId,
          'p_rating': rating,
          'p_correction': correction,
        },
      );
    });
  }
}
