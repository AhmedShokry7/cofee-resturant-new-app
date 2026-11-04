import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/option_groups/data/repositories/admin_product_option_repository.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';

/// مسار تسعير الأحجام والإضافات على القاعدة الحيّة بجلسة موظف حقيقية.
///
/// السياسيّات هي التي تقرّر، لا اختبارات زائفة: الكتابة تُقرأ من جديد عبر
/// `catalog.effective_product_option_groups` (224) و`option_value_delta` (229).
/// يُنطّ حين لا تُسمّى البيئة:
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

      final product = await catalog.saveProduct(
        AdminProduct.draft(
          'e2e-options-${DateTime.now().microsecondsSinceEpoch}',
        ).copyWith(
          nameAr: 'منتج تسعير الخيارات',
          nameEn: 'Option pricing E2E',
          basePrice: 20,
          categoryId: snapshot.categories.first.id,
        ),
        branchId: snapshot.branchId,
      );
      final options = AdminProductOptionRepository(client);
      addTearDown(() => _cleanUp(client, product.id));

      // 1. المشروب الجديد يرى المجموعات العامّة موصولة وحدها.
      final first = await options.loadForProduct(product.id);
      expect(first, isNotEmpty, reason: 'كل مجموعة معروضة للوحة لها جواب');
      final attached = _withValues(first.where((g) => g.isAttached));
      expect(attached, isNotEmpty, reason: 'نطاق `all` يمسك المشروب الجديد');

      // 2. تجاوز السعر لهذا المشروب وحده يسري على جواب القاعدة.
      final value = attached.values.first;
      await options.setValuePrice(product.id, value.id, 7.5);
      final priced = _valueOf(
        await options.loadForProduct(product.id),
        value.id,
      );
      expect(priced.overrideDelta, 7.5);
      expect(priced.effectiveDelta, 7.5, reason: 'التجاوز يحكم زيادة المجموعة');

      // 3. الامحاء رجوع إلى زيادة المجموعة، لا صفر.
      await options.setValuePrice(product.id, value.id, null);
      final cleared = _valueOf(
        await options.loadForProduct(product.id),
        value.id,
      );
      expect(cleared.overrideDelta, isNull);
      expect(cleared.effectiveDelta, cleared.groupDelta);

      // 4. الوصل والفصل يكتبان صفًّا ويجيب 224 بالجواب الجديد.
      final loose = first.where(
        (g) => !g.isAttached && g.bindsProductsDirectly,
      );
      if (loose.isNotEmpty) {
        final group = loose.first;
        await options.setGroupAttached(product.id, group.id, true);
        expect(
          _groupOf(
            await options.loadForProduct(product.id),
            group.id,
          ).isAttached,
          isTrue,
        );
        await options.setGroupAttached(product.id, group.id, false);
        expect(
          _groupOf(
            await options.loadForProduct(product.id),
            group.id,
          ).isAttached,
          isFalse,
        );
      }
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
  throw StateError('no attached group has a value');
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

/// يمحُو ما كتب الاختبار ثم المشروب نفسه.
Future<void> _cleanUp(SupabaseClient client, String productId) async {
  try {
    await client
        .from('product_option_value_pricing')
        .delete()
        .eq('product_id', productId);
    await client
        .from('product_option_groups')
        .delete()
        .eq('product_id', productId);
    await client.from('catalog.products').delete().eq('id', productId);
  } catch (_) {
    // التنظيف لا يُفشل الاختبار.
  }
}
