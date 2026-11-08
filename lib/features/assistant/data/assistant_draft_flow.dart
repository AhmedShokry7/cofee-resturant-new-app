import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_composer.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_order.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

/// The multi-turn order the assistant keeps in memory: parse, draft, confirm,
/// add to cart, cancel, pay.
///
/// Kept apart from the engine's routing because these are the only answers that
/// mutate state — every method writes into [AssistantMemory] — and the routing
/// reads that state back on the next message.
class AssistantDraftFlow {
  /// "Yes / اه / تمام" — continues whatever the bot just offered.
  static AssistantAnswer affirm(AssistantMemory memory, {bool arabic = false}) {
    if (memory.lastTopic == 'suggest') {
      return AssistantAnswer(
        text: AssistantComposer.pick(
          arabic
              ? AssistantComposer.affirmSuggestAr
              : AssistantComposer.affirmSuggest,
          memory.totalChats,
        ),
        topic: 'affirm',
      );
    }
    return AssistantAnswer(
      text: AssistantComposer.pick(
        arabic
            ? AssistantComposer.affirmGeneralAr
            : AssistantComposer.affirmGeneral,
        memory.totalChats,
      ),
      topic: 'affirm',
    );
  }

  /// "No / لا / بلاش" — backs off gracefully and asks for a direction.
  static AssistantAnswer deny(AssistantMemory memory, {bool arabic = false}) {
    if (memory.lastTopic == 'suggest') {
      return AssistantAnswer(
        text: arabic
            ? AssistantComposer.pick(
                AssistantComposer.denySuggestAr,
                memory.totalChats,
              )
            : 'No problem at all — tell me the mood and I will re-pick: strong, sweet, cold, or cheap?',
        topic: 'deny',
      );
    }
    return AssistantAnswer(
      text: AssistantComposer.pick(
        arabic
            ? AssistantComposer.denyGeneralAr
            : AssistantComposer.denyGeneral,
        memory.totalChats,
      ),
      topic: 'deny',
    );
  }

  static AssistantAnswer draftTotal(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    final summary = memory.draft.describe(arabic: arabic);
    final total = Formatters.price(memory.draft.total());
    return AssistantAnswer(
      text: arabic
          ? 'الاوردر بتاعك: $summary. الإجمالي $total.'
          : 'Your order so far: $summary. Total $total.',
      topic: 'order',
      sourceId: 'order-total',
      products: draftProducts(memory),
    );
  }

  static List<ProductModel> draftProducts(AssistantMemory memory) {
    final menu = AssistantSnapshot.current.products;
    final products = <ProductModel>[];
    for (final item in memory.draft.items) {
      for (final product in menu) {
        if (product.id == item.productId &&
            !products.any((p) => p.id == product.id)) {
          products.add(product);
        }
      }
    }
    return products;
  }

  static List<ProductModel> dessertOptions() {
    const sweetCats = {'desserts', 'snacks', 'bakery', 'donuts'};
    return AssistantSnapshot.current.products
        .where(
          (product) => sweetCats.contains(
            // Same lower-cased comparison as the parser: a category that is
            // stored as a display name is still the dessert category.
            AssistantSnapshot.categoryKey(product).toLowerCase(),
          ),
        )
        .take(3)
        .toList();
  }

  /// "اعملي اوردر لاتيه كبير..." → parses, merges into the draft and asks
  /// for confirmation (or asks which dessert when unclear).
  static AssistantAnswer takeOrder(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    required bool arabic,
  }) {
    final parsed = parseOrderMessage(query);
    for (final item in parsed.items) {
      memory.draft.add(item);
    }
    if (parsed.items.isEmpty && !parsed.unclearDessert) {
      return AssistantAnswer(
        text: arabic ? 'عيني! عايز تطلب إيه بالظبط؟ قولي مثلا "2 لاتيه كبير".' : 'With pleasure! What exactly would you like? Say e.g. "2 large lattes".',
        topic: 'order',
        sourceId: 'order-empty',
      );
    }
    if (parsed.unclearDessert) {
      memory.pendingQuestion = 'order_clarify';
      memory.pendingDessertSize = parsed.unclearSize;
      final known = memory.draft.items.isNotEmpty
          ? (arabic
                ? 'ضفت ${memory.draft.describe(arabic: arabic)}. '
                : 'Added ${memory.draft.describe(arabic: arabic)}. ')
          : '';
      final options = dessertOptions()
          .map((product) => product.name)
          .join('، ');
      return AssistantAnswer(
        text: arabic
            ? '$knownالحلو نوع إيه بالظبط؟ عندنا $options.'
            : '${known}Which dessert exactly? We have $options.',
        topic: 'order',
        sourceId: 'order-clarify',
        products: draftProducts(memory),
      );
    }
    return confirmDraftMessage(memory, arabic: arabic);
  }

  /// Resolves the dessert clarification ("تشيز كيك" after "وطبق حلو").
  /// Returns null when the reply names nothing (the bot asks again).
  static AssistantAnswer? resolveClarify(
    String query, {
    required AssistantMemory memory,
    required bool arabic,
  }) {
    final parsed = parseOrderMessage(query);
    if (parsed.items.isEmpty && !parsed.unclearDessert) return null;
    for (final item in parsed.items) {
      memory.draft.add(
        OrderDraftItem(
          productId: item.productId,
          quantity: item.quantity,
          size: item.size ?? memory.pendingDessertSize,
          sugar: item.sugar,
        ),
      );
    }
    memory.pendingDessertSize = null;
    if (memory.draft.items.isEmpty) {
      final options = dessertOptions()
          .map((product) => product.name)
          .join('، ');
      return AssistantAnswer(
        text: arabic ? 'محددتش — تحب $options؟' : 'Pick one for me — $options?',
        topic: 'order',
        sourceId: 'order-clarify',
      );
    }
    if (parsed.unclearDessert) {
      memory.pendingQuestion = 'order_clarify';
      return takeOrderClarifyAgain(memory, arabic: arabic);
    }
    return confirmDraftMessage(memory, arabic: arabic);
  }

  static AssistantAnswer takeOrderClarifyAgain(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    final options = dessertOptions().map((p) => p.name).join('، ');
    return AssistantAnswer(
      text: arabic
          ? 'ضفت ${memory.draft.describe(arabic: arabic)}. والحلو نوع إيه؟ عندنا $options.'
          : 'Added ${memory.draft.describe(arabic: arabic)}. And which dessert? We have $options.',
      topic: 'order',
      sourceId: 'order-clarify',
      products: draftProducts(memory),
    );
  }

  static AssistantAnswer confirmDraftMessage(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    memory.pendingQuestion = 'order_confirm';
    final summary = memory.draft.describe(arabic: arabic);
    final total = Formatters.price(memory.draft.total());
    return AssistantAnswer(
      text: arabic
          ? 'تمام! الاوردر بتاعك: $summary. الإجمالي $total. أكد؟'
          : 'Got it! Your order: $summary. Total $total. Confirm?',
      topic: 'order',
      sourceId: 'order-confirm',
      products: draftProducts(memory),
    );
  }

  /// "ايوه" on a confirmation → fills the real cart, then asks how to pay.
  static AssistantAnswer executeConfirm(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    if (memory.draft.items.isEmpty) {
      memory.pendingQuestion = null;
      return AssistantAnswer(
        text: arabic
            ? 'مفيش حاجة في الاوردر حالياً. قولي عايز تطلب إيه.'
            : 'Your order is empty right now. Tell me what to add.',
        topic: 'order',
        sourceId: 'order-empty-confirm',
      );
    }
    final actions = memory.draft.items
        .map(
          (item) => AssistantSnapshot.current.cartActionFor(
            item,
            arabic: arabic,
            // Reached only by an explicit "yes" on the proposal just shown, so
            // the write is authorised by that confirmation, not by the draft.
            approvedBy: 'explicit_confirm',
          ),
        )
        .toList();
    final summary = memory.draft.describe(arabic: arabic);
    final products = draftProducts(memory);
    memory.draft = OrderDraft();
    memory.pendingQuestion = 'order_payment';
    memory.pendingDessertSize = null;
    return AssistantAnswer(
      text: arabic
          ? 'تمام! حطيت طلبك في السلة: $summary. تحب تدفع دلوقتي ولا عند الاستلام؟'
          : 'Done! Added to your cart: $summary. Pay now or on delivery?',
      topic: 'order',
      sourceId: 'order-confirmed',
      products: products,
      actions: actions,
    );
  }

  /// "ضيف لاتيه للسلة" → drafts the line and asks for confirmation.
  ///
  /// Adding to the cart is a write like any order: it proposes first and waits
  /// for an explicit yes, instead of pushing the product in on the wording alone.
  static AssistantAnswer addDirect(
    String query, {
    required AssistantMemory memory,
    required bool arabic,
  }) {
    final parsed = parseOrderMessage(query);
    if (parsed.items.isEmpty && !parsed.unclearDessert) {
      return AssistantAnswer(
        text: arabic
            ? 'أضيف إيه للسلة؟ قولي اسم المشروب أو الحلو.'
            : 'What should I add to the cart? Name the drink or dessert.',
        topic: 'order',
        sourceId: 'order-add-empty',
      );
    }
    return takeOrder(query, memory: memory, now: DateTime.now(), arabic: arabic);
  }

  static AssistantAnswer cancelDraft(
    AssistantMemory memory, {
    required bool arabic,
    bool keptInCart = false,
  }) {
    final hadDraft = memory.draft.items.isNotEmpty;
    memory.draft = OrderDraft();
    memory.pendingQuestion = null;
    memory.pendingDessertSize = null;
    if (!hadDraft && !keptInCart) {
      return AssistantAnswer(
        text: arabic
            ? 'مفيش اوردر شغال حالياً.'
            : 'There is no active order right now.',
        topic: 'order',
        sourceId: 'order-cancel-empty',
      );
    }
    return AssistantAnswer(
      text: arabic
          ? (keptInCart
                ? 'تمام، طلبك محفوظ في السلة. وقت ما تحب تكمل قولي.'
                : 'تمام، لغيت الاوردر بتاعك.')
          : (keptInCart
                ? 'Done, your order is kept in the cart. Tell me when to continue.'
                : 'Done, your order is cancelled.'),
      topic: 'order',
      sourceId: 'order-cancelled',
    );
  }

  /// Opens checkout for the order already in the cart.
  ///
  /// An unconfirmed draft is not silently pushed into the cart on the way to
  /// payment: paying is a write too, so the customer confirms the order first.
  static AssistantAnswer payChoice(
    AssistantMemory memory, {
    required bool arabic,
    required bool now,
  }) {
    if (memory.draft.items.isNotEmpty) {
      return confirmDraftMessage(memory, arabic: arabic);
    }
    memory.pendingQuestion = null;
    memory.pendingDessertSize = null;
    if (now) {
      return AssistantAnswer(
        text: arabic
            ? 'تمام، افتح الدفع واختار البطاقة المناسبة.'
            : 'Opening payment — pick your card there.',
        topic: 'order',
        sourceId: 'order-pay-now',
        destination: AssistantDestination.checkout,
        navigateLabel: arabic ? 'ادفع دلوقتي' : 'Pay now',
      );
    }
    return AssistantAnswer(
      text: arabic
          ? 'تمام، افتح الدفع واختار (عند الاستلام).'
          : 'Opening checkout — choose On Delivery there.',
      topic: 'order',
      sourceId: 'order-pay-cash',
      destination: AssistantDestination.checkout,
      navigateLabel: arabic ? 'إتمام الاوردر' : 'Checkout',
    );
  }
}
