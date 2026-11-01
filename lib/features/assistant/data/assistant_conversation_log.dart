import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';

/// Message channel today, ready for voice tomorrow.
enum MessageChannel { text, voice }

/// One logged chat line, stored verbatim.
class LoggedMessage {
  const LoggedMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.channel = MessageChannel.text,
    this.intent,
    this.topic,
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String text; // EXACT user wording, never paraphrased
  final DateTime at;
  final MessageChannel channel;
  final String? intent;
  final String? topic;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'text': text,
    'at': at.toIso8601String(),
    'channel': channel.name,
    if (intent != null) 'intent': intent,
    if (topic != null) 'topic': topic,
  };

  static LoggedMessage? fromJson(dynamic value) {
    if (value is! Map) return null;
    try {
      return LoggedMessage(
        id: value['id']?.toString() ?? '',
        role: value['role']?.toString() ?? 'user',
        text: value['text']?.toString() ?? '',
        at: DateTime.tryParse(value['at']?.toString() ?? '') ?? DateTime.now(),
        channel: value['channel'] == 'voice'
            ? MessageChannel.voice
            : MessageChannel.text,
        intent: value['intent']?.toString(),
        topic: value['topic']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Verbatim conversation log: every user message (text today, voice
/// tomorrow) is stored exactly as written so the bot can learn from it.
///
/// [exportJson] produces a DB-ready payload: one object per line with
/// id / role / text / timestamp / channel / detected intent+topic, ready
/// to upload as future training/reference material.
class ConversationLog {
  ConversationLog([List<LoggedMessage>? messages]) : _messages = messages ?? [];

  static const _storageKey = 'assistant_conversation_log_v1';
  static const _maxMessages = 200;

  final List<LoggedMessage> _messages;

  List<LoggedMessage> get messages => List.unmodifiable(_messages);

  /// User messages only, oldest first — the learning corpus.
  List<LoggedMessage> get userMessages =>
      _messages.where((m) => m.role == 'user').toList();

  static Future<ConversationLog> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty) return ConversationLog();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return ConversationLog();
      final messages = decoded
          .map(LoggedMessage.fromJson)
          .whereType<LoggedMessage>()
          .toList();
      return ConversationLog(messages);
    } catch (_) {
      return ConversationLog();
    }
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(_messages.map((m) => m.toJson()).toList()),
      );
    } catch (_) {
      // Logging is best-effort: never break the chat if storage fails.
    }
  }

  Future<void> logUser(
    String rawText, {
    MessageChannel channel = MessageChannel.text,
    String? intent,
  }) async {
    _messages.add(
      LoggedMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}_u',
        role: 'user',
        text: rawText,
        at: DateTime.now(),
        channel: channel,
        intent: intent,
      ),
    );
    _trim();
    await _persist();
  }

  Future<void> logAssistant(
    String text, {
    String? intent,
    String? topic,
  }) async {
    _messages.add(
      LoggedMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}_a',
        role: 'assistant',
        text: text,
        at: DateTime.now(),
        channel: MessageChannel.text,
        intent: intent,
        topic: topic,
      ),
    );
    _trim();
    await _persist();
  }

  void _trim() {
    if (_messages.length > _maxMessages) {
      _messages.removeRange(0, _messages.length - _maxMessages);
    }
  }

  /// DB-ready export: list of plain JSON maps (user + assistant lines).
  List<Map<String, dynamic>> exportJson() =>
      _messages.map((m) => m.toJson()).toList();
}
