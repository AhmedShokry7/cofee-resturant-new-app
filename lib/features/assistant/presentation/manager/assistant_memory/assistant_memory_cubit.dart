import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';

/// The screen where a customer reads, and takes back, what the assistant knows
/// about them.
///
/// It is separate from [AssistantCubit] on purpose: the chat cubit owns a
/// conversation, this one owns a legal relationship with the database. A
/// customer should be able to open their memory without starting a chat, and
/// the review must not disappear because they closed the sheet.
class AssistantMemoryViewState {
  const AssistantMemoryViewState({
    this.loading = true,
    this.signedIn = true,
    this.consent = const AssistantMemoryConsent(),
    this.memories = const [],
    this.erased = false,
  });

  final bool loading;

  /// False when there is no account to hold a memory, so the screen can say so
  /// instead of showing an empty list that will never fill.
  final bool signedIn;
  final AssistantMemoryConsent consent;
  final List<AssistantMemoryItem> memories;

  /// Set once after a delete-everything, so the list can say what happened
  /// rather than look broken.
  final bool erased;

  AssistantMemoryViewState copyWith({
    bool? loading,
    bool? signedIn,
    AssistantMemoryConsent? consent,
    List<AssistantMemoryItem>? memories,
    bool? erased,
  }) {
    return AssistantMemoryViewState(
      loading: loading ?? this.loading,
      signedIn: signedIn ?? this.signedIn,
      consent: consent ?? this.consent,
      memories: memories ?? this.memories,
      erased: erased ?? this.erased,
    );
  }
}

class AssistantMemoryCubit extends Cubit<AssistantMemoryViewState> {
  AssistantMemoryCubit({required this._store, bool signedIn = true})
    : super(
        AssistantMemoryViewState(
          signedIn: signedIn,
          // An account with no consent row has no version string; showing the
          // switch off is the same truth in both cases.
          consent: const AssistantMemoryConsent(),
        ),
      );

  final AssistantMemoryStore _store;

  Future<void> load() async {
    if (!state.signedIn) {
      emit(state.copyWith(loading: false));
      return;
    }
    final consent = await _store.consent();
    final memories = consent.memoryEnabled
        ? await _store.recall(limit: 40)
        : const <AssistantMemoryItem>[];
    if (isClosed) return;
    emit(state.copyWith(loading: false, consent: consent, memories: memories));
  }

  /// Turning memory on starts remembering; turning it off deletes. The switch
  /// is not a mute button, because a memory the customer withdrew must not sit
  /// in a table waiting for them to change their mind.
  Future<void> setMemoryEnabled(bool enabled) async {
    await _store.setConsent(memory: enabled);
    if (isClosed) return;
    emit(
      state.copyWith(
        consent: AssistantMemoryConsent(
          memoryEnabled: enabled,
          webSearchEnabled: state.consent.webSearchEnabled,
          version: 'v1',
        ),
      ),
    );
    if (enabled) {
      final memories = await _store.recall(limit: 40);
      if (isClosed) return;
      emit(state.copyWith(memories: memories));
      return;
    }
    await _store.erase();
    if (isClosed) return;
    emit(state.copyWith(memories: const [], erased: true));
  }

  /// Letting the assistant read outside the shop. Its own switch, because a
  /// customer may want the bot to remember them and still not want it browsing
  /// the internet on their behalf — and the other way round.
  Future<void> setWebSearchEnabled(bool enabled) async {
    await _store.setConsent(
      memory: state.consent.memoryEnabled,
      webSearch: enabled,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        consent: AssistantMemoryConsent(
          memoryEnabled: state.consent.memoryEnabled,
          webSearchEnabled: enabled,
          version: 'v1',
        ),
      ),
    );
  }

  Future<void> forget(AssistantMemoryItem item) async {
    await _store.forget(id: item.id);
    if (isClosed) return;
    emit(
      state.copyWith(
        memories: state.memories.where((m) => m.id != item.id).toList(),
      ),
    );
  }

  Future<void> eraseAll() async {
    await _store.erase();
    if (isClosed) return;
    emit(state.copyWith(memories: const [], erased: true));
  }
}
