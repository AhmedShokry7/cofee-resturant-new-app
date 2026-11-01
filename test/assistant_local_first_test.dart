// The assistant answers locally, and answers fast.
//
// Two rules are pinned here:
//
//   1. Opening the assistant never waits for the network. The greeting goes
//      out first and the catalogue arrives behind it.
//   2. Everyday Arabic is answered by the local engine. A question that
//      reaches the language model is a question the app could have answered
//      on its own.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'support/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

/// A catalogue that takes its time, like a real one on a phone.
class _SlowCatalog implements CatalogRepository {
  _SlowCatalog(this._inner, {this.delay = const Duration(seconds: 5)});

  final CatalogRepository _inner;
  final Duration delay;

  int productReads = 0;

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    productReads++;
    await Future<void>.delayed(delay);
    return _inner.getProducts(
      branchId: branchId,
      categoryId: categoryId,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Map<String, List<OptionGroup>>> getOptionsByProduct(
    List<String> productIds,
  ) => _inner.getOptionsByProduct(productIds);

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) =>
      _inner.getById(id, branchId: branchId);

  @override
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId}) =>
      _inner.getWithOptions(id, branchId: branchId);

  @override
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) => _inner.search(
    query,
    branchId: branchId,
    categoryId: categoryId,
    sort: sort,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) => _inner.getFeatured(branchId: branchId, limit: limit);

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) => _inner.getBestSellers(
    branchId: branchId,
    period: period,
    limit: limit,
  );

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) => _inner.resolvePrice(
    productId,
    branchId: branchId,
    optionValueIds: optionValueIds,
  );

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) =>
      _inner.getBanners(limit: limit);

  @override
  Future<List<BundleModel>> getBundles({String? branchId, int limit = 20}) =>
      _inner.getBundles(branchId: branchId, limit: limit);

  @override
  Future<BundleModel?> getBundleById(String id) => _inner.getBundleById(id);

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) =>
      _inner.getCategories(includeInactive: includeInactive);

  @override
  Future<CategoryModel?> getCategoryById(String id) =>
      _inner.getCategoryById(id);

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) =>
      _inner.getCategoryBySlug(slug);

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) =>
      _inner.getCategoryChildren(parentId);
}

/// No order history, and none of the write paths are ever used.
class _NoOrders implements OrdersRepository {
  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async {}

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) async => throw UnimplementedError();

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  group('opening the assistant', () {
    test('the greeting arrives without waiting for the catalogue', () async {
      // The catalogue takes five seconds. The greeting must not.
      final catalog = _SlowCatalog(const MockProductRepository());
      final cubit = AssistantCubit(catalog: catalog, orders: _NoOrders());
      addTearDown(cubit.close);

      final stopwatch = Stopwatch()..start();
      await cubit.start();
      stopwatch.stop();

      expect(
        cubit.state.messages,
        isNotEmpty,
        reason: 'the customer must see the assistant right away',
      );
      expect(
        cubit.state.messages.first.role,
        MessageRole.assistant,
      );
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 1)),
        reason: 'the greeting must not wait for the network',
      );
      expect(
        catalog.productReads,
        greaterThan(0),
        reason: 'the catalogue still loads, just in the background',
      );
    });

    test('the catalogue is still ready when the first question arrives',
        () async {
      final catalog = _SlowCatalog(
        const MockProductRepository(),
        delay: const Duration(milliseconds: 10),
      );
      final cubit = AssistantCubit(catalog: catalog, orders: _NoOrders());
      addTearDown(cubit.close);
      await cubit.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await cubit.sendMessage('عايز اشرب ايه');

      final answer = cubit.state.messages.last;
      expect(answer.role, MessageRole.assistant);
      expect(answer.text, isNotEmpty);
      expect(
        cubit.state.products,
        isNotEmpty,
        reason: 'the local engine must be able to suggest real products',
      );
    });
  });

  group('answering locally', () {
    /// Everyday Arabic a customer actually types.
    const everyday = <String>[
      'عايز اشرب ايه',
      'عاوز حاجه حلوه',
      'رشحلي قهوه',
      'فين طلبي',
      'عايز اطلب لاتيه',
      'الاوردر وصل؟',
      'فيه عروض؟',
      'كام سعر اللاتيه',
      'ابغى مشروب',
      'نفس الطلب',
      'زي كل مره',
      'مش عاجبني',
      'غالي اوي',
      'ممكن اجرب',
      'عايز حاجه فيها شوكولاتة',
      'عايز اضيف للسلة',
      'تمام',
      'ايوه',
      'لا',
      'شكرا',
      'مع السلامه',
      'انت مين',
      'ابي شي حلو',
      'وش تنصحني',
      'ابغى اطلب',
      'وين طلبي',
      'كم سعره',
      'عطني كابتشينو',
      'ابي حاجه قويه',
      'زين',
      'يعطيك العافيه',
      'وش هو الطلب',
      'ابي اضيف للسلة',
      'اوكي',
      'طيب',
      'يا هلا',
      'بدي اشرب شي',
      'شو بتنصحني',
      'فين طلبي',
      'بدي حاجه حلوه',
      'كيفك',
      'ماشي',
      'ابغى اشرب ايه',
      'عاوز ترشيح',
      'فين العروض',
      'عايز اطممن',
      'عايز حاجه ب 20 ريال',
      'ابغى كافيه',
      'عندكم قهوه بارده',
      'عايز اقول حاجة',
      'ابغى اعرف',
      'عندي قهوه احسن عندكم؟',
      'بكم الكوباية',
      'عايز حاجه من غير سكر',
      'عايز لاتيه كبير',
      'لو سمحت ساعدني',
      'ممكن اجرب حاجة جديده',
      'شو فيه اليوم',
      'عندكم حلا؟',
      'عايز حلو',
      'ابي مشروب بارد',
      'كمان فيه عروض؟',
      'عايز اعرف احسن قهوه',
      'الناس بتاخد ايه',
      'وش اللى بيعجب الناس',
    ];

    test('everyday Arabic is answered without the language model', () async {
      final snapshot = await AssistantSnapshot.load(
        catalog: const MockProductRepository(),
        activeOrders: () async => const <OrderItemModel>[],
      );

      final handedToTheModel = <String>[];
      for (final query in everyday) {
        // A fresh memory per question: the draft from one question would
        // otherwise steer the next one.
        final memory = AssistantMemory(replyArabic: true);
        final answer = AssistantEngine.answer(
          query,
          snapshot: snapshot,
          memory: memory,
          now: DateTime.now(),
        );
        if (answer.topic == 'fallback' || answer.topic == 'unknown') {
          handedToTheModel.add(query);
        }
      }

      expect(
        handedToTheModel,
        isEmpty,
        reason: 'these questions must be answered on the device',
      );
    });

    test('a short word is not recovered from an unrelated keyword', () {
      // "زين" (good) is one letter away from "فين" (where). Recovering the
      // order tracker for it sent the customer to the wrong screen.
      expect(detectIntent('زين'), AssistantIntent.affirm);

      // A short word that is only one letter away from a keyword must not
      // pick an intent at all: one typo is not a question.
      expect(recoverIntent('فبن'), isNull);
    });

    test('"what do people order" is a suggestion, not a yes', () {
      expect(detectIntent('الناس بتاخد ايه'), AssistantIntent.suggestDrink);
      expect(detectIntent('وش اللى بيعجب الناس'), AssistantIntent.suggestDrink);
    });

    test('a greeting for help is a greeting', () {
      expect(detectIntent('لو سمحت ساعدني'), AssistantIntent.greeting);
    });

    test('"ايه" is a question, not a yes', () {
      // "ايه" means "yes" in Saudi and "what" in Egyptian. A question that
      // starts with it must not be answered with "yes please".
      expect(detectIntent('ايه رأيك في طقس اليوم؟'), AssistantIntent.unknown);
      expect(recoverIntent('ايه رأيك في طقس اليوم؟'), isNull);
      // A short "yes" still is a yes.
      expect(detectIntent('ايه'), AssistantIntent.affirm);
      expect(detectIntent('ايه تمام'), AssistantIntent.affirm);
    });
  });
}
