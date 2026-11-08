// The assistant as the customer meets it: a page of its own, the older
// conversations in the drawer, and a fresh chat every arrival.
//
// What these tests guard is the shape of the screen, not the answers. The chat
// arrived here as a sheet over Home and could not be gone back to; the page has
// to hold the whole conversation, list the ones before it, and never let an old
// one leak into the question being asked now.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_page.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_bubbles.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_history_drawer.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_input_bar.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

import 'support/mock_product_repository.dart';

const _chatsKey = 'assistant_conversations_v1';

class _NoOrders implements OrdersRepository {
  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<Branch>> activeBranches() async => const [];
}

/// One conversation written the way the store writes it, so the page is read by
/// the same shape a previous visit left on the device.
String _storedChat({
  required String id,
  required String question,
  required String answer,
  required DateTime at,
}) => jsonEncode([
  {
    'id': id,
    'title': question,
    'updatedAt': at.toIso8601String(),
    'messages': [
      {'id': '$id-q', 'role': 'user', 'text': question},
      {'id': '$id-a', 'role': 'assistant', 'text': answer},
    ],
  },
]);

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => BranchCubit(repository: _FakeBranchRepository()),
          ),
          RepositoryProvider<CatalogRepository>(
            create: (_) => const MockProductRepository(),
          ),
          RepositoryProvider<OrdersRepository>(create: (_) => _NoOrders()),
        ],
        child: const AssistantPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip(S.assistantChatsTooltip));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  group('the assistant page', () {
    testWidgets(
      'is a page that holds the chat, not a sheet over another screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await _pumpPage(tester);

        expect(find.byType(AssistantPage), findsOneWidget);
        expect(find.byType(AssistantInputBar), findsOneWidget);
        expect(find.byType(AssistantMessageBubble), findsOneWidget);

        // The whole window belongs to the conversation: the scaffold starts at
        // the top edge and the question box is inside the viewport.
        final scaffold = find.byType(Scaffold).first;
        expect(tester.getRect(scaffold).top, 0);
        expect(
          tester.getRect(find.byType(AssistantInputBar)).bottom,
          lessThanOrEqualTo(
            tester.view.physicalSize.height / tester.view.devicePixelRatio,
          ),
        );

        // A first visit has a list to open and nothing in it yet.
        await _openDrawer(tester);
        expect(find.text(S.assistantEmptyHistory), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'every arrival is a new chat and keeps the old one in the drawer',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          _chatsKey: _storedChat(
            id: 'old-chat',
            question: 'الموكا بكام؟',
            answer: 'الموكا بسبعة عشر ريال.',
            at: DateTime(2026, 11, 1, 9),
          ),
        });
        await _pumpPage(tester);

        // Nothing of the older chat is on screen.
        expect(find.text('الموكا بكام؟'), findsNothing);
        expect(find.text('الموكا بسبعة عشر ريال.'), findsNothing);

        await _openDrawer(tester);
        expect(find.byType(AssistantChatRow), findsOneWidget);
        expect(find.text('الموكا بكام؟'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('opening a chat from the drawer puts its own lines back', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        _chatsKey: _storedChat(
          id: 'old-chat',
          question: 'الموكا بكام؟',
          answer: 'الموكا بسبعة عشر ريال.',
          at: DateTime(2026, 11, 1, 9),
        ),
      });
      await _pumpPage(tester);
      await _openDrawer(tester);

      await tester.tap(find.text('الموكا بكام؟'));
      await tester.pumpAndSettle();

      expect(find.text('الموكا بكام؟'), findsOneWidget);
      expect(find.text('الموكا بسبعة عشر ريال.'), findsOneWidget);
      // The drawer went with the tap, so what is on screen is the conversation.
      expect(find.byType(AssistantChatRow), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a deleted chat comes back when the customer undoes it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        _chatsKey: _storedChat(
          id: 'old-chat',
          question: 'الموكا بكام؟',
          answer: 'الموكا بسبعة عشر ريال.',
          at: DateTime(2026, 11, 1, 9),
        ),
      });
      await _pumpPage(tester);
      await _openDrawer(tester);

      await tester.tap(find.byTooltip(S.assistantChatDelete));
      await tester.pumpAndSettle();

      // A delete from inside the list closes the list, which is what makes the
      // message it leaves behind readable and its undo reachable.
      expect(find.byType(AssistantChatRow), findsNothing);
      expect(find.text(S.assistantChatDeleted), findsOneWidget);

      await tester.tap(find.text(S.undo));
      await tester.pumpAndSettle();

      await _openDrawer(tester);
      expect(find.text('الموكا بكام؟'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the new-chat button leaves the stored chats as they are', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        _chatsKey: _storedChat(
          id: 'old-chat',
          question: 'الموكا بكام؟',
          answer: 'الموكا بسبعة عشر ريال.',
          at: DateTime(2026, 11, 1, 9),
        ),
      });
      await _pumpPage(tester);

      await tester.tap(find.byTooltip(S.assistantNewChat));
      await tester.pumpAndSettle();

      // A chat that only ever held a greeting is not filed over the old one.
      expect(find.text('الموكا بكام؟'), findsNothing);
      await _openDrawer(tester);
      expect(find.byType(AssistantChatRow), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'a confirmed order reaches the real cart through the page wiring',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final cart = CartCubit(
          cartRepository: LocalCartRepository(),
          catalogRepository: const MockProductRepository(),
        );
        await cart.load();
        addTearDown(cart.close);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      BranchCubit(repository: _FakeBranchRepository()),
                ),
                BlocProvider<CartCubit>.value(value: cart),
                RepositoryProvider<CatalogRepository>(
                  create: (_) => const MockProductRepository(),
                ),
                RepositoryProvider<OrdersRepository>(
                  create: (_) => _NoOrders(),
                ),
              ],
              child: const AssistantPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The cubit the page built, read from below its provider, so the send
        // runs the page's own cart executor against the real CartCubit above.
        final cubit = tester
            .element(find.byType(AssistantInputBar))
            .read<AssistantCubit>();

        await cubit.sendMessage('عايز اطلب لاتيه كبير');
        await tester.pump();
        // The proposal is on screen; the cart is still empty.
        expect(cart.state.items, isEmpty);

        await cubit.sendMessage('أيوه');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The explicit yes wrote the latte into the real cart.
        expect(
          cart.state.items.map((item) => item.product.name),
          contains('Latte'),
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });
}
