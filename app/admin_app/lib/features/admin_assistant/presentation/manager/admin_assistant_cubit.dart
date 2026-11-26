import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_repository.dart';

class AdminAssistantMessage {
  const AdminAssistantMessage({required this.role, required this.text});

  final String role;
  final String text;
  bool get isUser => role == 'user';

  Map<String, String> toPromptMessage() => {'role': role, 'content': text};
}

class AdminAssistantState {
  const AdminAssistantState({
    this.messages = const [],
    this.isSending = false,
    this.failure = AdminAssistantFailure.none,
  });

  final List<AdminAssistantMessage> messages;
  final bool isSending;
  final AdminAssistantFailure failure;
  bool get hasError => failure != AdminAssistantFailure.none;

  AdminAssistantState copyWith({
    List<AdminAssistantMessage>? messages,
    bool? isSending,
    AdminAssistantFailure? failure,
  }) => AdminAssistantState(
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    failure: failure ?? this.failure,
  );
}

enum AdminAssistantFailure { none, provider, session, network }

class AdminAssistantCubit extends Cubit<AdminAssistantState> {
  AdminAssistantCubit({
    AdminAssistantRepository? repository,
    AdminSession? session,
  }) : _repository = repository ?? AdminAssistantRepository(session: session),
       super(const AdminAssistantState());

  final AdminAssistantRepository _repository;

  Future<void> send(String raw) async {
    final query = raw.trim();
    if (query.isEmpty || state.isSending || query.length > 4000) return;

    final priorMessages = state.messages;
    final userMessage = AdminAssistantMessage(role: 'user', text: query);
    final pendingMessages = [...priorMessages, userMessage];
    final recentMessages = priorMessages.length <= 12
        ? priorMessages
        : priorMessages.sublist(priorMessages.length - 12);
    emit(
      state.copyWith(
        messages: pendingMessages,
        isSending: true,
        failure: AdminAssistantFailure.none,
      ),
    );

    try {
      final answer = await _repository.reply(
        history: recentMessages
            .map((message) => message.toPromptMessage())
            .toList(growable: false),
        query: query,
      );
      if (isClosed) return;
      _appendReply(pendingMessages, answer);
    } on AdminAssistantSessionException {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          failure: AdminAssistantFailure.session,
        ),
      );
    } on AdminAssistantProviderException {
      if (isClosed) return;
      await _sendOfflineReply(pendingMessages, recentMessages, query);
    } catch (_) {
      if (isClosed) return;
      await _sendOfflineReply(pendingMessages, recentMessages, query);
    }
  }

  Future<void> _sendOfflineReply(
    List<AdminAssistantMessage> pendingMessages,
    List<AdminAssistantMessage> priorMessages,
    String query,
  ) async {
    try {
      final answer = await _repository.offlineReply(
        query,
        history: priorMessages
            .take(12)
            .map((message) => message.toPromptMessage())
            .toList(growable: false),
      );
      if (isClosed) return;
      _appendReply(pendingMessages, answer);
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          failure: AdminAssistantFailure.network,
        ),
      );
    }
  }

  void _appendReply(
    List<AdminAssistantMessage> pendingMessages,
    String answer,
  ) {
    emit(
      state.copyWith(
        messages: [
          ...pendingMessages,
          AdminAssistantMessage(role: 'assistant', text: answer),
        ],
        isSending: false,
        failure: AdminAssistantFailure.none,
      ),
    );
  }
}
