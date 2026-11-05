import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/option_groups/data/repositories/admin_product_option_repository.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';

/// مسار تسعير الأحجام والإضافات على القاعدة الحيّة بجلسة موظف حقيقية.
///
/// السياسيّات هي التي تقرّر: الكتابة تُقرأ من جديد عبر
/// `catalog.effective_product_option_groups` (224) و`option_value_delta` (229).
/// يُتخطّى الاختبار حين لا تُسمّى البيئة:
///
///   E2E_SUPABASE_URL=... E2E_SUPABASE_KEY=... \
///   E2E_ADMIN_EMAIL=... E2E_ADMIN_PASSWORD=... \
///   flutter test test/product_option_pricing_e2e_test.dart
void main() {
  final url = const String.fromEnvironment('E2E_SUPABASE_URL');
  final key = const String.fromEnvironment('E2E_SUPABASE_KEY');
  final email = const String.fromEnvironment('E2E_ADMIN_EMAIL');
  final password = const String.fromEnvironment('E2E_ADMIN_PASSWORD');

  final canRun =
      url.isNotEmpty &&
      key.isNotEmpty &&
      email.isNotEmpty &&
      password.isNotEmpty;

  test(
    'a staff session prices a size of one product and links a group',
    () async {
      final client = SupabaseClient(url, key);
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(email: email, password: password);

      final catalog = AdminProductRepository(client);
      final snapshot = await catalog.loadCatalog();
      expect(snapshot.categories, isNotEmpty);

      // مشروب واحد يُعاد استخدامه: الاسم الإنجليزي يولّد المعرف، فالبحث به
      // يجعل للمشروب صفًّا واحدًا بدل صفٍّ عن كل تشغيل.
      const slug = 'option-pricing-e2e';
      final saved = snapshot.products.where((p) => p.slug == slug);
      final product = saved.isEmpty
          ? await catalog.saveProduct(
              AdminProduct.draft(slug).copyWith(
                nameAr: 'منتج تسعير الخيارات',
                nameEn: 'Option pricing E2E',
                basePrice: 20,
                categoryId: snapshot.categories.first.id,
              ),
              branchId: snapshot.branchId,
            )
          : saved.first;
      final options = AdminProductOptionRepository(client);
      addTearDown(() => _cleanUp(client, product.id));

      // 1. المشروب لا يمسك مجموعة: نطاقهما `products` وصفُّها هو الوصل.
      final opened = await options.loadForProduct(product.id);
      expect(opened, isNotEmpty, reason: 'كل مجموعة نشطة تُعرض للوحة');
      final group = _withValues(opened);
      expect(group.isAttached, isFalse, reason: 'لم يُوصَل بها بعد');

      // 2. الوصل يكتب صفَّه، و224 يجيب المشروب به.
      await options.setGroupAttached(product.id, group.id, true);
      final linked = _groupOf(
        await options.loadForProduct(product.id),
        group.id,
      );
      expect(linked.isAttached, isTrue);
      expect(linked.hasValues, isTrue);

      // 3. تجاوز السعر لهذا المشروب وحده يسري على جواب القاعدة.
      final value = linked.values.first;
      await options.setValuePrice(product.id, value.id, 7.5);
      final priced = _valueOf(
        await options.loadForProduct(product.id),
        value.id,
      );
      expect(priced.overrideDelta, 7.5);
      expect(priced.effectiveDelta, 7.5, reason: 'التجاوز يحكم زيادة المجموعة');

      // 4. الامحاء رجوع إلى زيادة المجموعة، لا صفر.
      await options.setValuePrice(product.id, value.id, null);
      final cleared = _valueOf(
        await options.loadForProduct(product.id),
        value.id,
      );
      expect(cleared.overrideDelta, isNull);
      expect(cleared.effectiveDelta, cleared.groupDelta);

      // 5. الفصل يمحُ الصفّ، فيعود المشروب لا يرى المجموعة.
      await options.setGroupAttached(product.id, group.id, false);
      expect(
        _groupOf(await options.loadForProduct(product.id), group.id).isAttached,
        isFalse,
      );
    },
    skip: canRun
        ? false
        : 'Set E2E_SUPABASE_URL, E2E_SUPABASE_KEY, E2E_ADMIN_EMAIL and '
              'E2E_ADMIN_PASSWORD to run it against the development project.',
  );
}

AdminProductOptionGroup _withValues(Iterable<AdminProductOptionGroup> groups) {
  for (final group in groups) {
    if (group.hasValues) return group;
  }
  throw StateError('no group offered has a value');
}

AdminProductOptionGroup _groupOf(
  List<AdminProductOptionGroup> groups,
  String id,
) => groups.firstWhere((g) => g.id == id);

AdminProductOptionValue _valueOf(
  List<AdminProductOptionGroup> groups,
  String id,
) {
  for (final group in groups) {
    for (final value in group.values) {
      if (value.id == id) return value;
    }
  }
  throw StateError('$id is gone');
}

/// يمحُو ما كتب الاختبار: صفَّي الوصل والتسعير يُمسحان من جسريهما اللذين
/// يُكتب عليهما، أمّا المشروب فيبقى للمرات القادمة.
Future<void> _cleanUp(SupabaseClient client, String productId) async {
  for (final table in [
    'product_option_value_pricing',
    'product_option_groups',
  ]) {
    try {
      await client.from(table).delete().eq('product_id', productId);
    } catch (error) {
      // التنظيف لا يُفشل الاختبار، لكنه لا يُمحى صمتًا.
      // ignore: avoid_print
      print('e2e cleanup refused on $table: $error');
    }
  }
}
