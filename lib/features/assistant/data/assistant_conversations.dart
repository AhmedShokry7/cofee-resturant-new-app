import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';

/// One conversation the customer had with the assistant, kept on this device.
///
/// The messages are the point: someone coming back tomorrow wants the answer
/// they were given, with the sources it cited — not a summary of it.
class AssistantConversation {
  const AssistantConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  /// Arabic carries the same question in fewer glyphs, so a row of a Latin
  /// title would already be trailing off where an Arabic one still fits.
  static const int _titleArabicLength = 28;
  static const int _titleLatinLength = 42;

  static final RegExp _arabicRunes = RegExp(r'[؀-ۿ]');

  /// The customer's own first question, on one short line. A conversation with
  /// no question in it has no title, and is not a conversation yet.
  static String titleOf(List<ChatMessage> messages) {
    final index = messages.indexWhere(
      (message) => message.role == MessageRole.user,
    );
    if (index < 0) return '';
    final line = messages[index].text.replaceAll('\n', ' ').trim();
    if (line.isEmpty) return '';
    final limit = _arabicRunes.hasMatch(line)
        ? _titleArabicLength
        : _titleLatinLength;
    return line.length <= limit ? line : '${line.substring(0, limit)}…';
  }

  final String id;

  /// Derived from [messages] by [titleOf] and stored, so listing a month of
  /// chats never means re-reading every line of them.
  final String title;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': [for (final message in messages) message.toJson()],
  };

  /// Null for anything unreadable. Half a conversation shown as a whole one is
  /// worse than the customer finding it missing.
  static AssistantConversation? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = value['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final rawMessages = value['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .map(ChatMessage.fromJson)
              .whereType<ChatMessage>()
              .toList()
        : const <ChatMessage>[];
    if (messages.isEmpty) return null;
    final title = value['title']?.toString() ?? '';
    return AssistantConversation(
      id: id,
      title: title.isEmpty ? titleOf(messages) : title,
      updatedAt:
          DateTime.tryParse(value['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      messages: messages,
    );
  }
}

/// The customer's own chat history: newest first, capped, on the device.
///
/// It lives in SharedPreferences because that is the only place it can live
/// today. The server has no table of conversations to list and no function that
/// returns one — the migration that would add them is written but was never
/// applied — so a history read over the network would come back empty for
/// everyone, signed in or not. The device copy is real, works for a guest, and
/// leaves with the app.
///
/// It is not shared with another customer and it is not a brain: the prompt
/// history is built from the conversation open on screen, never from this list.
class AssistantConversations {
  AssistantConversations([List<AssistantConversation>? items])
    : _items = items ?? [];

  static const _storageKey = 'assistant_conversations_v1';

  /// Thirty chats is months of ordinary use. The list is an aid, not an archive:
  /// past that a row is noise, and all of them are read on every open.
  static const int maxChats = 30;

  /// The same ceiling the open chat keeps, so nothing is lost by being stored
  /// that was not already lost by being on screen.
  static const int maxMessagesPerChat = 100;

  final List<AssistantConversation> _items;

  /// Newest first — the order the history drawer draws.
  List<AssistantConversation> get all => List.unmodifiable(_items);

  AssistantConversation? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static Future<AssistantConversations> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty) return AssistantConversations();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return AssistantConversations();
      return AssistantConversations(
        decoded
            .map(AssistantConversation.fromJson)
            .whereType<AssistantConversation>()
            .toList(),
      );
    } catch (_) {
      return AssistantConversations();
    }
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(_items.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      // Storage that fails must not stop the chat: the customer is talking to
      // the assistant now, and that works without a disk write.
    }
  }

  /// Adds or replaces one conversation, newest first.
  ///
  /// An untitled one is dropped: a greeting on its own is not a conversation,
  /// and a drawer full of them would say nothing about the customer.
  Future<void> save(AssistantConversation conversation) async {
    final title = conversation.title.isNotEmpty
        ? conversation.title
        : AssistantConversation.titleOf(conversation.messages);
    if (title.isEmpty) return;
    var messages = conversation.messages;
    if (messages.length > maxMessagesPerChat) {
      messages = messages.sublist(messages.length - maxMessagesPerChat);
    }
    _items.removeWhere((item) => item.id == conversation.id);
    _items.add(
      AssistantConversation(
        id: conversation.id,
        title: title,
        updatedAt: conversation.updatedAt,
        messages: messages,
      ),
    );
    _sortNewestFirst();
    if (_items.length > maxChats) _items.removeRange(maxChats, _items.length);
    await _persist();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _persist();
  }

  /// Puts a deleted conversation back where its own date says it belongs, which
  /// is where the customer pressed undo.
  Future<void> restore(AssistantConversation conversation) async {
    if (byId(conversation.id) != null) return;
    _items.add(conversation);
    _sortNewestFirst();
    if (_items.length > maxChats) _items.removeRange(maxChats, _items.length);
    await _persist();
  }

  void _sortNewestFirst() {
    _items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
