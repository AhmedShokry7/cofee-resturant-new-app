// The conversations the assistant keeps on the device: what is written, in what
// order, and what a customer gets back when they open one again.
//
// What these tests guard is the shape of the history the drawer shows — a chat
// is only listed once the customer asked something in it, a new open never
// inherits the lines of the chat before it, and a deleted row can come back.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversations.dart';
import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

import 'support/mock_product_repository.dart';

class _NoOrders implements OrdersRepository {
  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ChatMessage _line(int index, MessageRole role, String text) =>
    ChatMessage(id: 'm$index', role: role, text: text);

AssistantConversation _chat(
  String id,
  DateTime at,
  List<ChatMessage> messages, {
  String title = '',
}) => AssistantConversation(
  id: id,
  title: title,
  updatedAt: at,
  messages: messages,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  group('the title of a conversation', () {
    test('is the customer own question, not the greeting', () {
      final title = AssistantConversation.titleOf([
        _line(0, MessageRole.assistant, 'صباح الخير! قولي محتاج إيه.'),
        _line(1, MessageRole.user, 'عايز لاتيه سادة'),
        _line(2, MessageRole.assistant, 'اللاتيه السادة بعشرين ريال.'),
      ]);

      expect(title, 'عايز لاتيه سادة');
    });

    test('a chat that was only greeted has no title at all', () {
      expect(
        AssistantConversation.titleOf([
          _line(0, MessageRole.assistant, 'صباح الخير!'),
        ]),
        isEmpty,
      );
    });

    test('is one line, and short enough to be a row', () {
      final title = AssistantConversation.titleOf([
        _line(
          0,
          MessageRole.user,
          'عايز أعرف سعر أمريكانو كبير و هل في خصم عليه النهاردة في فرع النخيل',
        ),
      ]);

      expect(title.contains('\n'), isFalse);
      expect(title.length, lessThanOrEqualTo(29));
      expect(title, endsWith('…'));
    });
  });

  group('the store', () {
    test('reads back what it wrote, messages and sources included', () async {
      final store = AssistantConversations();
      await store.save(
        _chat('c-1', DateTime(2026, 11, 5, 9), [
          _line(0, MessageRole.assistant, 'قولي محتاج إيه.'),
          _line(1, MessageRole.user, 'الموكا بكام؟'),
          ChatMessage(
            id: 'm2',
            role: MessageRole.assistant,
            text: 'الموكا بعشرين ريال.',
            sourceId: 'p-1',
            sources: const [
              RetrievedSource(
                sourceType: 'product',
                sourceId: 'p-1',
                title: 'موكا',
                body: 'وصف طويل لا يحتاجه التاريخ',
                score: 0.9,
                uri: 'https://shop.example/mocha',
              ),
            ],
            feedback: 1,
          ),
        ]),
      );

      final again = await AssistantConversations.load();
      final chat = again.byId('c-1');

      expect(chat, isNotNull);
      expect(chat!.title, 'الموكا بكام؟');
      expect(chat.messages.map((message) => message.text), [
        'قولي محتاج إيه.',
        'الموكا بكام؟',
        'الموكا بعشرين ريال.',
      ]);
      // The citation survives the reopen, the passage it was read from does not.
      expect(chat.messages.last.sources.single.sourceId, 'p-1');
      expect(chat.messages.last.sources.single.title, 'موكا');
      expect(
        chat.messages.last.sources.single.uri,
        'https://shop.example/mocha',
      );
      expect(chat.messages.last.sources.single.body, isEmpty);
      expect(chat.messages.last.feedback, 1);
    });

    test('a greeting alone is never stored', () async {
      final store = AssistantConversations();
      await store.save(
        _chat('c-1', DateTime(2026, 11, 5), [
          _line(0, MessageRole.assistant, 'قولي محتاج إيه.'),
        ]),
      );

      expect(store.all, isEmpty);
      expect((await AssistantConversations.load()).all, isEmpty);
    });

    test(
      'newest first, and the same chat written twice stays one row',
      () async {
        final store = AssistantConversations();
        await store.save(
          _chat('old', DateTime(2026, 10, 1), [
            _line(0, MessageRole.user, 'الشجر عندي؟'),
          ], title: 'الشجر عندي؟'),
        );
        await store.save(
          _chat('new', DateTime(2026, 11, 2), [
            _line(1, MessageRole.user, 'اللاتيه بكام؟'),
          ], title: 'اللاتيه بكام؟'),
        );
        await store.save(
          _chat('old', DateTime(2026, 11, 3), [
            _line(0, MessageRole.user, 'الشجر عندي؟'),
            _line(2, MessageRole.assistant, 'اتبلغ شجرك.'),
          ]),
        );

        expect(store.all.map((chat) => chat.id), ['old', 'new']);
        expect(store.byId('old')!.messages.length, 2);
      },
    );

    test('the oldest rows leave when the list passes its ceiling', () async {
      final store = AssistantConversations();
      for (
        var index = 0;
        index < AssistantConversations.maxChats + 5;
        index++
      ) {
        await store.save(
          _chat(
            'c-$index',
            DateTime(2026, 1, 1).add(Duration(minutes: index)),
            [_line(index, MessageRole.user, 'سؤال $index')],
          ),
        );
      }

      expect(store.all.length, AssistantConversations.maxChats);
      // The five oldest questions are gone and the newest is still readable.
      expect(store.byId('c-0'), isNull);
      expect(store.byId('c-4'), isNull);
      expect(store.byId('c-5')?.title, 'سؤال 5');
      expect(store.byId('c-34')?.title, 'سؤال 34');
      expect(store.all.map((chat) => chat.title), isNot(contains('سؤال 0')));
    });

    test('a long chat keeps its newest lines', () async {
      final store = AssistantConversations();
      final messages = [
        for (var index = 0; index < 130; index++)
          _line(index, MessageRole.user, 'سؤال $index'),
      ];
      await store.save(_chat('c-1', DateTime(2026, 11, 5), messages));

      final stored = store.byId('c-1')!;
      expect(stored.messages.length, AssistantConversations.maxMessagesPerChat);
      expect(stored.messages.first.text, 'سؤال 30');
      expect(stored.messages.last.text, 'سؤال 129');
    });

    test('deleting is undone by putting the row back where it was', () async {
      final store = AssistantConversations();
      final first = _chat('a', DateTime(2026, 11, 1), [
        _line(0, MessageRole.user, 'الأول'),
      ]);
      final second = _chat('b', DateTime(2026, 11, 2), [
        _line(1, MessageRole.user, 'التاني'),
      ]);
      await store.save(first);
      await store.save(second);

      await store.remove('b');
      expect(store.all.map((chat) => chat.id), ['a']);

      await store.restore(second);
      expect(store.all.map((chat) => chat.id), ['b', 'a']);
    });

    test('a row that cannot be read is dropped, not shown broken', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'assistant_conversations_v1':
            '[{"id":"c-1","messages":[{"id":"m1","role":"user",'
            '"text":"محفوظة"}]},{"id":"c-2","messages":[]},'
            '{"messages":[{"role":"user","text":"بدون معرف"}]}]',
      });

      final store = await AssistantConversations.load();

      expect(store.all.map((chat) => chat.id), ['c-1']);
      // The stored title is rebuilt from the line when the row was written
      // before titles existed.
      expect(store.byId('c-1')!.title, 'محفوظة');
    });
  });

  group('the cubit and the conversations', () {
    Future<AssistantCubit> openChat() async {
      final cubit = AssistantCubit(
        catalog: const MockProductRepository(),
        orders: _NoOrders(),
        memoryStore: const NoAssistantMemoryStore(),
        retrieval: const NoRetrieval(),
      );
      addTearDown(cubit.close);
      await cubit.start();
      return cubit;
    }

    test(
      'opening the assistant starts a conversation with a greeting in it',
      () async {
        final cubit = await openChat();

        expect(cubit.state.messages.length, 1);
        expect(cubit.state.activeChatId, isNotNull);
        // Nothing to list yet: the customer has not asked anything.
        expect(cubit.state.chats, isEmpty);
      },
    );

    test(
      'every open is a new conversation, not the last one left open',
      () async {
        final first = await openChat();
        await first.sendMessage('الموكا بكام؟');
        final firstChatId = first.state.activeChatId;
        final firstLines = first.state.messages.length;
        await first.close();

        final second = await openChat();

        expect(second.state.activeChatId, isNot(firstChatId));
        // The new chat holds only its own greeting.
        expect(second.state.messages.length, 1);
        expect(second.state.messages.first.role, MessageRole.assistant);
        // And the chat that ended is still there to be read.
        expect(second.state.chats.map((chat) => chat.title), ['الموكا بكام؟']);
        expect(second.state.chats.single.messages.length, firstLines);
      },
    );

    test(
      'a new chat drops the unconfirmed draft so a stray yes cannot execute it',
      () async {
        final cubit = await openChat();
        await cubit.sendMessage('عايز اطلب لاتيه كبير');
        // A draft is now waiting for the customer to confirm it.
        expect(cubit.state.messages.last.sourceId, 'order-confirm');

        await cubit.newChat();
        await cubit.sendMessage('أيوه');

        // The yes belongs to no open question: nothing is confirmed or written.
        expect(cubit.state.messages.last.sourceId, isNot('order-confirmed'));
      },
    );

    test(
      'the question and its answer are stored under the open chat',
      () async {
        final cubit = await openChat();
        final chatId = cubit.state.activeChatId!;

        await cubit.sendMessage('اللاتيه بكام؟');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final stored = (await AssistantConversations.load()).byId(chatId);
        expect(stored, isNotNull);
        expect(stored!.title, 'اللاتيه بكام؟');
        expect(stored.messages.map((message) => message.role), [
          MessageRole.assistant,
          MessageRole.user,
          MessageRole.assistant,
        ]);
        expect(cubit.state.chats.map((chat) => chat.id), [chatId]);
      },
    );

    test('opening an older chat puts its own lines on screen', () async {
      final cubit = await openChat();
      await cubit.sendMessage('الموكا بكام؟');
      final older = cubit.state.activeChatId!;

      await cubit.newChat();
      await cubit.sendMessage('انا بحب الحاجات السادة');
      final newer = cubit.state.activeChatId!;

      await cubit.openChat(older);

      expect(cubit.state.activeChatId, older);
      expect(cubit.state.messages.map((message) => message.text), [
        contains('قولي'),
        'الموكا بكام؟',
        isNot(isEmpty),
      ]);
      // The chat the customer left is not lost.
      expect(cubit.state.chats.map((chat) => chat.id), contains(newer));
    });

    test(
      'the last chat on screen cannot be deleted out from under the customer',
      () async {
        final cubit = await openChat();
        await cubit.sendMessage('الشاورما بكام؟');
        final chatId = cubit.state.activeChatId!;

        final removed = await cubit.deleteChat(chatId);

        expect(removed, isNotNull);
        expect(cubit.state.chats, isEmpty);
        // A new conversation takes the place of the one that went.
        expect(cubit.state.activeChatId, isNot(chatId));
        expect(cubit.state.messages.length, 1);
        expect(
          (await AssistantConversations.load()).byId(chatId),
          isNull,
          reason:
              'the row is gone from the device too, not only from the screen',
        );
      },
    );

    test('undo puts the deleted conversation back in the list', () async {
      final cubit = await openChat();
      await cubit.sendMessage('الباراتستا شغال امتى؟');
      final chatId = cubit.state.activeChatId!;
      final removed = await cubit.deleteChat(chatId);

      await cubit.restoreChat(removed!);

      expect(cubit.state.chats.map((chat) => chat.id), [chatId]);
      expect((await AssistantConversations.load()).byId(chatId), isNotNull);
    });

    test(
      'a chat the customer never asked anything in is never listed',
      () async {
        final cubit = await openChat();

        await cubit.newChat();
        await cubit.newChat();

        expect(cubit.state.chats, isEmpty);
        expect((await AssistantConversations.load()).all, isEmpty);
      },
    );

    test('the vote on an answer is stored with the conversation', () async {
      final cubit = await openChat();
      await cubit.sendMessage('المواعيد امتى؟');
      final chatId = cubit.state.activeChatId!;
      final answer = cubit.state.messages.last;

      await cubit.giveFeedback(answer.id, true);

      final stored = (await AssistantConversations.load()).byId(chatId)!;
      expect(stored.messages.last.id, answer.id);
      expect(stored.messages.last.feedback, 1);
    });
  });
}
